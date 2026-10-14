-- =====================================================================
-- Findout Jornada · Migration 0010 · Lista de alunos mostra bloqueados
-- Rodar no SQL Editor do Supabase depois da 0009. Idempotente.
-- A coluna nova "banido" diz se o login do aluno está bloqueado
-- (botões Bloquear/Liberar da aba Alunos do painel).
-- =====================================================================

drop function if exists public.alunos_admin(text, int);
create or replace function public.alunos_admin(p_busca text default '', p_limite int default 50)
returns table (
  user_id uuid, nome text, email text, avatar text,
  xp int, moedas int, coracoes int, congeladores int,
  findout_plus_ate timestamptz, criado_em timestamptz, visto_em timestamptz,
  licoes int, ofensiva int, admin boolean, banido boolean
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
      coalesce(u.banned_until > now(), false)
    from public.perfis p
    join auth.users u on u.id = p.user_id
    left join public.economia_aluno e on e.user_id = p.user_id
    where coalesce(p_busca, '') = ''
       or p.nome ilike '%' || p_busca || '%'
       or u.email ilike '%' || p_busca || '%'
    order by p.visto_em desc
    limit greatest(1, least(coalesce(p_limite, 50), 200));
end $$;
grant execute on function public.alunos_admin(text, int) to authenticated;
