-- =====================================================================
-- Findout Jornada · Migration 0057 · Correções da revisão geral (23 out 2026)
-- Rodar no SQL Editor depois da 0056. Idempotente.
--
--  Duelos
--   (1) A questão do duelo sai com id opaco (não o id do banco): sem isso, cruzar o id com o
--       pacote publicado (que traz gabarito) dava a resposta certa em menos de 1 s.
--   (2) Um aluno joga um duelo por vez: não dá para desafiar nem aceitar com outro duelo em
--       sala ou em jogo (antes, os duelos paralelos perdiam por prazo e davam moedas ao outro).
--   (3) Desafiar só em turma ativa; aceitar convite vencido não funciona mais.
--   (4) Sala cancela pelo tempo mesmo que os dois tenham entrado em horários diferentes.
--   (5) Prêmio diário com trava na linha de economia (dois duelos fechando juntos furavam o teto).
--   (6) Resposta de no máximo 4 KB.
--   (7) A presença na sala só é regravada a cada 8 s (antes, a cada leitura de 2 s).
--   (8) Aluno que sai da turma tem os duelos abertos daquela turma cancelados.
--  Turma única (0056): trava por aluno contra duas entradas simultâneas e código de erro próprio.
--  Privilégios: anon não executa param/escola_bloqueada/fj_seed_q; search_path fixo em funções que faltavam.
--  Desempenho: índices para duelos e chaves estrangeiras sem índice.
--  Integridade: apagar matéria não falha mais por causa de perfis.materia_atual.
--  Auditoria: limpeza diária dos eventos de navegação do painel com mais de 180 dias.
-- =====================================================================

-- ---------- (2)(3) desafiar: turma ativa e um duelo por vez ----------
create or replace function public.fj_duelo_ocupado(p_user uuid, p_exceto uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.duelos where status in ('sala', 'jogando') and p_user in (desafiante, desafiado)
                 and (p_exceto is null or id <> p_exceto));
$$;
revoke execute on function public.fj_duelo_ocupado(uuid, uuid) from public, anon, authenticated;

create or replace function public.desafiar_duelo(p_turma uuid, p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.duelos; pr jsonb := param('duelo'); seg text;
begin
  if p_user = u then raise exception 'Escolha um colega para desafiar.'; end if;
  if not aluno_da_turma(p_turma) then raise exception 'Você não está nesta turma.' using errcode = '42501'; end if;
  if not exists (select 1 from public.turmas where id = p_turma and ativa) then raise exception 'Esta turma está arquivada.'; end if;
  if not exists (select 1 from public.turma_alunos where turma_id = p_turma and user_id = p_user and aceito) then
    raise exception 'Este colega não está na turma.';
  end if;
  select segmento_id into seg from public.turmas where id = p_turma;
  if jsonb_array_length(fj_duelo_areas(seg)) = 0 then
    raise exception 'Ainda não há questões publicadas para o duelo.';
  end if;
  -- resolve prazos vencidos dos duelos abertos dos dois antes de conferir
  perform fj_duelo_avanca(x.id) from public.duelos x
    where x.status in ('convite', 'sala', 'jogando') and (u in (x.desafiante, x.desafiado) or p_user in (x.desafiante, x.desafiado));
  select * into d from public.duelos
    where status in ('convite', 'sala', 'jogando')
      and least(desafiante, desafiado) = least(u, p_user)
      and greatest(desafiante, desafiado) = greatest(u, p_user);
  if found then
    return jsonb_build_object('id', d.id, 'jaExistia', true, 'duelo', fj_duelo_json(d.id, u));
  end if;
  if fj_duelo_ocupado(u) then raise exception 'Você já está num duelo. Termine ou desista dele antes de desafiar outro colega.'; end if;
  if fj_duelo_ocupado(p_user) then raise exception 'Este colega está num duelo agora. Tente daqui a pouco.'; end if;
  insert into public.duelos (turma_id, desafiante, desafiado, total)
    values (p_turma, u, p_user, greatest(2, least(10, coalesce((pr->>'rodadas')::int, 5))))
    returning * into d;
  return jsonb_build_object('id', d.id, 'jaExistia', false, 'duelo', fj_duelo_json(d.id, u));
end $$;
grant execute on function public.desafiar_duelo(uuid, uuid) to authenticated;

create or replace function public.responder_convite_duelo(p_duelo uuid, p_aceitar boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.duelos;
begin
  perform fj_duelo_avanca(p_duelo);   -- convite vencido vira cancelado aqui
  select * into d from public.duelos where id = p_duelo for update;
  if not found or d.desafiado <> u then raise exception 'Convite não encontrado.' using errcode = '42501'; end if;
  if d.status <> 'convite' then raise exception 'Este convite já foi respondido ou expirou.'; end if;
  if p_aceitar then
    if fj_duelo_ocupado(u, d.id) then raise exception 'Você já está num duelo. Termine ou desista dele antes de aceitar outro.'; end if;
    if fj_duelo_ocupado(d.desafiante, d.id) then raise exception 'Quem te desafiou entrou em outro duelo. Desafie de volta depois.'; end if;
    update public.duelos set status = 'sala', visto_desafiado = now(), sala_em = now() where id = d.id;
  else
    update public.duelos set status = 'recusado', encerrado_em = now() where id = d.id;
  end if;
  return jsonb_build_object('status', case when p_aceitar then 'sala' else 'recusado' end);
end $$;
grant execute on function public.responder_convite_duelo(uuid, boolean) to authenticated;

-- ---------- (4) sala cancela pelo tempo ----------
create or replace function public.fj_duelo_avanca(p_duelo uuid)
returns void language plpgsql security definer set search_path = public as $$
declare d public.duelos; pr jsonb := param('duelo'); lim timestamptz; voltas int := 0;
begin
  select * into d from public.duelos where id = p_duelo;
  if not found then return; end if;
  if d.status = 'convite' and d.criado_em < now() - make_interval(hours => coalesce((pr->>'conviteHoras')::int, 24)) then
    update public.duelos set status = 'cancelado', encerrado_em = now() where id = d.id; return;
  end if;
  if d.status = 'sala' and coalesce(d.sala_em, d.criado_em) < now() - make_interval(mins => coalesce((pr->>'salaMinutos')::int, 10)) then
    update public.duelos set status = 'cancelado', encerrado_em = now() where id = d.id; return;
  end if;
  while voltas < 12 loop
    voltas := voltas + 1;
    select * into d from public.duelos where id = p_duelo;
    exit when d.status <> 'jogando';
    lim := fj_duelo_limite(d);
    exit when lim is null or now() <= lim;
    if d.fase = 'resp' then perform fj_duelo_registra(d.id, d.vez, null);
    else perform fj_duelo_gira(d.id); end if;
  end loop;
end $$;
revoke execute on function public.fj_duelo_avanca(uuid) from public, anon, authenticated;

-- ---------- (5) prêmio com trava ----------
create or replace function public.fj_duelo_encerra(p_duelo uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  d public.duelos; pr jsonb := param('duelo'); venc uuid;
  a1 int; a2 int; t1 int; t2 int; teto int; premiar boolean := false;
begin
  select * into d from public.duelos where id = p_duelo for update;
  if not found or d.status = 'fim' then return; end if;
  select count(*) filter (where acertou), coalesce(sum(tempo_ms), 0) into a1, t1
    from public.duelo_respostas where duelo_id = d.id and user_id = d.desafiante;
  select count(*) filter (where acertou), coalesce(sum(tempo_ms), 0) into a2, t2
    from public.duelo_respostas where duelo_id = d.id and user_id = d.desafiado;
  venc := case when a1 > a2 then d.desafiante when a2 > a1 then d.desafiado
               when t1 < t2 then d.desafiante when t2 < t1 then d.desafiado else null end;
  teto := coalesce((pr->>'premiadosPorDia')::int, 3);
  if venc is not null then
    perform 1 from public.economia_aluno where user_id = venc for update;   -- serializa os prêmios do vencedor
    premiar := (select count(*) from public.duelos x
                where x.premiado and x.vencedor = venc
                  and (x.encerrado_em at time zone 'America/Sao_Paulo')::date = hoje()) < teto
           and not exists (select 1 from public.duelos x
                where x.premiado and (x.encerrado_em at time zone 'America/Sao_Paulo')::date = hoje()
                  and least(x.desafiante, x.desafiado) = least(d.desafiante, d.desafiado)
                  and greatest(x.desafiante, x.desafiado) = greatest(d.desafiante, d.desafiado));
  end if;
  update public.duelos set status = 'fim', vencedor = venc, premiado = premiar,
    encerrado_em = now(), vez = null, fase = 'revelada' where id = d.id;
  if premiar then
    update public.economia_aluno set moedas = moedas + coalesce((pr->>'moedasVitoria')::int, 15) where user_id = venc;
  end if;
end $$;
revoke execute on function public.fj_duelo_encerra(uuid) from public, anon, authenticated;

-- ---------- (6) resposta com tamanho máximo ----------
create or replace function public.responder_duelo(p_duelo uuid, p_rodada int, p_resposta jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.duelos;
begin
  if p_resposta is not null and pg_column_size(p_resposta) > 4096 then raise exception 'Resposta grande demais.'; end if;
  select * into d from public.duelos where id = p_duelo;
  if not found or u not in (d.desafiante, d.desafiado) then raise exception 'Duelo não encontrado.' using errcode = '42501'; end if;
  perform fj_duelo_avanca(d.id);
  select * into d from public.duelos where id = p_duelo;
  if d.status <> 'jogando' or d.fase <> 'resp' or d.rodada <> p_rodada then raise exception 'Esta rodada já fechou.'; end if;
  if d.vez <> u then raise exception 'Não é a sua vez.'; end if;
  if p_resposta is null then raise exception 'Escolha uma resposta.'; end if;
  perform fj_duelo_registra(d.id, u, p_resposta);
  return fj_duelo_json(p_duelo, u);
end $$;
grant execute on function public.responder_duelo(uuid, int, jsonb) to authenticated;

-- ---------- (7) presença regravada só a cada 8 s ----------
create or replace function public.estado_duelo(p_duelo uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.duelos; quem uuid;
begin
  select * into d from public.duelos where id = p_duelo;
  if not found then raise exception 'Duelo não encontrado.'; end if;
  if u not in (d.desafiante, d.desafiado) then raise exception 'Este duelo não é seu.' using errcode = '42501'; end if;
  if d.status in ('sala', 'jogando') then
    if u = d.desafiante and coalesce(d.visto_desafiante, 'epoch'::timestamptz) < now() - interval '8 seconds' then
      update public.duelos set visto_desafiante = now() where id = d.id;
    elsif u = d.desafiado and coalesce(d.visto_desafiado, 'epoch'::timestamptz) < now() - interval '8 seconds' then
      update public.duelos set visto_desafiado = now() where id = d.id;
    end if;
  end if;
  perform fj_duelo_avanca(d.id);
  select * into d from public.duelos where id = p_duelo for update;
  if d.status = 'sala' and d.visto_desafiante > now() - interval '20 seconds' and d.visto_desafiado > now() - interval '20 seconds' then
    quem := case when random() < .5 then d.desafiante else d.desafiado end;
    update public.duelos set status = 'jogando', rodada = 0, fase = 'girar',
      comeca = quem, vez = quem, vez_em = now() where id = d.id;
  end if;
  return fj_duelo_json(p_duelo, u);
end $$;
grant execute on function public.estado_duelo(uuid) to authenticated;

-- ---------- (8) saiu da turma: duelos abertos daquela turma são cancelados ----------
create or replace function public.fj_duelo_saiu_turma()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.duelos set status = 'cancelado', encerrado_em = now(), vez = null
    where turma_id = old.turma_id and status in ('convite', 'sala', 'jogando') and old.user_id in (desafiante, desafiado);
  return old;
end $$;
drop trigger if exists fj_duelo_saiu on public.turma_alunos;
create trigger fj_duelo_saiu after delete on public.turma_alunos for each row execute function public.fj_duelo_saiu_turma();

-- ---------- Turma única (0056): trava por aluno e código de erro próprio ----------
create or replace function public.fj_uma_turma_por_aluno()
returns trigger language plpgsql security definer set search_path = public as $$
declare outra text;
begin
  if not new.aceito then return new; end if;
  if tg_op = 'UPDATE' and old.aceito and old.turma_id = new.turma_id then return new; end if;
  perform pg_advisory_xact_lock(hashtext('fj-turma:' || new.user_id::text));   -- duas entradas ao mesmo tempo esperam uma a outra
  select t.nome into outra
    from public.turma_alunos ta join public.turmas t on t.id = ta.turma_id
    where ta.user_id = new.user_id and ta.aceito and t.ativa and ta.turma_id <> new.turma_id
    limit 1;
  if outra is not null then
    raise exception 'Você já está na turma %. Cada aluno participa de uma turma só: peça ao professor para tirar você dela antes de entrar em outra.', outra;
  end if;
  return new;
end $$;

-- ---------- Privilégios e search_path ----------
revoke execute on function public.param(text) from anon;
revoke execute on function public.escola_bloqueada(uuid) from public, anon;
grant execute on function public.escola_bloqueada(uuid) to authenticated;
do $$ begin
  if to_regprocedure('public.fj_seed_q(text, text, text, int, text, text, jsonb, text, int)') is not null then
    revoke execute on function public.fj_seed_q(text, text, text, int, text, text, jsonb, text, int) from public, anon, authenticated;
  end if;
end $$;
alter function public.fj_ranking_dinamica(uuid, uuid) set search_path = public;
alter function public.fj_duelo_outro(public.duelos, uuid) set search_path = public;
alter function public.fj_duelo_girador(public.duelos, int) set search_path = public;
alter function public.fj_duelo_mapa() set search_path = public;
alter function public.hoje() set search_path = public;
alter function public.fj_normalizar_materias(text[], text) set search_path = public;

-- ---------- Índices ----------
create index if not exists duelos_par_idx on public.duelos (least(desafiante, desafiado), greatest(desafiante, desafiado), status);
create index if not exists duelos_vencedor_idx on public.duelos (vencedor, encerrado_em) where status = 'fim';
create index if not exists duelos_desafiado_idx on public.duelos (desafiado, status);
create index if not exists duelos_desafiante_idx on public.duelos (desafiante, status);
create index if not exists duelo_respostas_user_idx on public.duelo_respostas (user_id);
create index if not exists dinamica_membros_user_idx on public.dinamica_membros (user_id);
create index if not exists dinamica_respostas_user_idx on public.dinamica_respostas (user_id);

-- ---------- Integridade: apagar matéria não falha por causa da matéria atual do aluno ----------
do $$
declare c text;
begin
  select conname into c from pg_constraint
    where conrelid = 'public.perfis'::regclass and contype = 'f'
      and conkey = array[(select attnum from pg_attribute where attrelid = 'public.perfis'::regclass and attname = 'materia_atual')];
  if c is not null then execute format('alter table public.perfis drop constraint %I', c); end if;
  alter table public.perfis add constraint perfis_materia_atual_fkey foreign key (materia_atual) references public.materias(id) on delete set null;
end $$;

-- ---------- Auditoria: navegação do painel com mais de 180 dias sai todo dia às 04h UTC ----------
do $$ begin perform cron.unschedule('fj-limpar-auditoria'); exception when others then null; end $$;
do $$ begin
  perform cron.schedule('fj-limpar-auditoria', '0 4 * * *',
    'delete from public.auditoria where origem = ''painel'' and acao in (''tela'', ''busca'', ''clique'', ''login'', ''sair'') and criado_em < now() - interval ''180 days'';');
exception when others then raise notice 'pg_cron indisponível: limpeza da auditoria não agendada.';
end $$;

-- ---------- (1) questão do duelo com id opaco (o app só usa o id como chave de tela; a correção usa o gabarito guardado) ----------
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
    'questao', case when pode then (rod->'pub') || jsonb_build_object('id', md5(d.id::text || ':' || d.rodada::text)) end,
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

insert into public.schema_versao (versao) values (57) on conflict do nothing;
