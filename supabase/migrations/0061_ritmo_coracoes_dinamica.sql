-- =====================================================================
-- Findout Jornada · Migration 0061 · Farm de XP, corações na lição e
-- id da questão na dinâmica
-- Rodar no SQL Editor depois da 0060. Idempotente.
--
-- F2 (ALTA) · farm ilimitado de XP, ofensiva e missões
--   A trava de ritmo da 0058 só valia quando p_acertos + p_erros > 0.
--   Uma chamada 0/0 escapava da trava, levava o bônus de "lição
--   perfeita" (perfeita := p_erros = 0), acendia a ofensiva, enchia
--   licoes/perfeitas do dia (missões e baú) e podia injetar 100 linhas
--   em `tentativas` — corrompendo o domínio (0048) e a revisão (0049).
--   O XP do perfil e o do mês não têm teto diário.
--   Aqui: lição sem nenhuma questão respondida não paga XP nem moedas,
--   não acende a ofensiva, não conta em licoes/perfeitas e não grava
--   tentativas; "perfeita" passa a exigir ao menos um acerto; e o ritmo
--   mínimo vale para qualquer chamada, inclusive 0/0.
--
-- F6 (MÉDIA) · coração que nunca volta dentro da lição
--   O app precisa regenerar corações sem recarregar o estado inteiro
--   (recarregarEstado desiste quando há lição em curso, para não trocar
--   S no meio dela). regenerar_coracoes existe desde a 0002 mas é
--   interna (revogada de authenticated). Aqui ela ganha uma casca
--   pública e mínima: devolve só os corações e o próximo horário.
--
-- F4 (MÉDIA) · dinâmica entregava o id real da questão
--   A proteção que atividades (0058) e duelos (0057) ganharam não
--   chegou à dinâmica: questaoPub levava o id do banco, que o aluno
--   cruza com o pacote local para acertar tudo. Mesmo molde do duelo:
--   md5(dinamica:índice). responder_dinamica recebe o índice
--   (p_questao int), não o id, então a correção não muda em nada.
-- =====================================================================

-- ---------- F6 · casca pública de regenerar_coracoes ----------
create or replace function public.coracoes_agora()
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); e public.economia_aluno; mx int;
begin
  if tem_plus(u) then return jsonb_build_object('coracoes', null, 'plus', true, 'proximoCoracaoEm', null); end if;
  e := regenerar_coracoes(u);
  mx := coalesce((param('economia')->>'coracoes')::int, 5);
  return jsonb_build_object('coracoes', e.coracoes, 'plus', false,
    'proximoCoracaoEm', case when e.coracoes < mx then e.coracoes_em end);
end $$;
grant execute on function public.coracoes_agora() to authenticated;

-- ---------- F2 · concluir_licao: ritmo mínimo sem a brecha do 0/0 ----------
-- Igual à da 0058, com três mudanças marcadas abaixo (respondeu / perfeita / ritmo).
create or replace function public.concluir_licao(
  p_modo text, p_licao uuid default null, p_unidade uuid default null, p_materia text default null,
  p_acertos int default 0, p_erros int default 0, p_melhor_combo int default 0, p_tempo_s int default 0,
  p_erradas uuid[] default '{}', p_acertadas uuid[] default '{}', p_sucesso boolean default true,
  p_tentativas jsonb default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := exigir_login(); ec jsonb := param('economia'); e public.economia_aluno;
  v_xp int := 0; v_moedas int := 0; linhas jsonb := '[]'::jsonb; nova boolean := false; passou boolean := p_sucesso;
  streak_antes int; praticou_hoje boolean; perfeita boolean; mat text := p_materia;
  bonus_combo int := 0; bonus_perf int := 0; lic public.licoes; cnt int; titulo text := '';
  ja_trofeu boolean; tem_pendente boolean; lim_cor int := coalesce((param('economia')->>'coracoesErrosDia')::int, 5);
  ev bigint;
  seg_min int := coalesce((ec->>'segundosMinQuestao')::int, 3);
  teto_liga int := coalesce((ec->>'tetoXpLigaDia')::int, 600);
  teto_moedas int := coalesce((ec->>'tetoMoedasDia')::int, 300);
  mx_cor int := coalesce((ec->>'coracoes')::int, 5);
  v_liga int := 0; gap numeric; dia public.dias_aluno; pend int; falta int; resta int;
  respondeu boolean;   -- F2: houve ao menos uma questão respondida?
begin
  if p_modo not in ('licao','pratica','revisao','erros','unidade','relampago','lendaria','pular') then
    raise exception 'Modo inválido: %', p_modo;
  end if;
  -- travas: o cliente não dita números fora do plausível
  p_acertos := least(greatest(coalesce(p_acertos, 0), 0), 60);
  p_erros := least(greatest(coalesce(p_erros, 0), 0), 60);
  p_melhor_combo := least(greatest(coalesce(p_melhor_combo, 0), 0), p_acertos);
  p_tempo_s := least(greatest(coalesce(p_tempo_s, 0), 0), 7200);
  respondeu := (p_acertos + p_erros) > 0;                  -- F2
  perfeita := p_erros = 0 and p_acertos > 0;               -- F2: 0/0 não é lição perfeita
  if not respondeu then passou := false; end if;           -- F2: sem questão, nada de ofensiva nem progresso
  e := regenerar_coracoes(u);
  streak_antes := ofensiva(u);
  praticou_hoje := exists (select 1 from public.ofensiva_dias where user_id = u and dia = hoje());
  if p_licao is not null then
    select * into lic from public.licoes where id = p_licao;
    if found then p_unidade := lic.unidade_id; titulo := lic.titulo; end if;
  end if;
  if mat is null and p_unidade is not null then
    select s.materia_id into mat from public.unidades un join public.secoes s on s.id = un.secao_id where un.id = p_unidade;
  end if;

  if p_modo = 'licao' then
    nova := not exists (select 1 from public.progresso where user_id = u and licao_id = p_licao);
    if nova then
      v_xp :=(ec->>'xpLicao')::int; v_moedas :=(ec->>'moedasLicao')::int;
      insert into public.progresso (user_id, licao_id, coroas) values (u, p_licao, 1);
      linhas := linhas || jsonb_build_object('rotulo', 'Lição concluída', 'valor', '+' || v_xp || ' XP');
    else
      v_xp :=(ec->>'xpPratica')::int; v_moedas :=greatest(1, (ec->>'moedasLicao')::int / 2);
      update public.progresso set coroas = least(5, coroas + 1), concluida_em = now() where user_id = u and licao_id = p_licao;
      linhas := linhas || jsonb_build_object('rotulo', 'Lição praticada', 'valor', '+' || v_xp || ' XP');
    end if;
  elsif p_modo = 'pratica' then
    v_xp :=(ec->>'xpPratica')::int; v_moedas :=greatest(1, (ec->>'moedasLicao')::int / 2);
    linhas := linhas || jsonb_build_object('rotulo', 'Prática', 'valor', '+' || v_xp || ' XP');
  elsif p_modo = 'revisao' then
    v_xp :=(ec->>'xpRevisao')::int; v_moedas :=(ec->>'moedasRevisao')::int;
    linhas := linhas || jsonb_build_object('rotulo', 'Revisão diária', 'valor', '+' || v_xp || ' XP');
    update public.dias_aluno set revisao = true where user_id = u and dia = hoje();
  elsif p_modo = 'erros' then
    v_xp :=(ec->>'xpErros')::int; v_moedas :=5;
    linhas := linhas || jsonb_build_object('rotulo', 'Prática de erros', 'valor', '+' || v_xp || ' XP');
    perform preparar_dia(u);
    select coracoes_erros into cnt from public.dias_aluno where user_id = u and dia = hoje();
    -- F2: o coração de brinde exige ter respondido algo
    if respondeu and not tem_plus(u) and e.coracoes < (ec->>'coracoes')::int and coalesce(cnt, 0) < lim_cor then
      update public.economia_aluno set coracoes = coracoes + 1 where user_id = u;
      update public.dias_aluno set coracoes_erros = coracoes_erros + 1 where user_id = u and dia = hoje();
      linhas := linhas || jsonb_build_object('rotulo', 'Coração recuperado', 'valor', '+1');
    end if;
  elsif p_modo = 'unidade' then
    v_xp :=(ec->>'xpErros')::int; v_moedas :=5;
    linhas := linhas || jsonb_build_object('rotulo', 'Revisão da unidade', 'valor', '+' || v_xp || ' XP');
  elsif p_modo = 'relampago' then
    if e.relampago_em = hoje() then
      v_xp := 0; v_moedas := 0;
      linhas := linhas || jsonb_build_object('rotulo', 'Relâmpago de hoje já feito', 'valor', '0 XP');
    else
      v_xp :=least(p_acertos, 40) * ((ec->>'xpExercicio')::int / 2) * (ec->>'multiplicadorRelampago')::int; v_moedas :=5;
      linhas := linhas || jsonb_build_object('rotulo', p_acertos || ' acertos × ' || (ec->>'multiplicadorRelampago') || '', 'valor', '+' || v_xp || ' XP');
    end if;
    update public.economia_aluno set relampago_em = hoje() where user_id = u;
  elsif p_modo = 'lendaria' then
    if passou then
      ja_trofeu := exists (select 1 from public.conquistas_unidade where user_id = u and unidade_id = p_unidade and trofeu_em is not null);
      if ja_trofeu then
        linhas := linhas || jsonb_build_object('rotulo', 'Troféu já conquistado antes', 'valor', '0 XP');
      else
        v_xp :=(ec->>'xpLendaria')::int; v_moedas :=(ec->>'moedasLendaria')::int;
        linhas := linhas || jsonb_build_object('rotulo', 'Prova sem erros', 'valor', '+' || v_xp || ' XP');
      end if;
      insert into public.conquistas_unidade (user_id, unidade_id, trofeu_em) values (u, p_unidade, now())
        on conflict (user_id, unidade_id) do update set trofeu_em = coalesce(public.conquistas_unidade.trofeu_em, now());
    else
      linhas := linhas || jsonb_build_object('rotulo', 'Um erro encerra a prova', 'valor', '0 XP');
    end if;
  elsif p_modo = 'pular' then
    passou := respondeu and p_acertos >= (ec->>'acertosPular')::int;   -- F2: 0/0 nunca passa no teste de pular
    if passou then
      tem_pendente := exists (select 1 from public.licoes l where l.unidade_id = p_unidade
        and not exists (select 1 from public.progresso pr where pr.user_id = u and pr.licao_id = l.id));
      if tem_pendente then
        v_xp :=(ec->>'xpPular')::int; v_moedas :=(ec->>'moedasPular')::int;
        linhas := linhas || jsonb_build_object('rotulo', 'Teste aprovado (' || p_acertos || '/' || (ec->>'questoesPular') || ')', 'valor', '+' || v_xp || ' XP');
      else
        linhas := linhas || jsonb_build_object('rotulo', 'Unidade já estava concluída', 'valor', '0 XP');
      end if;
      -- marca todas as lições da unidade pulada como concluídas (1 coroa)
      insert into public.progresso (user_id, licao_id, coroas)
        select u, l.id, 1 from public.licoes l where l.unidade_id = p_unidade on conflict do nothing;
      insert into public.conquistas_unidade (user_id, unidade_id, pulada_em) values (u, p_unidade, now())
        on conflict (user_id, unidade_id) do update set pulada_em = now();
    else
      linhas := linhas || jsonb_build_object('rotulo', 'Precisa de ' || (ec->>'acertosPular') || ' acertos', 'valor', '0 XP');
    end if;
  end if;

  -- bônus (só nos modos de lição comum)
  if passou and p_modo in ('licao','pratica','revisao','erros','unidade') then
    if p_melhor_combo >= (ec->>'comboAPartirDe')::int then bonus_combo := (ec->>'bonusCombo')::int; end if;
    if perfeita then bonus_perf := (ec->>'bonusPerfeita')::int; end if;
    v_xp := v_xp + bonus_combo + bonus_perf;
    linhas := linhas || jsonb_build_object('rotulo', 'Bônus de combo (' || p_melhor_combo || ' seguidos)', 'valor', case when bonus_combo > 0 then '+' || bonus_combo || ' XP' else '—' end);
    linhas := linhas || jsonb_build_object('rotulo', 'Bônus de lição perfeita', 'valor', case when bonus_perf > 0 then '+' || bonus_perf || ' XP' else '— (' || p_erros || ' erro' || case when p_erros = 1 then '' else 's' end || ')' end);
  end if;
  -- F2 · Lição sem nenhuma questão respondida não paga nada: era a brecha
  -- que dava XP, ofensiva e missões em chamadas 0/0 repetidas.
  if not respondeu then
    v_xp := 0; v_moedas := 0;
    linhas := jsonb_build_array(jsonb_build_object('rotulo', 'Nenhuma questão respondida', 'valor', '0 XP'));
  end if;
  -- Ritmo mínimo, medido no servidor: desde a última conclusão, ao menos seg_min segundos por questão respondida.
  -- Ninguém lê e responde mais rápido que isso; abaixo, a lição conta como feita mas não dá XP nem moedas.
  -- F2: vale para qualquer chamada. Em 0/0 cobra-se o piso de uma questão,
  -- senão bastava mandar 0/0 em rajada para escapar da trava.
  select extract(epoch from now() - max(criado_em)) into gap from public.eventos_licao where user_id = u;
  if gap is not null and gap < seg_min * greatest(p_acertos + p_erros, 1) then
    v_xp := 0; v_moedas := 0;
    linhas := linhas || jsonb_build_object('rotulo', 'Rápido demais para contar pontos', 'valor', '0 XP');
  end if;
  -- Tetos do dia: o XP do perfil não tem teto; o XP que conta para a liga e as moedas de lição têm.
  dia := preparar_dia(u);
  v_liga := least(v_xp, greatest(0, teto_liga - coalesce(dia.xp_liga, 0)));
  if v_liga < v_xp then
    linhas := linhas || jsonb_build_object('rotulo', 'Liga: máximo de hoje (' || teto_liga || ' XP) já garantido', 'valor', 'XP vai só para o perfil');
  end if;
  resta := greatest(0, teto_moedas - coalesce(dia.moedas_licoes, 0));
  if v_moedas > resta then
    v_moedas := resta;
    linhas := linhas || jsonb_build_object('rotulo', 'Moedas: máximo de hoje atingido', 'valor', case when resta > 0 then '+' || resta else '0' end);
  end if;
  -- Corações no servidor: os erros que o app não descontou (perder_coracao) são descontados aqui.
  if p_modo in ('licao','pratica','revisao','unidade','relampago','lendaria') and not tem_plus(u) then
    select coracoes_pend into pend from public.economia_aluno where user_id = u;
    falta := greatest(0, p_erros - coalesce(pend, 0));
    if falta > 0 then
      update public.economia_aluno set coracoes = greatest(0, coracoes - falta),
        coracoes_em = case when coracoes >= mx_cor then now() else coracoes_em end where user_id = u;
    end if;
  end if;
  update public.economia_aluno set coracoes_pend = 0 where user_id = u;
  if v_moedas > 0 then linhas := linhas || jsonb_build_object('rotulo', 'Moedas ganhas', 'valor', '+' || v_moedas); end if;

  -- grava economia, dia, ofensiva, erros, liga, evento
  update public.economia_aluno set xp = economia_aluno.xp + v_xp, xp_semana = xp_semana + v_liga, xp_mes = xp_mes + v_xp, moedas = economia_aluno.moedas + v_moedas
    where user_id = u;
  perform preparar_dia(u);
  -- F2: licoes/perfeitas e minutos só contam com questão respondida (missões e baú diário)
  update public.dias_aluno set
      xp = dias_aluno.xp + v_xp,
      xp_liga = dias_aluno.xp_liga + v_liga,
      moedas_licoes = dias_aluno.moedas_licoes + v_moedas,
      melhor_combo = greatest(melhor_combo, p_melhor_combo),
      materias = case when respondeu and mat is not null and not (mat = any(materias)) then array_append(materias, mat) else materias end,
      licoes = licoes + case when respondeu and p_modo in ('licao','pratica') then 1 else 0 end,
      perfeitas = perfeitas + case when respondeu and perfeita and passou and p_modo in ('licao','pratica') then 1 else 0 end,
      minutos = minutos + case when respondeu then greatest(0, p_tempo_s / 60) else 0 end
    where user_id = u and dia = hoje();
  if passou then
    insert into public.ofensiva_dias (user_id, dia) values (u, hoje()) on conflict (user_id, dia) do update set tipo = 'praticou';
  end if;
  insert into public.erros (user_id, questao_id) select u, x from unnest(p_erradas) x on conflict (user_id, questao_id) do update set errado_em = now();
  if p_modo = 'erros' then delete from public.erros where user_id = u and questao_id = any(p_acertadas); end if;
  update public.liga_participantes set xp = liga_participantes.xp + v_liga where user_id = u and liga_id = entrar_liga(u);
  insert into public.eventos_licao (user_id, modo, licao_id, unidade_id, acertos, erros, melhor_combo, tempo_s, xp, moedas)
    values (u, p_modo, p_licao, p_unidade, p_acertos, p_erros, p_melhor_combo, p_tempo_s, v_xp, v_moedas)
    returning id into ev;

  -- tentativa por questão: valida cada item e ignora o que não fizer sentido
  -- F2: sem questão respondida não há tentativa para gravar (o motor de
  -- domínio e a revisão espaçada leem desta tabela)
  if respondeu and p_tentativas is not null and jsonb_typeof(p_tentativas) = 'array' then
    insert into public.tentativas (user_id, evento_id, questao_id, licao_id, unidade_id, materia_id, modo, correta, tentativa, tempo_s, resposta)
    select u, ev, t.q, p_licao, p_unidade, mat, p_modo, t.ok,
           least(greatest(coalesce(t.n, 1), 1), 20),
           least(greatest(coalesce(t.t, 0), 0), 600),
           left(t.r, 200)
    from jsonb_to_recordset(p_tentativas) as t(q uuid, ok boolean, t int, n int, r text)
    where t.q is not null and t.ok is not null
      and exists (select 1 from public.questoes qq where qq.id = t.q)
    limit 100;
  end if;

  return jsonb_build_object(
    'xp', v_xp, 'xpLiga', v_liga, 'moedas', v_moedas, 'linhas', linhas, 'passou', passou, 'nova', nova, 'titulo', titulo,
    'precisao', case when p_acertos + p_erros = 0 then 100 else round(100.0 * p_acertos / (p_acertos + p_erros)) end,
    'ofensivaSubiu', passou and not praticou_hoje, 'ofensiva', ofensiva(u), 'ofensivaAntes', streak_antes,
    'estado', estado_aluno()
  );
end $$;
grant execute on function public.concluir_licao(text, uuid, uuid, text, int, int, int, int, uuid[], uuid[], boolean, jsonb) to authenticated;

-- ---------- F4 · id opaco na dinâmica ----------
-- Igual à estado_dinamica da 0032, com uma mudança: o id de questaoPub
-- vira md5(dinâmica:índice), como já é no duelo (0057).
create or replace function public.estado_dinamica(p_dinamica uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := exigir_login(); d public.dinamicas; prof boolean; gq jsonb; certa jsonb;
  meu_grupo uuid; r public.dinamica_respostas; quem text; fim timestamptz;
begin
  select * into d from public.dinamicas where id = p_dinamica;
  if not found then raise exception 'Dinâmica não encontrada.'; end if;
  prof := is_admin() or professor_da_turma(d.turma_id);
  if not prof and not aluno_da_turma(d.turma_id) then raise exception 'Você não está na turma desta dinâmica.' using errcode = '42501'; end if;
  if not prof and d.status <> 'fim' then
    insert into public.dinamica_membros (dinamica_id, user_id) values (d.id, u)
      on conflict (dinamica_id, user_id) do update set visto_em = now();
  end if;
  select grupo_id into meu_grupo from public.dinamica_membros where dinamica_id = d.id and user_id = u;
  if d.origem = 'questoes' and d.questao >= 0 and d.status in ('pergunta', 'revelada') then
    gq := d.questoes->d.questao;
    if d.modo = 'grupos' and meu_grupo is not null then
      select * into r from public.dinamica_respostas where dinamica_id = d.id and questao = d.questao and grupo_id = meu_grupo;
    else
      select * into r from public.dinamica_respostas where dinamica_id = d.id and questao = d.questao and user_id = u;
    end if;
    if r.user_id is not null and r.user_id <> u then select nome into quem from public.perfis where user_id = r.user_id; end if;
    if d.status = 'revelada' then
      certa := case gq->>'tipo'
        when 'mc' then gq->'dados'->'opts'->((gq->'dados'->>'a')::int)
        when 'tf' then gq->'dados'->'a'
        when 'bank' then gq->'dados'->'a'
        when 'order' then gq->'dados'->'items'
        when 'match' then gq->'dados'->'pairs'
        else null end;
    end if;
  end if;
  if d.tempo_questao > 0 and d.questao_iniciada_em is not null then fim := d.questao_iniciada_em + make_interval(secs => d.tempo_questao); end if;
  return jsonb_build_object(
    'id', d.id, 'titulo', d.titulo, 'modo', d.modo, 'origem', d.origem, 'status', d.status,
    'questao', d.questao, 'total', jsonb_array_length(d.publicas), 'tempo', d.tempo_questao,
    'agora', now(), 'fimEm', fim,
    'turma', (select nome from public.turmas where id = d.turma_id),
    'grupo', case when meu_grupo is not null then (select jsonb_build_object('id', g.id, 'nome', g.nome,
        'colegas', (select coalesce(jsonb_agg(p.nome order by p.nome), '[]'::jsonb) from public.dinamica_membros m join public.perfis p on p.user_id = m.user_id where m.dinamica_id = d.id and m.grupo_id = g.id and m.user_id <> u))
      from public.dinamica_grupos g where g.id = meu_grupo) end,
    'temGrupos', exists (select 1 from public.dinamica_grupos g where g.dinamica_id = d.id),
    -- F4: id opaco — o aluno não consegue cruzar com o pacote publicado.
    -- responder_dinamica recebe o índice, não o id, então nada mais muda.
    'questaoPub', case when d.status in ('pergunta', 'revelada')
      then (d.publicas->d.questao) || jsonb_build_object('id', md5(d.id::text || ':' || d.questao::text)) end,
    'respondi', r.user_id is not null,
    'respondeuPor', quem,
    'minhaResposta', case when d.status = 'revelada' then r.resposta end,
    'acertei', case when d.status = 'revelada' and r.user_id is not null then r.acertou end,
    'certa', certa,
    'explicacao', case when d.status = 'revelada' then gq->>'explicacao' end,
    'ranking', case when d.status = 'fim' or d.status = 'revelada' or d.origem = 'manual' then fj_ranking_dinamica(d.id, u) end
  );
end $$;
grant execute on function public.estado_dinamica(uuid) to authenticated;

insert into public.schema_versao (versao) values (61) on conflict do nothing;
