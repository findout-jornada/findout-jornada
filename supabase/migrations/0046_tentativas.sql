-- =====================================================================
-- Findout Jornada · Migration 0046 · Tentativa por questão nas lições
-- Rodar no SQL Editor depois da 0045. Idempotente.
--
-- Primeira etapa do motor de aprendizagem personalizada: cada resposta
-- do aluno nas lições da trilha (e revisão, erros, relâmpago, provas)
-- vira uma linha em `tentativas` — questão, acertou ou não, tempo,
-- nº da tentativa na sessão e a resposta dada. É a matéria-prima das
-- próximas fases (domínio por habilidade, lacunas, recomendações).
-- As atividades de turma não passam por aqui: já guardam as respostas.
--
-- Ordem de publicação: rodar esta migration ANTES de publicar o app
-- novo (o app tem fallback, mas a ordem certa evita ruído).
-- =====================================================================

create table if not exists public.tentativas (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  evento_id bigint references public.eventos_licao(id) on delete cascade,  -- sessão em que aconteceu
  questao_id uuid references public.questoes(id) on delete set null,
  licao_id uuid references public.licoes(id) on delete set null,
  unidade_id uuid references public.unidades(id) on delete set null,
  materia_id text,
  modo text not null,            -- licao, pratica, revisao, erros, unidade, relampago, lendaria, pular
  correta boolean not null,
  tentativa int not null default 1,  -- nº da vez que viu esta questão na sessão (erro reapresenta)
  tempo_s int,                   -- segundos nesta questão (teto 600)
  resposta text,                 -- o que o aluno marcou, resumido (null = pulou)
  criado_em timestamptz not null default now()
);
create index if not exists tentativas_user_idx on public.tentativas(user_id, criado_em desc);
create index if not exists tentativas_questao_idx on public.tentativas(questao_id, criado_em desc);
create index if not exists tentativas_user_questao_idx on public.tentativas(user_id, questao_id, criado_em desc);

alter table public.tentativas enable row level security;
drop policy if exists tentativas_dono on public.tentativas;
create policy tentativas_dono on public.tentativas for select to authenticated using (user_id = auth.uid());
drop policy if exists tentativas_admin on public.tentativas;
create policy tentativas_admin on public.tentativas for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- concluir_licao ganha p_tentativas (assinatura muda: derruba a antiga)
drop function if exists public.concluir_licao(text, uuid, uuid, text, int, int, int, int, uuid[], uuid[], boolean);
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
    'xp', v_xp, 'moedas', v_moedas, 'linhas', linhas, 'passou', passou, 'nova', nova, 'titulo', titulo,
    'precisao', case when p_acertos + p_erros = 0 then 100 else round(100.0 * p_acertos / (p_acertos + p_erros)) end,
    'ofensivaSubiu', passou and not praticou_hoje, 'ofensiva', ofensiva(u), 'ofensivaAntes', streak_antes,
    'estado', estado_aluno()
  );
end $$;
grant execute on function public.concluir_licao(text, uuid, uuid, text, int, int, int, int, uuid[], uuid[], boolean, jsonb) to authenticated;

insert into public.schema_versao (versao) values (46) on conflict do nothing;
