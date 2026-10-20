-- =====================================================================
-- Findout Jornada · Migration 0020 · Fechamento das ligas e travas anti-fraude
-- Rodar no SQL Editor depois da 0019. Idempotente.
--
--  · fechar_ligas(): toda segunda 00h10 (horário de Brasília, via pg_cron)
--    as ligas da semana anterior fecham de verdade: os N melhores sobem,
--    os N últimos caem (nos limites Bronze/topo), top 3 ganha as moedas,
--    tudo pelos parâmetros da aba Ligas do painel (sobem, caem, moedasTop3).
--    O XP da semana (economia_aluno.xp_semana) zera junto, então o ranking
--    da turma volta a ser semanal de fato.
--  · concluir_licao() com travas no servidor (antes confiava no cliente):
--    acertos/erros/combo/tempo com teto; relâmpago só paga 1 vez por dia;
--    prova lendária só paga moedas na primeira conquista da unidade;
--    pular unidade só paga se a unidade ainda tinha lição pendente;
--    praticar erros devolve no máximo 5 corações por dia (parâmetro
--    economia.coracoesErrosDia).
--  · Perfis: aluno só lê o próprio perfil (educador e admin seguem lendo
--    todos). Ranking e listas não mudam: eles vêm de funções do servidor.
--  · Questões: só educador e admin leem a tabela (o aluno usa o pacote
--    publicado; antes qualquer logado lia gabarito e rascunhos).
--  · Índices que faltavam nas consultas mais comuns.
-- =====================================================================

-- ---------------------------------------------------------------
-- Corações ganhos no dia praticando erros (para o teto diário)
-- ---------------------------------------------------------------
alter table public.dias_aluno add column if not exists coracoes_erros int not null default 0;

-- ---------------------------------------------------------------
-- concluir_licao com travas (substitui a versão da 0002)
-- ---------------------------------------------------------------
create or replace function public.concluir_licao(
  p_modo text, p_licao uuid default null, p_unidade uuid default null, p_materia text default null,
  p_acertos int default 0, p_erros int default 0, p_melhor_combo int default 0, p_tempo_s int default 0,
  p_erradas uuid[] default '{}', p_acertadas uuid[] default '{}', p_sucesso boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := exigir_login(); ec jsonb := param('economia'); e public.economia_aluno;
  v_xp int := 0; v_moedas int := 0; linhas jsonb := '[]'::jsonb; nova boolean := false; passou boolean := p_sucesso;
  streak_antes int; praticou_hoje boolean; perfeita boolean; mat text := p_materia;
  bonus_combo int := 0; bonus_perf int := 0; lic public.licoes; cnt int; titulo text := '';
  ja_trofeu boolean; tem_pendente boolean; lim_cor int := coalesce((param('economia')->>'coracoesErrosDia')::int, 5);
begin
  if p_modo not in ('licao','pratica','revisao','erros','unidade','relampago','lendaria','pular') then
    raise exception 'Modo inválido: %', p_modo;
  end if;
  -- travas: o cliente não dita números fora do plausível
  p_acertos := least(greatest(coalesce(p_acertos, 0), 0), 60);
  p_erros := least(greatest(coalesce(p_erros, 0), 0), 60);
  p_melhor_combo := least(greatest(coalesce(p_melhor_combo, 0), 0), p_acertos);
  p_tempo_s := least(greatest(coalesce(p_tempo_s, 0), 0), 7200);
  perfeita := p_erros = 0;
  e := regenerar_coracoes(u);
  streak_antes := ofensiva(u);
  praticou_hoje := exists (select 1 from public.ofensiva_dias where user_id = u and dia = hoje());
  if p_licao is not null then
    select * into lic from public.licoes where id = p_licao;
    if found then p_unidade := lic.unidade_id; titulo := lic.titulo; end if;
  end if;
  if mat is null and p_unidade is not null then
    select s.materia_id into mat from public.unidades un join public.secoes s on s.id = un.secao_id where un.id = p_unidade;
  end if;

  if p_modo = 'licao' then
    nova := not exists (select 1 from public.progresso where user_id = u and licao_id = p_licao);
    if nova then
      v_xp :=(ec->>'xpLicao')::int; v_moedas :=(ec->>'moedasLicao')::int;
      insert into public.progresso (user_id, licao_id, coroas) values (u, p_licao, 1);
      linhas := linhas || jsonb_build_object('rotulo', 'Lição concluída', 'valor', '+' || v_xp || ' XP');
    else
      v_xp :=(ec->>'xpPratica')::int; v_moedas :=greatest(1, (ec->>'moedasLicao')::int / 2);
      update public.progresso set coroas = least(5, coroas + 1), concluida_em = now() where user_id = u and licao_id = p_licao;
      linhas := linhas || jsonb_build_object('rotulo', 'Lição praticada', 'valor', '+' || v_xp || ' XP');
    end if;
  elsif p_modo = 'pratica' then
    v_xp :=(ec->>'xpPratica')::int; v_moedas :=greatest(1, (ec->>'moedasLicao')::int / 2);
    linhas := linhas || jsonb_build_object('rotulo', 'Prática', 'valor', '+' || v_xp || ' XP');
  elsif p_modo = 'revisao' then
    v_xp :=(ec->>'xpRevisao')::int; v_moedas :=(ec->>'moedasRevisao')::int;
    linhas := linhas || jsonb_build_object('rotulo', 'Revisão diária', 'valor', '+' || v_xp || ' XP');
    update public.dias_aluno set revisao = true where user_id = u and dia = hoje();
  elsif p_modo = 'erros' then
    v_xp :=(ec->>'xpErros')::int; v_moedas :=5;
    linhas := linhas || jsonb_build_object('rotulo', 'Prática de erros', 'valor', '+' || v_xp || ' XP');
    perform preparar_dia(u);
    select coracoes_erros into cnt from public.dias_aluno where user_id = u and dia = hoje();
    if not tem_plus(u) and e.coracoes < (ec->>'coracoes')::int and coalesce(cnt, 0) < lim_cor then
      update public.economia_aluno set coracoes = coracoes + 1 where user_id = u;
      update public.dias_aluno set coracoes_erros = coracoes_erros + 1 where user_id = u and dia = hoje();
      linhas := linhas || jsonb_build_object('rotulo', 'Coração recuperado', 'valor', '+1');
    end if;
  elsif p_modo = 'unidade' then
    v_xp :=(ec->>'xpErros')::int; v_moedas :=5;
    linhas := linhas || jsonb_build_object('rotulo', 'Revisão da unidade', 'valor', '+' || v_xp || ' XP');
  elsif p_modo = 'relampago' then
    if e.relampago_em = hoje() then
      v_xp := 0; v_moedas := 0;
      linhas := linhas || jsonb_build_object('rotulo', 'Relâmpago de hoje já feito', 'valor', '0 XP');
    else
      v_xp :=least(p_acertos, 40) * ((ec->>'xpExercicio')::int / 2) * (ec->>'multiplicadorRelampago')::int; v_moedas :=5;
      linhas := linhas || jsonb_build_object('rotulo', p_acertos || ' acertos × ' || (ec->>'multiplicadorRelampago') || '', 'valor', '+' || v_xp || ' XP');
    end if;
    update public.economia_aluno set relampago_em = hoje() where user_id = u;
  elsif p_modo = 'lendaria' then
    if passou then
      ja_trofeu := exists (select 1 from public.conquistas_unidade where user_id = u and unidade_id = p_unidade and trofeu_em is not null);
      if ja_trofeu then
        linhas := linhas || jsonb_build_object('rotulo', 'Troféu já conquistado antes', 'valor', '0 XP');
      else
        v_xp :=(ec->>'xpLendaria')::int; v_moedas :=(ec->>'moedasLendaria')::int;
        linhas := linhas || jsonb_build_object('rotulo', 'Prova sem erros', 'valor', '+' || v_xp || ' XP');
      end if;
      insert into public.conquistas_unidade (user_id, unidade_id, trofeu_em) values (u, p_unidade, now())
        on conflict (user_id, unidade_id) do update set trofeu_em = coalesce(public.conquistas_unidade.trofeu_em, now());
    else
      linhas := linhas || jsonb_build_object('rotulo', 'Um erro encerra a prova', 'valor', '0 XP');
    end if;
  elsif p_modo = 'pular' then
    passou := p_acertos >= (ec->>'acertosPular')::int;
    if passou then
      tem_pendente := exists (select 1 from public.licoes l where l.unidade_id = p_unidade
        and not exists (select 1 from public.progresso pr where pr.user_id = u and pr.licao_id = l.id));
      if tem_pendente then
        v_xp :=(ec->>'xpPular')::int; v_moedas :=(ec->>'moedasPular')::int;
        linhas := linhas || jsonb_build_object('rotulo', 'Teste aprovado (' || p_acertos || '/' || (ec->>'questoesPular') || ')', 'valor', '+' || v_xp || ' XP');
      else
        linhas := linhas || jsonb_build_object('rotulo', 'Unidade já estava concluída', 'valor', '0 XP');
      end if;
      -- marca todas as lições da unidade pulada como concluídas (1 coroa)
      insert into public.progresso (user_id, licao_id, coroas)
        select u, l.id, 1 from public.licoes l where l.unidade_id = p_unidade on conflict do nothing;
      insert into public.conquistas_unidade (user_id, unidade_id, pulada_em) values (u, p_unidade, now())
        on conflict (user_id, unidade_id) do update set pulada_em = now();
    else
      linhas := linhas || jsonb_build_object('rotulo', 'Precisa de ' || (ec->>'acertosPular') || ' acertos', 'valor', '0 XP');
    end if;
  end if;

  -- bônus (só nos modos de lição comum)
  if passou and p_modo in ('licao','pratica','revisao','erros','unidade') then
    if p_melhor_combo >= (ec->>'comboAPartirDe')::int then bonus_combo := (ec->>'bonusCombo')::int; end if;
    if perfeita then bonus_perf := (ec->>'bonusPerfeita')::int; end if;
    v_xp := v_xp + bonus_combo + bonus_perf;
    linhas := linhas || jsonb_build_object('rotulo', 'Bônus de combo (' || p_melhor_combo || ' seguidos)', 'valor', case when bonus_combo > 0 then '+' || bonus_combo || ' XP' else '—' end);
    linhas := linhas || jsonb_build_object('rotulo', 'Bônus de lição perfeita', 'valor', case when bonus_perf > 0 then '+' || bonus_perf || ' XP' else '— (' || p_erros || ' erro' || case when p_erros = 1 then '' else 's' end || ')' end);
  end if;
  if v_moedas > 0 then linhas := linhas || jsonb_build_object('rotulo', 'Moedas ganhas', 'valor', '+' || v_moedas); end if;

  -- grava economia, dia, ofensiva, erros, liga, evento
  update public.economia_aluno set xp = economia_aluno.xp + v_xp, xp_semana = xp_semana + v_xp, xp_mes = xp_mes + v_xp, moedas = economia_aluno.moedas + v_moedas
    where user_id = u;
  perform preparar_dia(u);
  update public.dias_aluno set
      xp = dias_aluno.xp + v_xp,
      melhor_combo = greatest(melhor_combo, p_melhor_combo),
      materias = case when mat is not null and not (mat = any(materias)) then array_append(materias, mat) else materias end,
      licoes = licoes + case when p_modo in ('licao','pratica') then 1 else 0 end,
      perfeitas = perfeitas + case when perfeita and passou and p_modo in ('licao','pratica') then 1 else 0 end,
      minutos = minutos + greatest(0, p_tempo_s / 60)
    where user_id = u and dia = hoje();
  if passou then
    insert into public.ofensiva_dias (user_id, dia) values (u, hoje()) on conflict (user_id, dia) do update set tipo = 'praticou';
  end if;
  insert into public.erros (user_id, questao_id) select u, x from unnest(p_erradas) x on conflict (user_id, questao_id) do update set errado_em = now();
  if p_modo = 'erros' then delete from public.erros where user_id = u and questao_id = any(p_acertadas); end if;
  update public.liga_participantes set xp = liga_participantes.xp + v_xp where user_id = u and liga_id = entrar_liga(u);
  insert into public.eventos_licao (user_id, modo, licao_id, unidade_id, acertos, erros, melhor_combo, tempo_s, xp, moedas)
    values (u, p_modo, p_licao, p_unidade, p_acertos, p_erros, p_melhor_combo, p_tempo_s, v_xp, v_moedas);

  return jsonb_build_object(
    'xp', v_xp, 'moedas', v_moedas, 'linhas', linhas, 'passou', passou, 'nova', nova, 'titulo', titulo,
    'precisao', case when p_acertos + p_erros = 0 then 100 else round(100.0 * p_acertos / (p_acertos + p_erros)) end,
    'ofensivaSubiu', passou and not praticou_hoje, 'ofensiva', ofensiva(u), 'ofensivaAntes', streak_antes,
    'estado', estado_aluno()
  );
end $$;

-- ---------------------------------------------------------------
-- Fecha as ligas das semanas anteriores: grava subiu/manteve/caiu
-- e paga as moedas do top 3. Idempotente (só mexe em quem está sem
-- resultado). entrar_liga() já usa o resultado para o nível seguinte.
-- ---------------------------------------------------------------
create or replace function public.fechar_ligas()
returns int language plpgsql security definer set search_path = public as $$
declare
  lg record; cfg jsonb := param('ligas'); sobem int; caem int; topo int; moedas_top3 int; fechadas int := 0;
begin
  sobem := coalesce((cfg->>'sobem')::int, 7);
  caem := coalesce((cfg->>'caem')::int, 5);
  topo := coalesce(jsonb_array_length(cfg->'niveis'), 7) - 1;
  moedas_top3 := coalesce((cfg->>'moedasTop3')::int, 0);
  for lg in select l.id, l.nivel from public.ligas l
    where l.semana < semana_atual()
      and exists (select 1 from public.liga_participantes p where p.liga_id = l.id and p.resultado is null)
  loop
    -- sobe quem pontuou e ficou no top N (fora do topo); cai quem ficou nos
    -- últimos N (fora da Bronze), só em liga cheia o bastante para ter zona
    with r as (
      select p.user_id, p.xp, row_number() over (order by p.xp desc, p.user_id) pos, count(*) over () tot
      from public.liga_participantes p where p.liga_id = lg.id
    )
    update public.liga_participantes p set resultado = case
        when lg.nivel < topo and r.pos <= sobem and r.xp > 0 then 'subiu'
        when lg.nivel > 0 and r.tot > sobem + caem and r.pos > r.tot - caem then 'caiu'
        else 'manteve' end
      from r where p.liga_id = lg.id and p.user_id = r.user_id and p.resultado is null;
    if moedas_top3 > 0 then
      update public.economia_aluno e set moedas = e.moedas + moedas_top3
        from (select p.user_id from public.liga_participantes p where p.liga_id = lg.id and p.xp > 0
              order by p.xp desc, p.user_id limit 3) t
        where e.user_id = t.user_id;
    end if;
    fechadas := fechadas + 1;
  end loop;
  return fechadas;
end $$;
revoke execute on function public.fechar_ligas() from public, anon, authenticated;

-- Agenda: toda segunda 03h10 UTC (00h10 em Brasília) fecha as ligas e zera o XP da semana.
-- Se der erro de permissão aqui, ative a extensão pg_cron em Database → Extensions e rode de novo.
create extension if not exists pg_cron;
do $$ begin perform cron.unschedule('fj-fechar-ligas'); exception when others then null; end $$;
select cron.schedule('fj-fechar-ligas', '10 3 * * 1',
  'select public.fechar_ligas(); update public.economia_aluno set xp_semana = 0 where xp_semana <> 0;');

-- ---------------------------------------------------------------
-- Perfis: aluno lê só o próprio; educador e admin leem todos
-- (ranking, listas e relatórios vêm de funções security definer)
-- ---------------------------------------------------------------
drop policy if exists perfis_ler on public.perfis;
create policy perfis_ler on public.perfis for select to authenticated
  using (user_id = auth.uid() or public.eh_educador());

-- Questões: só educador e admin leem a tabela (gabarito e rascunhos);
-- o aluno estuda pelo pacote publicado
drop policy if exists questoes_ler on public.questoes;
create policy questoes_ler on public.questoes for select to authenticated using (public.eh_educador());

-- ---------------------------------------------------------------
-- Índices que faltavam
-- ---------------------------------------------------------------
create index if not exists ligas_semana_nivel_idx on public.ligas (semana, nivel);
create index if not exists eventos_licao_quando_idx on public.eventos_licao (criado_em desc);
create index if not exists licao_questoes_questao_idx on public.licao_questoes (questao_id);
create index if not exists erros_questao_idx on public.erros (questao_id);
create index if not exists atividades_professor_idx on public.atividades (professor_id);
create index if not exists turmas_escola_idx on public.turmas (escola_id);
create index if not exists turma_professores_user_idx on public.turma_professores (user_id);
create index if not exists escola_membros_user_idx on public.escola_membros (user_id);
