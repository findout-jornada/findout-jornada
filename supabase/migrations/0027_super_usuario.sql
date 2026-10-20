-- =====================================================================
-- Findout Jornada · Migration 0027 · Super usuário, admin da escola e exclusão de contas
-- Rodar no SQL Editor depois da 0026. Idempotente.
--
-- Modelo "multiempresa":
--  · SUPER USUÁRIO (tabela admins, o antigo "admin"): suporte da plataforma
--    inteira — conteúdo, publicação, relatórios, auditoria, todas as escolas
--    e a exclusão de contas. Continua sendo o que is_admin() confere, então
--    nenhuma policy antiga muda de significado.
--  · ADMIN DA ESCOLA (papel novo em escola_membros): gerencia a escola dele
--    inteira — membros (professores, coordenadores e outros admins), todas
--    as turmas e segmentos, sem restrição de segmento.
--  · Coordenador (escola limitada aos segmentos dele) e professor (as turmas
--    em que dá aula) continuam como na 0026.
--  · Só o super usuário cria escolas e exclui contas (excluir_usuario).
-- =====================================================================

-- Papel 'admin' no perfil e na escola
alter table public.perfis drop constraint if exists perfis_papel_check;
alter table public.perfis add constraint perfis_papel_check check (papel in ('aluno', 'professor', 'coordenador', 'admin'));
alter table public.escola_membros drop constraint if exists escola_membros_papel_check;
alter table public.escola_membros add constraint escola_membros_papel_check check (papel in ('professor', 'coordenador', 'admin'));

create or replace function public.admin_da_escola(p_escola uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.escola_membros where escola_id = p_escola and user_id = auth.uid() and papel = 'admin');
$$;
grant execute on function public.admin_da_escola(uuid) to authenticated;

-- Quem gerencia a escola (membros, segmentos, dados da escola): coordenador ou admin dela
create or replace function public.coord_da_escola(p_escola uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.escola_membros where escola_id = p_escola and user_id = auth.uid() and papel in ('coordenador', 'admin'));
$$;

-- Acesso às turmas: admin da escola vê todas; coordenador só as dos segmentos dele
create or replace function public.coord_da_turma(p_turma uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.turmas t
    join public.escola_membros em on em.escola_id = t.escola_id and em.user_id = auth.uid()
    where t.id = p_turma
      and (em.papel = 'admin'
        or (em.papel = 'coordenador' and (em.segmentos = '{}' or t.segmento_id is null or t.segmento_id = any(em.segmentos))))
  );
$$;

-- Admin da escola também entra no painel e cria turmas
create or replace function public.eh_educador()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or public.meu_papel() in ('professor', 'coordenador', 'admin');
$$;

-- O super define o papel pela aba Alunos (admin = admin de escola; o vínculo
-- com a escola em si é feito no card da escola, em "Adicionar admin")
create or replace function public.definir_papel(p_user uuid, p_papel text, p_disciplina text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Só o super usuário.' using errcode = '42501'; end if;
  if p_papel not in ('aluno', 'professor', 'coordenador', 'admin') then raise exception 'Papel inválido: %', p_papel; end if;
  if p_papel = 'professor' and p_disciplina is null then raise exception 'Informe a disciplina do professor.'; end if;
  if p_disciplina is not null and not exists (select 1 from public.materias where id = p_disciplina) then raise exception 'Disciplina inválida.'; end if;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set papel = p_papel, disciplina_id = case when p_papel = 'professor' then p_disciplina else null end where user_id = p_user;
end $$;

-- Só o super cria escolas (modelo multiempresa: o suporte abre a escola e
-- define o admin dela em "Adicionar admin" no card da escola)
create or replace function public.criar_escola(p_nome text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); e public.escolas;
begin
  if not is_admin() then raise exception 'Só o super usuário cria escolas.' using errcode = '42501'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome à escola.'; end if;
  insert into public.escolas (nome, criada_por) values (trim(p_nome), u) returning * into e;
  return to_jsonb(e);
end $$;

-- Membros: papel 'admin' só pode ser dado pelo super ou por um admin da escola;
-- e só eles mexem em quem já é admin da escola
drop function if exists public.adicionar_membro_escola(uuid, text, text, text, text[]);
create or replace function public.adicionar_membro_escola(p_escola uuid, p_email text, p_papel text default 'professor', p_disciplina text default null, p_segmentos text[] default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo uuid; nome_alvo text; segs text[] := coalesce(p_segmentos, '{}'); invalido text;
begin
  perform exigir_login();
  if not (is_admin() or coord_da_escola(p_escola)) then raise exception 'Só o admin ou o coordenador da escola.' using errcode = '42501'; end if;
  if p_papel not in ('professor', 'coordenador', 'admin') then raise exception 'Papel inválido.'; end if;
  if p_papel = 'admin' and not (is_admin() or admin_da_escola(p_escola)) then raise exception 'Só o super usuário ou um admin da escola adiciona outro admin.' using errcode = '42501'; end if;
  if p_papel = 'professor' and p_disciplina is null then raise exception 'Informe a disciplina do professor.'; end if;
  if p_disciplina is not null and not exists (select 1 from public.materias where id = p_disciplina) then raise exception 'Disciplina inválida.'; end if;
  if p_papel <> 'coordenador' then segs := '{}'; end if;
  select s into invalido from unnest(segs) s where not exists (select 1 from public.segmentos g where g.id = s) limit 1;
  if invalido is not null then raise exception 'Segmento inválido: %', invalido; end if;
  select id into alvo from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if alvo is null then raise exception 'Nenhuma conta com o e-mail %. A pessoa precisa criar a conta no app primeiro.', trim(p_email); end if;
  if exists (select 1 from public.escola_membros where escola_id = p_escola and user_id = alvo and papel = 'admin')
     and not (is_admin() or admin_da_escola(p_escola)) then
    raise exception 'Esta pessoa é admin da escola; só o super usuário ou outro admin pode mudar.' using errcode = '42501';
  end if;
  insert into public.escola_membros (escola_id, user_id, papel, segmentos) values (p_escola, alvo, p_papel, segs)
    on conflict (escola_id, user_id) do update set papel = excluded.papel, segmentos = excluded.segmentos;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis
    set papel = case when p_papel = 'admin' then 'admin' when p_papel = 'coordenador' then 'coordenador' when papel = 'aluno' then 'professor' else papel end,
        disciplina_id = case when p_papel = 'professor' then p_disciplina else disciplina_id end
    where user_id = alvo returning nome into nome_alvo;
  return jsonb_build_object('user_id', alvo, 'nome', nome_alvo);
end $$;
grant execute on function public.adicionar_membro_escola(uuid, text, text, text, text[]) to authenticated;

-- Remover membro: coordenador não remove um admin da escola
drop policy if exists escola_membros_coord on public.escola_membros;
create policy escola_membros_coord on public.escola_membros for delete to authenticated
  using (public.is_admin() or public.admin_da_escola(escola_id) or (public.coord_da_escola(escola_id) and papel <> 'admin'));

-- Excluir a escola: só o super ou um admin dela
drop policy if exists escolas_apagar on public.escolas;
create policy escolas_apagar on public.escolas for delete to authenticated
  using (public.is_admin() or public.admin_da_escola(id));

-- ---------------------------------------------------------------
-- Exclusão de contas (só o super usuário)
-- A conta sai do auth.users e o cascade apaga perfil, economia,
-- progresso, turmas e entregas. atividades.professor_id e
-- publicacoes.criada_por ficam nulos (migration 0021), e a auditoria
-- não tem FK, então o histórico (inclusive desta exclusão) permanece.
-- ---------------------------------------------------------------
create or replace function public.excluir_usuario(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); alvo_email text; alvo_nome text;
begin
  if not is_admin() then raise exception 'Só o super usuário exclui contas.' using errcode = '42501'; end if;
  if p_user = u then raise exception 'Você não pode excluir a própria conta por aqui.'; end if;
  if exists (select 1 from public.admins where user_id = p_user) then raise exception 'Esta conta é super usuário. Tire o acesso dela primeiro.'; end if;
  select us.email::text, p.nome into alvo_email, alvo_nome
    from auth.users us left join public.perfis p on p.user_id = us.id where us.id = p_user;
  if alvo_email is null then raise exception 'Conta não encontrada.'; end if;
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', 'exclusao_conta', 'alunos', p_user::text,
            left('Excluiu a conta de ' || coalesce(alvo_nome, alvo_email), 200),
            jsonb_build_object('email', alvo_email, 'nome', alvo_nome));
  delete from auth.users where id = p_user;
  return jsonb_build_object('ok', true, 'email', alvo_email);
end $$;
grant execute on function public.excluir_usuario(uuid) to authenticated;

insert into public.schema_versao (versao) values (27) on conflict do nothing;
