-- =====================================================================
-- Findout Jornada · Migration 0011 · Professores, turmas e atividades
-- Rodar no SQL Editor do Supabase depois da 0010. Idempotente.
--
-- O que entra:
--   · papel no perfil: aluno | professor | coordenador
--   · escolas (coordenador cria) e seus membros (professores e coordenadores)
--   · turmas com código de convite; alunos entram pelo código ou pelo e-mail
--   · atividades criadas pelo professor (questões do banco ou próprias),
--     com prazo, valor por questão e nota automática
--   · entregas dos alunos, corrigidas no servidor
--   · coluna "assuntos" nas questões para a busca por assunto
-- =====================================================================

-- ---------------------------------------------------------------
-- Papel do usuário e assuntos das questões
-- ---------------------------------------------------------------
alter table public.perfis add column if not exists papel text not null default 'aluno';
alter table public.perfis drop constraint if exists perfis_papel_check;
alter table public.perfis add constraint perfis_papel_check check (papel in ('aluno', 'professor', 'coordenador'));

alter table public.questoes add column if not exists assuntos text[] not null default '{}';
create index if not exists questoes_assuntos_idx on public.questoes using gin (assuntos);

create or replace function public.meu_papel()
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select papel from public.perfis where user_id = auth.uid()), 'aluno');
$$;

create or replace function public.eh_educador()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.meu_papel() in ('professor', 'coordenador');
$$;

-- O dono do perfil pode mudar nome/avatar/matéria, mas papel e Findout+
-- só mudam por admin ou pelas funções deste arquivo (que ligam a flag).
create or replace function public.perfis_protege_colunas()
returns trigger language plpgsql as $$
begin
  if (new.papel is distinct from old.papel or new.findout_plus_ate is distinct from old.findout_plus_ate)
     and not public.is_admin() and coalesce(current_setting('fj.liberar_perfil', true), '') <> '1' then
    raise exception 'Você não pode alterar este campo do perfil.' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists perfis_protege on public.perfis;
create trigger perfis_protege before update on public.perfis for each row execute function public.perfis_protege_colunas();

-- Admin define o papel de alguém (aba Alunos do painel)
create or replace function public.definir_papel(p_user uuid, p_papel text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  if p_papel not in ('aluno', 'professor', 'coordenador') then raise exception 'Papel inválido: %', p_papel; end if;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set papel = p_papel where user_id = p_user;
end $$;
grant execute on function public.definir_papel(uuid, text) to authenticated;

-- ---------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------
create table if not exists public.escolas (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  criada_por uuid references auth.users(id) on delete set null,
  criada_em timestamptz not null default now()
);

create table if not exists public.escola_membros (
  escola_id uuid not null references public.escolas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  papel text not null default 'professor' check (papel in ('professor', 'coordenador')),
  entrou_em timestamptz not null default now(),
  primary key (escola_id, user_id)
);

create table if not exists public.turmas (
  id uuid primary key default gen_random_uuid(),
  escola_id uuid references public.escolas(id) on delete set null,
  nome text not null,
  codigo text not null unique,                 -- convite: o aluno digita no app
  ativa boolean not null default true,
  criada_por uuid references auth.users(id) on delete set null,
  criada_em timestamptz not null default now()
);

create table if not exists public.turma_professores (
  turma_id uuid not null references public.turmas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  materia_id text references public.materias(id) on delete set null,   -- null = todas
  primary key (turma_id, user_id)
);

create table if not exists public.turma_alunos (
  turma_id uuid not null references public.turmas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  entrou_em timestamptz not null default now(),
  primary key (turma_id, user_id)
);
create index if not exists turma_alunos_user_idx on public.turma_alunos(user_id);

-- As questões da atividade ficam copiadas em "questoes" (jsonb):
-- [{id, tipo, enunciado, dados, explicacao, imagem, materia, valor, origem}]
-- Assim a atividade não muda se a questão do banco for editada, e o
-- professor pode criar questões só para a atividade (origem = 'propria').
create table if not exists public.atividades (
  id uuid primary key default gen_random_uuid(),
  turma_id uuid not null references public.turmas(id) on delete cascade,
  professor_id uuid not null references auth.users(id) on delete cascade,
  materia_id text references public.materias(id) on delete set null,
  titulo text not null,
  descricao text not null default '',
  prazo timestamptz,
  questoes jsonb not null default '[]'::jsonb,
  status text not null default 'rascunho' check (status in ('rascunho', 'aberta', 'encerrada')),
  criada_em timestamptz not null default now(),
  atualizada_em timestamptz not null default now()
);
create index if not exists atividades_turma_idx on public.atividades(turma_id);

create table if not exists public.atividade_entregas (
  atividade_id uuid not null references public.atividades(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  respostas jsonb not null default '[]'::jsonb,   -- [{id, resposta, acertou}]
  acertos int not null default 0,
  total int not null default 0,
  pontos numeric not null default 0,
  pontos_total numeric not null default 0,
  nota numeric(4,1),
  iniciada_em timestamptz not null default now(),
  entregue_em timestamptz,
  tempo_s int not null default 0,
  primary key (atividade_id, user_id)
);
create index if not exists entregas_user_idx on public.atividade_entregas(user_id);

-- ---------------------------------------------------------------
-- Quem é quem (usadas nas políticas; security definer evita recursão)
-- ---------------------------------------------------------------
create or replace function public.coord_da_escola(p_escola uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.escola_membros where escola_id = p_escola and user_id = auth.uid() and papel = 'coordenador');
$$;
create or replace function public.membro_da_escola(p_escola uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.escola_membros where escola_id = p_escola and user_id = auth.uid());
$$;
create or replace function public.professor_da_turma(p_turma uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.turma_professores where turma_id = p_turma and user_id = auth.uid())
      or exists (select 1 from public.turmas t where t.id = p_turma
                   and (t.criada_por = auth.uid() or (t.escola_id is not null and public.coord_da_escola(t.escola_id))));
$$;
create or replace function public.aluno_da_turma(p_turma uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.turma_alunos where turma_id = p_turma and user_id = auth.uid());
$$;

-- ---------------------------------------------------------------
-- Segurança (RLS)
-- ---------------------------------------------------------------
alter table public.escolas enable row level security;
alter table public.escola_membros enable row level security;
alter table public.turmas enable row level security;
alter table public.turma_professores enable row level security;
alter table public.turma_alunos enable row level security;
alter table public.atividades enable row level security;
alter table public.atividade_entregas enable row level security;

drop policy if exists escolas_ler on public.escolas;
create policy escolas_ler on public.escolas for select to authenticated using (public.is_admin() or public.membro_da_escola(id));
drop policy if exists escolas_coord on public.escolas;
create policy escolas_coord on public.escolas for update to authenticated using (public.is_admin() or public.coord_da_escola(id)) with check (public.is_admin() or public.coord_da_escola(id));
drop policy if exists escolas_apagar on public.escolas;
create policy escolas_apagar on public.escolas for delete to authenticated using (public.is_admin() or public.coord_da_escola(id));

drop policy if exists escola_membros_ler on public.escola_membros;
create policy escola_membros_ler on public.escola_membros for select to authenticated using (public.is_admin() or public.membro_da_escola(escola_id));
drop policy if exists escola_membros_coord on public.escola_membros;
create policy escola_membros_coord on public.escola_membros for delete to authenticated using (public.is_admin() or public.coord_da_escola(escola_id));

drop policy if exists turmas_ler on public.turmas;
create policy turmas_ler on public.turmas for select to authenticated using (public.is_admin() or public.professor_da_turma(id) or public.aluno_da_turma(id));
drop policy if exists turmas_editar on public.turmas;
create policy turmas_editar on public.turmas for update to authenticated using (public.is_admin() or public.professor_da_turma(id)) with check (public.is_admin() or public.professor_da_turma(id));
drop policy if exists turmas_apagar on public.turmas;
create policy turmas_apagar on public.turmas for delete to authenticated using (public.is_admin() or public.professor_da_turma(id));

drop policy if exists turma_prof_ler on public.turma_professores;
create policy turma_prof_ler on public.turma_professores for select to authenticated using (public.is_admin() or public.professor_da_turma(turma_id) or public.aluno_da_turma(turma_id));
drop policy if exists turma_prof_apagar on public.turma_professores;
create policy turma_prof_apagar on public.turma_professores for delete to authenticated using (public.is_admin() or public.professor_da_turma(turma_id));

drop policy if exists turma_alunos_ler on public.turma_alunos;
create policy turma_alunos_ler on public.turma_alunos for select to authenticated using (public.is_admin() or user_id = auth.uid() or public.professor_da_turma(turma_id));
drop policy if exists turma_alunos_apagar on public.turma_alunos;
create policy turma_alunos_apagar on public.turma_alunos for delete to authenticated using (public.is_admin() or user_id = auth.uid() or public.professor_da_turma(turma_id));

drop policy if exists atividades_ler on public.atividades;
create policy atividades_ler on public.atividades for select to authenticated
  using (public.is_admin() or public.professor_da_turma(turma_id) or (status <> 'rascunho' and public.aluno_da_turma(turma_id)));
drop policy if exists atividades_criar on public.atividades;
create policy atividades_criar on public.atividades for insert to authenticated
  with check (public.is_admin() or (professor_id = auth.uid() and public.professor_da_turma(turma_id)));
drop policy if exists atividades_editar on public.atividades;
create policy atividades_editar on public.atividades for update to authenticated
  using (public.is_admin() or public.professor_da_turma(turma_id)) with check (public.is_admin() or public.professor_da_turma(turma_id));
drop policy if exists atividades_apagar on public.atividades;
create policy atividades_apagar on public.atividades for delete to authenticated using (public.is_admin() or public.professor_da_turma(turma_id));

drop policy if exists entregas_ler on public.atividade_entregas;
create policy entregas_ler on public.atividade_entregas for select to authenticated
  using (public.is_admin() or user_id = auth.uid()
         or exists (select 1 from public.atividades a where a.id = atividade_id and public.professor_da_turma(a.turma_id)));

-- Professores e coordenadores precisam ler as questões em rascunho também (já permitido: logado lê).

-- ---------------------------------------------------------------
-- Escolas
-- ---------------------------------------------------------------
create or replace function public.criar_escola(p_nome text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); e public.escolas;
begin
  if not (is_admin() or meu_papel() = 'coordenador') then raise exception 'Só coordenadores criam escolas.' using errcode = '42501'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome à escola.'; end if;
  insert into public.escolas (nome, criada_por) values (trim(p_nome), u) returning * into e;
  insert into public.escola_membros (escola_id, user_id, papel) values (e.id, u, 'coordenador') on conflict do nothing;
  return to_jsonb(e);
end $$;

-- Coordenador coloca alguém na escola pelo e-mail. Se a pessoa era aluno, vira professor (ou coordenador).
create or replace function public.adicionar_membro_escola(p_escola uuid, p_email text, p_papel text default 'professor')
returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo uuid; nome_alvo text;
begin
  perform exigir_login();
  if not (is_admin() or coord_da_escola(p_escola)) then raise exception 'Só o coordenador da escola.' using errcode = '42501'; end if;
  if p_papel not in ('professor', 'coordenador') then raise exception 'Papel inválido.'; end if;
  select id into alvo from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if alvo is null then raise exception 'Nenhuma conta com o e-mail %. A pessoa precisa criar a conta no app primeiro.', trim(p_email); end if;
  insert into public.escola_membros (escola_id, user_id, papel) values (p_escola, alvo, p_papel)
    on conflict (escola_id, user_id) do update set papel = excluded.papel;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set papel = case when p_papel = 'coordenador' then 'coordenador' when papel = 'aluno' then 'professor' else papel end where user_id = alvo returning nome into nome_alvo;
  return jsonb_build_object('user_id', alvo, 'nome', nome_alvo);
end $$;

-- ---------------------------------------------------------------
-- Turmas
-- ---------------------------------------------------------------
create or replace function public.gerar_codigo_turma()
returns text language plpgsql as $$
declare alfabeto text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; c text; i int;
begin
  loop
    c := '';
    for i in 1..6 loop c := c || substr(alfabeto, 1 + floor(random() * length(alfabeto))::int, 1); end loop;
    exit when not exists (select 1 from public.turmas where codigo = c);
  end loop;
  return c;
end $$;

create or replace function public.criar_turma(p_nome text, p_escola uuid default null, p_materia text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); t public.turmas;
begin
  if not eh_educador() then raise exception 'Só professores e coordenadores criam turmas.' using errcode = '42501'; end if;
  if p_escola is not null and not (is_admin() or membro_da_escola(p_escola)) then raise exception 'Você não faz parte desta escola.' using errcode = '42501'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome à turma.'; end if;
  insert into public.turmas (escola_id, nome, codigo, criada_por) values (p_escola, trim(p_nome), gerar_codigo_turma(), u) returning * into t;
  insert into public.turma_professores (turma_id, user_id, materia_id) values (t.id, u, p_materia) on conflict do nothing;
  return to_jsonb(t);
end $$;

create or replace function public.novo_codigo_turma(p_turma uuid)
returns text language plpgsql security definer set search_path = public as $$
declare c text;
begin
  perform exigir_login();
  if not (is_admin() or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  c := gerar_codigo_turma();
  update public.turmas set codigo = c where id = p_turma;
  return c;
end $$;

create or replace function public.adicionar_professor_turma(p_turma uuid, p_email text, p_materia text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo uuid; nome_alvo text; esc uuid;
begin
  perform exigir_login();
  if not (is_admin() or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  select id into alvo from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if alvo is null then raise exception 'Nenhuma conta com o e-mail %. A pessoa precisa criar a conta no app primeiro.', trim(p_email); end if;
  insert into public.turma_professores (turma_id, user_id, materia_id) values (p_turma, alvo, p_materia)
    on conflict (turma_id, user_id) do update set materia_id = excluded.materia_id;
  select escola_id into esc from public.turmas where id = p_turma;
  if esc is not null then insert into public.escola_membros (escola_id, user_id, papel) values (esc, alvo, 'professor') on conflict do nothing; end if;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set papel = case when papel = 'aluno' then 'professor' else papel end where user_id = alvo returning nome into nome_alvo;
  return jsonb_build_object('user_id', alvo, 'nome', nome_alvo);
end $$;

create or replace function public.adicionar_aluno_turma(p_turma uuid, p_email text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo uuid; nome_alvo text;
begin
  perform exigir_login();
  if not (is_admin() or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  select id into alvo from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if alvo is null then raise exception 'Nenhuma conta com o e-mail %. O aluno precisa criar a conta no app primeiro.', trim(p_email); end if;
  insert into public.turma_alunos (turma_id, user_id) values (p_turma, alvo) on conflict do nothing;
  select nome into nome_alvo from public.perfis where user_id = alvo;
  return jsonb_build_object('user_id', alvo, 'nome', nome_alvo);
end $$;

-- Aluno entra numa turma digitando o código no app
create or replace function public.entrar_turma(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); t public.turmas;
begin
  select * into t from public.turmas where codigo = upper(trim(p_codigo)) and ativa;
  if not found then raise exception 'Código não encontrado. Confira com o professor.'; end if;
  insert into public.turma_alunos (turma_id, user_id) values (t.id, u) on conflict do nothing;
  return jsonb_build_object('id', t.id, 'nome', t.nome, 'estado', estado_aluno());
end $$;

-- Lista de alunos de uma turma, com e-mail (só quem dá aula nela)
create or replace function public.alunos_da_turma(p_turma uuid)
returns table (user_id uuid, nome text, email text, xp int, ofensiva int, entrou_em timestamptz, entregas int)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform exigir_login();
  if not (is_admin() or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  return query
    select ta.user_id, p.nome, u.email::text, coalesce(e.xp, 0), public.ofensiva(ta.user_id), ta.entrou_em,
      (select count(*) from public.atividade_entregas en join public.atividades a on a.id = en.atividade_id
         where en.user_id = ta.user_id and a.turma_id = p_turma and en.entregue_em is not null)::int
    from public.turma_alunos ta
    join public.perfis p on p.user_id = ta.user_id
    join auth.users u on u.id = ta.user_id
    left join public.economia_aluno e on e.user_id = ta.user_id
    where ta.turma_id = p_turma
    order by p.nome;
end $$;

-- Nome e e-mail de professores/coordenadores das turmas e escolas que o usuário acessa
create or replace function public.pessoas_das_turmas()
returns table (user_id uuid, nome text, email text, papel text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform exigir_login();
  return query
    select distinct p.user_id, p.nome, u.email::text, p.papel
    from public.perfis p join auth.users u on u.id = p.user_id
    where is_admin()
       or p.user_id in (select tp.user_id from public.turma_professores tp where professor_da_turma(tp.turma_id) or aluno_da_turma(tp.turma_id))
       or p.user_id in (select em.user_id from public.escola_membros em where membro_da_escola(em.escola_id))
       or p.user_id in (select t.criada_por from public.turmas t where professor_da_turma(t.id));
end $$;

-- ---------------------------------------------------------------
-- Atividades: o que o aluno vê e como entrega
-- ---------------------------------------------------------------
create or replace function public.atividades_do_aluno(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'titulo', a.titulo, 'descricao', a.descricao, 'materia', a.materia_id, 'prazo', a.prazo,
    'turma', t.nome, 'turmaId', t.id, 'questoes', jsonb_array_length(a.questoes),
    'status', case when e.entregue_em is not null then 'entregue'
                   when a.status = 'encerrada' or (a.prazo is not null and a.prazo < now()) then 'encerrada'
                   else 'pendente' end,
    'nota', e.nota, 'acertos', e.acertos, 'total', e.total, 'entregueEm', e.entregue_em
  ) order by (e.entregue_em is not null), a.prazo asc nulls last, a.criada_em desc), '[]'::jsonb)
  from public.atividades a
  join public.turmas t on t.id = a.turma_id and t.ativa
  join public.turma_alunos ta on ta.turma_id = a.turma_id and ta.user_id = p_user
  left join public.atividade_entregas e on e.atividade_id = a.id and e.user_id = p_user
  where a.status <> 'rascunho';
$$;

create or replace function public.turmas_do_aluno(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'nome', t.nome, 'escola', es.nome, 'codigo', t.codigo) order by t.nome), '[]'::jsonb)
  from public.turma_alunos ta join public.turmas t on t.id = ta.turma_id left join public.escolas es on es.id = t.escola_id
  where ta.user_id = p_user and t.ativa;
$$;

-- Abre a atividade para responder: devolve as questões e marca o início
create or replace function public.abrir_atividade(p_atividade uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); a public.atividades; e public.atividade_entregas;
begin
  select * into a from public.atividades where id = p_atividade;
  if not found or a.status = 'rascunho' then raise exception 'Atividade não encontrada.'; end if;
  if not aluno_da_turma(a.turma_id) then raise exception 'Você não está na turma desta atividade.' using errcode = '42501'; end if;
  if a.status = 'encerrada' or (a.prazo is not null and a.prazo < now()) then raise exception 'O prazo desta atividade acabou.'; end if;
  select * into e from public.atividade_entregas where atividade_id = a.id and user_id = u;
  if found and e.entregue_em is not null then raise exception 'Você já entregou esta atividade.'; end if;
  if not found then insert into public.atividade_entregas (atividade_id, user_id) values (a.id, u); end if;
  return jsonb_build_object('id', a.id, 'titulo', a.titulo, 'descricao', a.descricao, 'materia', a.materia_id, 'prazo', a.prazo, 'questoes', a.questoes);
end $$;

-- Corrige no servidor a partir da cópia das questões e grava a nota.
-- p_respostas: [{id, resposta, acertou}] — resposta por tipo:
--   mc: índice da alternativa original · tf: true/false · bank: ["palavra1","palavra2"]
--   order: itens na ordem escolhida · match: true se ligou tudo sem errar
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
  select * into e from public.atividade_entregas where atividade_id = a.id and user_id = u;
  if found and e.entregue_em is not null then raise exception 'Você já entregou esta atividade.'; end if;
  if a.status = 'encerrada' or (a.prazo is not null and a.prazo < now() - interval '10 minutes') then raise exception 'O prazo desta atividade acabou.'; end if;

  for q in select * from jsonb_array_elements(a.questoes) loop
    valor := coalesce((q->>'valor')::numeric, 1);
    select x->'resposta' into r from jsonb_array_elements(p_respostas) x where x->>'id' = q->>'id' limit 1;
    ok := case q->>'tipo'
      when 'mc' then r is not null and r = q->'dados'->'a'
      when 'tf' then r is not null and r = q->'dados'->'a'
      when 'bank' then r is not null and r = q->'dados'->'a'
      when 'order' then r is not null and r = q->'dados'->'items'
      when 'match' then coalesce(r = 'true'::jsonb, false)
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

-- Resultados para o professor: quem entregou, nota de cada um, e quais questões a turma mais errou
create or replace function public.resultados_atividade(p_atividade uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare a public.atividades;
begin
  perform exigir_login();
  select * into a from public.atividades where id = p_atividade;
  if not found then raise exception 'Atividade não encontrada.'; end if;
  if not (is_admin() or professor_da_turma(a.turma_id)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'alunos', (select coalesce(jsonb_agg(jsonb_build_object('user_id', ta.user_id, 'nome', p.nome, 'email', us.email,
        'nota', e.nota, 'acertos', e.acertos, 'total', e.total, 'entregueEm', e.entregue_em, 'iniciadaEm', e.iniciada_em, 'tempo_s', e.tempo_s,
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

-- ---------------------------------------------------------------
-- estado_aluno() passa a trazer papel, turmas e atividades
-- (mesma função da 0002 com três chaves a mais)
-- ---------------------------------------------------------------
create or replace function public.estado_aluno()
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); e public.economia_aluno; d public.dias_aluno; lid uuid; pf public.perfis; mx int; hrs numeric;
begin
  e := regenerar_coracoes(u);
  d := preparar_dia(u);
  lid := entrar_liga(u);
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set visto_em = now() where user_id = u returning * into pf;
  mx := coalesce((param('economia')->>'coracoes')::int, 5);
  hrs := coalesce((param('economia')->>'horasCoracao')::numeric, 5);
  return jsonb_build_object(
    'perfil', jsonb_build_object('nome', pf.nome, 'avatar', pf.avatar, 'materia', pf.materia_atual, 'plus', tem_plus(u), 'plusAte', pf.findout_plus_ate, 'admin', is_admin(), 'papel', pf.papel),
    'economia', jsonb_build_object('coracoes', e.coracoes, 'maxCoracoes', mx,
      'proximoCoracaoEm', case when e.coracoes >= mx then null else e.coracoes_em + (hrs * interval '1 hour') end,
      'moedas', e.moedas, 'xp', e.xp, 'xpSemana', e.xp_semana, 'xpMes', e.xp_mes, 'congeladores', e.congeladores,
      'relampagoHoje', e.relampago_em = hoje()),
    'ofensiva', jsonb_build_object('dias', ofensiva(u), 'hoje', exists (select 1 from public.ofensiva_dias where user_id = u and dia = hoje()),
      'historico', (select coalesce(jsonb_object_agg(dia, tipo), '{}'::jsonb) from public.ofensiva_dias where user_id = u and dia >= hoje() - 60)),
    'progresso', (select coalesce(jsonb_object_agg(licao_id, coroas), '{}'::jsonb) from public.progresso where user_id = u),
    'unidades', (select coalesce(jsonb_object_agg(unidade_id, jsonb_build_object('bau', bau_em is not null, 'trofeu', trofeu_em is not null, 'pulada', pulada_em is not null)), '{}'::jsonb) from public.conquistas_unidade where user_id = u),
    'dia', jsonb_build_object('xp', d.xp, 'licoes', d.licoes, 'bauAberto', d.bau_aberto, 'missoes', missoes_do_dia(u)),
    'erros', (select coalesce(jsonb_agg(questao_id order by errado_em desc), '[]'::jsonb) from public.erros where user_id = u),
    'liga', (select jsonb_build_object('id', l.id, 'nivel', l.nivel, 'semana', l.semana,
      'ranking', (select jsonb_agg(jsonb_build_object('user', p.user_id, 'nome', pr.nome, 'avatar', pr.avatar, 'xp', p.xp, 'eu', p.user_id = u) order by p.xp desc, pr.nome)
                  from public.liga_participantes p join public.perfis pr on pr.user_id = p.user_id where p.liga_id = l.id))
      from public.ligas l where l.id = lid),
    'parametros', jsonb_build_object('economia', param('economia'), 'ligas', param('ligas'), 'missoes', param('missoes')),
    'versaoConteudo', (select max(versao) from public.publicacoes),
    'turmas', turmas_do_aluno(u),
    'atividades', atividades_do_aluno(u)
  );
end $$;

-- A lista de alunos do painel passa a dizer o papel
drop function if exists public.alunos_admin(text, int);
create or replace function public.alunos_admin(p_busca text default '', p_limite int default 50)
returns table (
  user_id uuid, nome text, email text, avatar text,
  xp int, moedas int, coracoes int, congeladores int,
  findout_plus_ate timestamptz, criado_em timestamptz, visto_em timestamptz,
  licoes int, ofensiva int, admin boolean, banido boolean, papel text
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  return query
    select p.user_id, p.nome, u.email::text, p.avatar,
      coalesce(e.xp, 0), coalesce(e.moedas, 0), coalesce(e.coracoes, 0), coalesce(e.congeladores, 0),
      p.findout_plus_ate, p.criado_em, p.visto_em,
      (select count(*) from public.progresso pr where pr.user_id = p.user_id)::int,
      public.ofensiva(p.user_id),
      exists (select 1 from public.admins a where a.user_id = p.user_id),
      coalesce(u.banned_until > now(), false),
      p.papel
    from public.perfis p
    join auth.users u on u.id = p.user_id
    left join public.economia_aluno e on e.user_id = p.user_id
    where coalesce(p_busca, '') = ''
       or p.nome ilike '%' || p_busca || '%'
       or u.email ilike '%' || p_busca || '%'
    order by p.visto_em desc
    limit greatest(1, least(coalesce(p_limite, 50), 200));
end $$;

-- ---------------------------------------------------------------
-- Permissões de execução
-- ---------------------------------------------------------------
grant execute on function public.meu_papel(), public.eh_educador(), public.coord_da_escola(uuid), public.membro_da_escola(uuid), public.professor_da_turma(uuid), public.aluno_da_turma(uuid) to authenticated;
grant execute on function public.criar_escola(text), public.adicionar_membro_escola(uuid, text, text) to authenticated;
grant execute on function public.criar_turma(text, uuid, text), public.novo_codigo_turma(uuid), public.adicionar_professor_turma(uuid, text, text), public.adicionar_aluno_turma(uuid, text), public.entrar_turma(text) to authenticated;
grant execute on function public.alunos_da_turma(uuid), public.pessoas_das_turmas(), public.abrir_atividade(uuid), public.entregar_atividade(uuid, jsonb, int), public.resultados_atividade(uuid) to authenticated;
grant execute on function public.alunos_admin(text, int), public.estado_aluno() to authenticated;
revoke execute on function public.gerar_codigo_turma(), public.atividades_do_aluno(uuid), public.turmas_do_aluno(uuid) from public, anon, authenticated;
