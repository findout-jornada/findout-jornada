-- =====================================================================
-- Findout Jornada · Migration 0028 · Alunos da escola (tela Escola do painel)
-- Rodar no SQL Editor depois da 0027. Idempotente.
--
--  · alunos_da_escola(): lista os alunos de todas as turmas da escola para
--    a aba Alunos da tela Escola (admin da escola, coordenador e super).
--    O coordenador com segmentos só recebe os alunos das turmas dos
--    segmentos dele (o filtro é o mesmo professor_da_turma das policies).
-- =====================================================================

create or replace function public.alunos_da_escola(p_escola uuid)
returns table (user_id uuid, nome text, email text, xp int, ofensiva int, turmas text[], entregas int)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform exigir_login();
  if not (is_admin() or coord_da_escola(p_escola)) then raise exception 'Só o admin ou um coordenador da escola.' using errcode = '42501'; end if;
  return query
    select ta.user_id, p.nome, u.email::text, coalesce(e.xp, 0), public.ofensiva(ta.user_id),
      array_agg(distinct t.nome order by t.nome),
      (select count(*) from public.atividade_entregas en
         join public.atividades a2 on a2.id = en.atividade_id
         join public.turmas t2 on t2.id = a2.turma_id
         where en.user_id = ta.user_id and en.entregue_em is not null and t2.escola_id = p_escola)::int
    from public.turma_alunos ta
    join public.turmas t on t.id = ta.turma_id and t.escola_id = p_escola and (is_admin() or professor_da_turma(t.id))
    join public.perfis p on p.user_id = ta.user_id
    join auth.users u on u.id = ta.user_id
    left join public.economia_aluno e on e.user_id = ta.user_id
    group by ta.user_id, p.nome, u.email, e.xp
    order by p.nome;
end $$;
grant execute on function public.alunos_da_escola(uuid) to authenticated;

insert into public.schema_versao (versao) values (28) on conflict do nothing;
