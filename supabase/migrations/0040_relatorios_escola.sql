-- =====================================================================
-- Findout Jornada · Migration 0040 · Relatórios por escola, segmento, turma e aluno
-- Rodar no SQL Editor depois da 0039. Idempotente.
--
-- Três funções para a aba Relatórios do painel (agora também para professor,
-- coordenador e admin da escola — cada um só recebe as turmas que o seu papel
-- já enxerga, pelo mesmo professor_da_turma() das policies):
--
--  · relatorio_turmas(): uma linha por turma visível, com escola e segmento,
--    alunos, ativos e estudos na semana, XP, minutos, atividades abertas,
--    entregas e notas dos últimos 30 dias. O painel agrupa essas linhas por
--    escola e por segmento (as somas de notas vêm separadas — notas30_soma e
--    notas30_n — para a média ficar certa em qualquer agrupamento).
--  · relatorio_turma(p_turma): uma linha por aluno da turma — XP, lições,
--    minutos, ofensiva, último estudo, entregas, pendências, média e acertos.
--  · relatorio_aluno(p_user): o raio-x de um aluno — série de 14 dias,
--    progresso por matéria, atividades (só das turmas que quem pergunta vê)
--    e resumo de engajamento.
-- =====================================================================

-- ---------------------------------------------------------------
-- 1) Turmas visíveis com os números da semana e do mês
-- ---------------------------------------------------------------
create or replace function public.relatorio_turmas()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform exigir_login();
  if not eh_educador() then raise exception 'Só professores, coordenadores e admins.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', t.id, 'nome', t.nome, 'ativa', t.ativa,
      'escola_id', t.escola_id, 'escola', e.nome,
      'segmento_id', t.segmento_id, 'segmento', s.nome,
      'alunos', (select count(*) from public.turma_alunos ta where ta.turma_id = t.id and ta.aceito),
      'ativos7', (select count(distinct ev.user_id) from public.eventos_licao ev
        join public.turma_alunos ta on ta.user_id = ev.user_id and ta.turma_id = t.id and ta.aceito
        where ev.criado_em >= now() - interval '7 days'),
      'estudos7', (select count(*) from public.eventos_licao ev
        join public.turma_alunos ta on ta.user_id = ev.user_id and ta.turma_id = t.id and ta.aceito
        where ev.criado_em >= now() - interval '7 days'),
      'xp7', (select coalesce(sum(d.xp), 0) from public.dias_aluno d
        join public.turma_alunos ta on ta.user_id = d.user_id and ta.turma_id = t.id and ta.aceito
        where d.dia >= hoje() - 6),
      'minutos7', (select coalesce(sum(d.minutos), 0) from public.dias_aluno d
        join public.turma_alunos ta on ta.user_id = d.user_id and ta.turma_id = t.id and ta.aceito
        where d.dia >= hoje() - 6),
      'abertas', (select count(*) from public.atividades a
        where a.turma_id = t.id and a.status = 'aberta' and (a.prazo is null or a.prazo > now())),
      'entregas30', (select count(*) from public.atividade_entregas en
        join public.atividades a on a.id = en.atividade_id and a.turma_id = t.id
        where en.entregue_em >= now() - interval '30 days'),
      'notas30_soma', (select coalesce(sum(en.nota), 0) from public.atividade_entregas en
        join public.atividades a on a.id = en.atividade_id and a.turma_id = t.id
        where en.entregue_em >= now() - interval '30 days' and en.nota is not null),
      'notas30_n', (select count(*) from public.atividade_entregas en
        join public.atividades a on a.id = en.atividade_id and a.turma_id = t.id
        where en.entregue_em >= now() - interval '30 days' and en.nota is not null),
      'dinamicas30', (select count(*) from public.dinamicas d2
        where d2.turma_id = t.id and d2.criada_em >= now() - interval '30 days')
    ) order by e.nome nulls last, s.ordem nulls last, t.nome)
    from public.turmas t
    left join public.escolas e on e.id = t.escola_id
    left join public.segmentos s on s.id = t.segmento_id
    where is_admin() or professor_da_turma(t.id)), '[]'::jsonb);
end $$;
grant execute on function public.relatorio_turmas() to authenticated;

-- ---------------------------------------------------------------
-- 2) Uma turma, aluno por aluno
-- ---------------------------------------------------------------
create or replace function public.relatorio_turma(p_turma uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform exigir_login();
  if not (is_admin() or professor_da_turma(p_turma)) then
    raise exception 'Você não acompanha esta turma.' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'turma', (select jsonb_build_object('id', t.id, 'nome', t.nome, 'escola', e.nome, 'segmento', s.nome)
      from public.turmas t
      left join public.escolas e on e.id = t.escola_id
      left join public.segmentos s on s.id = t.segmento_id
      where t.id = p_turma),
    'abertas', (select count(*) from public.atividades a
      where a.turma_id = p_turma and a.status = 'aberta' and (a.prazo is null or a.prazo > now())),
    'alunos', coalesce((select jsonb_agg(jsonb_build_object(
        'user_id', ta.user_id, 'nome', p.nome, 'email', u.email,
        'xp', coalesce(ec.xp, 0),
        'xp7', (select coalesce(sum(d.xp), 0) from public.dias_aluno d where d.user_id = ta.user_id and d.dia >= hoje() - 6),
        'minutos7', (select coalesce(sum(d.minutos), 0) from public.dias_aluno d where d.user_id = ta.user_id and d.dia >= hoje() - 6),
        'licoes', (select count(*) from public.progresso pr where pr.user_id = ta.user_id),
        'ofensiva', public.ofensiva(ta.user_id),
        'ultimo', (select max(ev.criado_em) from public.eventos_licao ev where ev.user_id = ta.user_id),
        'entregues', (select count(*) from public.atividade_entregas en
          join public.atividades a on a.id = en.atividade_id and a.turma_id = p_turma
          where en.user_id = ta.user_id and en.entregue_em is not null),
        'pendentes', (select count(*) from public.atividades a
          where a.turma_id = p_turma and a.status = 'aberta' and (a.prazo is null or a.prazo > now())
            and not exists (select 1 from public.atividade_entregas en
              where en.atividade_id = a.id and en.user_id = ta.user_id and en.entregue_em is not null)),
        'media', (select round(avg(en.nota), 1) from public.atividade_entregas en
          join public.atividades a on a.id = en.atividade_id and a.turma_id = p_turma
          where en.user_id = ta.user_id and en.entregue_em is not null and en.nota is not null),
        'acertos30', (select coalesce(sum(ev.acertos), 0) from public.eventos_licao ev
          where ev.user_id = ta.user_id and ev.criado_em >= now() - interval '30 days'),
        'erros30', (select coalesce(sum(ev.erros), 0) from public.eventos_licao ev
          where ev.user_id = ta.user_id and ev.criado_em >= now() - interval '30 days')
      ) order by p.nome)
      from public.turma_alunos ta
      join public.perfis p on p.user_id = ta.user_id
      join auth.users u on u.id = ta.user_id
      left join public.economia_aluno ec on ec.user_id = ta.user_id
      where ta.turma_id = p_turma and ta.aceito), '[]'::jsonb)
  );
end $$;
grant execute on function public.relatorio_turma(uuid) to authenticated;

-- ---------------------------------------------------------------
-- 3) O raio-x de um aluno (só de quem acompanha alguma turma dele)
-- ---------------------------------------------------------------
create or replace function public.relatorio_aluno(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform exigir_login();
  if not (is_admin() or exists (select 1 from public.turma_alunos ta
      where ta.user_id = p_user and ta.aceito and professor_da_turma(ta.turma_id))) then
    raise exception 'Você não acompanha nenhuma turma deste aluno.' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'perfil', (select jsonb_build_object('nome', p.nome, 'email', u.email, 'criado_em', p.criado_em,
        'visto_em', p.visto_em, 'plus', coalesce(p.findout_plus_ate > now(), false))
      from public.perfis p join auth.users u on u.id = p.user_id where p.user_id = p_user),
    'xp', (select coalesce(ec.xp, 0) from public.economia_aluno ec where ec.user_id = p_user),
    'ofensiva', public.ofensiva(p_user),
    'turmas', coalesce((select jsonb_agg(t.nome order by t.nome) from public.turma_alunos ta
      join public.turmas t on t.id = ta.turma_id
      where ta.user_id = p_user and ta.aceito and (is_admin() or professor_da_turma(t.id))), '[]'::jsonb),
    'dias', (select coalesce(jsonb_agg(jsonb_build_object('dia', g.dia,
        'xp', coalesce(d.xp, 0), 'licoes', coalesce(d.licoes, 0), 'minutos', coalesce(d.minutos, 0)) order by g.dia), '[]'::jsonb)
      from (select hoje() - n as dia from generate_series(13, 0, -1) n) g
      left join public.dias_aluno d on d.user_id = p_user and d.dia = g.dia),
    'materias', coalesce((select jsonb_agg(jsonb_build_object(
        'id', m.id, 'nome', m.nome, 'sigla', m.sigla, 'cor', m.cor,
        'feitas', (select count(*) from public.progresso pr
          join public.licoes l on l.id = pr.licao_id
          join public.unidades un on un.id = l.unidade_id
          join public.secoes se on se.id = un.secao_id
          where pr.user_id = p_user and se.materia_id = m.id),
        'coroas', (select coalesce(sum(pr.coroas), 0) from public.progresso pr
          join public.licoes l on l.id = pr.licao_id
          join public.unidades un on un.id = l.unidade_id
          join public.secoes se on se.id = un.secao_id
          where pr.user_id = p_user and se.materia_id = m.id),
        'total', (select count(*) from public.licoes l
          join public.unidades un on un.id = l.unidade_id
          join public.secoes se on se.id = un.secao_id
          where se.materia_id = m.id)
      ) order by m.ordem, m.nome)
      from public.materias m where m.ativa), '[]'::jsonb),
    'atividades', coalesce((select jsonb_agg(jsonb_build_object(
        'id', a.id, 'titulo', a.titulo, 'turma', t.nome, 'turma_id', t.id, 'materia', a.materia_id,
        'prazo', a.prazo, 'status', a.status,
        'nota', en.nota, 'acertos', en.acertos, 'total', en.total, 'entregue_em', en.entregue_em
      ) order by coalesce(a.prazo, a.criada_em) desc)
      from public.atividades a
      join public.turmas t on t.id = a.turma_id
      join public.turma_alunos ta on ta.turma_id = t.id and ta.user_id = p_user and ta.aceito
      left join public.atividade_entregas en on en.atividade_id = a.id and en.user_id = p_user and en.entregue_em is not null
      where a.status <> 'rascunho' and (is_admin() or professor_da_turma(t.id))), '[]'::jsonb),
    'resumo', jsonb_build_object(
      'minutos30', (select coalesce(sum(d.minutos), 0) from public.dias_aluno d where d.user_id = p_user and d.dia >= hoje() - 29),
      'xp30', (select coalesce(sum(d.xp), 0) from public.dias_aluno d where d.user_id = p_user and d.dia >= hoje() - 29),
      'acertos30', (select coalesce(sum(ev.acertos), 0) from public.eventos_licao ev
        where ev.user_id = p_user and ev.criado_em >= now() - interval '30 days'),
      'erros30', (select coalesce(sum(ev.erros), 0) from public.eventos_licao ev
        where ev.user_id = p_user and ev.criado_em >= now() - interval '30 days')
    )
  );
end $$;
grant execute on function public.relatorio_aluno(uuid) to authenticated;

insert into public.schema_versao (versao) values (40) on conflict do nothing;
