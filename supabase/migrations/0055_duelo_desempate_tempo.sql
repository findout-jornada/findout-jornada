-- =====================================================================
-- Findout Jornada · Migration 0055 · Duelo: tempos no fim, para explicar o desempate
-- Rodar no SQL Editor depois da 0054. Idempotente.
--
--  · fj_duelo_json passa a devolver, só depois que o duelo termina, o tempo total de
--    resposta de cada jogador (tempoEu, tempoRival, em ms) e se o resultado foi
--    decidido pelo tempo (porTempo: acertos iguais e tempos diferentes).
--    O app usa isso para mostrar "Empate em acertos: X respondeu mais rápido".
--    Durante o jogo os tempos continuam ocultos.
-- =====================================================================

create or replace function public.fj_duelo_json(p_duelo uuid, p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  d public.duelos; pr jsonb := param('duelo'); outro uuid; rod jsonb; minha public.duelo_respostas;
  dele public.duelo_respostas; pode boolean; certa jsonb; seg text;
  perfil_eu jsonb; perfil_ele jsonb; placar jsonb;
begin
  select * into d from public.duelos where id = p_duelo;
  if not found then raise exception 'Duelo não encontrado.'; end if;
  outro := fj_duelo_outro(d, p_user);
  rod := case when d.rodada >= 0 then d.rodadas->d.rodada end;
  if rod is not null then
    select * into minha from public.duelo_respostas where duelo_id = d.id and rodada = d.rodada and user_id = p_user;
    select * into dele from public.duelo_respostas where duelo_id = d.id and rodada = d.rodada and user_id = outro;
    -- pode ver a questão: na sua vez de responder, depois de ter respondido, ou revelada
    pode := d.status = 'fim' or d.fase = 'revelada' or (d.fase = 'resp' and (d.vez = p_user or minha.respondida_em is not null));
    -- entrega: grava o relógio na primeira vez que a questão chega a quem está na vez
    if d.status = 'jogando' and d.fase = 'resp' and d.vez = p_user and minha.vista_em is null then
      insert into public.duelo_respostas (duelo_id, rodada, user_id, vista_em) values (d.id, d.rodada, p_user, now())
        on conflict (duelo_id, rodada, user_id) do update set vista_em = coalesce(duelo_respostas.vista_em, now());
      select * into minha from public.duelo_respostas where duelo_id = d.id and rodada = d.rodada and user_id = p_user;
    end if;
    if d.fase = 'revelada' or d.status = 'fim' then
      certa := case rod->'q'->>'tipo'
        when 'mc' then rod->'q'->'dados'->'opts'->((rod->'q'->'dados'->>'a')::int)
        when 'tf' then rod->'q'->'dados'->'a'
        when 'bank' then rod->'q'->'dados'->'a'
        when 'order' then rod->'q'->'dados'->'items'
        when 'match' then rod->'q'->'dados'->'pairs'
        else null end;
    end if;
  end if;
  select jsonb_build_object('user', user_id, 'nome', nome, 'avatar', avatar) into perfil_eu from public.perfis where user_id = p_user;
  select jsonb_build_object('user', user_id, 'nome', nome, 'avatar', avatar) into perfil_ele from public.perfis where user_id = outro;
  select segmento_id into seg from public.turmas where id = d.turma_id;
  -- histórico das rodadas fechadas, para o placar: quem acertou o que
  select coalesce(jsonb_agg(jsonb_build_object(
      'area', v.r->>'area', 'areaNome', v.r->>'areaNome', 'materiaNome', v.r->>'materiaNome',
      'eu', (select acertou from public.duelo_respostas x where x.duelo_id = d.id and x.rodada = v.k and x.user_id = p_user and x.respondida_em is not null),
      'rival', (select acertou from public.duelo_respostas x where x.duelo_id = d.id and x.rodada = v.k and x.user_id = outro and x.respondida_em is not null)
    ) order by v.k), '[]'::jsonb) into placar
  from (select (ordinalidade - 1)::int as k, valor as r
        from jsonb_array_elements(d.rodadas) with ordinality as t(valor, ordinalidade)) v
  where d.fase = 'revelada' or d.status = 'fim' or v.k < d.rodada;
  return jsonb_build_object(
    'id', d.id, 'status', d.status, 'total', d.total, 'rodada', d.rodada, 'fase', d.fase,
    'agora', now(), 'limiteEm', fj_duelo_limite(d), 'segundos', coalesce((pr->>'segundos')::int, 30),
    'turma', (select nome from public.turmas where id = d.turma_id),
    'euDesafiei', d.desafiante = p_user,
    'eu', perfil_eu, 'rival', perfil_ele,
    'areas', fj_duelo_areas(seg),
    'comeca', d.comeca, 'comeceiEu', d.comeca = p_user,
    'vez', d.vez, 'minhaVez', d.vez = p_user,
    'giroEhMeu', d.rodada >= 0 and d.comeca is not null and fj_duelo_girador(d, case when d.fase = 'revelada' then d.rodada + 1 else d.rodada end) = p_user,
    'area', rod->>'area', 'areaNome', rod->>'areaNome', 'materiaNome', rod->>'materiaNome',
    'questao', case when pode then rod->'pub' end,
    'respondi', minha.respondida_em is not null,
    'rivalRespondeu', dele.respondida_em is not null,
    'acertei', case when (d.fase = 'revelada' or d.status = 'fim') and minha.respondida_em is not null then minha.acertou end,
    'rivalAcertou', case when (d.fase = 'revelada' or d.status = 'fim') and dele.respondida_em is not null then dele.acertou end,
    'minhaResposta', case when d.fase = 'revelada' or d.status = 'fim' then minha.resposta end,
    'certa', certa,
    'explicacao', case when d.fase = 'revelada' or d.status = 'fim' then rod->'q'->>'explicacao' end,
    'placar', placar,
    -- Só contam as rodadas já fechadas. Contar a rodada em curso entregaria, no placar, o
    -- acerto de quem respondeu primeiro — justamente o que o duelo esconde até os dois responderem.
    'acertosEu', (select count(*) from public.duelo_respostas r where r.duelo_id = d.id and r.user_id = p_user and r.acertou
                    and (r.rodada < d.rodada or d.fase = 'revelada' or d.status = 'fim')),
    'acertosRival', (select count(*) from public.duelo_respostas r where r.duelo_id = d.id and r.user_id = outro and r.acertou
                    and (r.rodada < d.rodada or d.fase = 'revelada' or d.status = 'fim')),
    'vencedor', d.vencedor, 'euGanhei', d.status = 'fim' and d.vencedor = p_user,
    'empate', d.status = 'fim' and d.vencedor is null,
    'premio', case when d.status = 'fim' and d.premiado and d.vencedor = p_user then coalesce((pr->>'moedasVitoria')::int, 15) else 0 end,
    'tempoEu', case when d.status = 'fim' then (select coalesce(sum(r.tempo_ms), 0) from public.duelo_respostas r where r.duelo_id = d.id and r.user_id = p_user) end,
    'tempoRival', case when d.status = 'fim' then (select coalesce(sum(r.tempo_ms), 0) from public.duelo_respostas r where r.duelo_id = d.id and r.user_id = outro) end,
    'porTempo', d.status = 'fim' and d.vencedor is not null
      and (select count(*) filter (where r.acertou) from public.duelo_respostas r where r.duelo_id = d.id and r.user_id = p_user)
        = (select count(*) filter (where r.acertou) from public.duelo_respostas r where r.duelo_id = d.id and r.user_id = outro),
    'rivalNaSala', coalesce(case when d.desafiante = p_user then d.visto_desafiado else d.visto_desafiante end > now() - interval '20 seconds', false)
  );
end $$;
revoke execute on function public.fj_duelo_json(uuid, uuid) from public, anon, authenticated;

insert into public.schema_versao (versao) values (55) on conflict do nothing;
