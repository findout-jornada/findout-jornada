-- =====================================================================
-- Findout Jornada · Migration 0017 · Convite de turma com aceite, e-mails restritos e ranking da turma
-- Rodar no SQL Editor do Supabase depois da 0016. Idempotente.
--
-- · Quando o professor adiciona um aluno pelo e-mail, vira um CONVITE: o aluno aceita ou recusa no app
--   (aba Turma). Só depois de aceitar ele vê as atividades e entra nas listas da turma.
--   Quem entra pelo código já aceita na hora. Quem já estava na turma continua como está.
-- · E-mails de professores/alunos só aparecem para quem usa o painel (professor, coordenador, admin).
-- · ranking_turma(): XP da semana dos colegas da turma, para a aba Turma do app.
-- =====================================================================

alter table public.turma_alunos add column if not exists aceito boolean not null default true;

create or replace function public.aluno_da_turma(p_turma uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.turma_alunos where turma_id = p_turma and user_id = auth.uid() and aceito);
$$;

create or replace function public.turmas_do_aluno(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'nome', t.nome, 'escola', es.nome, 'codigo', t.codigo) order by t.nome), '[]'::jsonb)
  from public.turma_alunos ta join public.turmas t on t.id = ta.turma_id left join public.escolas es on es.id = t.escola_id
  where ta.user_id = p_user and ta.aceito and t.ativa;
$$;

-- Convites pendentes (turma + quem convidou)
create or replace function public.convites_do_aluno(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'nome', t.nome, 'escola', es.nome,
      'professor', (select p.nome from public.turma_professores tp join public.perfis p on p.user_id = tp.user_id where tp.turma_id = t.id order by p.nome limit 1),
      'alunos', (select count(*) from public.turma_alunos x where x.turma_id = t.id and x.aceito)) order by ta.entrou_em desc), '[]'::jsonb)
  from public.turma_alunos ta join public.turmas t on t.id = ta.turma_id left join public.escolas es on es.id = t.escola_id
  where ta.user_id = p_user and not ta.aceito and t.ativa;
$$;

create or replace function public.atividades_do_aluno(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'titulo', a.titulo, 'descricao', a.descricao, 'materia', a.materia_id, 'prazo', a.prazo,
    'turma', t.nome, 'turmaId', t.id, 'questoes', jsonb_array_length(a.questoes),
    'status', case when e.entregue_em is not null then 'entregue'
                   when a.status = 'encerrada' or (a.prazo is not null and a.prazo < now()) then 'encerrada'
                   else 'pendente' end,
    'nota', e.nota, 'acertos', e.acertos, 'total', e.total, 'entregueEm', e.entregue_em
  ) order by (e.entregue_em is not null), a.prazo asc nulls last, a.criada_em desc), '[]'::jsonb)
  from public.atividades a
  join public.turmas t on t.id = a.turma_id and t.ativa
  join public.turma_alunos ta on ta.turma_id = a.turma_id and ta.user_id = p_user and ta.aceito
  left join public.atividade_entregas e on e.atividade_id = a.id and e.user_id = p_user
  where a.status <> 'rascunho';
$$;

-- Estado do aluno passa a trazer os convites
create or replace function public.estado_aluno()
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); e public.economia_aluno; d public.dias_aluno; lid uuid; pf public.perfis; mx int; hrs numeric;
begin
  e := regenerar_coracoes(u);
  d := preparar_dia(u);
  lid := entrar_liga(u);
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set visto_em = now() where user_id = u returning * into pf;
  mx := coalesce((param('economia')->>'coracoes')::int, 5);
  hrs := coalesce((param('economia')->>'horasCoracao')::numeric, 5);
  return jsonb_build_object(
    'perfil', jsonb_build_object('nome', pf.nome, 'avatar', pf.avatar, 'materia', pf.materia_atual, 'plus', tem_plus(u), 'plusAte', pf.findout_plus_ate, 'admin', is_admin(), 'papel', pf.papel),
    'economia', jsonb_build_object('coracoes', e.coracoes, 'maxCoracoes', mx,
      'proximoCoracaoEm', case when e.coracoes >= mx then null else e.coracoes_em + (hrs * interval '1 hour') end,
      'moedas', e.moedas, 'xp', e.xp, 'xpSemana', e.xp_semana, 'xpMes', e.xp_mes, 'congeladores', e.congeladores,
      'relampagoHoje', e.relampago_em = hoje()),
    'ofensiva', jsonb_build_object('dias', ofensiva(u), 'hoje', exists (select 1 from public.ofensiva_dias where user_id = u and dia = hoje()),
      'historico', (select coalesce(jsonb_object_agg(dia, tipo), '{}'::jsonb) from public.ofensiva_dias where user_id = u and dia >= hoje() - 60)),
    'progresso', (select coalesce(jsonb_object_agg(licao_id, coroas), '{}'::jsonb) from public.progresso where user_id = u),
    'unidades', (select coalesce(jsonb_object_agg(unidade_id, jsonb_build_object('bau', bau_em is not null, 'trofeu', trofeu_em is not null, 'pulada', pulada_em is not null)), '{}'::jsonb) from public.conquistas_unidade where user_id = u),
    'dia', jsonb_build_object('xp', d.xp, 'licoes', d.licoes, 'bauAberto', d.bau_aberto, 'missoes', missoes_do_dia(u)),
    'erros', (select coalesce(jsonb_agg(questao_id order by errado_em desc), '[]'::jsonb) from public.erros where user_id = u),
    'liga', (select jsonb_build_object('id', l.id, 'nivel', l.nivel, 'semana', l.semana,
      'ranking', (select jsonb_agg(jsonb_build_object('user', p.user_id, 'nome', pr.nome, 'avatar', pr.avatar, 'xp', p.xp, 'eu', p.user_id = u) order by p.xp desc, pr.nome)
                  from public.liga_participantes p join public.perfis pr on pr.user_id = p.user_id where p.liga_id = l.id))
      from public.ligas l where l.id = lid),
    'parametros', jsonb_build_object('economia', param('economia'), 'ligas', param('ligas'), 'missoes', param('missoes')),
    'versaoConteudo', (select max(versao) from public.publicacoes),
    'turmas', turmas_do_aluno(u),
    'convites', convites_do_aluno(u),
    'atividades', atividades_do_aluno(u)
  );
end $$;

-- Entrar pelo código: aceita na hora (mesmo que houvesse convite pendente)
create or replace function public.entrar_turma(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); t public.turmas;
begin
  select * into t from public.turmas where codigo = upper(trim(p_codigo)) and ativa;
  if not found then raise exception 'Código não encontrado. Confira com o professor.'; end if;
  insert into public.turma_alunos (turma_id, user_id, aceito) values (t.id, u, true)
    on conflict (turma_id, user_id) do update set aceito = true;
  return jsonb_build_object('id', t.id, 'nome', t.nome, 'estado', estado_aluno());
end $$;

-- Professor adiciona pelo e-mail: vira convite
create or replace function public.adicionar_aluno_turma(p_turma uuid, p_email text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo uuid; nome_alvo text; ja boolean;
begin
  perform exigir_login();
  if not (is_admin() or coord_da_turma(p_turma) or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  select id into alvo from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if alvo is null then raise exception 'Nenhuma conta com o e-mail %. O aluno precisa criar a conta no app primeiro.', trim(p_email); end if;
  select aceito into ja from public.turma_alunos where turma_id = p_turma and user_id = alvo;
  if ja is null then insert into public.turma_alunos (turma_id, user_id, aceito) values (p_turma, alvo, false); end if;
  select nome into nome_alvo from public.perfis where user_id = alvo;
  return jsonb_build_object('user_id', alvo, 'nome', nome_alvo, 'aceito', coalesce(ja, false));
end $$;

-- Aluno aceita ou recusa o convite
create or replace function public.responder_convite(p_turma uuid, p_aceitar boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); t public.turmas;
begin
  select * into t from public.turmas where id = p_turma;
  if not found then raise exception 'Turma não encontrada.'; end if;
  if p_aceitar then update public.turma_alunos set aceito = true, entrou_em = now() where turma_id = p_turma and user_id = u;
  else delete from public.turma_alunos where turma_id = p_turma and user_id = u and not aceito; end if;
  return jsonb_build_object('id', t.id, 'nome', t.nome, 'estado', estado_aluno());
end $$;
grant execute on function public.responder_convite(uuid, boolean) to authenticated;

-- Lista de alunos do painel: diz quem ainda não aceitou
drop function if exists public.alunos_da_turma(uuid);
create or replace function public.alunos_da_turma(p_turma uuid)
returns table (user_id uuid, nome text, email text, xp int, ofensiva int, entrou_em timestamptz, entregas int, aceito boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform exigir_login();
  if not (is_admin() or coord_da_turma(p_turma) or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  return query
    select ta.user_id, p.nome, u.email::text, coalesce(e.xp, 0), public.ofensiva(ta.user_id), ta.entrou_em,
      (select count(*) from public.atividade_entregas en join public.atividades a on a.id = en.atividade_id
         where en.user_id = ta.user_id and a.turma_id = p_turma and en.entregue_em is not null)::int,
      ta.aceito
    from public.turma_alunos ta
    join public.perfis p on p.user_id = ta.user_id
    join auth.users u on u.id = ta.user_id
    left join public.economia_aluno e on e.user_id = ta.user_id
    where ta.turma_id = p_turma
    order by ta.aceito desc, p.nome;
end $$;
grant execute on function public.alunos_da_turma(uuid) to authenticated;

-- E-mail só para quem usa o painel
drop function if exists public.pessoas_das_turmas();
create or replace function public.pessoas_das_turmas()
returns table (user_id uuid, nome text, email text, papel text, disciplina text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform exigir_login();
  return query
    select distinct p.user_id, p.nome, case when eh_educador() then u.email::text else null end, p.papel, p.disciplina_id
    from public.perfis p join auth.users u on u.id = p.user_id
    where is_admin()
       or p.user_id in (select tp.user_id from public.turma_professores tp where professor_da_turma(tp.turma_id) or aluno_da_turma(tp.turma_id))
       or p.user_id in (select em.user_id from public.escola_membros em where membro_da_escola(em.escola_id))
       or p.user_id in (select t.criada_por from public.turmas t where professor_da_turma(t.id));
end $$;
grant execute on function public.pessoas_das_turmas() to authenticated;

-- Ranking da turma (XP da semana), para os próprios alunos e professores da turma
create or replace function public.ranking_turma(p_turma uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when is_admin() or professor_da_turma(p_turma) or aluno_da_turma(p_turma) then
    coalesce((select jsonb_agg(jsonb_build_object('user', ta.user_id, 'nome', p.nome, 'avatar', p.avatar, 'xp', coalesce(e.xp_semana, 0), 'xpTotal', coalesce(e.xp, 0), 'eu', ta.user_id = auth.uid())
                               order by coalesce(e.xp_semana, 0) desc, p.nome)
              from public.turma_alunos ta join public.perfis p on p.user_id = ta.user_id left join public.economia_aluno e on e.user_id = ta.user_id
              where ta.turma_id = p_turma and ta.aceito), '[]'::jsonb)
  else '[]'::jsonb end;
$$;
grant execute on function public.ranking_turma(uuid) to authenticated;
