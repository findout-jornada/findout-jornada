-- =====================================================================
-- Findout Jornada · Migration 0001 · Esquema, segurança (RLS) e gatilhos
-- Rodar no SQL Editor do Supabase. Idempotente: pode rodar de novo.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------
-- Administradores (quem edita conteúdo no painel)
-- ---------------------------------------------------------------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  criado_em timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- ---------------------------------------------------------------
-- CONTEÚDO (editado no painel, lido pelo app através do pacote publicado)
-- ---------------------------------------------------------------
create table if not exists public.materias (
  id text primary key,                       -- 'mat', 'por', ...
  nome text not null,
  sigla text not null,
  cor text not null default '#503C9D',
  ativa boolean not null default true,
  ordem int not null default 0
);

create table if not exists public.secoes (
  id uuid primary key default gen_random_uuid(),
  materia_id text not null references public.materias(id) on delete cascade,
  titulo text not null,
  ordem int not null default 0
);

create table if not exists public.unidades (
  id uuid primary key default gen_random_uuid(),
  secao_id uuid not null references public.secoes(id) on delete cascade,
  titulo text not null,
  ordem int not null default 0
);

create table if not exists public.licoes (
  id uuid primary key default gen_random_uuid(),
  unidade_id uuid not null references public.unidades(id) on delete cascade,
  titulo text not null,
  descricao text not null default '',
  ordem int not null default 0
);

create table if not exists public.questoes (
  id uuid primary key default gen_random_uuid(),
  materia_id text not null references public.materias(id) on delete cascade,
  unidade_id uuid references public.unidades(id) on delete set null,
  tipo text not null check (tipo in ('mc','tf','bank','order','match')),
  enunciado text not null,
  dados jsonb not null default '{}'::jsonb,   -- alternativas/pares/itens conforme o tipo
  explicacao text not null default '',
  status text not null default 'rascunho' check (status in ('rascunho','publicada')),
  criada_em timestamptz not null default now(),
  atualizada_em timestamptz not null default now()
);
create index if not exists questoes_unidade_idx on public.questoes(unidade_id);
create index if not exists questoes_materia_idx on public.questoes(materia_id);

create table if not exists public.licao_questoes (
  licao_id uuid not null references public.licoes(id) on delete cascade,
  questao_id uuid not null references public.questoes(id) on delete cascade,
  ordem int not null default 0,
  primary key (licao_id, questao_id)
);

create table if not exists public.missoes (
  id uuid primary key default gen_random_uuid(),
  texto text not null,
  tipo text not null check (tipo in ('xp','combo','materias','licoes','perfeita','revisao','minutos')),
  meta int not null default 1,
  recompensa text not null default 'bau',
  ativa boolean not null default true,
  ordem int not null default 0
);

create table if not exists public.itens_loja (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,              -- 'congelador', 'recarga', 'plus', ...
  nome text not null,
  tipo text not null check (tipo in ('moedas','assinatura')),
  preco int not null default 0,
  rotulo_preco text,
  ativo boolean not null default true,
  ordem int not null default 0
);

-- Parâmetros de jogo (economia, ligas, missões): um registro por chave
create table if not exists public.parametros (
  chave text primary key,
  valor jsonb not null,
  atualizado_em timestamptz not null default now()
);

-- Pacote publicado: o app lê só a última linha
create table if not exists public.publicacoes (
  versao int generated always as identity primary key,
  pacote jsonb not null,
  nota text not null default '',
  criada_em timestamptz not null default now(),
  criada_por uuid references auth.users(id)
);

-- ---------------------------------------------------------------
-- ALUNO
-- ---------------------------------------------------------------
create table if not exists public.perfis (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nome text not null default 'Estudante',
  avatar text not null default 'raposa',
  materia_atual text references public.materias(id),
  findout_plus_ate timestamptz,              -- null = sem Findout+
  criado_em timestamptz not null default now(),
  visto_em timestamptz not null default now()
);

create table if not exists public.economia_aluno (
  user_id uuid primary key references auth.users(id) on delete cascade,
  coracoes int not null default 5,
  coracoes_em timestamptz not null default now(),  -- quando o último coração foi perdido (base da recarga)
  moedas int not null default 0,
  xp int not null default 0,
  xp_semana int not null default 0,
  xp_mes int not null default 0,
  mes_ref text not null default to_char(now(), 'YYYY-MM'),
  congeladores int not null default 0,
  relampago_em date                           -- último dia em que jogou o relâmpago grátis
);

create table if not exists public.progresso (
  user_id uuid not null references auth.users(id) on delete cascade,
  licao_id uuid not null references public.licoes(id) on delete cascade,
  coroas int not null default 1,
  concluida_em timestamptz not null default now(),
  primary key (user_id, licao_id)
);

create table if not exists public.conquistas_unidade (
  user_id uuid not null references auth.users(id) on delete cascade,
  unidade_id uuid not null references public.unidades(id) on delete cascade,
  bau_em timestamptz,
  trofeu_em timestamptz,
  pulada_em timestamptz,
  primary key (user_id, unidade_id)
);

create table if not exists public.ofensiva_dias (
  user_id uuid not null references auth.users(id) on delete cascade,
  dia date not null,
  tipo text not null default 'praticou' check (tipo in ('praticou','congelado')),
  primary key (user_id, dia)
);

-- Contadores do dia: base das missões diárias
create table if not exists public.dias_aluno (
  user_id uuid not null references auth.users(id) on delete cascade,
  dia date not null,
  xp int not null default 0,
  melhor_combo int not null default 0,
  materias text[] not null default '{}',
  licoes int not null default 0,
  perfeitas int not null default 0,
  revisao boolean not null default false,
  minutos int not null default 0,
  missoes uuid[] not null default '{}',      -- missões sorteadas para o dia
  bau_aberto boolean not null default false,
  primary key (user_id, dia)
);

create table if not exists public.erros (
  user_id uuid not null references auth.users(id) on delete cascade,
  questao_id uuid not null references public.questoes(id) on delete cascade,
  errado_em timestamptz not null default now(),
  primary key (user_id, questao_id)
);

create table if not exists public.ligas (
  id uuid primary key default gen_random_uuid(),
  semana date not null,                      -- segunda-feira da semana
  nivel int not null default 0,              -- 0 = Bronze
  criada_em timestamptz not null default now()
);

create table if not exists public.liga_participantes (
  liga_id uuid not null references public.ligas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  xp int not null default 0,
  resultado text check (resultado in ('subiu','manteve','caiu')),
  primary key (liga_id, user_id)
);
create index if not exists liga_part_user_idx on public.liga_participantes(user_id);

-- Registro de cada lição feita (métricas)
create table if not exists public.eventos_licao (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  modo text not null,                        -- licao, pratica, revisao, erros, lendaria, pular, relampago, unidade
  licao_id uuid references public.licoes(id) on delete set null,
  unidade_id uuid references public.unidades(id) on delete set null,
  acertos int not null default 0,
  erros int not null default 0,
  melhor_combo int not null default 0,
  tempo_s int not null default 0,
  xp int not null default 0,
  moedas int not null default 0,
  criado_em timestamptz not null default now()
);
create index if not exists eventos_user_idx on public.eventos_licao(user_id, criado_em desc);

-- ---------------------------------------------------------------
-- Gatilho: novo usuário ganha perfil e economia inicial
-- ---------------------------------------------------------------
create or replace function public.novo_usuario()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfis (user_id, nome)
  values (new.id, coalesce(new.raw_user_meta_data->>'nome', new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)))
  on conflict do nothing;
  insert into public.economia_aluno (user_id, moedas)
  values (new.id, coalesce((select (valor->>'moedasIniciais')::int from public.parametros where chave = 'economia'), 100))
  on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.novo_usuario();

-- ---------------------------------------------------------------
-- Segurança (RLS)
-- ---------------------------------------------------------------
alter table public.admins enable row level security;
alter table public.materias enable row level security;
alter table public.secoes enable row level security;
alter table public.unidades enable row level security;
alter table public.licoes enable row level security;
alter table public.questoes enable row level security;
alter table public.licao_questoes enable row level security;
alter table public.missoes enable row level security;
alter table public.itens_loja enable row level security;
alter table public.parametros enable row level security;
alter table public.publicacoes enable row level security;
alter table public.perfis enable row level security;
alter table public.economia_aluno enable row level security;
alter table public.progresso enable row level security;
alter table public.conquistas_unidade enable row level security;
alter table public.ofensiva_dias enable row level security;
alter table public.dias_aluno enable row level security;
alter table public.erros enable row level security;
alter table public.ligas enable row level security;
alter table public.liga_participantes enable row level security;
alter table public.eventos_licao enable row level security;

-- admins: cada um vê só a própria linha (basta para o painel saber que é admin)
drop policy if exists admins_self on public.admins;
create policy admins_self on public.admins for select using (user_id = auth.uid());

-- conteúdo: logado lê; só admin escreve
do $$
declare t text;
begin
  foreach t in array array['materias','secoes','unidades','licoes','questoes','licao_questoes','missoes','itens_loja','parametros']
  loop
    execute format('drop policy if exists %I_ler on public.%I', t, t);
    execute format('create policy %I_ler on public.%I for select to authenticated using (true)', t, t);
    execute format('drop policy if exists %I_admin on public.%I', t, t);
    execute format('create policy %I_admin on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())', t, t);
  end loop;
end $$;

-- publicações: logado lê; só admin publica
drop policy if exists publicacoes_ler on public.publicacoes;
create policy publicacoes_ler on public.publicacoes for select to authenticated using (true);
drop policy if exists publicacoes_admin on public.publicacoes;
create policy publicacoes_admin on public.publicacoes for insert to authenticated with check (public.is_admin());

-- perfis: todos logados leem nome/avatar (liga); dono edita nome/avatar/matéria; admin tudo
drop policy if exists perfis_ler on public.perfis;
create policy perfis_ler on public.perfis for select to authenticated using (true);
drop policy if exists perfis_dono on public.perfis;
create policy perfis_dono on public.perfis for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists perfis_admin on public.perfis;
create policy perfis_admin on public.perfis for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- dados do aluno: só o dono lê. Escrita só pelas funções (security definer) ou admin.
do $$
declare t text;
begin
  foreach t in array array['economia_aluno','progresso','conquistas_unidade','ofensiva_dias','dias_aluno','erros','eventos_licao']
  loop
    execute format('drop policy if exists %I_dono on public.%I', t, t);
    execute format('create policy %I_dono on public.%I for select to authenticated using (user_id = auth.uid())', t, t);
    execute format('drop policy if exists %I_admin on public.%I', t, t);
    execute format('create policy %I_admin on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())', t, t);
  end loop;
end $$;

-- ligas: participante vê a própria liga e os colegas dela
drop policy if exists ligas_ler on public.ligas;
create policy ligas_ler on public.ligas for select to authenticated
  using (public.is_admin() or exists (select 1 from public.liga_participantes p where p.liga_id = ligas.id and p.user_id = auth.uid()));
drop policy if exists liga_part_ler on public.liga_participantes;
create policy liga_part_ler on public.liga_participantes for select to authenticated
  using (public.is_admin() or exists (select 1 from public.liga_participantes p where p.liga_id = liga_participantes.liga_id and p.user_id = auth.uid()));
drop policy if exists ligas_admin on public.ligas;
create policy ligas_admin on public.ligas for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists liga_part_admin on public.liga_participantes;
create policy liga_part_admin on public.liga_participantes for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------
-- Parâmetros iniciais (os mesmos do protótipo)
-- ---------------------------------------------------------------
insert into public.parametros (chave, valor) values
('economia', '{"coracoes":5,"horasCoracao":5,"custoRecarga":350,"custoCongelador":200,"maxCongeladores":2,
  "xpLicao":15,"xpPratica":5,"xpExercicio":10,"comboAPartirDe":3,"bonusCombo":5,"bonusPerfeita":5,
  "moedasLicao":10,"moedasBau":25,"xpLendaria":40,"moedasLendaria":100,"xpPular":20,"moedasPular":20,
  "acertosPular":4,"questoesPular":5,"tamanhoLicao":5,"segundosRelampago":120,"multiplicadorRelampago":2,
  "xpRevisao":20,"moedasRevisao":10,"tamanhoRevisao":8,"xpErros":10,"moedasIniciais":100}'),
('ligas', '{"tamanho":15,"sobem":7,"caem":5,"moedasTop3":200,"niveis":["Bronze","Prata","Ouro","Safira","Rubi","Esmeralda","Diamante"]}'),
('missoes', '{"porDia":3,"moedasBauDiario":50,
  "mensal":{"titulo":"Desafio do mês","metaXp":1500,"moedas":150,"distintivo":"Mensal","ativo":true},
  "dupla":{"ativo":false,"licoes":20,"dias":5,"moedas":100},
  "revisao":{"ativo":true,"tamanho":8,"xp":20}}')
on conflict (chave) do nothing;

insert into public.itens_loja (codigo, nome, tipo, preco, rotulo_preco, ativo, ordem) values
('plus', 'Findout+ (corações ilimitados)', 'assinatura', 0, 'Pix · fale com a gente', true, 0),
('congelador', 'Congelador de ofensiva', 'moedas', 200, null, true, 1),
('recarga', 'Recarga de corações', 'moedas', 350, null, true, 2)
on conflict (codigo) do nothing;

insert into public.missoes (texto, tipo, meta, ordem) values
('Ganhe 30 XP', 'xp', 30, 0),
('Acerte 5 exercícios seguidos', 'combo', 5, 1),
('Pratique 2 matérias diferentes', 'materias', 2, 2),
('Complete 3 lições', 'licoes', 3, 3),
('Faça uma lição perfeita', 'perfeita', 1, 4),
('Faça a revisão diária', 'revisao', 1, 5)
on conflict do nothing;
