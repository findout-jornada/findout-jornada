-- =====================================================================
-- Findout Jornada · Migration 0004 · Gerenciar administradores pelo painel
-- Rodar no SQL Editor do Supabase depois da 0003. Idempotente.
-- =====================================================================

-- Torna (ou deixa de ser) administrador. Só admin chama; ninguém remove a si mesmo.
create or replace function public.definir_admin(p_user uuid, p_admin boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  if p_admin then
    insert into public.admins (user_id) values (p_user) on conflict do nothing;
  else
    if p_user = auth.uid() then raise exception 'Você não pode remover seu próprio acesso de administrador.'; end if;
    delete from public.admins where user_id = p_user;
  end if;
end $$;
grant execute on function public.definir_admin(uuid, boolean) to authenticated;

-- A lista de alunos passa a dizer quem é admin
drop function if exists public.alunos_admin(text, int);
create or replace function public.alunos_admin(p_busca text default '', p_limite int default 50)
returns table (
  user_id uuid, nome text, email text, avatar text,
  xp int, moedas int, coracoes int, congeladores int,
  findout_plus_ate timestamptz, criado_em timestamptz, visto_em timestamptz,
  licoes int, ofensiva int, admin boolean
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
      exists (select 1 from public.admins a where a.user_id = p.user_id)
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
