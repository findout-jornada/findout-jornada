-- =====================================================================
-- Findout Jornada · Migration 0058 · Liga justa, corações no servidor e atividades blindadas
-- Rodar no SQL Editor depois da 0057. Idempotente.
--
--  Decisões do Artur (23 out 2026):
--   · XP do perfil, trilha, coroas e ofensiva: sem teto.
--   · XP que conta para a LIGA: até 600 por dia (parâmetro economia.tetoXpLigaDia).
--   · Moedas de lição: até 300 por dia (economia.tetoMoedasDia).
--   · Ritmo mínimo: 3 s por questão respondida, medido no servidor desde a última conclusão
--     (economia.segundosMinQuestao). Mais rápido que isso, a lição conta mas não dá XP nem moedas.
--   · Corações: o servidor desconta, na conclusão, os erros que o app não descontou durante a lição
--     (antes bastava o app não chamar perder_coracao para ter corações infinitos).
--   · Atividades com nota: as questões chegam ao aluno com código embaralhado; não dá mais para
--     achar a resposta procurando o id da questão no pacote publicado.
--  Os três números ficam em Economia e loja, no painel.
-- =====================================================================

alter table public.dias_aluno add column if not exists xp_liga int not null default 0;
alter table public.dias_aluno add column if not exists moedas_licoes int not null default 0;
alter table public.economia_aluno add column if not exists coracoes_pend int not null default 0;

-- valores padrão dos novos parâmetros (o que já estiver gravado vale mais)
update public.parametros
  set valor = '{"tetoXpLigaDia":600,"tetoMoedasDia":300,"segundosMinQuestao":3}'::jsonb || valor
  where chave = 'economia';

-- perder_coracao (chamado pelo app a cada erro) anota quantos já descontou nesta lição
create or replace function public.perder_coracao()
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); e public.economia_aluno; mx int;
begin
  if tem_plus(u) then return jsonb_build_object('coracoes', null, 'plus', true); end if;
  e := regenerar_coracoes(u);
  mx := coalesce((param('economia')->>'coracoes')::int, 5);
  update public.economia_aluno
    set coracoes = greatest(0, coracoes - 1),
        coracoes_em = case when coracoes = mx then now() else coracoes_em end,
        coracoes_pend = least(coracoes_pend + 1, 60)
    where user_id = u returning * into e;
  return jsonb_build_object('coracoes', e.coracoes, 'plus', false);
end $$;

-- concluir_licao: igual à da 0046, mais ritmo mínimo, tetos do dia e corações no servidor
create or replace function public.concluir_licao(
  p_modo text, p_licao uuid default null, p_unidade uuid default null, p_materia text default null,
  p_acertos int default 0, p_erros int default 0, p_melhor_combo int default 0, p_tempo_s int default 0,
  p_erradas uuid[] default '{}', p_acertadas uuid[] default '{}', p_sucesso boolean default true,
  p_tentativas jsonb default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := exigir_login(); ec jsonb := param('economia'); e public.economia_aluno;
  v_xp int := 0; v_moedas int := 0; linhas jsonb := '[]'::jsonb; nova boolean := false; passou boolean := p_sucesso;
  streak_antes int; praticou_hoje boolean; perfeita boolean; mat text := p_materia;
  bonus_combo int := 0; bonus_perf int := 0; lic public.licoes; cnt int; titulo text := '';
  ja_trofeu boolean; tem_pendente boolean; lim_cor int := coalesce((param('economia')->>'coracoesErrosDia')::int, 5);
  ev bigint;
  -- revisão 23 out: ritmo mínimo, tetos do dia e corações no servidor
  seg_min int := coalesce((ec->>'segundosMinQuestao')::int, 3);
  teto_liga int := coalesce((ec->>'tetoXpLigaDia')::int, 600);
  teto_moedas int := coalesce((ec->>'tetoMoedasDia')::int, 300);
  mx_cor int := coalesce((ec->>'coracoes')::int, 5);
  v_liga int := 0; gap numeric; dia public.dias_aluno; pend int; falta int; resta int;
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
  -- Ritmo mínimo, medido no servidor: desde a última conclusão, ao menos seg_min segundos por questão respondida.
  -- Ninguém lê e responde mais rápido que isso; abaixo, a lição conta como feita mas não dá XP nem moedas.
  select extract(epoch from now() - max(criado_em)) into gap from public.eventos_licao where user_id = u;
  if (p_acertos + p_erros) > 0 and gap is not null and gap < seg_min * (p_acertos + p_erros) then
    v_xp := 0; v_moedas := 0;
    linhas := linhas || jsonb_build_object('rotulo', 'Rápido demais para contar pontos', 'valor', '0 XP');
  end if;
  -- Tetos do dia: o XP do perfil não tem teto; o XP que conta para a liga e as moedas de lição têm.
  dia := preparar_dia(u);
  v_liga := least(v_xp, greatest(0, teto_liga - coalesce(dia.xp_liga, 0)));
  if v_liga < v_xp then
    linhas := linhas || jsonb_build_object('rotulo', 'Liga: máximo de hoje (' || teto_liga || ' XP) já garantido', 'valor', 'XP vai só para o perfil');
  end if;
  resta := greatest(0, teto_moedas - coalesce(dia.moedas_licoes, 0));
  if v_moedas > resta then
    v_moedas := resta;
    linhas := linhas || jsonb_build_object('rotulo', 'Moedas: máximo de hoje atingido', 'valor', case when resta > 0 then '+' || resta else '0' end);
  end if;
  -- Corações no servidor: os erros que o app não descontou (perder_coracao) são descontados aqui.
  if p_modo in ('licao','pratica','revisao','unidade','relampago','lendaria') and not tem_plus(u) then
    select coracoes_pend into pend from public.economia_aluno where user_id = u;
    falta := greatest(0, p_erros - coalesce(pend, 0));
    if falta > 0 then
      update public.economia_aluno set coracoes = greatest(0, coracoes - falta),
        coracoes_em = case when coracoes >= mx_cor then now() else coracoes_em end where user_id = u;
    end if;
  end if;
  update public.economia_aluno set coracoes_pend = 0 where user_id = u;
  if v_moedas > 0 then linhas := linhas || jsonb_build_object('rotulo', 'Moedas ganhas', 'valor', '+' || v_moedas); end if;

  -- grava economia, dia, ofensiva, erros, liga, evento
  update public.economia_aluno set xp = economia_aluno.xp + v_xp, xp_semana = xp_semana + v_liga, xp_mes = xp_mes + v_xp, moedas = economia_aluno.moedas + v_moedas
    where user_id = u;
  perform preparar_dia(u);
  update public.dias_aluno set
      xp = dias_aluno.xp + v_xp,
      xp_liga = dias_aluno.xp_liga + v_liga,
      moedas_licoes = dias_aluno.moedas_licoes + v_moedas,
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
  update public.liga_participantes set xp = liga_participantes.xp + v_liga where user_id = u and liga_id = entrar_liga(u);
  insert into public.eventos_licao (user_id, modo, licao_id, unidade_id, acertos, erros, melhor_combo, tempo_s, xp, moedas)
    values (u, p_modo, p_licao, p_unidade, p_acertos, p_erros, p_melhor_combo, p_tempo_s, v_xp, v_moedas)
    returning id into ev;

  -- tentativa por questão (novo): valida cada item e ignora o que não fizer sentido
  if p_tentativas is not null and jsonb_typeof(p_tentativas) = 'array' then
    insert into public.tentativas (user_id, evento_id, questao_id, licao_id, unidade_id, materia_id, modo, correta, tentativa, tempo_s, resposta)
    select u, ev, t.q, p_licao, p_unidade, mat, p_modo, t.ok,
           least(greatest(coalesce(t.n, 1), 1), 20),
           least(greatest(coalesce(t.t, 0), 0), 600),
           left(t.r, 200)
    from jsonb_to_recordset(p_tentativas) as t(q uuid, ok boolean, t int, n int, r text)
    where t.q is not null and t.ok is not null
      and exists (select 1 from public.questoes qq where qq.id = t.q)
    limit 100;
  end if;

  return jsonb_build_object(
    'xp', v_xp, 'xpLiga', v_liga, 'moedas', v_moedas, 'linhas', linhas, 'passou', passou, 'nova', nova, 'titulo', titulo,
    'precisao', case when p_acertos + p_erros = 0 then 100 else round(100.0 * p_acertos / (p_acertos + p_erros)) end,
    'ofensivaSubiu', passou and not praticou_hoje, 'ofensiva', ofensiva(u), 'ofensivaAntes', streak_antes,
    'estado', estado_aluno()
  );
end $$;

grant execute on function public.concluir_licao(text, uuid, uuid, text, int, int, int, int, uuid[], uuid[], boolean, jsonb) to authenticated;

-- ---------- Atividades: código embaralhado por atividade ----------
-- O aluno recebe md5(atividade:questão) no lugar do id do banco. Na entrega, o código volta
-- a ser o id real antes da correção (respostas com o id real, de app antigo, também valem).
create or replace function public.fj_ativ_qid(p_atividade uuid, p_qid text)
returns text language sql immutable set search_path = public as $$ select md5(p_atividade::text || ':' || coalesce(p_qid, '')) $$;
revoke execute on function public.fj_ativ_qid(uuid, text) from public, anon, authenticated;

create or replace function public.abrir_atividade(p_atividade uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); a public.atividades; e public.atividade_entregas; q jsonb; d jsonb; sq jsonb; lista jsonb := '[]'::jsonb;
begin
  select * into a from public.atividades where id = p_atividade;
  if not found or a.status = 'rascunho' then raise exception 'Atividade não encontrada.'; end if;
  if not aluno_da_turma(a.turma_id) then raise exception 'Você não está na turma desta atividade.' using errcode = '42501'; end if;
  if a.status = 'encerrada' or (a.prazo is not null and a.prazo < now()) then raise exception 'O prazo desta atividade acabou.'; end if;
  select * into e from public.atividade_entregas where atividade_id = a.id and user_id = u;
  if found and e.entregue_em is not null then raise exception 'Você já entregou esta atividade.'; end if;
  if not found then insert into public.atividade_entregas (atividade_id, user_id) values (a.id, u); end if;
  for q in select * from jsonb_array_elements(a.questoes) loop
    d := q->'dados';
    sq := case q->>'tipo'
      when 'mc' then jsonb_build_object('opts', (select jsonb_agg(v order by random()) from jsonb_array_elements(d->'opts') v))
      when 'tf' then jsonb_build_object('stmt', d->'stmt')
      when 'bank' then jsonb_build_object('parts', d->'parts',
        'words', (select jsonb_agg(v order by random()) from jsonb_array_elements(coalesce(d->'a', '[]'::jsonb) || coalesce(d->'extra', '[]'::jsonb)) v))
      when 'order' then jsonb_build_object('items', (select jsonb_agg(v order by random()) from jsonb_array_elements(d->'items') v))
      when 'match' then jsonb_build_object(
        'left',  (select jsonb_agg(v->0 order by random()) from jsonb_array_elements(d->'pairs') v),
        'right', (select jsonb_agg(v->1 order by random()) from jsonb_array_elements(d->'pairs') v))
      else '{}'::jsonb end;
    lista := lista || jsonb_build_object('id', fj_ativ_qid(a.id, q->>'id'), 'tipo', q->'tipo', 'enunciado', q->'enunciado',
      'imagem', q->'imagem', 'valor', q->'valor', 'dados', sq);
  end loop;
  return jsonb_build_object('id', a.id, 'titulo', a.titulo, 'descricao', a.descricao, 'materia', a.materia_id,
    'prazo', a.prazo, 'questoes', lista, 'cega', true);
end $$;
grant execute on function public.abrir_atividade(uuid) to authenticated;

create or replace function public.entregar_atividade(p_atividade uuid, p_respostas jsonb default '[]'::jsonb, p_tempo_s int default 0)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := exigir_login(); a public.atividades; e public.atividade_entregas; c jsonb;
  v_acertos int; v_total int; v_nota numeric; v_xp int; linhas jsonb := '[]'::jsonb; praticou_hoje boolean; mat text;
begin
  select * into a from public.atividades where id = p_atividade;
  if not found or a.status = 'rascunho' then raise exception 'Atividade não encontrada.'; end if;
  if not aluno_da_turma(a.turma_id) then raise exception 'Você não está na turma desta atividade.' using errcode = '42501'; end if;
  select * into e from public.atividade_entregas where atividade_id = a.id and user_id = u for update;
  if found and e.entregue_em is not null then raise exception 'Você já entregou esta atividade.'; end if;
  if a.status = 'encerrada' or (a.prazo is not null and a.prazo < now() - interval '10 minutes') then raise exception 'O prazo desta atividade acabou.'; end if;

  -- traduz o código embaralhado de volta para o id real (resposta com id real, de app antigo, passa direto)
  if jsonb_typeof(p_respostas) = 'array' then
    select coalesce(jsonb_agg(case when q.id is not null then r || jsonb_build_object('id', q.id) else r end), '[]'::jsonb) into p_respostas
    from jsonb_array_elements(p_respostas) r
    left join lateral (select x->>'id' as id from jsonb_array_elements(a.questoes) x where fj_ativ_qid(a.id, x->>'id') = r->>'id' limit 1) q on true;
  end if;
  c := fj_corrige_respostas(a.questoes, p_respostas);
  v_acertos := (c->>'acertos')::int; v_total := (c->>'total')::int; v_nota := (c->>'nota')::numeric;

  insert into public.atividade_entregas (atividade_id, user_id, respostas, acertos, total, pontos, pontos_total, nota, entregue_em, tempo_s)
    values (a.id, u, c->'corrigidas', v_acertos, v_total, (c->>'pontos')::numeric, (c->>'pontosTotal')::numeric, v_nota, now(), greatest(0, p_tempo_s))
    on conflict (atividade_id, user_id) do update
      set respostas = excluded.respostas, acertos = excluded.acertos, total = excluded.total, pontos = excluded.pontos,
          pontos_total = excluded.pontos_total, nota = excluded.nota, entregue_em = now(), tempo_s = excluded.tempo_s;

  -- XP: base por atividade + 2 por acerto. Conta para ofensiva, missões (xp) e liga.
  v_xp := coalesce((param('economia')->>'xpAtividade')::int, 20) + v_acertos * 2;
  praticou_hoje := exists (select 1 from public.ofensiva_dias where user_id = u and dia = hoje());
  mat := a.materia_id;
  perform regenerar_coracoes(u);
  update public.economia_aluno set xp = economia_aluno.xp + v_xp, xp_semana = xp_semana + v_xp, xp_mes = xp_mes + v_xp where user_id = u;
  perform preparar_dia(u);
  update public.dias_aluno set xp = dias_aluno.xp + v_xp,
      materias = case when mat is not null and not (mat = any(materias)) then array_append(materias, mat) else materias end,
      minutos = minutos + greatest(0, p_tempo_s / 60)
    where user_id = u and dia = hoje();
  insert into public.ofensiva_dias (user_id, dia) values (u, hoje()) on conflict (user_id, dia) do update set tipo = 'praticou';
  update public.liga_participantes set xp = liga_participantes.xp + v_xp where user_id = u and liga_id = entrar_liga(u);
  insert into public.eventos_licao (user_id, modo, acertos, erros, tempo_s, xp, moedas) values (u, 'atividade', v_acertos, v_total - v_acertos, p_tempo_s, v_xp, 0);
  linhas := linhas || jsonb_build_object('rotulo', 'Atividade entregue', 'valor', '+' || (v_xp - v_acertos * 2) || ' XP');
  linhas := linhas || jsonb_build_object('rotulo', v_acertos || ' acertos de ' || v_total, 'valor', '+' || (v_acertos * 2) || ' XP');
  linhas := linhas || jsonb_build_object('rotulo', 'Nota', 'valor', replace(v_nota::text, '.', ','));

  return jsonb_build_object('acertos', v_acertos, 'total', v_total, 'nota', v_nota, 'xp', v_xp, 'moedas', 0, 'linhas', linhas,
    'precisao', case when v_total = 0 then 100 else round(100.0 * v_acertos / v_total) end,
    'ofensivaSubiu', not praticou_hoje, 'estado', estado_aluno());
end $$;

grant execute on function public.entregar_atividade(uuid, jsonb, int) to authenticated;

insert into public.schema_versao (versao) values (58) on conflict do nothing;
