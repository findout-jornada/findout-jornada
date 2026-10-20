-- =====================================================================
-- Findout Jornada · Migration 0023 · Relatórios de uso do app
-- Rodar no SQL Editor depois da 0022. Idempotente.
--
--  · relatorio_uso() (só admin): alimenta a aba Relatórios do painel com
--    dados que o banco já guardava e ninguém via — alunos ativos por dia
--    (14 dias), modos de estudo (30 dias), minutos médios, retenção
--    (hoje / 7 / 30 dias) e as questões que mais alunos estão errando
--    no app (tabela erros).
-- =====================================================================

create or replace function public.relatorio_uso()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare ini date := hoje() - 13;
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'alunosTotal', (select count(*) from public.perfis where coalesce(papel, 'aluno') = 'aluno'),
    'ativosHoje', (select count(*) from public.dias_aluno where dia = hoje() and (xp > 0 or licoes > 0 or minutos > 0)),
    'ativos7', (select count(distinct user_id) from public.eventos_licao where criado_em >= now() - interval '7 days'),
    'ativos30', (select count(distinct user_id) from public.eventos_licao where criado_em >= now() - interval '30 days'),
    'minutosMedios7', (select coalesce(round(avg(minutos)), 0) from public.dias_aluno where dia >= hoje() - 6 and minutos > 0),
    'dias', (select coalesce(jsonb_agg(jsonb_build_object('dia', d.dia::date, 'alunos', coalesce(t.alunos, 0), 'eventos', coalesce(t.eventos, 0), 'xp', coalesce(t.xp, 0)) order by d.dia), '[]'::jsonb)
      from generate_series(ini::timestamp, hoje()::timestamp, interval '1 day') d(dia)
      left join (select (criado_em at time zone 'America/Sao_Paulo')::date dia, count(distinct user_id) alunos, count(*) eventos, sum(xp) xp
                 from public.eventos_licao where criado_em >= (ini::timestamp at time zone 'America/Sao_Paulo') group by 1) t
        on t.dia = d.dia::date),
    'modos', (select coalesce(jsonb_object_agg(z.modo, z.n), '{}'::jsonb)
      from (select modo, count(*) n from public.eventos_licao where criado_em >= now() - interval '30 days' group by modo) z),
    'erradas', (select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'enunciado', left(q.enunciado, 140), 'materia', q.materia_id, 'tipo', q.tipo, 'alunos', e.n) order by e.n desc, q.enunciado), '[]'::jsonb)
      from (select questao_id, count(*) n from public.erros group by questao_id order by count(*) desc limit 15) e
      join public.questoes q on q.id = e.questao_id)
  );
end $$;
-- só o painel (admin) usa; a checagem é dentro da função

insert into public.schema_versao (versao) values (23) on conflict do nothing;
