-- =====================================================================
-- Findout Jornada · Migration 0019 · Segurança das atividades e da auditoria
-- Rodar no SQL Editor depois da 0018 e ANTES de publicar o app novo.
--
--  · O gabarito não sai mais do servidor: abrir_atividade devolve as questões
--    sem resposta e sem explicação, com alternativas, itens e pares
--    embaralhados A CADA ABERTURA. O app vira "modo prova" (sem certo/errado
--    durante a atividade) e toda a correção acontece na entrega.
--  · entregar_atividade: múltipla escolha aceita o texto da alternativa
--    (app novo) ou o índice (app antigo); ligar pares passa a ser corrigido
--    no servidor (lista de pares, não mais um true vindo do cliente);
--    a entrega ganha lock de linha contra duplo clique (XP pago 2x).
--  · Aluno não lê mais a tabela atividades direto (a cópia das questões
--    guarda o gabarito); ele usa atividades_do_aluno e abrir_atividade.
--  · Embaralha as alternativas das questões de múltipla escolha gravadas:
--    a resposta certa estava na posição 0 em ~93% do banco.
--  · auditar_painel só aceita ação com letras minúsculas e _ (fecha o XSS
--    na tela Auditoria; o painel também passou a escapar esse campo).
--  · Revoga o EXECUTE das funções que recebem p_user e eram chamáveis por
--    qualquer um via /rpc (vazavam ofensiva, missões, plus e convites de
--    qualquer aluno). Elas continuam funcionando por dentro das funções
--    security definer, que é o único lugar onde o app as usa.
-- =====================================================================

-- ---------------------------------------------------------------
-- Embaralha as alternativas de múltipla escolha no banco de questões.
-- Desliga o gatilho de auditoria durante o ajuste para não poluir o log.
-- (As cópias dentro de atividades já criadas ficam como estão: as entregas
--  antigas guardam a resposta pelo índice original.)
-- ---------------------------------------------------------------
alter table public.questoes disable trigger auditoria_questoes;
do $$
declare q record; n int; perm int[]; novo jsonb; na int;
begin
  for q in select id, dados from public.questoes where tipo = 'mc' loop
    n := coalesce(jsonb_array_length(q.dados->'opts'), 0);
    if n < 2 then continue; end if;
    select array_agg(i order by random()) into perm from generate_series(0, n - 1) i;
    select jsonb_agg(q.dados->'opts'->perm[i] order by i) into novo from generate_series(1, n) i;
    na := coalesce(array_position(perm, coalesce((q.dados->>'a')::int, 0)), 1) - 1;
    update public.questoes set dados = dados || jsonb_build_object('opts', novo, 'a', na) where id = q.id;
  end loop;
end $$;
alter table public.questoes enable trigger auditoria_questoes;

-- ---------------------------------------------------------------
-- Aluno não lê atividades direto (o jsonb questoes tem o gabarito)
-- ---------------------------------------------------------------
drop policy if exists atividades_ler on public.atividades;
create policy atividades_ler on public.atividades for select to authenticated
  using (public.acesso_atividade(turma_id, materia_id, professor_id));

-- ---------------------------------------------------------------
-- Abre a atividade SEM gabarito, embaralhando a cada abertura
-- ---------------------------------------------------------------
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
    lista := lista || jsonb_build_object('id', q->'id', 'tipo', q->'tipo', 'enunciado', q->'enunciado',
      'imagem', q->'imagem', 'valor', q->'valor', 'dados', sq);
  end loop;
  return jsonb_build_object('id', a.id, 'titulo', a.titulo, 'descricao', a.descricao, 'materia', a.materia_id,
    'prazo', a.prazo, 'questoes', lista, 'cega', true);
end $$;

-- ---------------------------------------------------------------
-- Entrega: corrige tudo no servidor, com lock contra duplo clique.
-- Respostas por tipo: mc = texto da alternativa (ou índice, app antigo) ·
-- tf = true/false · bank = ["palavra1","palavra2"] · order = itens na ordem ·
-- match = [["esquerda","direita"], …] com todos os pares.
-- ---------------------------------------------------------------
create or replace function public.entregar_atividade(p_atividade uuid, p_respostas jsonb default '[]'::jsonb, p_tempo_s int default 0)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := exigir_login(); a public.atividades; e public.atividade_entregas; q jsonb; r jsonb; ok boolean;
  v_acertos int := 0; v_total int := 0; v_pontos numeric := 0; v_pontos_total numeric := 0; valor numeric; v_nota numeric;
  corrigidas jsonb := '[]'::jsonb; v_xp int; linhas jsonb := '[]'::jsonb; praticou_hoje boolean; mat text;
begin
  select * into a from public.atividades where id = p_atividade;
  if not found or a.status = 'rascunho' then raise exception 'Atividade não encontrada.'; end if;
  if not aluno_da_turma(a.turma_id) then raise exception 'Você não está na turma desta atividade.' using errcode = '42501'; end if;
  select * into e from public.atividade_entregas where atividade_id = a.id and user_id = u for update;
  if found and e.entregue_em is not null then raise exception 'Você já entregou esta atividade.'; end if;
  if a.status = 'encerrada' or (a.prazo is not null and a.prazo < now() - interval '10 minutes') then raise exception 'O prazo desta atividade acabou.'; end if;

  for q in select * from jsonb_array_elements(a.questoes) loop
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
  v_nota := case when v_pontos_total > 0 then round(10 * v_pontos / v_pontos_total, 1) else 0 end;

  insert into public.atividade_entregas (atividade_id, user_id, respostas, acertos, total, pontos, pontos_total, nota, entregue_em, tempo_s)
    values (a.id, u, corrigidas, v_acertos, v_total, v_pontos, v_pontos_total, v_nota, now(), greatest(0, p_tempo_s))
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
-- Auditoria: a ação vira identificador controlado (anti-XSS no painel)
-- ---------------------------------------------------------------
create or replace function public.auditar_painel(p_acao text, p_tabela text default null, p_registro text default null, p_resumo text default null, p_dados jsonb default null)
returns void language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login();
begin
  if not eh_educador() then return; end if;   -- só quem entra no painel gera eventos
  if p_acao is null or p_acao !~ '^[a-z_]{1,40}$' then p_acao := 'evento'; end if;
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', p_acao, left(p_tabela, 60), left(p_registro, 120), left(p_resumo, 200), p_dados);
end $$;

-- ---------------------------------------------------------------
-- Funções com p_user não são mais chamáveis direto pela API
-- (o app só as usa por dentro de estado_aluno e companhia)
-- ---------------------------------------------------------------
revoke execute on function public.ofensiva(uuid), public.missoes_do_dia(uuid), public.tem_plus(uuid), public.convites_do_aluno(uuid)
  from public, anon, authenticated;
