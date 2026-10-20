-- =====================================================================
-- Findout Jornada · Migration 0024 · Nota manual e recorreção de atividade
-- Rodar no SQL Editor depois da 0023. Idempotente.
--
--  · definir_nota(): o professor (ou coordenador/admin da atividade) ajusta
--    a nota de um aluno — inclusive de quem não entregou pelo app (ex.: fez
--    em papel). A nota fica marcada como manual, guarda a nota corrigida
--    original e o motivo, e dá para restaurar a nota automática depois
--    (p_nota = null). Tudo vai para a auditoria.
--  · recorrigir_atividade(): corrige de novo todas as entregas com o
--    gabarito atual da atividade (útil depois de consertar uma questão).
--    Notas manuais não são tocadas. XP já pago não muda.
--  · fj_corrige_respostas(): a regra de correção vira uma função só, usada
--    pela entrega e pela recorreção (sem duplicar a lógica).
--  · resultados_atividade() passa a dizer quais notas são manuais.
-- =====================================================================

alter table public.atividade_entregas add column if not exists nota_manual boolean not null default false;
alter table public.atividade_entregas add column if not exists nota_original numeric(4,1);
alter table public.atividade_entregas add column if not exists nota_obs text;

-- ---------------------------------------------------------------
-- Correção (regra única): mc por texto da alternativa (ou índice, app
-- antigo) · tf true/false · bank array de palavras · order itens na ordem ·
-- match lista com todos os pares
-- ---------------------------------------------------------------
create or replace function public.fj_corrige_respostas(p_questoes jsonb, p_respostas jsonb)
returns jsonb language plpgsql immutable as $$
declare
  q jsonb; r jsonb; ok boolean; valor numeric;
  v_acertos int := 0; v_total int := 0; v_pontos numeric := 0; v_pontos_total numeric := 0; corrigidas jsonb := '[]'::jsonb;
begin
  for q in select * from jsonb_array_elements(p_questoes) loop
    valor := coalesce((q->>'valor')::numeric, 1);
    select x->'resposta' into r from jsonb_array_elements(p_respostas) x where x->>'id' = q->>'id' limit 1;
    ok := case q->>'tipo'
      when 'mc' then r is not null and (
        (jsonb_typeof(r) = 'number' and r = q->'dados'->'a') or
        (jsonb_typeof(r) = 'string' and r = q->'dados'->'opts'->((q->'dados'->>'a')::int)))
      when 'tf' then r is not null and r = q->'dados'->'a'
      when 'bank' then r is not null and r = q->'dados'->'a'
      when 'order' then r is not null and r = q->'dados'->'items'
      when 'match' then r is not null and jsonb_typeof(r) = 'array'
        and jsonb_array_length(r) = jsonb_array_length(q->'dados'->'pairs')
        and (select count(distinct p->>0) from jsonb_array_elements(r) p) = jsonb_array_length(q->'dados'->'pairs')
        and not exists (select 1 from jsonb_array_elements(r) p where not (q->'dados'->'pairs') @> jsonb_build_array(p))
      else false end;
    v_total := v_total + 1; v_pontos_total := v_pontos_total + valor;
    if ok then v_acertos := v_acertos + 1; v_pontos := v_pontos + valor; end if;
    corrigidas := corrigidas || jsonb_build_object('id', q->>'id', 'resposta', r, 'acertou', ok);
  end loop;
  return jsonb_build_object('corrigidas', corrigidas, 'acertos', v_acertos, 'total', v_total,
    'pontos', v_pontos, 'pontosTotal', v_pontos_total,
    'nota', case when v_pontos_total > 0 then round(10 * v_pontos / v_pontos_total, 1) else 0 end);
end $$;
revoke execute on function public.fj_corrige_respostas(jsonb, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------
-- Entrega usa a correção compartilhada (mesmas regras da 0019)
-- ---------------------------------------------------------------
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

-- ---------------------------------------------------------------
-- Nota manual: define (0 a 10) ou restaura a corrigida (p_nota = null)
-- ---------------------------------------------------------------
create or replace function public.definir_nota(p_atividade uuid, p_user uuid, p_nota numeric default null, p_obs text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); a public.atividades; e public.atividade_entregas; aluno text; antes numeric;
begin
  select * into a from public.atividades where id = p_atividade;
  if not found then raise exception 'Atividade não encontrada.'; end if;
  if not acesso_atividade(a.turma_id, a.materia_id, a.professor_id) then raise exception 'Sem permissão nesta atividade.' using errcode = '42501'; end if;
  if not exists (select 1 from public.turma_alunos where turma_id = a.turma_id and user_id = p_user) then raise exception 'Este aluno não está na turma.'; end if;
  select nome into aluno from public.perfis where user_id = p_user;
  select * into e from public.atividade_entregas where atividade_id = a.id and user_id = p_user for update;
  antes := case when found then e.nota else null end;

  if p_nota is null then
    -- restaurar a nota corrigida original
    if not found or not e.nota_manual then raise exception 'Esta nota não é manual.'; end if;
    if e.nota_original is null then raise exception 'Este aluno não tem nota corrigida para restaurar (a nota foi lançada sem entrega).'; end if;
    update public.atividade_entregas set nota = e.nota_original, nota_manual = false, nota_original = null, nota_obs = null
      where atividade_id = a.id and user_id = p_user;
    insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
      values (u, 'painel', 'nota_manual', 'resultados', a.id::text, left('Restaurou a nota corrigida de ' || coalesce(aluno, '?') || ' em ' || a.titulo, 200),
              jsonb_build_object('aluno', p_user, 'de', antes, 'para', e.nota_original));
    return jsonb_build_object('nota', e.nota_original, 'manual', false);
  end if;

  if p_nota < 0 or p_nota > 10 then raise exception 'A nota vai de 0 a 10.'; end if;
  p_nota := round(p_nota, 1);
  if found then
    update public.atividade_entregas
      set nota_original = case when e.nota_manual then e.nota_original else e.nota end,
          nota = p_nota, nota_manual = true, nota_obs = left(p_obs, 200), entregue_em = coalesce(e.entregue_em, now())
      where atividade_id = a.id and user_id = p_user;
  else
    insert into public.atividade_entregas (atividade_id, user_id, nota, nota_manual, nota_obs, entregue_em, total)
      values (a.id, p_user, p_nota, true, left(p_obs, 200), now(), jsonb_array_length(a.questoes));
  end if;
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', 'nota_manual', 'resultados', a.id::text, left('Nota manual ' || replace(p_nota::text, '.', ',') || ' para ' || coalesce(aluno, '?') || ' em ' || a.titulo, 200),
            jsonb_build_object('aluno', p_user, 'de', antes, 'para', p_nota, 'motivo', p_obs));
  return jsonb_build_object('nota', p_nota, 'manual', true);
end $$;

-- ---------------------------------------------------------------
-- Recorrige todas as entregas com o gabarito atual (notas manuais ficam)
-- ---------------------------------------------------------------
create or replace function public.recorrigir_atividade(p_atividade uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); a public.atividades; e record; c jsonb; n int := 0; mud int := 0;
begin
  select * into a from public.atividades where id = p_atividade;
  if not found then raise exception 'Atividade não encontrada.'; end if;
  if not acesso_atividade(a.turma_id, a.materia_id, a.professor_id) then raise exception 'Sem permissão nesta atividade.' using errcode = '42501'; end if;
  for e in select * from public.atividade_entregas where atividade_id = a.id and entregue_em is not null and not nota_manual for update loop
    c := fj_corrige_respostas(a.questoes, e.respostas);
    n := n + 1;
    if (c->>'nota')::numeric is distinct from e.nota then mud := mud + 1; end if;
    update public.atividade_entregas
      set respostas = c->'corrigidas', acertos = (c->>'acertos')::int, total = (c->>'total')::int,
          pontos = (c->>'pontos')::numeric, pontos_total = (c->>'pontosTotal')::numeric, nota = (c->>'nota')::numeric
      where atividade_id = e.atividade_id and user_id = e.user_id;
  end loop;
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', 'recorrecao', 'resultados', a.id::text, left('Recorrigiu as entregas de ' || a.titulo, 200),
            jsonb_build_object('entregas', n, 'mudaramDeNota', mud));
  return jsonb_build_object('entregas', n, 'mudaram', mud);
end $$;

-- ---------------------------------------------------------------
-- Resultados dizem quais notas são manuais (substitui a versão da 0016)
-- ---------------------------------------------------------------
create or replace function public.resultados_atividade(p_atividade uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare a public.atividades;
begin
  perform exigir_login();
  select * into a from public.atividades where id = p_atividade;
  if not found then raise exception 'Atividade não encontrada.'; end if;
  if not acesso_atividade(a.turma_id, a.materia_id, a.professor_id) then raise exception 'Sem permissão nesta atividade.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'alunos', (select coalesce(jsonb_agg(jsonb_build_object('user_id', ta.user_id, 'nome', p.nome, 'email', us.email,
        'nota', e.nota, 'acertos', e.acertos, 'total', e.total, 'entregueEm', e.entregue_em, 'iniciadaEm', e.iniciada_em, 'tempo_s', e.tempo_s,
        'notaManual', e.nota_manual, 'notaObs', e.nota_obs, 'notaOriginal', e.nota_original,
        'respostas', e.respostas) order by p.nome), '[]'::jsonb)
      from public.turma_alunos ta join public.perfis p on p.user_id = ta.user_id join auth.users us on us.id = ta.user_id
      left join public.atividade_entregas e on e.atividade_id = a.id and e.user_id = ta.user_id
      where ta.turma_id = a.turma_id),
    'questoes', (select coalesce(jsonb_agg(jsonb_build_object('id', q->>'id', 'enunciado', q->>'enunciado', 'tipo', q->>'tipo',
        'acertos', (select count(*) from public.atividade_entregas e, jsonb_array_elements(e.respostas) r where e.atividade_id = a.id and e.entregue_em is not null and r->>'id' = q->>'id' and (r->>'acertou')::boolean),
        'erros', (select count(*) from public.atividade_entregas e, jsonb_array_elements(e.respostas) r where e.atividade_id = a.id and e.entregue_em is not null and r->>'id' = q->>'id' and not (r->>'acertou')::boolean))), '[]'::jsonb)
      from jsonb_array_elements(a.questoes) q),
    'entregues', (select count(*) from public.atividade_entregas e where e.atividade_id = a.id and e.entregue_em is not null),
    'alunosTotal', (select count(*) from public.turma_alunos ta where ta.turma_id = a.turma_id),
    'media', (select round(avg(e.nota), 1) from public.atividade_entregas e where e.atividade_id = a.id and e.entregue_em is not null)
  );
end $$;

insert into public.schema_versao (versao) values (24) on conflict do nothing;
