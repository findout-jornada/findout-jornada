-- =====================================================================
-- Findout Jornada · Migration 0016 · Disciplina do professor e limites de acesso
-- Rodar no SQL Editor do Supabase depois da 0015. Idempotente.
--
-- · O cadastro do professor indica a disciplina dele (perfis.disciplina_id).
-- · Professor com disciplina só vê, cria e acompanha atividades da sua disciplina
--   (ou criadas por ele) nas turmas em que dá aula. Turmas: só as dele (já era assim).
-- · Coordenador enxerga a escola inteira (todas as turmas e atividades), mas continua
--   sem o resto do painel (conteúdo, questões, publicação, auditoria), que é só do admin.
-- =====================================================================

alter table public.perfis add column if not exists disciplina_id text references public.materias(id) on delete set null;

-- A disciplina também é protegida: só admin/coordenador mudam (pelas funções abaixo)
create or replace function public.perfis_protege_colunas()
returns trigger language plpgsql as $$
begin
  if (new.papel is distinct from old.papel or new.findout_plus_ate is distinct from old.findout_plus_ate or new.disciplina_id is distinct from old.disciplina_id)
     and not public.is_admin() and coalesce(current_setting('fj.liberar_perfil', true), '') <> '1' then
    raise exception 'Você não pode alterar este campo do perfil.' using errcode = '42501';
  end if;
  return new;
end $$;

create or replace function public.minha_disciplina()
returns text language sql stable security definer set search_path = public as $$
  select disciplina_id from public.perfis where user_id = auth.uid();
$$;
-- Professor (não admin, não coordenador) com disciplina definida: vê só a disciplina dele
create or replace function public.disciplina_restrita()
returns boolean language sql stable security definer set search_path = public as $$
  select not public.is_admin() and public.meu_papel() = 'professor' and public.minha_disciplina() is not null;
$$;
-- Coordenador da escola da turma
create or replace function public.coord_da_turma(p_turma uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.turmas t where t.id = p_turma and t.escola_id is not null and public.coord_da_escola(t.escola_id));
$$;
-- Quem pode ver/gerenciar uma atividade: admin, coordenador da escola, ou professor da turma
-- (se tiver disciplina, só atividades dela ou criadas por ele)
create or replace function public.acesso_atividade(p_turma uuid, p_materia text, p_prof uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.coord_da_turma(p_turma)
      or (public.professor_da_turma(p_turma) and (not public.disciplina_restrita() or p_prof = auth.uid() or p_materia = public.minha_disciplina()));
$$;

drop policy if exists atividades_ler on public.atividades;
create policy atividades_ler on public.atividades for select to authenticated
  using (public.acesso_atividade(turma_id, materia_id, professor_id) or (status <> 'rascunho' and public.aluno_da_turma(turma_id)));
drop policy if exists atividades_criar on public.atividades;
create policy atividades_criar on public.atividades for insert to authenticated
  with check (public.is_admin() or (professor_id = auth.uid() and public.professor_da_turma(turma_id) and (not public.disciplina_restrita() or materia_id = public.minha_disciplina())));
drop policy if exists atividades_editar on public.atividades;
create policy atividades_editar on public.atividades for update to authenticated
  using (public.acesso_atividade(turma_id, materia_id, professor_id))
  with check (public.acesso_atividade(turma_id, materia_id, professor_id) and (not public.disciplina_restrita() or materia_id = public.minha_disciplina()));
drop policy if exists atividades_apagar on public.atividades;
create policy atividades_apagar on public.atividades for delete to authenticated using (public.acesso_atividade(turma_id, materia_id, professor_id));

drop policy if exists entregas_ler on public.atividade_entregas;
create policy entregas_ler on public.atividade_entregas for select to authenticated
  using (user_id = auth.uid() or exists (select 1 from public.atividades a where a.id = atividade_id and public.acesso_atividade(a.turma_id, a.materia_id, a.professor_id)));

-- Resultados: mesma regra
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
-- Cadastro: papel + disciplina
-- ---------------------------------------------------------------
drop function if exists public.definir_papel(uuid, text);
create or replace function public.definir_papel(p_user uuid, p_papel text, p_disciplina text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  if p_papel not in ('aluno', 'professor', 'coordenador') then raise exception 'Papel inválido: %', p_papel; end if;
  if p_papel = 'professor' and p_disciplina is null then raise exception 'Informe a disciplina do professor.'; end if;
  if p_disciplina is not null and not exists (select 1 from public.materias where id = p_disciplina) then raise exception 'Disciplina inválida.'; end if;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set papel = p_papel, disciplina_id = case when p_papel = 'professor' then p_disciplina else null end where user_id = p_user;
end $$;
grant execute on function public.definir_papel(uuid, text, text) to authenticated;

-- Coordenador adiciona professor à escola já com a disciplina
drop function if exists public.adicionar_membro_escola(uuid, text, text);
create or replace function public.adicionar_membro_escola(p_escola uuid, p_email text, p_papel text default 'professor', p_disciplina text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo uuid; nome_alvo text;
begin
  perform exigir_login();
  if not (is_admin() or coord_da_escola(p_escola)) then raise exception 'Só o coordenador da escola.' using errcode = '42501'; end if;
  if p_papel not in ('professor', 'coordenador') then raise exception 'Papel inválido.'; end if;
  if p_papel = 'professor' and p_disciplina is null then raise exception 'Informe a disciplina do professor.'; end if;
  if p_disciplina is not null and not exists (select 1 from public.materias where id = p_disciplina) then raise exception 'Disciplina inválida.'; end if;
  select id into alvo from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if alvo is null then raise exception 'Nenhuma conta com o e-mail %. A pessoa precisa criar a conta no app primeiro.', trim(p_email); end if;
  insert into public.escola_membros (escola_id, user_id, papel) values (p_escola, alvo, p_papel)
    on conflict (escola_id, user_id) do update set papel = excluded.papel;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis
    set papel = case when p_papel = 'coordenador' then 'coordenador' when papel = 'aluno' then 'professor' else papel end,
        disciplina_id = case when p_papel = 'professor' then p_disciplina else disciplina_id end
    where user_id = alvo returning nome into nome_alvo;
  return jsonb_build_object('user_id', alvo, 'nome', nome_alvo);
end $$;
grant execute on function public.adicionar_membro_escola(uuid, text, text, text) to authenticated;

-- Professor na turma: sem matéria informada, vale a disciplina do cadastro dele
create or replace function public.adicionar_professor_turma(p_turma uuid, p_email text, p_materia text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo uuid; nome_alvo text; esc uuid; mat text;
begin
  perform exigir_login();
  if not (is_admin() or coord_da_turma(p_turma) or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  select id into alvo from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if alvo is null then raise exception 'Nenhuma conta com o e-mail %. A pessoa precisa criar a conta no app primeiro.', trim(p_email); end if;
  mat := coalesce(p_materia, (select disciplina_id from public.perfis where user_id = alvo));
  insert into public.turma_professores (turma_id, user_id, materia_id) values (p_turma, alvo, mat)
    on conflict (turma_id, user_id) do update set materia_id = excluded.materia_id;
  select escola_id into esc from public.turmas where id = p_turma;
  if esc is not null then insert into public.escola_membros (escola_id, user_id, papel) values (esc, alvo, 'professor') on conflict do nothing; end if;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set papel = case when papel = 'aluno' then 'professor' else papel end where user_id = alvo returning nome into nome_alvo;
  return jsonb_build_object('user_id', alvo, 'nome', nome_alvo);
end $$;

-- Criar turma: a matéria do criador na turma é a disciplina dele, se não informar outra
create or replace function public.criar_turma(p_nome text, p_escola uuid default null, p_materia text default null, p_segmento text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); t public.turmas;
begin
  if not eh_educador() then raise exception 'Só professores e coordenadores criam turmas.' using errcode = '42501'; end if;
  if p_escola is not null and not (is_admin() or membro_da_escola(p_escola)) then raise exception 'Você não faz parte desta escola.' using errcode = '42501'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome à turma.'; end if;
  if p_segmento is not null and not exists (select 1 from public.segmentos where id = p_segmento) then raise exception 'Segmento inválido.'; end if;
  insert into public.turmas (escola_id, nome, codigo, criada_por, segmento_id) values (p_escola, trim(p_nome), gerar_codigo_turma(), u, p_segmento) returning * into t;
  insert into public.turma_professores (turma_id, user_id, materia_id) values (t.id, u, coalesce(p_materia, minha_disciplina())) on conflict do nothing;
  return to_jsonb(t);
end $$;

-- Pessoas das turmas agora trazem a disciplina (para listar os professores com a matéria deles)
drop function if exists public.pessoas_das_turmas();
create or replace function public.pessoas_das_turmas()
returns table (user_id uuid, nome text, email text, papel text, disciplina text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform exigir_login();
  return query
    select distinct p.user_id, p.nome, u.email::text, p.papel, p.disciplina_id
    from public.perfis p join auth.users u on u.id = p.user_id
    where is_admin()
       or p.user_id in (select tp.user_id from public.turma_professores tp where professor_da_turma(tp.turma_id) or aluno_da_turma(tp.turma_id))
       or p.user_id in (select em.user_id from public.escola_membros em where membro_da_escola(em.escola_id))
       or p.user_id in (select t.criada_por from public.turmas t where professor_da_turma(t.id));
end $$;
grant execute on function public.pessoas_das_turmas() to authenticated;
