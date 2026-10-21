-- =====================================================================
-- Findout Jornada · Migration 0038 · Dashboard da plataforma (super usuário)
-- Rodar no SQL Editor depois da 0037. Idempotente.
--
-- dashboard_admin(): todos os números da plataforma numa chamada só, para
-- a aba Dashboard do painel — contas por papel, engajamento (ativos, estudos,
-- XP, minutos), série de 14 dias, cenário por escola (alunos, professores,
-- turmas, atividades, entregas, média, ativos e dinâmicas), atividades,
-- dinâmicas, conteúdo por matéria e modos de estudo. Só o super usuário.
-- =====================================================================

create or replace function public.dashboard_admin()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'contas', jsonb_build_object(
      'alunos', (select count(*) from public.perfis where papel = 'aluno'),
      'professores', (select count(*) from public.perfis where papel = 'professor'),
      'coordenadores', (select count(*) from public.perfis where papel = 'coordenador'),
      'adminsEscola', (select count(*) from public.perfis where papel = 'admin'),
      'supers', (select count(*) from public.admins),
      'bloqueados', (select count(*) from auth.users where banned_until > now()),
      'plus', (select count(*) from public.perfis where findout_plus_ate > now()),
      'novos7', (select count(*) from public.perfis where criado_em >= now() - interval '7 days'),
      'novos30', (select count(*) from public.perfis where criado_em >= now() - interval '30 days')
    ),
    'engajamento', jsonb_build_object(
      'ativosHoje', (select count(*) from public.dias_aluno where dia = hoje() and (xp > 0 or licoes > 0 or minutos > 0)),
      'ativos7', (select count(distinct user_id) from public.eventos_licao where criado_em >= now() - interval '7 days'),
      'ativos30', (select count(distinct user_id) from public.eventos_licao where criado_em >= now() - interval '30 days'),
      'estudos7', (select count(*) from public.eventos_licao where criado_em >= now() - interval '7 days'),
      'licoes7', (select count(*) from public.eventos_licao where criado_em >= now() - interval '7 days' and modo = 'licao'),
      'xp7', (select coalesce(sum(xp), 0) from public.dias_aluno where dia >= hoje() - 6),
      'minutosMedios7', (select coalesce(round(avg(minutos)), 0) from public.dias_aluno where dia >= hoje() - 6 and minutos > 0),
      'ofensivasHoje', (select count(*) from public.ofensiva_dias where dia = hoje())
    ),
    'dias', (select coalesce(jsonb_agg(jsonb_build_object('dia', d.dia, 'alunos', coalesce(t.n, 0), 'estudos', coalesce(t.e, 0)) order by d.dia), '[]'::jsonb)
      from (select hoje() - g as dia from generate_series(13, 0, -1) g) d
      left join (select (criado_em at time zone 'America/Sao_Paulo')::date as dia, count(distinct user_id) as n, count(*) as e
                 from public.eventos_licao where criado_em >= now() - interval '15 days' group by 1) t on t.dia = d.dia),
    'atividades', jsonb_build_object(
      'abertas', (select count(*) from public.atividades a where a.status = 'aberta' and (a.prazo is null or a.prazo > now())),
      'encerram7', (select count(*) from public.atividades a where a.status = 'aberta' and a.prazo between now() and now() + interval '7 days'),
      'entregas7', (select count(*) from public.atividade_entregas where entregue_em >= now() - interval '7 days'),
      'media30', (select round(avg(nota), 1) from public.atividade_entregas where entregue_em >= now() - interval '30 days' and nota is not null),
      'taxaEntrega', (select case when coalesce(sum(x.na), 0) = 0 then null else round(100.0 * sum(x.ent) / sum(x.na)) end
        from (select (select count(*) from public.turma_alunos ta where ta.turma_id = a.turma_id and ta.aceito) as na,
                     (select count(*) from public.atividade_entregas e where e.atividade_id = a.id and e.entregue_em is not null) as ent
              from public.atividades a where a.status = 'aberta' and (a.prazo is null or a.prazo > now())) x)
    ),
    'dinamicas', jsonb_build_object(
      'total', (select count(*) from public.dinamicas),
      'ultimos30', (select count(*) from public.dinamicas where criada_em >= now() - interval '30 days'),
      'aoVivo', (select count(*) from public.dinamicas where status <> 'fim' and criada_em > now() - interval '12 hours'),
      'respostas30', (select count(*) from public.dinamica_respostas where respondida_em >= now() - interval '30 days')
    ),
    'escolas', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', e.id, 'nome', e.nome,
        'turmas', (select count(*) from public.turmas t where t.escola_id = e.id),
        'professores', (select count(*) from public.escola_membros m where m.escola_id = e.id and m.papel = 'professor'),
        'gestores', (select count(*) from public.escola_membros m where m.escola_id = e.id and m.papel <> 'professor'),
        'alunos', (select count(distinct ta.user_id) from public.turma_alunos ta join public.turmas t on t.id = ta.turma_id where t.escola_id = e.id and ta.aceito),
        'abertas', (select count(*) from public.atividades a join public.turmas t on t.id = a.turma_id where t.escola_id = e.id and a.status = 'aberta' and (a.prazo is null or a.prazo > now())),
        'entregas30', (select count(*) from public.atividade_entregas en join public.atividades a on a.id = en.atividade_id join public.turmas t on t.id = a.turma_id where t.escola_id = e.id and en.entregue_em >= now() - interval '30 days'),
        'media30', (select round(avg(en.nota), 1) from public.atividade_entregas en join public.atividades a on a.id = en.atividade_id join public.turmas t on t.id = a.turma_id where t.escola_id = e.id and en.entregue_em >= now() - interval '30 days' and en.nota is not null),
        'ativos7', (select count(distinct ev.user_id) from public.eventos_licao ev
          where ev.criado_em >= now() - interval '7 days'
            and ev.user_id in (select ta.user_id from public.turma_alunos ta join public.turmas t on t.id = ta.turma_id where t.escola_id = e.id and ta.aceito)),
        'dinamicas30', (select count(*) from public.dinamicas d2 join public.turmas t on t.id = d2.turma_id where t.escola_id = e.id and d2.criada_em >= now() - interval '30 days')
      ) order by e.nome), '[]'::jsonb) from public.escolas e),
    'semEscola', jsonb_build_object(
      'turmas', (select count(*) from public.turmas where escola_id is null),
      'alunos', (select count(distinct ta.user_id) from public.turma_alunos ta join public.turmas t on t.id = ta.turma_id where t.escola_id is null and ta.aceito)
    ),
    'conteudo', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', m.id, 'nome', m.nome, 'sigla', m.sigla, 'cor', m.cor, 'ativa', m.ativa,
        'questoes', (select count(*) from public.questoes q where q.materia_id = m.id and q.status = 'publicada'),
        'licoes', (select count(*) from public.licoes l join public.unidades u on u.id = l.unidade_id join public.secoes s on s.id = u.secao_id where s.materia_id = m.id)
      ) order by m.ordem, m.nome), '[]'::jsonb) from public.materias m),
    'modos', (select coalesce(jsonb_object_agg(z.modo, z.n), '{}'::jsonb)
      from (select modo, count(*) as n from public.eventos_licao where criado_em >= now() - interval '30 days' group by modo) z),
    'esquema', (select max(versao) from public.schema_versao),
    'publicacao', (select jsonb_build_object('versao', versao, 'em', criada_em) from public.publicacoes order by versao desc limit 1),
    'agora', now()
  );
end $$;
grant execute on function public.dashboard_admin() to authenticated;

insert into public.schema_versao (versao) values (38) on conflict do nothing;
