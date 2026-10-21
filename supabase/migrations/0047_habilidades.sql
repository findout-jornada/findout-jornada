-- =====================================================================
-- Findout Jornada · Migration 0047 · Habilidades e pré-requisitos
-- Rodar no SQL Editor depois da 0046. Idempotente.
--
-- Fase B do motor de aprendizagem personalizada: a habilidade vira
-- entidade (código BNCC/ENEM cadastrado pelo admin — nunca inventado),
-- cada questão pode apontar as habilidades que exige e cada habilidade
-- pode declarar pré-requisitos. É o grafo que as fases C (domínio) e
-- D (lacunas e recomendações) vão percorrer sobre as `tentativas`.
-- =====================================================================

create table if not exists public.habilidades (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,              -- ex.: EM13MAT302 (BNCC), C2H7 (ENEM) ou um código próprio
  nome text not null,
  descricao text not null default '',
  materia_id text references public.materias(id) on delete set null,
  referencial text not null default 'propria' check (referencial in ('bncc', 'enem', 'propria')),
  ativa boolean not null default true,
  criada_em timestamptz not null default now()
);

create table if not exists public.questao_habilidades (
  questao_id uuid not null references public.questoes(id) on delete cascade,
  habilidade_id uuid not null references public.habilidades(id) on delete cascade,
  primary key (questao_id, habilidade_id)
);
create index if not exists qhab_habilidade_idx on public.questao_habilidades(habilidade_id);

create table if not exists public.habilidade_prerequisitos (
  habilidade_id uuid not null references public.habilidades(id) on delete cascade,
  prerequisito_id uuid not null references public.habilidades(id) on delete cascade,
  primary key (habilidade_id, prerequisito_id),
  check (habilidade_id <> prerequisito_id)
);

-- Leitura para qualquer logado (não há gabarito aqui); escrita só do admin
do $$
declare t text;
begin
  foreach t in array array['habilidades', 'questao_habilidades', 'habilidade_prerequisitos']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I_ler on public.%I', t, t);
    execute format('create policy %I_ler on public.%I for select to authenticated using (true)', t, t);
    execute format('drop policy if exists %I_admin on public.%I', t, t);
    execute format('create policy %I_admin on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())', t, t);
    -- auditoria: mesmo gatilho genérico das demais tabelas de conteúdo (migration 0014)
    execute format('drop trigger if exists auditoria_%I on public.%I', t, t);
    execute format('create trigger auditoria_%I after insert or update or delete on public.%I for each row execute function public.fj_auditar_trigger()', t, t);
  end loop;
end $$;

insert into public.schema_versao (versao) values (47) on conflict do nothing;
