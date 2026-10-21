-- =====================================================================
-- Findout Jornada · Migration 0049 · Revisão espaçada e recomendações
-- Rodar no SQL Editor depois da 0048. Idempotente.
--
-- Fase D do motor de aprendizagem personalizada:
--  · `revisao_habilidades`: fila de revisão espaçada por aluno × habilidade.
--    Um gatilho em `tentativas` (0046) a mantém sozinho: sessão com erro
--    numa habilidade volta a revisão para amanhã; sessão toda certa alarga
--    o intervalo (parametros['revisao_espacada'].intervalos, padrão
--    1 → 3 → 7 → 16 → 35 → 60 dias).
--  · `revisao_do_dia()`: o que o aluno deve rever hoje — habilidades com
--    revisão vencida na fila ou no estado "precisa de revisão" (0048) —
--    com as questões publicadas de cada uma. A Revisão Diária do app
--    passa a usar esta lista primeiro.
--  · `recomendacoes(p_user)`: sugestões POR REGRAS, cada uma com uma
--    justificativa legível ("sugerimos X porque você está errando Y,
--    e X é pré-requisito dela"), para o app (aba Treinar) e para o
--    raio-x do aluno no painel (mesma permissão do relatorio_aluno).
--
-- Sem habilidades vinculadas a questões tudo continua funcionando:
-- a fila fica vazia e a Revisão Diária segue como era (erros + mistura).
-- =====================================================================

insert into public.parametros (chave, valor) values
('revisao_espacada', '{"intervalos":[1,3,7,16,35,60],"maxPorHabilidade":3,"maxRecomendacoes":10}')
on conflict (chave) do nothing;

-- ---------------------------------------------------------------------
-- Fila de revisão espaçada
-- nivel = sessões seguidas sem erro na habilidade (0 = errou na última).
-- proxima_em = hoje + intervalos[min(nivel, último)] no momento da gravação.
-- ---------------------------------------------------------------------
create table if not exists public.revisao_habilidades (
  user_id uuid not null references auth.users(id) on delete cascade,
  habilidade_id uuid not null references public.habilidades(id) on delete cascade,
  nivel int not null default 0,
  proxima_em date not null,
  atualizado_em timestamptz not null default now(),
  primary key (user_id, habilidade_id)
);
create index if not exists revisao_hab_proxima_idx on public.revisao_habilidades(user_id, proxima_em);

alter table public.revisao_habilidades enable row level security;
drop policy if exists revisao_hab_dono on public.revisao_habilidades;
create policy revisao_hab_dono on public.revisao_habilidades for select to authenticated using (user_id = auth.uid());
drop policy if exists revisao_hab_admin on public.revisao_habilidades;
create policy revisao_hab_admin on public.revisao_habilidades for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Gatilho: a cada lote de tentativas gravado pelo concluir_licao, agrupa
-- por habilidade tocada e reprograma a fila. Errou algo da habilidade na
-- sessão → volta ao intervalo 1; acertou tudo → sobe um degrau.
create or replace function public.fj_fila_revisao_trigger()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  iv int[];
begin
  select array_agg((e.x)::int order by e.o) into iv
  from jsonb_array_elements_text(coalesce(param('revisao_espacada')->'intervalos', '[]'::jsonb)) with ordinality as e(x, o);
  if iv is null or array_length(iv, 1) is null then iv := array[1, 3, 7, 16, 35, 60]; end if;
  insert into public.revisao_habilidades as r (user_id, habilidade_id, nivel, proxima_em, atualizado_em)
  select t.user_id, qh.habilidade_id,
         case when bool_and(t.correta) then 1 else 0 end,
         hoje() + iv[case when bool_and(t.correta) then least(2, array_length(iv, 1)) else 1 end],
         now()
  from novas t
  join public.questao_habilidades qh on qh.questao_id = t.questao_id
  group by t.user_id, qh.habilidade_id
  on conflict (user_id, habilidade_id) do update set
    nivel = case when excluded.nivel = 0 then 0 else r.nivel + 1 end,
    proxima_em = hoje() + iv[least(case when excluded.nivel = 0 then 1 else r.nivel + 2 end, array_length(iv, 1))],
    atualizado_em = now();
  return null;
end $$;

drop trigger if exists fila_revisao on public.tentativas;
create trigger fila_revisao after insert on public.tentativas
  referencing new table as novas
  for each statement execute function public.fj_fila_revisao_trigger();

-- ---------------------------------------------------------------------
-- revisao_do_dia(): para o próprio aluno. Devolve as habilidades que
-- vencem hoje (fila ∪ "precisa_revisao" da 0048), cada uma com um motivo
-- legível, e a lista de questões publicadas para revisá-las — primeiro
-- as que o aluno errou ou nunca viu, depois as vistas há mais tempo.
-- ---------------------------------------------------------------------
create or replace function public.revisao_do_dia()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  u uuid := exigir_login();
  v_max int := coalesce((param('revisao_espacada')->>'maxPorHabilidade')::int, 3);
  habs jsonb; qs jsonb;
begin
  with todas as (
    select h.id, h.codigo, h.nome, (hoje() - r.proxima_em) as atraso,
      case when r.proxima_em >= hoje()
           then 'Revisão espaçada: hoje é o dia de rever «' || h.nome || '».'
           else 'Revisão espaçada: a revisão de «' || h.nome || '» venceu há ' || (hoje() - r.proxima_em)
                || ' dia' || case when hoje() - r.proxima_em = 1 then '' else 's' end || '.' end as motivo
    from public.revisao_habilidades r
    join public.habilidades h on h.id = r.habilidade_id and h.ativa
    where r.user_id = u and r.proxima_em <= hoje()
    union all
    select d.habilidade_id, d.codigo, d.nome, 0,
      'Você dominava «' || d.nome || '», mas está há ' || extract(day from now() - d.ultima)::int || ' dias sem praticar.'
    from public.dominio_habilidades() d
    where d.estado = 'precisa_revisao'
      and not exists (select 1 from public.revisao_habilidades r2
        where r2.user_id = u and r2.habilidade_id = d.habilidade_id and r2.proxima_em <= hoje())
  ), devidas as (
    select * from todas order by atraso desc, codigo limit 8
  ), escolha as (
    select dv.*, pick.qids from devidas dv
    cross join lateral (
      select coalesce(jsonb_agg(to_jsonb(s.qid)), '[]'::jsonb) as qids from (
        select qh.questao_id as qid
        from public.questao_habilidades qh
        join public.questoes qq on qq.id = qh.questao_id and qq.status = 'publicada'
        left join lateral (
          select t.correta, t.criado_em from public.tentativas t
          where t.user_id = u and t.questao_id = qh.questao_id
          order by t.criado_em desc limit 1
        ) ult on true
        where qh.habilidade_id = dv.id
        order by (ult.correta is distinct from true) desc, ult.criado_em asc nulls first
        limit v_max
      ) s
    ) pick
  )
  select
    coalesce(jsonb_agg(jsonb_build_object('codigo', e.codigo, 'nome', e.nome, 'motivo', e.motivo) order by e.atraso desc, e.codigo), '[]'::jsonb),
    coalesce((select jsonb_agg(f.value order by f.atraso desc, f.codigo, f.ordinality)
              from (select e2.atraso, e2.codigo, q2.value, q2.ordinality
                    from escolha e2, jsonb_array_elements(e2.qids) with ordinality q2) f), '[]'::jsonb)
  into habs, qs
  from escolha e;
  return jsonb_build_object('habilidades', coalesce(habs, '[]'::jsonb), 'questoes', coalesce(qs, '[]'::jsonb));
end $$;
grant execute on function public.revisao_do_dia() to authenticated;

-- ---------------------------------------------------------------------
-- recomendacoes(p_user): sugestões de estudo por regras, com justificativa.
--   1 · revisar   — revisão espaçada vencida na fila
--   2 · revisar   — dominava (0048), mas parou de praticar
--   3 · base      — pré-requisito fraco de uma habilidade que o aluno erra
--   4 · reforcar  — em desenvolvimento: falta pouco
-- Cada habilidade aparece uma vez, pela regra mais forte. p_user null =
-- o próprio aluno; outro aluno exige super usuário ou professor /
-- coordenador de uma turma aceita dele (mesma regra do relatorio_aluno).
-- ---------------------------------------------------------------------
create or replace function public.recomendacoes(p_user uuid default null)
returns table (ordem int, tipo text, habilidade_id uuid, codigo text, nome text, materia_id text, motivo text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  u uuid := exigir_login(); alvo uuid;
  v_max int := coalesce((param('revisao_espacada')->>'maxRecomendacoes')::int, 10);
begin
  alvo := coalesce(p_user, u);
  if alvo <> u and not (is_admin() or exists (select 1 from public.turma_alunos ta
      where ta.user_id = alvo and ta.aceito and professor_da_turma(ta.turma_id))) then
    raise exception 'Você não acompanha nenhuma turma deste aluno.' using errcode = '42501';
  end if;
  return query
  with d as (
    select * from public.dominio_habilidades(alvo)
  ), fila as (
    select r.habilidade_id as hid, r.proxima_em from public.revisao_habilidades r
    where r.user_id = alvo and r.proxima_em <= hoje()
  ), regras as (
    select 1 as pri, 'revisar'::text as tipo, d.habilidade_id, d.codigo, d.nome, d.materia_id,
      'Está na hora de rever «' || d.nome || '»: a revisão espaçada venceu ' ||
        case when f.proxima_em >= hoje() then 'hoje'
             else 'há ' || (hoje() - f.proxima_em) || ' dia' || case when hoje() - f.proxima_em = 1 then '' else 's' end end
        || '. Rever agora ajuda a fixar.' as motivo,
      (hoje() - f.proxima_em) as peso
    from fila f join d on d.habilidade_id = f.hid
    union all
    select 2, 'revisar', d.habilidade_id, d.codigo, d.nome, d.materia_id,
      'Você dominava «' || d.nome || '», mas está há ' || extract(day from now() - d.ultima)::int
        || ' dias sem praticar — uma revisão evita esquecer.',
      extract(day from now() - d.ultima)::int
    from d
    where d.estado = 'precisa_revisao' and not exists (select 1 from fila f where f.hid = d.habilidade_id)
    union all
    select 3, 'base', pre.habilidade_id, pre.codigo, pre.nome, pre.materia_id,
      'Sugerimos «' || pre.nome || '» porque você está errando «' || alvo_h.nome || '», e «' || pre.nome || '» é pré-requisito dela.',
      alvo_h.n_tentativas
    from d alvo_h
    join public.habilidade_prerequisitos hp on hp.habilidade_id = alvo_h.habilidade_id
    join d pre on pre.habilidade_id = hp.prerequisito_id
    where alvo_h.estado = 'em_desenvolvimento'
      and pre.estado in ('em_desenvolvimento', 'evidencia_insuficiente', 'sem_evidencia')
    union all
    select 4, 'reforcar', d.habilidade_id, d.codigo, d.nome, d.materia_id,
      'Você acertou ' || d.n_acertos || ' de ' || d.n_tentativas || ' das últimas questões de «' || d.nome
        || '» — mais um pouco de prática fecha essa lacuna.',
      d.n_tentativas
    from d where d.estado = 'em_desenvolvimento'
  ), unicas as (
    select distinct on (r.habilidade_id) r.* from regras r order by r.habilidade_id, r.pri, r.peso desc
  )
  select row_number() over (order by u2.pri, u2.peso desc, u2.codigo)::int,
         u2.tipo, u2.habilidade_id, u2.codigo, u2.nome, u2.materia_id, u2.motivo
  from unicas u2
  order by 1
  limit v_max;
end $$;
grant execute on function public.recomendacoes(uuid) to authenticated;

insert into public.schema_versao (versao) values (49) on conflict do nothing;
