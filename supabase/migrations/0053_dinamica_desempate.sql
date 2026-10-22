-- =====================================================================
-- Findout Jornada · Migration 0053 · Dinâmica: critério de desempate por tempo médio
-- Rodar no SQL Editor depois da 0052. Idempotente.
--
--  · dinamicas.desempate: 'tempo_total' (como era: menor soma dos tempos de resposta) ou
--    'tempo_medio' (menor tempo médio por resposta). Escolhido no painel ao criar a dinâmica.
--  · criar_dinamica ganha p_desempate; painel_dinamica devolve o critério; o ranking devolve
--    também 'tempoMedio' e ordena pelo critério escolhido.
--  · As outras novidades do painel (montar grupos à mão, sortear questões do banco por matéria,
--    assunto ou todas as matérias) não precisam de banco: usam p_questoes e definir_grupos_dinamica.
-- =====================================================================

alter table public.dinamicas add column if not exists desempate text not null default 'tempo_total';
alter table public.dinamicas drop constraint if exists dinamicas_desempate_check;
alter table public.dinamicas add constraint dinamicas_desempate_check check (desempate in ('tempo_total', 'tempo_medio'));

create or replace function public.fj_ranking_dinamica(p_dinamica uuid, p_user uuid)
returns jsonb language sql stable as $$
  select case when d.modo = 'grupos' then (
    select coalesce(jsonb_agg(jsonb_build_object('nome', x.nome, 'acertos', x.pts, 'tempo', x.tm, 'tempoMedio', x.tmed, 'eu', x.meu)
             order by x.pts desc, case when d.desempate = 'tempo_medio' then x.tmed else x.tm end asc, x.ordem), '[]'::jsonb)
    from (
      select g.nome, g.ordem, g.pontos_manual + coalesce(r.ac, 0) as pts, coalesce(r.tm, 0) as tm,
        coalesce(r.tm, 0)::numeric / greatest(coalesce(r.n, 0), 1) as tmed,
        exists (select 1 from public.dinamica_membros m where m.dinamica_id = d.id and m.user_id = p_user and m.grupo_id = g.id) as meu
      from public.dinamica_grupos g
      left join (select grupo_id, count(*) filter (where acertou) as ac, coalesce(sum(tempo_ms), 0) as tm, count(*) as n
                 from public.dinamica_respostas where dinamica_id = d.id and grupo_id is not null group by grupo_id) r on r.grupo_id = g.id
      where g.dinamica_id = d.id
    ) x
  ) else (
    select coalesce(jsonb_agg(jsonb_build_object('nome', x.nome, 'acertos', x.pts, 'tempo', x.tm, 'tempoMedio', x.tmed, 'eu', x.meu)
             order by x.pts desc, case when d.desempate = 'tempo_medio' then x.tmed else x.tm end asc, x.nome), '[]'::jsonb)
    from (
      select p.nome, coalesce(r.ac, 0) as pts, coalesce(r.tm, 0) as tm,
        coalesce(r.tm, 0)::numeric / greatest(coalesce(r.n, 0), 1) as tmed,
        m.user_id = p_user as meu
      from public.dinamica_membros m
      join public.perfis p on p.user_id = m.user_id
      left join (select user_id, count(*) filter (where acertou) as ac, coalesce(sum(tempo_ms), 0) as tm, count(*) as n
                 from public.dinamica_respostas where dinamica_id = d.id group by user_id) r on r.user_id = m.user_id
      where m.dinamica_id = d.id
    ) x
  ) end
  from public.dinamicas d where d.id = p_dinamica;
$$;
revoke execute on function public.fj_ranking_dinamica(uuid, uuid) from public, anon, authenticated;

drop function if exists public.criar_dinamica(uuid, text, text, text, uuid, int, jsonb);
create or replace function public.criar_dinamica(p_turma uuid, p_titulo text, p_modo text default 'grupos', p_origem text default 'questoes', p_atividade uuid default null, p_tempo int default 60, p_questoes jsonb default null, p_desempate text default 'tempo_total')
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); a public.atividades; dnova public.dinamicas; q jsonb; d jsonb; sq jsonb; pub jsonb := '[]'::jsonb; gab jsonb := '[]'::jsonb; usa_ativ boolean := false;
begin
  if not (is_admin() or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  if coalesce(trim(p_titulo), '') = '' then raise exception 'Dê um nome à dinâmica.'; end if;
  if p_modo not in ('grupos', 'individual') then raise exception 'Modo inválido.'; end if;
  if p_origem not in ('questoes', 'manual') then raise exception 'Origem inválida.'; end if;
  if coalesce(p_desempate, 'tempo_total') not in ('tempo_total', 'tempo_medio') then raise exception 'Critério de desempate inválido.'; end if;
  if p_origem = 'manual' then p_modo := 'grupos'; end if;   -- manual é sempre por grupos
  if p_tempo <> 0 and (p_tempo < 10 or p_tempo > 600) then raise exception 'O tempo por questão vai de 10 a 600 segundos (0 = sem cronômetro).'; end if;
  if p_origem = 'questoes' then
    if p_questoes is not null and jsonb_typeof(p_questoes) = 'array' and jsonb_array_length(p_questoes) > 0 then
      if jsonb_array_length(p_questoes) > 200 then raise exception 'No máximo 200 questões.'; end if;
      for q in select * from jsonb_array_elements(p_questoes) loop
        if coalesce(q->>'id', '') = '' or coalesce(q->>'tipo', '') not in ('mc', 'tf', 'bank', 'order', 'match')
           or coalesce(q->>'enunciado', '') = '' or jsonb_typeof(q->'dados') <> 'object' then
          raise exception 'Questão inválida na lista.';
        end if;
      end loop;
      gab := p_questoes;
    else
      if p_atividade is null then raise exception 'Escolha a atividade ou monte a lista de questões.'; end if;
      select * into a from public.atividades where id = p_atividade;
      if not found or not (is_admin() or professor_da_turma(a.turma_id)) then raise exception 'Atividade não encontrada.'; end if;
      if jsonb_array_length(a.questoes) = 0 then raise exception 'Esta atividade não tem questões.'; end if;
      gab := a.questoes; usa_ativ := true;
    end if;
    for q in select * from jsonb_array_elements(gab) loop
      d := q->'dados';
      sq := case q->>'tipo'
        when 'mc' then jsonb_build_object('opts', (select jsonb_agg(v order by random()) from jsonb_array_elements(d->'opts') v))
        when 'tf' then jsonb_build_object('stmt', d->'stmt')
        when 'bank' then jsonb_build_object('parts', d->'parts',
          'words', (select jsonb_agg(v order by random()) from jsonb_array_elements(coalesce(d->'a', '[]'::jsonb) || coalesce(d->'extra', '[]'::jsonb)) v))
        when 'order' then jsonb_build_object('items', (select jsonb_agg(v order by random()) from jsonb_array_elements(d->'items') v))
        when 'match' then jsonb_build_object(
          'left',  (select jsonb_agg(v->0 order by random()) from jsonb_array_elements(d->'pairs') v),
          'right', (select jsonb_agg(v->1 order by random()) from jsonb_array_elements(d->'pairs') v))
        else '{}'::jsonb end;
      pub := pub || jsonb_build_object('id', q->'id', 'tipo', q->'tipo', 'enunciado', q->'enunciado', 'imagem', q->'imagem', 'dados', sq);
    end loop;
  end if;
  insert into public.dinamicas (turma_id, atividade_id, titulo, modo, origem, questoes, publicas, tempo_questao, criada_por, desempate)
    values (p_turma, case when usa_ativ then p_atividade end, trim(p_titulo), p_modo, p_origem, gab, pub, p_tempo, u, coalesce(p_desempate, 'tempo_total'))
    returning * into dnova;
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', 'dinamica', 'dinamicas', dnova.id::text, left('Criou a dinâmica ' || dnova.titulo, 200),
            jsonb_build_object('turma', p_turma, 'modo', p_modo, 'origem', p_origem, 'questoes', jsonb_array_length(gab), 'desempate', dnova.desempate));
  return jsonb_build_object('id', dnova.id, 'titulo', dnova.titulo);
end $$;
grant execute on function public.criar_dinamica(uuid, text, text, text, uuid, int, jsonb, text) to authenticated;

create or replace function public.painel_dinamica(p_dinamica uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.dinamicas;
begin
  select * into d from public.dinamicas where id = p_dinamica;
  if not found or not (is_admin() or professor_da_turma(d.turma_id)) then raise exception 'Dinâmica não encontrada.'; end if;
  return jsonb_build_object(
    'id', d.id, 'titulo', d.titulo, 'modo', d.modo, 'origem', d.origem, 'status', d.status, 'desempate', d.desempate,
    'turma_id', d.turma_id, 'questao', d.questao, 'total', jsonb_array_length(d.publicas),
    'tempo', d.tempo_questao, 'agora', now(),
    'fimEm', case when d.tempo_questao > 0 and d.questao_iniciada_em is not null then d.questao_iniciada_em + make_interval(secs => d.tempo_questao) end,
    'questoes', d.questoes, 'publicas', d.publicas,
    'grupos', (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'nome', g.nome, 'ordem', g.ordem, 'pontos_manual', g.pontos_manual,
        'membros', (select coalesce(jsonb_agg(jsonb_build_object('user_id', m.user_id, 'nome', p.nome, 'online', m.visto_em > now() - interval '15 seconds') order by p.nome), '[]'::jsonb)
                    from public.dinamica_membros m join public.perfis p on p.user_id = m.user_id where m.dinamica_id = d.id and m.grupo_id = g.id)) order by g.ordem), '[]'::jsonb)
      from public.dinamica_grupos g where g.dinamica_id = d.id),
    'semGrupo', (select coalesce(jsonb_agg(jsonb_build_object('user_id', m.user_id, 'nome', p.nome, 'online', m.visto_em > now() - interval '15 seconds') order by p.nome), '[]'::jsonb)
      from public.dinamica_membros m join public.perfis p on p.user_id = m.user_id where m.dinamica_id = d.id and m.grupo_id is null),
    'alunos', (select coalesce(jsonb_agg(jsonb_build_object('user_id', ta.user_id, 'nome', p.nome,
        'online', exists (select 1 from public.dinamica_membros m where m.dinamica_id = d.id and m.user_id = ta.user_id and m.visto_em > now() - interval '15 seconds')) order by p.nome), '[]'::jsonb)
      from public.turma_alunos ta join public.perfis p on p.user_id = ta.user_id where ta.turma_id = d.turma_id and ta.aceito),
    'respostas', case when d.questao >= 0 then (select coalesce(jsonb_agg(jsonb_build_object(
        'user_id', r.user_id, 'nome', p.nome, 'grupoId', r.grupo_id,
        'grupo', (select g.nome from public.dinamica_grupos g where g.id = r.grupo_id),
        'resposta', r.resposta, 'acertou', r.acertou, 'tempo', r.tempo_ms) order by r.respondida_em), '[]'::jsonb)
      from public.dinamica_respostas r join public.perfis p on p.user_id = r.user_id
      where r.dinamica_id = d.id and r.questao = d.questao) end,
    'ranking', fj_ranking_dinamica(d.id, u)
  );
end $$;
grant execute on function public.painel_dinamica(uuid) to authenticated;

insert into public.schema_versao (versao) values (53) on conflict do nothing;
