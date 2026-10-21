-- =====================================================================
-- Findout Jornada · Migration 0048 · Domínio por habilidade
-- Rodar no SQL Editor depois da 0047. Idempotente.
--
-- Fase C do motor: estimativa EXPLICÁVEL do domínio de cada habilidade,
-- calculada sobre as últimas tentativas (0046) das questões vinculadas
-- (0047). Regras simples e configuráveis (parametros['dominio']):
--   sem_evidencia          nenhuma tentativa em questão da habilidade
--   evidencia_insuficiente menos de minTentativas tentativas
--   em_desenvolvimento     taxa de acerto abaixo de limiarDominada
--   dominada               taxa >= limiarDominada nas últimas N
--   precisa_revisao        dominada, mas sem praticar há revisaoDias
-- Nunca declara domínio a partir de uma única resposta.
-- =====================================================================

insert into public.parametros (chave, valor) values
('dominio', '{"janelaDias":90,"ultimas":10,"minTentativas":3,"limiarDominada":0.8,"revisaoDias":21}')
on conflict (chave) do nothing;

-- p_user null = o próprio aluno. Outro aluno: só super usuário ou
-- professor/coordenador de uma turma aceita dele (mesma regra do
-- relatorio_aluno da 0040).
create or replace function public.dominio_habilidades(p_user uuid default null)
returns table (
  habilidade_id uuid, codigo text, nome text, materia_id text,
  estado text, taxa numeric, n_tentativas int, n_acertos int, ultima timestamptz
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  u uuid := exigir_login(); alvo uuid;
  cfg jsonb := coalesce(param('dominio'), '{}'::jsonb);
  v_janela int; v_ult int; v_min int; v_rev int; v_lim numeric;
begin
  alvo := coalesce(p_user, u);
  v_janela := coalesce((cfg->>'janelaDias')::int, 90);
  v_ult := coalesce((cfg->>'ultimas')::int, 10);
  v_min := coalesce((cfg->>'minTentativas')::int, 3);
  v_lim := coalesce((cfg->>'limiarDominada')::numeric, 0.8);
  v_rev := coalesce((cfg->>'revisaoDias')::int, 21);
  if alvo <> u and not (is_admin() or exists (select 1 from public.turma_alunos ta
      where ta.user_id = alvo and ta.aceito and professor_da_turma(ta.turma_id))) then
    raise exception 'Você não acompanha nenhuma turma deste aluno.' using errcode = '42501';
  end if;
  return query
  with ult as (
    select qh.habilidade_id as hid, t.correta as ok, t.criado_em as em,
           row_number() over (partition by qh.habilidade_id order by t.criado_em desc) as rn
    from public.tentativas t
    join public.questao_habilidades qh on qh.questao_id = t.questao_id
    where t.user_id = alvo and t.criado_em >= now() - make_interval(days => v_janela)
  ), agg as (
    select hid, count(*)::int as n, (count(*) filter (where ok))::int as ac, max(em) as ult_em
    from ult where rn <= v_ult group by hid
  )
  select h.id, h.codigo, h.nome, h.materia_id,
    case
      when a.hid is null then 'sem_evidencia'
      when a.n < v_min then 'evidencia_insuficiente'
      when a.ac::numeric / a.n >= v_lim and a.ult_em < now() - make_interval(days => v_rev) then 'precisa_revisao'
      when a.ac::numeric / a.n >= v_lim then 'dominada'
      else 'em_desenvolvimento'
    end,
    case when a.hid is null then null else round(a.ac::numeric / a.n, 2) end,
    coalesce(a.n, 0), coalesce(a.ac, 0), a.ult_em
  from public.habilidades h
  left join agg a on a.hid = h.id
  where h.ativa
  order by h.materia_id nulls last, h.codigo;
end $$;
grant execute on function public.dominio_habilidades(uuid) to authenticated;

insert into public.schema_versao (versao) values (48) on conflict do nothing;
