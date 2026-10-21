-- =====================================================================
-- Findout Jornada · Migration 0031 · Várias matérias por professor em cada turma
-- Rodar no SQL Editor depois da 0030. Idempotente.
--
--  · turma_professores ganha a coluna materias (lista). Lista vazia = todas as matérias.
--    A coluna antiga materia_id continua existindo: recebe a matéria quando a lista
--    tem exatamente uma, e fica nula quando tem zero ou várias.
--  · criar_turma e adicionar_professor_turma aceitam p_materias (lista). Sem lista e
--    sem p_materia, vale a disciplina do cadastro do professor, como antes.
--  · No painel, o modal "Nova turma" passa a ter caixas de marcar para as matérias e,
--    quando aberto de dentro da tela Escola, não pergunta mais a escola.
-- =====================================================================

alter table public.turma_professores add column if not exists materias text[] not null default '{}';
update public.turma_professores set materias = array[materia_id] where materia_id is not null and materias = '{}';

-- Normaliza a lista: usa p_materias; sem ela, p_materia; tira vazios e repetidos; confere se as matérias existem
create or replace function public.fj_normalizar_materias(p_materias text[], p_materia text default null)
returns text[] language plpgsql stable as $$
declare arr text[];
begin
  arr := coalesce(p_materias, case when p_materia is not null then array[p_materia] else '{}'::text[] end);
  select coalesce(array_agg(distinct x), '{}'::text[]) into arr from unnest(arr) x where x is not null and trim(x) <> '';
  if exists (select 1 from unnest(arr) x where not exists (select 1 from public.materias where id = x)) then raise exception 'Matéria inválida.'; end if;
  return arr;
end $$;

drop function if exists public.criar_turma(text, uuid, text, text);
create or replace function public.criar_turma(p_nome text, p_escola uuid default null, p_materia text default null, p_segmento text default null, p_materias text[] default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); t public.turmas; arr text[];
begin
  if not eh_educador() then raise exception 'Só professores e coordenadores criam turmas.' using errcode = '42501'; end if;
  if p_escola is not null and not (is_admin() or membro_da_escola(p_escola)) then raise exception 'Você não faz parte desta escola.' using errcode = '42501'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome à turma.'; end if;
  if p_segmento is not null and not exists (select 1 from public.segmentos where id = p_segmento) then raise exception 'Segmento inválido.'; end if;
  arr := fj_normalizar_materias(p_materias, p_materia);
  if arr = '{}' and minha_disciplina() is not null then arr := array[minha_disciplina()]; end if;
  insert into public.turmas (escola_id, nome, codigo, criada_por, segmento_id) values (p_escola, trim(p_nome), gerar_codigo_turma(), u, p_segmento) returning * into t;
  insert into public.turma_professores (turma_id, user_id, materia_id, materias)
    values (t.id, u, case when cardinality(arr) = 1 then arr[1] else null end, arr) on conflict do nothing;
  return to_jsonb(t);
end $$;
grant execute on function public.criar_turma(text, uuid, text, text, text[]) to authenticated;

drop function if exists public.adicionar_professor_turma(uuid, text, text);
create or replace function public.adicionar_professor_turma(p_turma uuid, p_email text, p_materia text default null, p_materias text[] default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo uuid; nome_alvo text; esc uuid; arr text[]; disc text;
begin
  perform exigir_login();
  if not (is_admin() or coord_da_turma(p_turma) or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  select id into alvo from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if alvo is null then raise exception 'Nenhuma conta com o e-mail %. A pessoa precisa criar a conta no app primeiro.', trim(p_email); end if;
  arr := fj_normalizar_materias(p_materias, p_materia);
  select disciplina_id into disc from public.perfis where user_id = alvo;
  if arr = '{}' and disc is not null then arr := array[disc]; end if;
  insert into public.turma_professores (turma_id, user_id, materia_id, materias)
    values (p_turma, alvo, case when cardinality(arr) = 1 then arr[1] else null end, arr)
    on conflict (turma_id, user_id) do update set materia_id = excluded.materia_id, materias = excluded.materias;
  select escola_id into esc from public.turmas where id = p_turma;
  if esc is not null then insert into public.escola_membros (escola_id, user_id, papel) values (esc, alvo, 'professor') on conflict do nothing; end if;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set papel = case when papel = 'aluno' then 'professor' else papel end where user_id = alvo returning nome into nome_alvo;
  return jsonb_build_object('user_id', alvo, 'nome', nome_alvo);
end $$;
grant execute on function public.adicionar_professor_turma(uuid, text, text, text[]) to authenticated;

insert into public.schema_versao (versao) values (31) on conflict do nothing;
