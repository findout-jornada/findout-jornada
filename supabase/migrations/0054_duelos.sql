-- =====================================================================
-- Findout Jornada · Migration 0054 · Duelo entre colegas
-- Rodar no SQL Editor depois da 0053. Idempotente.
--
-- Um aluno desafia um colega da MESMA turma. Os dois entram numa sala
-- (sem bate-papo: é só o jogo), o servidor sorteia quem começa e o duelo
-- corre em turnos, 5 rodadas:
--
--   1. Na sua vez, o jogador gira a roleta. Quem sorteia a área (as
--      mesmas do Mapa do ENEM) e a questão é o SERVIDOR; o app só anima
--      a roleta até a fatia que voltou. Girar não é vantagem nem azar:
--      a área sorteada vale para os dois.
--   2. Quem girou responde primeiro, com o relógio correndo.
--   3. Depois o adversário responde A MESMA QUESTÃO, com as alternativas
--      na mesma ordem e sem ver nada do que o primeiro respondeu.
--   4. A rodada é revelada para os dois, e quem gira a próxima é o outro.
--
-- A mesma questão para os dois é o que faz o duelo ser justo. Com uma
-- questão diferente para cada um, o placar mediria sorte de sorteio —
-- uma fácil contra uma difícil — e não quem sabe mais. É por isso que
-- nada do que o primeiro respondeu aparece antes de o segundo responder:
-- a resposta certa, o acerto e a explicação só saem quando os dois já
-- responderam.
--
-- Idiomas ficam fora do sorteio. O idioma da viagem (Inglês ou Espanhol)
-- é escolha de cada aluno e mora no aparelho, então o servidor não sabe
-- qual é o de cada um, e sortear Espanhol para quem estuda Inglês seria
-- injusto. Linguagens entra no duelo com Português.
--
-- Ninguém fica preso esperando: cada vez tem prazo. Quem não gira em
-- 45 s tem a roleta girada pelo servidor; quem não responde perde a
-- questão (o relógio da resposta, ou 90 s se nunca abriu a tela). Os
-- prazos são resolvidos de forma preguiçosa, na leitura seguinte do
-- estado — sem cron, sem job: quem está na sala faz o duelo andar.
--
-- Duelo não gasta coração e não dá XP. XP alimenta as ligas, e dois
-- amigos poderiam trocar vitórias para subir. A vitória dá moedas, com
-- teto de 3 duelos premiados por dia e um por adversário, para o prêmio
-- não virar fazenda.
-- =====================================================================

insert into public.parametros (chave, valor) values
  ('duelo', '{"rodadas":5,"segundos":30,"segundosGirar":45,"moedasVitoria":15,"premiadosPorDia":3,"salaMinutos":10,"conviteHoras":24}'::jsonb)
  on conflict (chave) do nothing;

-- ---------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------
create table if not exists public.duelos (
  id uuid primary key default gen_random_uuid(),
  turma_id uuid not null references public.turmas(id) on delete cascade,
  desafiante uuid not null references auth.users(id) on delete cascade,
  desafiado uuid not null references auth.users(id) on delete cascade,
  status text not null default 'convite' check (status in ('convite', 'sala', 'jogando', 'fim', 'recusado', 'cancelado')),
  comeca uuid references auth.users(id) on delete set null,   -- sorteado quando a sala fica cheia
  total int not null default 5,
  rodada int not null default -1,                             -- rodada em jogo (0 a total-1)
  fase text not null default 'girar' check (fase in ('girar', 'resp', 'revelada')),
  vez uuid references auth.users(id) on delete set null,      -- de quem é a ação agora
  vez_em timestamptz,
  rodadas jsonb not null default '[]'::jsonb,                 -- uma por rodada, com gabarito: só o servidor lê
  vencedor uuid references auth.users(id) on delete set null, -- null com status 'fim' = empate
  premiado boolean not null default false,
  visto_desafiante timestamptz,
  visto_desafiado timestamptz,
  criado_em timestamptz not null default now(),
  sala_em timestamptz,                                        -- quando o convite foi aceito
  encerrado_em timestamptz,
  constraint duelos_dois_jogadores check (desafiante <> desafiado)
);
create index if not exists duelos_desafiado_idx on public.duelos(desafiado, status);
create index if not exists duelos_desafiante_idx on public.duelos(desafiante, status);
create index if not exists duelos_turma_idx on public.duelos(turma_id);
-- Um duelo aberto por par, em qualquer direção: o convite de volta não cria um segundo
create unique index if not exists duelos_abertos_uq on public.duelos
  (least(desafiante, desafiado), greatest(desafiante, desafiado))
  where status in ('convite', 'sala', 'jogando');

create table if not exists public.duelo_respostas (
  duelo_id uuid not null references public.duelos(id) on delete cascade,
  rodada int not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  vista_em timestamptz,          -- quando a questão foi ENTREGUE a este jogador: o relógio conta daqui
  resposta jsonb,
  acertou boolean not null default false,
  tempo_ms int not null default 0,
  respondida_em timestamptz,     -- null = ainda não respondeu
  primary key (duelo_id, rodada, user_id)
);

alter table public.duelos enable row level security;
alter table public.duelo_respostas enable row level security;

-- As rodadas guardam o gabarito: ninguém lê a tabela direto, nem os dois
-- jogadores. Tudo passa por estado_duelo/girar_duelo/responder_duelo.
drop policy if exists duelos_ler on public.duelos;
create policy duelos_ler on public.duelos for select to authenticated using (public.is_admin());
drop policy if exists duelo_respostas_ler on public.duelo_respostas;
create policy duelo_respostas_ler on public.duelo_respostas for select to authenticated using (public.is_admin());

-- Escola bloqueada não joga: o gatilho da 0052 acha a escola pelo turma_id
drop trigger if exists fj_bloqueio_duelos on public.duelos;
create trigger fj_bloqueio_duelos before insert or update or delete on public.duelos
  for each row execute function public.fj_barra_escola_bloqueada();

-- ---------------------------------------------------------------
-- A roleta: as áreas são as mesmas ilhas do Mapa do ENEM (ILHAS, em
-- app/index.html). Se mudar lá, mude aqui. Só entram as áreas que têm
-- questão publicada para o segmento da turma, então a roleta nunca
-- mostra uma fatia que o sorteio não consegue cumprir.
-- ---------------------------------------------------------------
create or replace function public.fj_duelo_mapa()
returns table (id text, nome text, mats text[], ordem int) language sql immutable as $$
  values ('ling'::text, 'Linguagens'::text, array['por']::text[], 1),   -- idiomas fora: ver o cabeçalho
         ('hum',  'Humanas',     array['his', 'geo', 'fil'], 2),
         ('nat',  'Natureza',    array['bio', 'qui', 'fis'], 3),
         ('mat',  'Matemática',  array['mat'],             4),
         ('red',  'Redação',     array['red'],             5),
         ('extra','Atualidades', array['cge', 'eti'],       6);
$$;
revoke execute on function public.fj_duelo_mapa() from public, anon, authenticated;

create or replace function public.fj_duelo_areas(p_segmento text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'nome', m.nome) order by m.ordem), '[]'::jsonb)
  from public.fj_duelo_mapa() m
  where exists (
    select 1 from public.questoes q join public.materias ma on ma.id = q.materia_id
    where q.status = 'publicada' and ma.ativa and q.materia_id = any(m.mats)
      and (cardinality(q.segmentos) = 0 or p_segmento is null or p_segmento = any(q.segmentos)));
$$;
revoke execute on function public.fj_duelo_areas(text) from public, anon, authenticated;

-- Sorteia área + questão da rodada. Não repete questão no mesmo duelo
-- (p_usadas = {"<id>": true, ...}); se o banco acabar, repete em vez de travar.
create or replace function public.fj_duelo_questao(p_segmento text, p_usadas jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare areas jsonb; a jsonb; mats text[]; q public.questoes; d jsonb; sq jsonb; k int := 0; achou boolean := false;
begin
  areas := fj_duelo_areas(p_segmento);
  if jsonb_array_length(areas) = 0 then raise exception 'Ainda não há questões publicadas para o duelo.'; end if;
  -- tenta algumas áreas: uma pode ter só questões já usadas neste duelo
  while k < 10 and not achou loop
    k := k + 1;
    select v into a from jsonb_array_elements(areas) v order by random() limit 1;
    select m.mats into mats from public.fj_duelo_mapa() m where m.id = a->>'id';
    select qq.* into q from public.questoes qq join public.materias ma on ma.id = qq.materia_id
      where qq.status = 'publicada' and ma.ativa and qq.materia_id = any(mats)
        and (cardinality(qq.segmentos) = 0 or p_segmento is null or p_segmento = any(qq.segmentos))
        and not (p_usadas ? qq.id::text)
      order by random() limit 1;
    achou := found;
  end loop;
  if not achou then   -- banco esgotado: repete uma questão em vez de parar o duelo
    select v into a from jsonb_array_elements(areas) v order by random() limit 1;
    select m.mats into mats from public.fj_duelo_mapa() m where m.id = a->>'id';
    select qq.* into q from public.questoes qq join public.materias ma on ma.id = qq.materia_id
      where qq.status = 'publicada' and ma.ativa and qq.materia_id = any(mats)
        and (cardinality(qq.segmentos) = 0 or p_segmento is null or p_segmento = any(qq.segmentos))
      order by random() limit 1;
    achou := found;
  end if;
  if not achou then raise exception 'Ainda não há questões publicadas para o duelo.'; end if;
  -- cópia pública embaralhada UMA vez: os dois veem as alternativas na mesma ordem
  d := q.dados;
  sq := case q.tipo
    when 'mc' then jsonb_build_object('opts', (select jsonb_agg(v order by random()) from jsonb_array_elements(d->'opts') v))
    when 'tf' then jsonb_build_object('stmt', d->'stmt')
    when 'bank' then jsonb_build_object('parts', d->'parts',
      'words', (select jsonb_agg(v order by random()) from jsonb_array_elements(coalesce(d->'a', '[]'::jsonb) || coalesce(d->'extra', '[]'::jsonb)) v))
    when 'order' then jsonb_build_object('items', (select jsonb_agg(v order by random()) from jsonb_array_elements(d->'items') v))
    when 'match' then jsonb_build_object(
      'left',  (select jsonb_agg(v->0 order by random()) from jsonb_array_elements(d->'pairs') v),
      'right', (select jsonb_agg(v->1 order by random()) from jsonb_array_elements(d->'pairs') v))
    else '{}'::jsonb end;
  return jsonb_build_object(
    'area', a->>'id', 'areaNome', a->>'nome',
    'materia', q.materia_id, 'materiaNome', (select nome from public.materias where id = q.materia_id),
    'q', jsonb_build_object('id', q.id, 'tipo', q.tipo, 'enunciado', q.enunciado, 'dados', q.dados, 'explicacao', q.explicacao),
    'pub', jsonb_build_object('id', q.id, 'tipo', q.tipo, 'enunciado', q.enunciado, 'imagem', q.imagem_url, 'dados', sq),
    'em', now());
end $$;
revoke execute on function public.fj_duelo_questao(text, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------
-- Peças internas do turno
-- ---------------------------------------------------------------
create or replace function public.fj_duelo_outro(p_duelo public.duelos, p_user uuid)
returns uuid language sql immutable as $$
  select case when p_user = p_duelo.desafiante then p_duelo.desafiado else p_duelo.desafiante end;
$$;
revoke execute on function public.fj_duelo_outro(public.duelos, uuid) from public, anon, authenticated;

-- Quem gira a rodada k: alterna a partir de quem começou
create or replace function public.fj_duelo_girador(p_duelo public.duelos, p_rodada int)
returns uuid language sql immutable as $$
  select case when p_rodada % 2 = 0 then p_duelo.comeca else public.fj_duelo_outro(p_duelo, p_duelo.comeca) end;
$$;
revoke execute on function public.fj_duelo_girador(public.duelos, int) from public, anon, authenticated;

-- Prazo da vez. Girar: segundosGirar. Responder: o relógio começa quando
-- a questão foi entregue (vista_em); se o jogador nunca abriu a tela,
-- vale um teto a partir do início da vez, senão o duelo ficaria parado.
create or replace function public.fj_duelo_limite(p_duelo public.duelos)
returns timestamptz language plpgsql stable security definer set search_path = public as $$
declare pr jsonb := param('duelo'); visto timestamptz;
begin
  if p_duelo.status <> 'jogando' or p_duelo.vez_em is null then return null; end if;
  if p_duelo.fase in ('girar', 'revelada') then
    return p_duelo.vez_em + make_interval(secs => coalesce((pr->>'segundosGirar')::int, 45));
  end if;
  select vista_em into visto from public.duelo_respostas
    where duelo_id = p_duelo.id and rodada = p_duelo.rodada and user_id = p_duelo.vez;
  return coalesce(visto, p_duelo.vez_em + make_interval(secs => 60))
         + make_interval(secs => coalesce((pr->>'segundos')::int, 30));
end $$;
revoke execute on function public.fj_duelo_limite(public.duelos) from public, anon, authenticated;

-- Fecha o duelo: mais acertos vence, empate vai para o menor tempo somado
-- e, se der igual nos dois, fica empatado de verdade. Prêmio em moedas com
-- teto diário e um por adversário.
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
  -- o mesmo par não premia duas vezes no dia, e cada aluno tem teto de duelos premiados.
  -- O dia é o de Brasília (hoje()), o mesmo do resto do app, senão o teto viraria às 21h.
  if venc is not null then
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

-- Gira a roleta da rodada em jogo (ou abre a próxima, vindo de 'revelada').
-- Sem checagem de permissão: quem chama já decidiu que pode (o jogador da
-- vez, ou o próprio servidor quando o prazo estourou).
create or replace function public.fj_duelo_gira(p_duelo uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.duelos; seg text; usadas jsonb := '{}'::jsonb; r jsonb; nova int;
begin
  select * into d from public.duelos where id = p_duelo for update;
  if not found or d.status <> 'jogando' or d.fase = 'resp' then return null; end if;
  nova := case when d.fase = 'revelada' then d.rodada + 1 else d.rodada end;
  if nova >= d.total then perform fj_duelo_encerra(d.id); return null; end if;
  select segmento_id into seg from public.turmas where id = d.turma_id;
  select coalesce(jsonb_object_agg(v->'q'->>'id', true), '{}'::jsonb) into usadas
    from jsonb_array_elements(d.rodadas) v;
  r := fj_duelo_questao(seg, usadas);
  update public.duelos set rodada = nova, fase = 'resp', rodadas = d.rodadas || jsonb_build_array(r),
    vez = fj_duelo_girador(d, nova), vez_em = now() where id = d.id;
  return jsonb_build_object('area', r->>'area', 'areaNome', r->>'areaNome', 'materiaNome', r->>'materiaNome', 'rodada', nova);
end $$;
revoke execute on function public.fj_duelo_gira(uuid) from public, anon, authenticated;

-- Registra a resposta da vez (p_resposta null = em branco, quando o prazo
-- estourou) e passa a vez: para o adversário, ou para a revelação.
create or replace function public.fj_duelo_registra(p_duelo uuid, p_user uuid, p_resposta jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare d public.duelos; gq jsonb; c jsonb; ok boolean := false; ms int := 0; visto timestamptz; outro uuid;
begin
  select * into d from public.duelos where id = p_duelo for update;
  if not found or d.status <> 'jogando' or d.fase <> 'resp' or d.vez <> p_user then return; end if;
  gq := d.rodadas->d.rodada->'q';
  if p_resposta is not null then
    c := fj_corrige_respostas(jsonb_build_array(gq), jsonb_build_array(jsonb_build_object('id', gq->>'id', 'resposta', p_resposta)));
    ok := coalesce((c->'corrigidas'->0->>'acertou')::boolean, false);
  end if;
  select vista_em into visto from public.duelo_respostas where duelo_id = d.id and rodada = d.rodada and user_id = p_user;
  ms := greatest(0, least(600000, (extract(epoch from now() - coalesce(visto, d.vez_em, now())) * 1000)::int));
  insert into public.duelo_respostas (duelo_id, rodada, user_id, vista_em, resposta, acertou, tempo_ms, respondida_em)
    values (d.id, d.rodada, p_user, coalesce(visto, now()), p_resposta, ok, ms, now())
    on conflict (duelo_id, rodada, user_id) do update
      set resposta = excluded.resposta, acertou = excluded.acertou, tempo_ms = excluded.tempo_ms, respondida_em = excluded.respondida_em
      where duelo_respostas.respondida_em is null;
  outro := fj_duelo_outro(d, p_user);
  if exists (select 1 from public.duelo_respostas where duelo_id = d.id and rodada = d.rodada and user_id = outro and respondida_em is not null) then
    update public.duelos set fase = 'revelada', vez = fj_duelo_girador(d, d.rodada + 1), vez_em = now() where id = d.id;
    -- os dois responderam a última: fecha agora, sem deixar o duelo esperando um giro que não vem
    if d.rodada + 1 >= d.total then perform fj_duelo_encerra(d.id); end if;
  else
    update public.duelos set vez = outro, vez_em = now() where id = d.id;
  end if;
end $$;
revoke execute on function public.fj_duelo_registra(uuid, uuid, jsonb) from public, anon, authenticated;

-- Resolve o que venceu o prazo: gira sozinho, responde em branco, abre a
-- sala que ninguém ocupou, vence o convite esquecido. Roda no começo de
-- toda leitura de estado — é o que faz o duelo andar sem cron.
create or replace function public.fj_duelo_avanca(p_duelo uuid)
returns void language plpgsql security definer set search_path = public as $$
declare d public.duelos; pr jsonb := param('duelo'); lim timestamptz; voltas int := 0;
begin
  select * into d from public.duelos where id = p_duelo;
  if not found then return; end if;
  if d.status = 'convite' and d.criado_em < now() - make_interval(hours => coalesce((pr->>'conviteHoras')::int, 24)) then
    update public.duelos set status = 'cancelado', encerrado_em = now() where id = d.id; return;
  end if;
  if d.status = 'sala' and coalesce(d.sala_em, d.criado_em) < now() - make_interval(mins => coalesce((pr->>'salaMinutos')::int, 10))
     and (d.visto_desafiante is null or d.visto_desafiado is null) then
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

-- ---------------------------------------------------------------
-- O estado como um dos dois jogadores o vê. A questão só vai para quem
-- já pode vê-la, e o relógio da resposta começa exatamente na entrega:
-- é esta função que grava o vista_em de quem está na vez.
-- ---------------------------------------------------------------
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
    'rivalNaSala', coalesce(case when d.desafiante = p_user then d.visto_desafiado else d.visto_desafiante end > now() - interval '20 seconds', false)
  );
end $$;
revoke execute on function public.fj_duelo_json(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------
-- Desafiar um colega da turma
-- ---------------------------------------------------------------
create or replace function public.desafiar_duelo(p_turma uuid, p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.duelos; pr jsonb := param('duelo'); seg text;
begin
  if p_user = u then raise exception 'Escolha um colega para desafiar.'; end if;
  if not aluno_da_turma(p_turma) then raise exception 'Você não está nesta turma.' using errcode = '42501'; end if;
  if not exists (select 1 from public.turma_alunos where turma_id = p_turma and user_id = p_user and aceito) then
    raise exception 'Este colega não está na turma.';
  end if;
  -- sem área com questão publicada a roleta não tem o que sortear: barra aqui, não no meio do duelo
  select segmento_id into seg from public.turmas where id = p_turma;
  if jsonb_array_length(fj_duelo_areas(seg)) = 0 then
    raise exception 'Ainda não há questões publicadas para o duelo.';
  end if;
  -- limpa o que já venceu o prazo entre os dois, senão o índice de duelo aberto barra o novo
  perform fj_duelo_avanca(x.id) from public.duelos x
    where x.status in ('convite', 'sala', 'jogando')
      and least(x.desafiante, x.desafiado) = least(u, p_user)
      and greatest(x.desafiante, x.desafiado) = greatest(u, p_user);
  select * into d from public.duelos
    where status in ('convite', 'sala', 'jogando')
      and least(desafiante, desafiado) = least(u, p_user)
      and greatest(desafiante, desafiado) = greatest(u, p_user);
  if found then
    return jsonb_build_object('id', d.id, 'jaExistia', true, 'duelo', fj_duelo_json(d.id, u));
  end if;
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
  select * into d from public.duelos where id = p_duelo for update;
  if not found or d.desafiado <> u then raise exception 'Convite não encontrado.' using errcode = '42501'; end if;
  if d.status <> 'convite' then raise exception 'Este convite já foi respondido.'; end if;
  if p_aceitar then
    update public.duelos set status = 'sala', visto_desafiado = now(), sala_em = now() where id = d.id;
  else
    update public.duelos set status = 'recusado', encerrado_em = now() where id = d.id;
  end if;
  return jsonb_build_object('status', case when p_aceitar then 'sala' else 'recusado' end);
end $$;
grant execute on function public.responder_convite_duelo(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------
-- Estado do duelo (o app consulta a cada 2 s). Marca presença, resolve
-- prazos, sorteia quem começa quando os dois estão na sala.
-- ---------------------------------------------------------------
create or replace function public.estado_duelo(p_duelo uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.duelos; quem uuid;
begin
  select * into d from public.duelos where id = p_duelo;
  if not found then raise exception 'Duelo não encontrado.'; end if;
  if u not in (d.desafiante, d.desafiado) then raise exception 'Este duelo não é seu.' using errcode = '42501'; end if;
  if d.status in ('sala', 'jogando') then
    if u = d.desafiante then update public.duelos set visto_desafiante = now() where id = d.id;
    else update public.duelos set visto_desafiado = now() where id = d.id; end if;
  end if;
  perform fj_duelo_avanca(d.id);
  -- os dois na sala: sorteia quem começa e manda a primeira roleta para ele
  select * into d from public.duelos where id = p_duelo for update;
  if d.status = 'sala' and d.visto_desafiante > now() - interval '20 seconds' and d.visto_desafiado > now() - interval '20 seconds' then
    quem := case when random() < .5 then d.desafiante else d.desafiado end;   -- o sorteio de quem começa
    update public.duelos set status = 'jogando', rodada = 0, fase = 'girar',
      comeca = quem, vez = quem, vez_em = now() where id = d.id;
  end if;
  return fj_duelo_json(p_duelo, u);
end $$;
grant execute on function public.estado_duelo(uuid) to authenticated;

-- Girar a roleta na sua vez. Devolve só a área sorteada: a questão (e o
-- relógio) chega na leitura seguinte, quando a roleta já parou na tela.
create or replace function public.girar_duelo(p_duelo uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.duelos; r jsonb;
begin
  select * into d from public.duelos where id = p_duelo;
  if not found or u not in (d.desafiante, d.desafiado) then raise exception 'Duelo não encontrado.' using errcode = '42501'; end if;
  perform fj_duelo_avanca(d.id);
  select * into d from public.duelos where id = p_duelo;
  if d.status <> 'jogando' then raise exception 'Este duelo não está em andamento.'; end if;
  if d.fase = 'resp' then raise exception 'A questão desta rodada já está na mesa.'; end if;
  if d.vez <> u then raise exception 'É a vez do seu adversário girar.'; end if;
  r := fj_duelo_gira(d.id);
  -- de propósito NÃO devolve o estado: quem chama fj_duelo_json entrega a questão e
  -- começa o relógio, e aqui a roleta ainda está girando na tela. O app lê o estado
  -- quando a roleta para, e é nessa leitura que a questão chega e o relógio começa.
  return coalesce(r, '{}'::jsonb);
end $$;
grant execute on function public.girar_duelo(uuid) to authenticated;

create or replace function public.responder_duelo(p_duelo uuid, p_rodada int, p_resposta jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.duelos;
begin
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

-- Sair: cancela o convite ou a sala; com o duelo em andamento, desiste
-- (o adversário leva a vitória pelas rodadas que já estão no placar).
create or replace function public.sair_duelo(p_duelo uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.duelos;
begin
  select * into d from public.duelos where id = p_duelo for update;
  if not found or u not in (d.desafiante, d.desafiado) then raise exception 'Duelo não encontrado.' using errcode = '42501'; end if;
  if d.status in ('convite', 'sala') then
    update public.duelos set status = 'cancelado', encerrado_em = now() where id = d.id;
    return jsonb_build_object('status', 'cancelado');
  end if;
  if d.status = 'jogando' then
    update public.duelos set vencedor = fj_duelo_outro(d, u), status = 'fim', encerrado_em = now(), vez = null where id = d.id;
    return jsonb_build_object('status', 'fim', 'desisti', true);
  end if;
  return jsonb_build_object('status', d.status);
end $$;
grant execute on function public.sair_duelo(uuid) to authenticated;

-- ---------------------------------------------------------------
-- Para a aba Turma: convites recebidos, duelo em andamento e o retrospecto
-- ---------------------------------------------------------------
create or replace function public.duelos_do_aluno()
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login();
begin
  perform fj_duelo_avanca(x.id) from public.duelos x
    where x.status in ('convite', 'sala', 'jogando') and u in (x.desafiante, x.desafiado);
  return jsonb_build_object(
    'convites', (select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'de', p.nome, 'avatar', p.avatar, 'turma', t.nome) order by d.criado_em desc), '[]'::jsonb)
      from public.duelos d join public.perfis p on p.user_id = d.desafiante join public.turmas t on t.id = d.turma_id
      where d.desafiado = u and d.status = 'convite'),
    'emJogo', (select jsonb_build_object('id', d.id, 'status', d.status, 'rival', p.nome, 'avatar', p.avatar,
                 'minhaVez', d.vez = u, 'rodada', d.rodada + 1, 'total', d.total)
      from public.duelos d join public.perfis p on p.user_id = case when d.desafiante = u then d.desafiado else d.desafiante end
      where u in (d.desafiante, d.desafiado) and d.status in ('sala', 'jogando')
      order by d.criado_em desc limit 1),
    'enviado', (select jsonb_build_object('id', d.id, 'para', p.nome, 'avatar', p.avatar)
      from public.duelos d join public.perfis p on p.user_id = d.desafiado
      where d.desafiante = u and d.status = 'convite' order by d.criado_em desc limit 1),
    'vitorias', (select count(*) from public.duelos where status = 'fim' and vencedor = u),
    'derrotas', (select count(*) from public.duelos where status = 'fim' and vencedor is not null and vencedor <> u and u in (desafiante, desafiado)),
    'empates', (select count(*) from public.duelos where status = 'fim' and vencedor is null and u in (desafiante, desafiado))
  );
end $$;
grant execute on function public.duelos_do_aluno() to authenticated;

-- Colegas da turma para a tela de escolher adversário, com o retrospecto
-- de cada um contra mim e quem já está num duelo meu.
create or replace function public.colegas_para_duelo(p_turma uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login();
begin
  if not aluno_da_turma(p_turma) then raise exception 'Você não está nesta turma.' using errcode = '42501'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
      'user', ta.user_id, 'nome', p.nome, 'avatar', p.avatar,
      'vitorias', (select count(*) from public.duelos d where d.status = 'fim' and d.vencedor = u
                     and least(d.desafiante, d.desafiado) = least(u, ta.user_id) and greatest(d.desafiante, d.desafiado) = greatest(u, ta.user_id)),
      'derrotas', (select count(*) from public.duelos d where d.status = 'fim' and d.vencedor = ta.user_id
                     and least(d.desafiante, d.desafiado) = least(u, ta.user_id) and greatest(d.desafiante, d.desafiado) = greatest(u, ta.user_id)),
      'aberto', exists (select 1 from public.duelos d where d.status in ('convite', 'sala', 'jogando')
                     and least(d.desafiante, d.desafiado) = least(u, ta.user_id) and greatest(d.desafiante, d.desafiado) = greatest(u, ta.user_id))
    ) order by p.nome), '[]'::jsonb)
    from public.turma_alunos ta join public.perfis p on p.user_id = ta.user_id
    where ta.turma_id = p_turma and ta.aceito and ta.user_id <> u);
end $$;
grant execute on function public.colegas_para_duelo(uuid) to authenticated;

insert into public.schema_versao (versao) values (54) on conflict do nothing;
