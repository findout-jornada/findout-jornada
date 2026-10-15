-- =====================================================================
-- Findout Jornada · Migration 0012 · Segmentos de ensino
-- Rodar no SQL Editor do Supabase depois da 0011. Idempotente.
--
-- Segmento = etapa de ensino (Fundamental II, Ensino Médio, Pré-vestibular…).
-- O admin cadastra os segmentos no painel; cada turma pertence a um segmento;
-- cada questão pode indicar para quais segmentos serve (opcional, vazio = todos).
-- Na busca de questões do professor, o segmento da turma vira filtro padrão,
-- e cada questão mostra o nível (dificuldade) e o segmento.
-- =====================================================================

create table if not exists public.segmentos (
  id text primary key,                 -- 'fund2', 'medio', ...
  nome text not null,
  ordem int not null default 0,
  ativo boolean not null default true
);

alter table public.segmentos enable row level security;
drop policy if exists segmentos_ler on public.segmentos;
create policy segmentos_ler on public.segmentos for select to authenticated using (true);
drop policy if exists segmentos_admin on public.segmentos;
create policy segmentos_admin on public.segmentos for all to authenticated using (public.is_admin()) with check (public.is_admin());

insert into public.segmentos (id, nome, ordem) values
  ('fund1', 'Fundamental I (1º ao 5º ano)', 0),
  ('fund2', 'Fundamental II (6º ao 9º ano)', 1),
  ('medio', 'Ensino Médio', 2),
  ('prevest', 'Pré-vestibular / ENEM', 3),
  ('eja', 'EJA', 4)
on conflict (id) do nothing;

alter table public.turmas add column if not exists segmento_id text references public.segmentos(id) on delete set null;
alter table public.questoes add column if not exists segmentos text[] not null default '{}';
create index if not exists questoes_segmentos_idx on public.questoes using gin (segmentos);

-- criar_turma ganha o segmento
drop function if exists public.criar_turma(text, uuid, text);
create or replace function public.criar_turma(p_nome text, p_escola uuid default null, p_materia text default null, p_segmento text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); t public.turmas;
begin
  if not eh_educador() then raise exception 'Só professores e coordenadores criam turmas.' using errcode = '42501'; end if;
  if p_escola is not null and not (is_admin() or membro_da_escola(p_escola)) then raise exception 'Você não faz parte desta escola.' using errcode = '42501'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome à turma.'; end if;
  if p_segmento is not null and not exists (select 1 from public.segmentos where id = p_segmento) then raise exception 'Segmento inválido.'; end if;
  insert into public.turmas (escola_id, nome, codigo, criada_por, segmento_id) values (p_escola, trim(p_nome), gerar_codigo_turma(), u, p_segmento) returning * into t;
  insert into public.turma_professores (turma_id, user_id, materia_id) values (t.id, u, p_materia) on conflict do nothing;
  return to_jsonb(t);
end $$;
grant execute on function public.criar_turma(text, uuid, text, text) to authenticated;
