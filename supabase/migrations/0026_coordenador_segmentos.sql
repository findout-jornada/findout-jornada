-- =====================================================================
-- Findout Jornada · Migration 0026 · Coordenador por segmento
-- Rodar no SQL Editor depois da 0025. Idempotente.
--
-- Regras de acesso do painel:
--  · Admin: acessa tudo (como já era).
--  · Professor: só as turmas em que dá aula (turma_professores), incluindo
--    criar e acompanhar atividades nelas (como já era).
--  · Coordenador: tudo da(s) escola(s) dele, mas limitado aos SEGMENTOS
--    que ele coordena (escola_membros.segmentos). Lista vazia = a escola
--    inteira (compatível com os coordenadores que já existem). Turma sem
--    segmento aparece para qualquer coordenador da escola.
--
-- Como professor_da_turma() e coord_da_turma() são a base de todas as
-- policies e funções (turmas, alunos, atividades, entregas, resultados,
-- notas, recorreção), trocar as duas aplica a regra no sistema inteiro.
-- =====================================================================

-- Segmentos que cada coordenador coordena ('{}' = escola inteira)
alter table public.escola_membros add column if not exists segmentos text[] not null default '{}';

-- Coordenador da escola da turma, respeitando os segmentos dele
create or replace function public.coord_da_turma(p_turma uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.turmas t
    join public.escola_membros em on em.escola_id = t.escola_id and em.user_id = auth.uid() and em.papel = 'coordenador'
    where t.id = p_turma
      and (em.segmentos = '{}' or t.segmento_id is null or t.segmento_id = any(em.segmentos))
  );
$$;

-- Quem gerencia a turma: professor dela, quem a criou, coordenador do
-- segmento dela (antes era qualquer coordenador da escola) ou admin
-- (o is_admin() entra nas policies que chamam esta função).
create or replace function public.professor_da_turma(p_turma uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.turma_professores where turma_id = p_turma and user_id = auth.uid())
      or exists (select 1 from public.turmas t where t.id = p_turma and t.criada_por = auth.uid())
      or public.coord_da_turma(p_turma);
$$;

-- Admin ou coordenador da escola define os segmentos de um coordenador
create or replace function public.definir_segmentos_coordenador(p_escola uuid, p_user uuid, p_segmentos text[] default '{}')
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); segs text[] := coalesce(p_segmentos, '{}'); nome_alvo text; invalido text;
begin
  if not (is_admin() or coord_da_escola(p_escola)) then raise exception 'Só o coordenador da escola ou um admin.' using errcode = '42501'; end if;
  select s into invalido from unnest(segs) s where not exists (select 1 from public.segmentos g where g.id = s) limit 1;
  if invalido is not null then raise exception 'Segmento inválido: %', invalido; end if;
  if not exists (select 1 from public.escola_membros where escola_id = p_escola and user_id = p_user and papel = 'coordenador') then
    raise exception 'Esta pessoa não é coordenador desta escola.';
  end if;
  update public.escola_membros set segmentos = segs where escola_id = p_escola and user_id = p_user;
  select nome into nome_alvo from public.perfis where user_id = p_user;
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', 'segmentos_coord', 'escola_membros', p_user::text,
            left('Segmentos de ' || coalesce(nome_alvo, 'coordenador') || ': ' || case when segs = '{}' then 'escola inteira' else array_to_string(segs, ', ') end, 200),
            jsonb_build_object('escola', p_escola, 'segmentos', to_jsonb(segs)));
  return jsonb_build_object('user_id', p_user, 'segmentos', to_jsonb(segs));
end $$;
grant execute on function public.definir_segmentos_coordenador(uuid, uuid, text[]) to authenticated;

-- adicionar_membro_escola ganha os segmentos do coordenador (opcional)
drop function if exists public.adicionar_membro_escola(uuid, text, text, text);
create or replace function public.adicionar_membro_escola(p_escola uuid, p_email text, p_papel text default 'professor', p_disciplina text default null, p_segmentos text[] default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo uuid; nome_alvo text; segs text[] := coalesce(p_segmentos, '{}'); invalido text;
begin
  perform exigir_login();
  if not (is_admin() or coord_da_escola(p_escola)) then raise exception 'Só o coordenador da escola.' using errcode = '42501'; end if;
  if p_papel not in ('professor', 'coordenador') then raise exception 'Papel inválido.'; end if;
  if p_papel = 'professor' and p_disciplina is null then raise exception 'Informe a disciplina do professor.'; end if;
  if p_disciplina is not null and not exists (select 1 from public.materias where id = p_disciplina) then raise exception 'Disciplina inválida.'; end if;
  if p_papel <> 'coordenador' then segs := '{}'; end if;
  select s into invalido from unnest(segs) s where not exists (select 1 from public.segmentos g where g.id = s) limit 1;
  if invalido is not null then raise exception 'Segmento inválido: %', invalido; end if;
  select id into alvo from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if alvo is null then raise exception 'Nenhuma conta com o e-mail %. A pessoa precisa criar a conta no app primeiro.', trim(p_email); end if;
  insert into public.escola_membros (escola_id, user_id, papel, segmentos) values (p_escola, alvo, p_papel, segs)
    on conflict (escola_id, user_id) do update set papel = excluded.papel, segmentos = excluded.segmentos;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis
    set papel = case when p_papel = 'coordenador' then 'coordenador' when papel = 'aluno' then 'professor' else papel end,
        disciplina_id = case when p_papel = 'professor' then p_disciplina else disciplina_id end
    where user_id = alvo returning nome into nome_alvo;
  return jsonb_build_object('user_id', alvo, 'nome', nome_alvo);
end $$;
grant execute on function public.adicionar_membro_escola(uuid, text, text, text, text[]) to authenticated;

insert into public.schema_versao (versao) values (26) on conflict do nothing;
