-- =====================================================================
-- Findout Jornada · Migration 0032 · Dinâmica ao vivo (quiz de sala)
-- Rodar no SQL Editor depois da 0031. Idempotente.
--
-- O professor cria uma dinâmica para a turma, monta ou sorteia grupos
-- (ou joga cada um por si), projeta o painel com a questão da vez e um
-- cronômetro, e os alunos respondem pelo app. O ranking de acertos é
-- alimentado automaticamente. Também dá para fazer a dinâmica "por fora"
-- (perguntas faladas em sala): o professor marca no painel qual grupo
-- acertou cada rodada.
--
--  · As questões vêm de uma atividade (banco ou próprias do professor):
--    a dinâmica guarda uma cópia com gabarito (só o professor lê) e uma
--    cópia pública sem gabarito, embaralhada UMA vez, para todo mundo
--    ver as alternativas na mesma ordem (telão e celulares).
--  · Em grupos, vale a PRIMEIRA resposta do grupo (um índice único trava
--    as demais): o grupo discute e um responde. No individual, uma
--    resposta por aluno. Desempate do ranking: menor tempo somado.
--  · Alunos não leem as tabelas direto (a cópia tem gabarito); tudo
--    passa por estado_dinamica/responder_dinamica. Dinâmica não dá XP
--    nem mexe em corações: é um jogo de sala.
-- =====================================================================

create table if not exists public.dinamicas (
  id uuid primary key default gen_random_uuid(),
  turma_id uuid not null references public.turmas(id) on delete cascade,
  atividade_id uuid references public.atividades(id) on delete set null,
  titulo text not null,
  modo text not null default 'grupos' check (modo in ('grupos', 'individual')),
  origem text not null default 'questoes' check (origem in ('questoes', 'manual')),
  questoes jsonb not null default '[]'::jsonb,   -- cópia com gabarito (só professor)
  publicas jsonb not null default '[]'::jsonb,   -- cópia sem gabarito, embaralhada 1x
  status text not null default 'lobby' check (status in ('lobby', 'pergunta', 'revelada', 'fim')),
  questao int not null default -1,
  questao_iniciada_em timestamptz,
  tempo_questao int not null default 60,         -- segundos por questão; 0 = sem cronômetro
  criada_por uuid references auth.users(id) on delete set null,
  criada_em timestamptz not null default now(),
  encerrada_em timestamptz
);
create index if not exists dinamicas_turma_idx on public.dinamicas(turma_id);

create table if not exists public.dinamica_grupos (
  id uuid primary key default gen_random_uuid(),
  dinamica_id uuid not null references public.dinamicas(id) on delete cascade,
  nome text not null,
  ordem int not null default 0,
  pontos_manual int not null default 0           -- acertos marcados pelo professor (modo manual)
);
create index if not exists dinamica_grupos_din_idx on public.dinamica_grupos(dinamica_id);

create table if not exists public.dinamica_membros (
  dinamica_id uuid not null references public.dinamicas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  grupo_id uuid references public.dinamica_grupos(id) on delete set null,
  visto_em timestamptz not null default now(),
  primary key (dinamica_id, user_id)
);

create table if not exists public.dinamica_respostas (
  dinamica_id uuid not null references public.dinamicas(id) on delete cascade,
  questao int not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  grupo_id uuid references public.dinamica_grupos(id) on delete set null,
  resposta jsonb,
  acertou boolean not null default false,
  tempo_ms int not null default 0,
  respondida_em timestamptz not null default now(),
  primary key (dinamica_id, questao, user_id)
);
-- Em grupos, vale a primeira resposta do grupo na questão
create unique index if not exists dinamica_resp_grupo_uq
  on public.dinamica_respostas (dinamica_id, questao, grupo_id) where grupo_id is not null;

alter table public.dinamicas enable row level security;
alter table public.dinamica_grupos enable row level security;
alter table public.dinamica_membros enable row level security;
alter table public.dinamica_respostas enable row level security;

-- O jsonb questoes tem gabarito: só professor/admin leem a tabela.
-- Aluno usa estado_dinamica(); escrever é só pelas funções abaixo.
drop policy if exists dinamicas_ler on public.dinamicas;
create policy dinamicas_ler on public.dinamicas for select to authenticated
  using (public.is_admin() or public.professor_da_turma(turma_id));
drop policy if exists dinamicas_apagar on public.dinamicas;
create policy dinamicas_apagar on public.dinamicas for delete to authenticated
  using (public.is_admin() or public.professor_da_turma(turma_id));
drop policy if exists dinamica_grupos_ler on public.dinamica_grupos;
create policy dinamica_grupos_ler on public.dinamica_grupos for select to authenticated
  using (exists (select 1 from public.dinamicas d where d.id = dinamica_id
                   and (public.is_admin() or public.professor_da_turma(d.turma_id) or public.aluno_da_turma(d.turma_id))));
drop policy if exists dinamica_membros_ler on public.dinamica_membros;
create policy dinamica_membros_ler on public.dinamica_membros for select to authenticated
  using (user_id = auth.uid() or exists (select 1 from public.dinamicas d where d.id = dinamica_id
                   and (public.is_admin() or public.professor_da_turma(d.turma_id))));
drop policy if exists dinamica_respostas_ler on public.dinamica_respostas;
create policy dinamica_respostas_ler on public.dinamica_respostas for select to authenticated
  using (exists (select 1 from public.dinamicas d where d.id = dinamica_id
                   and (public.is_admin() or public.professor_da_turma(d.turma_id))));

-- ---------------------------------------------------------------
-- Criar a dinâmica (professor da turma). Com origem 'questoes', copia
-- as questões da atividade e gera a versão pública embaralhada 1 vez.
-- ---------------------------------------------------------------
create or replace function public.criar_dinamica(p_turma uuid, p_titulo text, p_modo text default 'grupos', p_origem text default 'questoes', p_atividade uuid default null, p_tempo int default 60)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); a public.atividades; dnova public.dinamicas; q jsonb; d jsonb; sq jsonb; pub jsonb := '[]'::jsonb; gab jsonb := '[]'::jsonb;
begin
  if not (is_admin() or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  if coalesce(trim(p_titulo), '') = '' then raise exception 'Dê um nome à dinâmica.'; end if;
  if p_modo not in ('grupos', 'individual') then raise exception 'Modo inválido.'; end if;
  if p_origem not in ('questoes', 'manual') then raise exception 'Origem inválida.'; end if;
  if p_origem = 'manual' then p_modo := 'grupos'; end if;   -- manual é sempre por grupos
  if p_tempo <> 0 and (p_tempo < 10 or p_tempo > 600) then raise exception 'O tempo por questão vai de 10 a 600 segundos (0 = sem cronômetro).'; end if;
  if p_origem = 'questoes' then
    if p_atividade is null then raise exception 'Escolha a atividade com as questões.'; end if;
    select * into a from public.atividades where id = p_atividade;
    if not found or not (is_admin() or professor_da_turma(a.turma_id)) then raise exception 'Atividade não encontrada.'; end if;
    if jsonb_array_length(a.questoes) = 0 then raise exception 'Esta atividade não tem questões.'; end if;
    gab := a.questoes;
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
      pub := pub || jsonb_build_object('id', q->'id', 'tipo', q->'tipo', 'enunciado', q->'enunciado', 'imagem', q->'imagem', 'dados', sq);
    end loop;
  end if;
  insert into public.dinamicas (turma_id, atividade_id, titulo, modo, origem, questoes, publicas, tempo_questao, criada_por)
    values (p_turma, case when p_origem = 'questoes' then p_atividade end, trim(p_titulo), p_modo, p_origem, gab, pub, p_tempo, u)
    returning * into dnova;
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', 'dinamica', 'dinamicas', dnova.id::text, left('Criou a dinâmica ' || dnova.titulo, 200),
            jsonb_build_object('turma', p_turma, 'modo', p_modo, 'origem', p_origem, 'questoes', jsonb_array_length(gab)));
  return jsonb_build_object('id', dnova.id, 'titulo', dnova.titulo);
end $$;
grant execute on function public.criar_dinamica(uuid, text, text, text, uuid, int) to authenticated;

-- ---------------------------------------------------------------
-- Grupos: o professor manda a lista pronta (sorteada ou montada no
-- painel). Só no lobby. p_grupos: [{nome, membros: [uuid, …]}, …]
-- ---------------------------------------------------------------
create or replace function public.definir_grupos_dinamica(p_dinamica uuid, p_grupos jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.dinamicas; g jsonb; m text; gid uuid; i int := 0; saida jsonb := '[]'::jsonb;
begin
  perform exigir_login();
  select * into d from public.dinamicas where id = p_dinamica;
  if not found or not (is_admin() or professor_da_turma(d.turma_id)) then raise exception 'Dinâmica não encontrada.'; end if;
  if d.status <> 'lobby' then raise exception 'Os grupos só mudam antes de começar.'; end if;
  if d.modo <> 'grupos' then raise exception 'Esta dinâmica é individual.'; end if;
  if jsonb_typeof(p_grupos) <> 'array' or jsonb_array_length(p_grupos) < 2 or jsonb_array_length(p_grupos) > 26 then
    raise exception 'Monte de 2 a 26 grupos.';
  end if;
  delete from public.dinamica_membros where dinamica_id = d.id;
  delete from public.dinamica_grupos where dinamica_id = d.id;
  for g in select * from jsonb_array_elements(p_grupos) loop
    if coalesce(trim(g->>'nome'), '') = '' then raise exception 'Todo grupo precisa de nome.'; end if;
    insert into public.dinamica_grupos (dinamica_id, nome, ordem) values (d.id, left(trim(g->>'nome'), 40), i) returning id into gid;
    i := i + 1;
    for m in select jsonb_array_elements_text(coalesce(g->'membros', '[]'::jsonb)) loop
      if not exists (select 1 from public.turma_alunos where turma_id = d.turma_id and user_id = m::uuid and aceito) then
        raise exception 'Um dos alunos não está na turma.';
      end if;
      insert into public.dinamica_membros (dinamica_id, user_id, grupo_id) values (d.id, m::uuid, gid)
        on conflict (dinamica_id, user_id) do update set grupo_id = excluded.grupo_id, visto_em = dinamica_membros.visto_em;
    end loop;
    saida := saida || jsonb_build_object('id', gid, 'nome', left(trim(g->>'nome'), 40));
  end loop;
  return saida;
end $$;
grant execute on function public.definir_grupos_dinamica(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------
-- Comandos do professor: iniciar · revelar · proxima · encerrar · tempo
-- ---------------------------------------------------------------
create or replace function public.comando_dinamica(p_dinamica uuid, p_acao text, p_tempo int default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.dinamicas; total int;
begin
  select * into d from public.dinamicas where id = p_dinamica for update;
  if not found or not (is_admin() or professor_da_turma(d.turma_id)) then raise exception 'Dinâmica não encontrada.'; end if;
  total := jsonb_array_length(d.publicas);
  if p_acao = 'iniciar' then
    if d.status <> 'lobby' then raise exception 'A dinâmica já começou.'; end if;
    if d.modo = 'grupos' and (select count(*) from public.dinamica_grupos where dinamica_id = d.id) < 2 then
      raise exception 'Monte os grupos antes de começar (pelo menos 2).';
    end if;
    update public.dinamicas set status = 'pergunta',
      questao = case when origem = 'questoes' then 0 else -1 end,
      questao_iniciada_em = case when origem = 'questoes' then now() end
      where id = d.id;
  elsif p_acao = 'revelar' then
    if d.status <> 'pergunta' or d.origem <> 'questoes' then raise exception 'Nada para revelar agora.'; end if;
    update public.dinamicas set status = 'revelada' where id = d.id;
  elsif p_acao = 'proxima' then
    if d.status <> 'revelada' then raise exception 'Revele a resposta antes de ir para a próxima.'; end if;
    if d.questao + 1 >= total then
      update public.dinamicas set status = 'fim', encerrada_em = now() where id = d.id;
    else
      update public.dinamicas set status = 'pergunta', questao = d.questao + 1, questao_iniciada_em = now() where id = d.id;
    end if;
  elsif p_acao = 'encerrar' then
    if d.status = 'fim' then raise exception 'A dinâmica já acabou.'; end if;
    update public.dinamicas set status = 'fim', encerrada_em = now() where id = d.id;
    insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo)
      values (u, 'painel', 'dinamica', 'dinamicas', d.id::text, left('Encerrou a dinâmica ' || d.titulo, 200));
  elsif p_acao = 'tempo' then
    if p_tempo is null or (p_tempo <> 0 and (p_tempo < 10 or p_tempo > 600)) then raise exception 'Tempo inválido.'; end if;
    update public.dinamicas set tempo_questao = p_tempo where id = d.id;
  else
    raise exception 'Comando inválido.';
  end if;
  select * into d from public.dinamicas where id = p_dinamica;
  return jsonb_build_object('status', d.status, 'questao', d.questao);
end $$;
grant execute on function public.comando_dinamica(uuid, text, int) to authenticated;

-- Modo manual (ou ajuste): o professor marca +1/−1 acerto para um grupo
create or replace function public.marcar_ponto_dinamica(p_dinamica uuid, p_grupo uuid, p_delta int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.dinamicas; novo int;
begin
  perform exigir_login();
  select * into d from public.dinamicas where id = p_dinamica;
  if not found or not (is_admin() or professor_da_turma(d.turma_id)) then raise exception 'Dinâmica não encontrada.'; end if;
  if d.status not in ('pergunta', 'revelada') then raise exception 'A dinâmica não está em andamento.'; end if;
  if p_delta not in (1, -1) then raise exception 'Ajuste de 1 em 1.'; end if;
  update public.dinamica_grupos set pontos_manual = greatest(0, pontos_manual + p_delta)
    where id = p_grupo and dinamica_id = d.id returning pontos_manual into novo;
  if novo is null then raise exception 'Grupo não encontrado.'; end if;
  return jsonb_build_object('grupo', p_grupo, 'pontos', novo);
end $$;
grant execute on function public.marcar_ponto_dinamica(uuid, uuid, int) to authenticated;

-- ---------------------------------------------------------------
-- Ranking (grupos ou alunos): acertos automáticos + pontos manuais,
-- desempate pelo menor tempo somado das respostas
-- ---------------------------------------------------------------
create or replace function public.fj_ranking_dinamica(p_dinamica uuid, p_user uuid)
returns jsonb language sql stable as $$
  select case when d.modo = 'grupos' then (
    select coalesce(jsonb_agg(jsonb_build_object('nome', x.nome, 'acertos', x.pts, 'tempo', x.tm, 'eu', x.meu) order by x.pts desc, x.tm asc, x.ordem), '[]'::jsonb)
    from (
      select g.nome, g.ordem, g.pontos_manual + coalesce(r.ac, 0) as pts, coalesce(r.tm, 0) as tm,
        exists (select 1 from public.dinamica_membros m where m.dinamica_id = d.id and m.user_id = p_user and m.grupo_id = g.id) as meu
      from public.dinamica_grupos g
      left join (select grupo_id, count(*) filter (where acertou) as ac, coalesce(sum(tempo_ms), 0) as tm
                 from public.dinamica_respostas where dinamica_id = d.id and grupo_id is not null group by grupo_id) r on r.grupo_id = g.id
      where g.dinamica_id = d.id
    ) x
  ) else (
    select coalesce(jsonb_agg(jsonb_build_object('nome', x.nome, 'acertos', x.pts, 'tempo', x.tm, 'eu', x.meu) order by x.pts desc, x.tm asc, x.nome), '[]'::jsonb)
    from (
      select p.nome, coalesce(r.ac, 0) as pts, coalesce(r.tm, 0) as tm, m.user_id = p_user as meu
      from public.dinamica_membros m
      join public.perfis p on p.user_id = m.user_id
      left join (select user_id, count(*) filter (where acertou) as ac, coalesce(sum(tempo_ms), 0) as tm
                 from public.dinamica_respostas where dinamica_id = d.id group by user_id) r on r.user_id = m.user_id
      where m.dinamica_id = d.id
    ) x
  ) end
  from public.dinamicas d where d.id = p_dinamica;
$$;
revoke execute on function public.fj_ranking_dinamica(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------
-- Aluno: estado da dinâmica (o app consulta a cada 2 s). Marca presença,
-- devolve a questão da vez SEM gabarito e, depois de revelada, se
-- acertou, a resposta certa e o ranking.
-- ---------------------------------------------------------------
create or replace function public.estado_dinamica(p_dinamica uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := exigir_login(); d public.dinamicas; prof boolean; gq jsonb; certa jsonb;
  meu_grupo uuid; r public.dinamica_respostas; quem text; fim timestamptz;
begin
  select * into d from public.dinamicas where id = p_dinamica;
  if not found then raise exception 'Dinâmica não encontrada.'; end if;
  prof := is_admin() or professor_da_turma(d.turma_id);
  if not prof and not aluno_da_turma(d.turma_id) then raise exception 'Você não está na turma desta dinâmica.' using errcode = '42501'; end if;
  if not prof and d.status <> 'fim' then
    insert into public.dinamica_membros (dinamica_id, user_id) values (d.id, u)
      on conflict (dinamica_id, user_id) do update set visto_em = now();
  end if;
  select grupo_id into meu_grupo from public.dinamica_membros where dinamica_id = d.id and user_id = u;
  if d.origem = 'questoes' and d.questao >= 0 and d.status in ('pergunta', 'revelada') then
    gq := d.questoes->d.questao;
    if d.modo = 'grupos' and meu_grupo is not null then
      select * into r from public.dinamica_respostas where dinamica_id = d.id and questao = d.questao and grupo_id = meu_grupo;
    else
      select * into r from public.dinamica_respostas where dinamica_id = d.id and questao = d.questao and user_id = u;
    end if;
    if r.user_id is not null and r.user_id <> u then select nome into quem from public.perfis where user_id = r.user_id; end if;
    if d.status = 'revelada' then
      certa := case gq->>'tipo'
        when 'mc' then gq->'dados'->'opts'->((gq->'dados'->>'a')::int)
        when 'tf' then gq->'dados'->'a'
        when 'bank' then gq->'dados'->'a'
        when 'order' then gq->'dados'->'items'
        when 'match' then gq->'dados'->'pairs'
        else null end;
    end if;
  end if;
  if d.tempo_questao > 0 and d.questao_iniciada_em is not null then fim := d.questao_iniciada_em + make_interval(secs => d.tempo_questao); end if;
  return jsonb_build_object(
    'id', d.id, 'titulo', d.titulo, 'modo', d.modo, 'origem', d.origem, 'status', d.status,
    'questao', d.questao, 'total', jsonb_array_length(d.publicas), 'tempo', d.tempo_questao,
    'agora', now(), 'fimEm', fim,
    'turma', (select nome from public.turmas where id = d.turma_id),
    'grupo', case when meu_grupo is not null then (select jsonb_build_object('id', g.id, 'nome', g.nome,
        'colegas', (select coalesce(jsonb_agg(p.nome order by p.nome), '[]'::jsonb) from public.dinamica_membros m join public.perfis p on p.user_id = m.user_id where m.dinamica_id = d.id and m.grupo_id = g.id and m.user_id <> u))
      from public.dinamica_grupos g where g.id = meu_grupo) end,
    'temGrupos', exists (select 1 from public.dinamica_grupos g where g.dinamica_id = d.id),
    'questaoPub', case when d.status in ('pergunta', 'revelada') then d.publicas->d.questao end,
    'respondi', r.user_id is not null,
    'respondeuPor', quem,
    'minhaResposta', case when d.status = 'revelada' then r.resposta end,
    'acertei', case when d.status = 'revelada' and r.user_id is not null then r.acertou end,
    'certa', certa,
    'explicacao', case when d.status = 'revelada' then gq->>'explicacao' end,
    'ranking', case when d.status = 'fim' or d.status = 'revelada' or d.origem = 'manual' then fj_ranking_dinamica(d.id, u) end
  );
end $$;
grant execute on function public.estado_dinamica(uuid) to authenticated;

-- A dinâmica ao vivo nas turmas do aluno (para o aviso na aba Turma)
create or replace function public.dinamica_ativa()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', d.id, 'titulo', d.titulo, 'turma', t.nome, 'status', d.status)
  from public.dinamicas d join public.turmas t on t.id = d.turma_id
  where d.status <> 'fim' and d.criada_em > now() - interval '12 hours' and aluno_da_turma(d.turma_id)
  order by d.criada_em desc limit 1;
$$;
grant execute on function public.dinamica_ativa() to authenticated;

-- ---------------------------------------------------------------
-- Aluno responde a questão da vez. Corrige na hora com o mesmo
-- fj_corrige_respostas das atividades; o acerto só aparece ao revelar.
-- ---------------------------------------------------------------
create or replace function public.responder_dinamica(p_dinamica uuid, p_questao int, p_resposta jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.dinamicas; gq jsonb; meu_grupo uuid; c jsonb; ok boolean; ms int;
begin
  select * into d from public.dinamicas where id = p_dinamica;
  if not found then raise exception 'Dinâmica não encontrada.'; end if;
  if not aluno_da_turma(d.turma_id) then raise exception 'Você não está na turma desta dinâmica.' using errcode = '42501'; end if;
  if d.origem <> 'questoes' or d.status <> 'pergunta' or p_questao <> d.questao then raise exception 'Esta pergunta já fechou.'; end if;
  if d.tempo_questao > 0 and now() > d.questao_iniciada_em + make_interval(secs => d.tempo_questao + 2) then
    raise exception 'O tempo desta pergunta acabou.';
  end if;
  if d.modo = 'grupos' then
    select grupo_id into meu_grupo from public.dinamica_membros where dinamica_id = d.id and user_id = u;
    if meu_grupo is null then raise exception 'Você está sem grupo nesta dinâmica. Avise o professor.'; end if;
  end if;
  gq := d.questoes->d.questao;
  c := fj_corrige_respostas(jsonb_build_array(gq), jsonb_build_array(jsonb_build_object('id', gq->>'id', 'resposta', p_resposta)));
  ok := (c->'corrigidas'->0->>'acertou')::boolean;
  ms := greatest(0, least(3600000, (extract(epoch from now() - coalesce(d.questao_iniciada_em, now())) * 1000)::int));
  begin
    insert into public.dinamica_respostas (dinamica_id, questao, user_id, grupo_id, resposta, acertou, tempo_ms)
      values (d.id, d.questao, u, meu_grupo, p_resposta, ok, ms);
  exception when unique_violation then
    if d.modo = 'grupos' then raise exception 'Seu grupo já respondeu esta pergunta.';
    else raise exception 'Você já respondeu esta pergunta.'; end if;
  end;
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.responder_dinamica(uuid, int, jsonb) to authenticated;

-- ---------------------------------------------------------------
-- Painel do professor (telão): tudo em uma chamada — grupos e membros
-- (com presença), respostas da questão da vez e ranking.
-- ---------------------------------------------------------------
create or replace function public.painel_dinamica(p_dinamica uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.dinamicas;
begin
  select * into d from public.dinamicas where id = p_dinamica;
  if not found or not (is_admin() or professor_da_turma(d.turma_id)) then raise exception 'Dinâmica não encontrada.'; end if;
  return jsonb_build_object(
    'id', d.id, 'titulo', d.titulo, 'modo', d.modo, 'origem', d.origem, 'status', d.status,
    'turma_id', d.turma_id, 'questao', d.questao, 'total', jsonb_array_length(d.publicas),
    'tempo', d.tempo_questao, 'agora', now(),
    'fimEm', case when d.tempo_questao > 0 and d.questao_iniciada_em is not null then d.questao_iniciada_em + make_interval(secs => d.tempo_questao) end,
    'questoes', d.questoes, 'publicas', d.publicas,
    'grupos', (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'nome', g.nome, 'ordem', g.ordem, 'pontos_manual', g.pontos_manual,
        'membros', (select coalesce(jsonb_agg(jsonb_build_object('user_id', m.user_id, 'nome', p.nome, 'online', m.visto_em > now() - interval '15 seconds') order by p.nome), '[]'::jsonb)
                    from public.dinamica_membros m join public.perfis p on p.user_id = m.user_id where m.dinamica_id = d.id and m.grupo_id = g.id)) order by g.ordem), '[]'::jsonb)
      from public.dinamica_grupos g where g.dinamica_id = d.id),
    'semGrupo', (select coalesce(jsonb_agg(jsonb_build_object('user_id', m.user_id, 'nome', p.nome, 'online', m.visto_em > now() - interval '15 seconds') order by p.nome), '[]'::jsonb)
      from public.dinamica_membros m join public.perfis p on p.user_id = m.user_id where m.dinamica_id = d.id and m.grupo_id is null),
    'alunos', (select coalesce(jsonb_agg(jsonb_build_object('user_id', ta.user_id, 'nome', p.nome,
        'online', exists (select 1 from public.dinamica_membros m where m.dinamica_id = d.id and m.user_id = ta.user_id and m.visto_em > now() - interval '15 seconds')) order by p.nome), '[]'::jsonb)
      from public.turma_alunos ta join public.perfis p on p.user_id = ta.user_id where ta.turma_id = d.turma_id and ta.aceito),
    'respostas', case when d.questao >= 0 then (select coalesce(jsonb_agg(jsonb_build_object(
        'user_id', r.user_id, 'nome', p.nome, 'grupoId', r.grupo_id,
        'grupo', (select g.nome from public.dinamica_grupos g where g.id = r.grupo_id),
        'resposta', r.resposta, 'acertou', r.acertou, 'tempo', r.tempo_ms) order by r.respondida_em), '[]'::jsonb)
      from public.dinamica_respostas r join public.perfis p on p.user_id = r.user_id
      where r.dinamica_id = d.id and r.questao = d.questao) end,
    'ranking', fj_ranking_dinamica(d.id, u)
  );
end $$;
grant execute on function public.painel_dinamica(uuid) to authenticated;

insert into public.schema_versao (versao) values (32) on conflict do nothing;
