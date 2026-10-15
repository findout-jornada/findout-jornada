-- =====================================================================
-- Findout Jornada · Migration 0014 · Auditoria do painel
-- Rodar no SQL Editor do Supabase depois da 0013. Idempotente.
--
-- Registra toda movimentação de quem usa o painel:
--   · Dados: gatilhos nas tabelas de conteúdo, turmas, atividades e perfis
--     gravam quem (auth.uid), quando, a ação e o que mudou (antes/depois).
--     Vale mesmo que a alteração seja feita fora do painel, direto na API.
--   · Painel: eventos como login, tela aberta, busca de alunos e cópia de notas,
--     enviados pela função auditar_painel().
--   · Consulta: só admin, pela função auditoria_admin() e pela tela Auditoria.
-- =====================================================================

create table if not exists public.auditoria (
  id bigint generated always as identity primary key,
  user_id uuid,                                -- quem fez (null = sistema)
  origem text not null default 'dados' check (origem in ('dados', 'painel')),
  acao text not null,                          -- insert | update | delete | login | tela | busca | ...
  tabela text,                                 -- tabela afetada (origem dados) ou área do painel
  registro text,                               -- id do registro afetado
  resumo text,                                 -- texto curto para listar (título, enunciado, nome)
  dados jsonb,                                 -- antes/depois (só os campos que mudaram) ou detalhes do evento
  criado_em timestamptz not null default now()
);
create index if not exists auditoria_quando_idx on public.auditoria (criado_em desc);
create index if not exists auditoria_user_idx on public.auditoria (user_id, criado_em desc);
create index if not exists auditoria_tabela_idx on public.auditoria (tabela, criado_em desc);

alter table public.auditoria enable row level security;
drop policy if exists auditoria_admin on public.auditoria;
create policy auditoria_admin on public.auditoria for select to authenticated using (public.is_admin());
-- ninguém escreve direto: só os gatilhos e a função auditar_painel (security definer)

-- ---------------------------------------------------------------
-- Gatilho genérico: grava insert/update/delete com o diff
-- ---------------------------------------------------------------
create or replace function public.fj_auditar_trigger()
returns trigger language plpgsql security definer set search_path = public as $$
declare ja jsonb; jd jsonb; antes jsonb; depois jsonb; rid text; res text; mudou jsonb;
begin
  ja := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
  jd := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
  -- id do registro: id, user_id, chave ou chave composta
  rid := coalesce(coalesce(jd, ja)->>'id', coalesce(jd, ja)->>'user_id', coalesce(jd, ja)->>'chave',
                  nullif(concat_ws('/', coalesce(jd, ja)->>'licao_id', coalesce(jd, ja)->>'questao_id', coalesce(jd, ja)->>'turma_id', coalesce(jd, ja)->>'escola_id', coalesce(jd, ja)->>'atividade_id'), ''));
  if tg_op = 'UPDATE' then
    -- só o que mudou, ignorando carimbos automáticos
    select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) into mudou
      from jsonb_each(jd) e where ja->e.key is distinct from e.value and e.key not in ('atualizada_em', 'atualizado_em', 'visto_em', 'coracoes_em', 'materia_atual');
    if mudou = '{}'::jsonb then return new; end if;
    select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) into antes from jsonb_each(ja) e where mudou ? e.key;
    depois := mudou;
  elsif tg_op = 'INSERT' then
    depois := jd;
  else
    antes := ja;
  end if;
  -- pacote publicado é enorme: guarda só versão e nota
  if tg_table_name = 'publicacoes' then
    depois := jsonb_build_object('versao', jd->>'versao', 'nota', jd->>'nota'); antes := null;
  end if;
  -- atividades: a cópia das questões é grande; guarda só a contagem
  if tg_table_name = 'atividades' then
    if depois ? 'questoes' then depois := (depois - 'questoes') || jsonb_build_object('questoes', jsonb_array_length(depois->'questoes')); end if;
    if antes ? 'questoes' then antes := (antes - 'questoes') || jsonb_build_object('questoes', jsonb_array_length(antes->'questoes')); end if;
  end if;
  res := left(coalesce(coalesce(jd, ja)->>'titulo', coalesce(jd, ja)->>'enunciado', coalesce(jd, ja)->>'nome', coalesce(jd, ja)->>'texto', coalesce(jd, ja)->>'nota', coalesce(jd, ja)->>'codigo', rid), 120);
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (auth.uid(), 'dados', lower(tg_op), tg_table_name, rid, res,
            jsonb_strip_nulls(jsonb_build_object('antes', antes, 'depois', depois)));
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array['materias','secoes','unidades','licoes','questoes','licao_questoes','missoes','itens_loja','parametros','publicacoes',
                           'segmentos','escolas','escola_membros','turmas','turma_professores','turma_alunos','atividades','perfis','admins']
  loop
    execute format('drop trigger if exists auditoria_%I on public.%I', t, t);
    execute format('create trigger auditoria_%I after insert or update or delete on public.%I for each row execute function public.fj_auditar_trigger()', t, t);
  end loop;
end $$;

-- ---------------------------------------------------------------
-- Eventos do painel (login, tela aberta, busca, cópia de notas…)
-- ---------------------------------------------------------------
create or replace function public.auditar_painel(p_acao text, p_tabela text default null, p_registro text default null, p_resumo text default null, p_dados jsonb default null)
returns void language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login();
begin
  if not eh_educador() then return; end if;   -- só quem entra no painel gera eventos
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', left(coalesce(p_acao, 'evento'), 40), left(p_tabela, 60), left(p_registro, 120), left(p_resumo, 200), p_dados);
end $$;
grant execute on function public.auditar_painel(text, text, text, text, jsonb) to authenticated;

-- ---------------------------------------------------------------
-- Consulta (admin): com nome e e-mail de quem fez
-- ---------------------------------------------------------------
create or replace function public.auditoria_admin(p_limite int default 200, p_antes_de bigint default null, p_user uuid default null, p_origem text default null, p_tabela text default null, p_acao text default null, p_desde timestamptz default null, p_busca text default null)
returns table (id bigint, user_id uuid, nome text, email text, papel text, origem text, acao text, tabela text, registro text, resumo text, dados jsonb, criado_em timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  return query
    select a.id, a.user_id, coalesce(p.nome, 'Sistema'), u.email::text, p.papel, a.origem, a.acao, a.tabela, a.registro, a.resumo, a.dados, a.criado_em
    from public.auditoria a
    left join public.perfis p on p.user_id = a.user_id
    left join auth.users u on u.id = a.user_id
    where (p_antes_de is null or a.id < p_antes_de)
      and (p_user is null or a.user_id = p_user)
      and (p_origem is null or a.origem = p_origem)
      and (p_tabela is null or a.tabela = p_tabela)
      and (p_acao is null or a.acao = p_acao)
      and (p_desde is null or a.criado_em >= p_desde)
      and (coalesce(p_busca, '') = '' or a.resumo ilike '%' || p_busca || '%' or a.registro ilike '%' || p_busca || '%' or u.email ilike '%' || p_busca || '%' or p.nome ilike '%' || p_busca || '%')
    order by a.id desc
    limit greatest(1, least(coalesce(p_limite, 200), 500));
end $$;
grant execute on function public.auditoria_admin(int, bigint, uuid, text, text, text, timestamptz, text) to authenticated;

-- Quem já aparece na auditoria (para o filtro de usuário)
create or replace function public.auditoria_usuarios()
returns table (user_id uuid, nome text, email text, papel text, eventos bigint, ultimo timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  return query
    select a.user_id, coalesce(p.nome, 'Sistema'), u.email::text, p.papel, count(*), max(a.criado_em)
    from public.auditoria a left join public.perfis p on p.user_id = a.user_id left join auth.users u on u.id = a.user_id
    group by a.user_id, p.nome, u.email, p.papel
    order by max(a.criado_em) desc;
end $$;
grant execute on function public.auditoria_usuarios() to authenticated;
