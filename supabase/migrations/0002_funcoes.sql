-- =====================================================================
-- Findout Jornada · Migration 0002 · Funções de jogo
-- O app chama estas funções via supabase.rpc(). Elas rodam como
-- "security definer": o aluno não escreve nas tabelas diretamente.
-- Idempotente: pode rodar de novo.
-- =====================================================================

-- ---------------------------------------------------------------
-- Auxiliares
-- ---------------------------------------------------------------
create or replace function public.hoje()
returns date language sql stable as $$
  select (now() at time zone 'America/Sao_Paulo')::date;
$$;

create or replace function public.param(p_chave text)
returns jsonb language sql stable security definer set search_path = public as $$
  select valor from public.parametros where chave = p_chave;
$$;

create or replace function public.tem_plus(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select findout_plus_ate > now() from public.perfis where user_id = p_user), false);
$$;

create or replace function public.exigir_login()
returns uuid language plpgsql stable as $$
begin
  if auth.uid() is null then raise exception 'Faça login para continuar.' using errcode = '42501'; end if;
  return auth.uid();
end $$;

-- Recarrega corações pelo tempo passado (1 a cada N horas) e devolve a linha atualizada
create or replace function public.regenerar_coracoes(p_user uuid)
returns public.economia_aluno language plpgsql security definer set search_path = public as $$
declare e public.economia_aluno; mx int; hrs numeric; ganhos int;
begin
  select * into e from public.economia_aluno where user_id = p_user for update;
  mx := coalesce((param('economia')->>'coracoes')::int, 5);
  hrs := coalesce((param('economia')->>'horasCoracao')::numeric, 5);
  if e.coracoes >= mx then
    update public.economia_aluno set coracoes_em = now() where user_id = p_user returning * into e;
    return e;
  end if;
  ganhos := floor(extract(epoch from (now() - e.coracoes_em)) / (hrs * 3600))::int;
  if ganhos > 0 then
    update public.economia_aluno
      set coracoes = least(mx, coracoes + ganhos),
          coracoes_em = case when coracoes + ganhos >= mx then now() else coracoes_em + (ganhos * hrs * interval '1 hour') end
      where user_id = p_user returning * into e;
  end if;
  -- virada de mês zera o XP mensal
  if e.mes_ref <> to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM') then
    update public.economia_aluno set xp_mes = 0, mes_ref = to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM')
      where user_id = p_user returning * into e;
  end if;
  return e;
end $$;

-- Dias seguidos de ofensiva (conta hoje se praticou; senão conta a partir de ontem)
create or replace function public.ofensiva(p_user uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare d date := hoje(); n int := 0;
begin
  if not exists (select 1 from public.ofensiva_dias where user_id = p_user and dia = d) then d := d - 1; end if;
  while exists (select 1 from public.ofensiva_dias where user_id = p_user and dia = d) loop
    n := n + 1; d := d - 1;
  end loop;
  return n;
end $$;

-- Garante a linha do dia com as missões sorteadas; usa congelador se ontem ficou sem praticar
create or replace function public.preparar_dia(p_user uuid)
returns public.dias_aluno language plpgsql security definer set search_path = public as $$
declare d public.dias_aluno; n int; sorteio uuid[]; ontem date := hoje() - 1; anteontem date := hoje() - 2; cong int;
begin
  select * into d from public.dias_aluno where user_id = p_user and dia = hoje();
  if not found then
    n := coalesce((param('missoes')->>'porDia')::int, 3);
    select coalesce(array_agg(id), '{}') into sorteio from (select id from public.missoes where ativa order by random() limit n) s;
    insert into public.dias_aluno (user_id, dia, missoes) values (p_user, hoje(), sorteio) returning * into d;
  end if;
  -- congelador: ontem sem praticar, anteontem com chama acesa
  if not exists (select 1 from public.ofensiva_dias where user_id = p_user and dia = ontem)
     and exists (select 1 from public.ofensiva_dias where user_id = p_user and dia = anteontem) then
    select congeladores into cong from public.economia_aluno where user_id = p_user;
    if cong > 0 then
      insert into public.ofensiva_dias (user_id, dia, tipo) values (p_user, ontem, 'congelado') on conflict do nothing;
      update public.economia_aluno set congeladores = congeladores - 1 where user_id = p_user;
    end if;
  end if;
  return d;
end $$;

-- Missões do dia com progresso calculado
create or replace function public.missoes_do_dia(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  with d as (select * from public.dias_aluno where user_id = p_user and dia = hoje())
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id, 'texto', m.texto, 'tipo', m.tipo, 'meta', m.meta,
    'progresso', least(m.meta, case m.tipo
        when 'xp' then d.xp when 'combo' then d.melhor_combo when 'materias' then cardinality(d.materias)
        when 'licoes' then d.licoes when 'perfeita' then d.perfeitas when 'revisao' then d.revisao::int
        when 'minutos' then d.minutos else 0 end),
    'concluida', (case m.tipo
        when 'xp' then d.xp when 'combo' then d.melhor_combo when 'materias' then cardinality(d.materias)
        when 'licoes' then d.licoes when 'perfeita' then d.perfeitas when 'revisao' then d.revisao::int
        when 'minutos' then d.minutos else 0 end) >= m.meta
  ) order by array_position(d.missoes, m.id)), '[]'::jsonb)
  from d join public.missoes m on m.id = any(d.missoes);
$$;

-- ---------------------------------------------------------------
-- Ligas: coloca o aluno na liga da semana atual (cria se precisar)
-- ---------------------------------------------------------------
create or replace function public.semana_atual()
returns date language sql stable as $$ select date_trunc('week', hoje())::date; $$;

create or replace function public.entrar_liga(p_user uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare lid uuid; nivel_aluno int := 0; tam int; ult record;
begin
  select l.id into lid from public.liga_participantes p join public.ligas l on l.id = p.liga_id
    where p.user_id = p_user and l.semana = semana_atual() limit 1;
  if lid is not null then return lid; end if;
  -- nível: resultado da última semana
  select l.nivel, p.resultado into ult from public.liga_participantes p join public.ligas l on l.id = p.liga_id
    where p.user_id = p_user order by l.semana desc limit 1;
  if found then
    nivel_aluno := case ult.resultado when 'subiu' then ult.nivel + 1 when 'caiu' then greatest(0, ult.nivel - 1) else ult.nivel end;
  end if;
  tam := coalesce((param('ligas')->>'tamanho')::int, 15);
  select l.id into lid from public.ligas l
    where l.semana = semana_atual() and l.nivel = nivel_aluno
      and (select count(*) from public.liga_participantes p where p.liga_id = l.id) < tam
    order by l.criada_em limit 1;
  if lid is null then
    insert into public.ligas (semana, nivel) values (semana_atual(), nivel_aluno) returning id into lid;
  end if;
  insert into public.liga_participantes (liga_id, user_id) values (lid, p_user) on conflict do nothing;
  return lid;
end $$;

-- ---------------------------------------------------------------
-- estado_aluno(): tudo que o app precisa ao abrir, em uma chamada
-- ---------------------------------------------------------------
create or replace function public.estado_aluno()
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); e public.economia_aluno; d public.dias_aluno; lid uuid; pf public.perfis; mx int; hrs numeric;
begin
  e := regenerar_coracoes(u);
  d := preparar_dia(u);
  lid := entrar_liga(u);
  update public.perfis set visto_em = now() where user_id = u returning * into pf;
  mx := coalesce((param('economia')->>'coracoes')::int, 5);
  hrs := coalesce((param('economia')->>'horasCoracao')::numeric, 5);
  return jsonb_build_object(
    'perfil', jsonb_build_object('nome', pf.nome, 'avatar', pf.avatar, 'materia', pf.materia_atual, 'plus', tem_plus(u), 'plusAte', pf.findout_plus_ate, 'admin', is_admin()),
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
    'versaoConteudo', (select max(versao) from public.publicacoes)
  );
end $$;

-- ---------------------------------------------------------------
-- perder_coracao(): chamado a cada erro em lição que custa coração
-- ---------------------------------------------------------------
create or replace function public.perder_coracao()
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); e public.economia_aluno; mx int;
begin
  if tem_plus(u) then return jsonb_build_object('coracoes', null, 'plus', true); end if;
  e := regenerar_coracoes(u);
  mx := coalesce((param('economia')->>'coracoes')::int, 5);
  if e.coracoes > 0 then
    update public.economia_aluno
      set coracoes = coracoes - 1, coracoes_em = case when coracoes = mx then now() else coracoes_em end
      where user_id = u returning * into e;
  end if;
  return jsonb_build_object('coracoes', e.coracoes, 'plus', false);
end $$;

-- ---------------------------------------------------------------
-- concluir_licao(): aplica XP, moedas, coroas, ofensiva, missões, erros
-- modos: licao | pratica | revisao | erros | unidade | relampago | lendaria | pular
-- ---------------------------------------------------------------
create or replace function public.concluir_licao(
  p_modo text, p_licao uuid default null, p_unidade uuid default null, p_materia text default null,
  p_acertos int default 0, p_erros int default 0, p_melhor_combo int default 0, p_tempo_s int default 0,
  p_erradas uuid[] default '{}', p_acertadas uuid[] default '{}', p_sucesso boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := exigir_login(); ec jsonb := param('economia'); e public.economia_aluno;
  v_xp int := 0; v_moedas int := 0; linhas jsonb := '[]'::jsonb; nova boolean := false; passou boolean := p_sucesso;
  streak_antes int; praticou_hoje boolean; perfeita boolean := p_erros = 0; mat text := p_materia;
  bonus_combo int := 0; bonus_perf int := 0; lic public.licoes; cnt int; feitas int; titulo text := '';
begin
  if p_modo not in ('licao','pratica','revisao','erros','unidade','relampago','lendaria','pular') then
    raise exception 'Modo inválido: %', p_modo;
  end if;
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
    if not tem_plus(u) and e.coracoes < (ec->>'coracoes')::int then
      update public.economia_aluno set coracoes = coracoes + 1 where user_id = u;
      linhas := linhas || jsonb_build_object('rotulo', 'Coração recuperado', 'valor', '+1');
    end if;
  elsif p_modo = 'unidade' then
    v_xp :=(ec->>'xpErros')::int; v_moedas :=5;
    linhas := linhas || jsonb_build_object('rotulo', 'Revisão da unidade', 'valor', '+' || v_xp || ' XP');
  elsif p_modo = 'relampago' then
    v_xp :=p_acertos * ((ec->>'xpExercicio')::int / 2) * (ec->>'multiplicadorRelampago')::int; v_moedas :=5;
    linhas := linhas || jsonb_build_object('rotulo', p_acertos || ' acertos × ' || (ec->>'multiplicadorRelampago') || '', 'valor', '+' || v_xp || ' XP');
    update public.economia_aluno set relampago_em = hoje() where user_id = u;
  elsif p_modo = 'lendaria' then
    if passou then
      v_xp :=(ec->>'xpLendaria')::int; v_moedas :=(ec->>'moedasLendaria')::int;
      insert into public.conquistas_unidade (user_id, unidade_id, trofeu_em) values (u, p_unidade, now())
        on conflict (user_id, unidade_id) do update set trofeu_em = coalesce(public.conquistas_unidade.trofeu_em, now());
      linhas := linhas || jsonb_build_object('rotulo', 'Prova sem erros', 'valor', '+' || v_xp || ' XP');
    else
      linhas := linhas || jsonb_build_object('rotulo', 'Um erro encerra a prova', 'valor', '0 XP');
    end if;
  elsif p_modo = 'pular' then
    passou := p_acertos >= (ec->>'acertosPular')::int;
    if passou then
      v_xp :=(ec->>'xpPular')::int; v_moedas :=(ec->>'moedasPular')::int;
      -- marca todas as lições da unidade pulada como concluídas (1 coroa)
      insert into public.progresso (user_id, licao_id, coroas)
        select u, l.id, 1 from public.licoes l where l.unidade_id = p_unidade on conflict do nothing;
      insert into public.conquistas_unidade (user_id, unidade_id, pulada_em) values (u, p_unidade, now())
        on conflict (user_id, unidade_id) do update set pulada_em = now();
      linhas := linhas || jsonb_build_object('rotulo', 'Teste aprovado (' || p_acertos || '/' || (ec->>'questoesPular') || ')', 'valor', '+' || v_xp || ' XP');
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
  if v_moedas > 0 then linhas := linhas || jsonb_build_object('rotulo', 'Moedas ganhas', 'valor', '+' || v_moedas); end if;

  -- grava economia, dia, ofensiva, erros, liga, evento
  update public.economia_aluno set xp = economia_aluno.xp + v_xp, xp_semana = xp_semana + v_xp, xp_mes = xp_mes + v_xp, moedas = economia_aluno.moedas + v_moedas
    where user_id = u;
  perform preparar_dia(u);
  update public.dias_aluno set
      xp = dias_aluno.xp + v_xp,
      melhor_combo = greatest(melhor_combo, p_melhor_combo),
      materias = case when mat is not null and not (mat = any(materias)) then array_append(materias, mat) else materias end,
      licoes = licoes + case when p_modo in ('licao','pratica') then 1 else 0 end,
      perfeitas = perfeitas + case when perfeita and passou and p_modo in ('licao','pratica') then 1 else 0 end,
      minutos = minutos + greatest(0, p_tempo_s / 60)
    where user_id = u and dia = hoje();
  if passou then
    insert into public.ofensiva_dias (user_id, dia) values (u, hoje()) on conflict (user_id, dia) do update set tipo = 'praticou';
  end if;
  insert into public.erros (user_id, questao_id) select u, x from unnest(p_erradas) x on conflict (user_id, questao_id) do update set errado_em = now();
  if p_modo = 'erros' then delete from public.erros where user_id = u and questao_id = any(p_acertadas); end if;
  update public.liga_participantes set xp = liga_participantes.xp + v_xp where user_id = u and liga_id = entrar_liga(u);
  insert into public.eventos_licao (user_id, modo, licao_id, unidade_id, acertos, erros, melhor_combo, tempo_s, xp, moedas)
    values (u, p_modo, p_licao, p_unidade, p_acertos, p_erros, p_melhor_combo, p_tempo_s, v_xp, v_moedas);

  return jsonb_build_object(
    'xp', v_xp, 'moedas', v_moedas, 'linhas', linhas, 'passou', passou, 'nova', nova, 'titulo', titulo,
    'precisao', case when p_acertos + p_erros = 0 then 100 else round(100.0 * p_acertos / (p_acertos + p_erros)) end,
    'ofensivaSubiu', passou and not praticou_hoje, 'ofensiva', ofensiva(u), 'ofensivaAntes', streak_antes,
    'estado', estado_aluno()
  );
end $$;

-- ---------------------------------------------------------------
-- Baús e loja
-- ---------------------------------------------------------------
-- Baú da unidade: libera depois da lição 4 (unidades com 5+ lições) ou da penúltima
create or replace function public.abrir_bau(p_unidade uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); total int; feitas int; precisa int; v_moedas int := (param('economia')->>'moedasBau')::int;
begin
  if exists (select 1 from public.conquistas_unidade where user_id = u and unidade_id = p_unidade and bau_em is not null) then
    raise exception 'Este baú já foi aberto.';
  end if;
  select count(*) into total from public.licoes where unidade_id = p_unidade;
  precisa := case when total >= 5 then 4 else greatest(1, total - 1) end;
  select count(*) into feitas from public.progresso p join public.licoes l on l.id = p.licao_id
    where p.user_id = u and l.unidade_id = p_unidade
      and l.ordem <= (select l2.ordem from public.licoes l2 where l2.unidade_id = p_unidade order by l2.ordem offset precisa - 1 limit 1);
  if feitas < precisa then raise exception 'Conclua a lição % para abrir o baú.', precisa; end if;
  insert into public.conquistas_unidade (user_id, unidade_id, bau_em) values (u, p_unidade, now())
    on conflict (user_id, unidade_id) do update set bau_em = now();
  update public.economia_aluno set moedas = economia_aluno.moedas + v_moedas where user_id = u;
  return jsonb_build_object('moedas', v_moedas, 'estado', estado_aluno());
end $$;

create or replace function public.abrir_bau_diario()
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); d public.dias_aluno; ms jsonb; v_moedas int := (param('missoes')->>'moedasBauDiario')::int;
begin
  d := preparar_dia(u);
  if d.bau_aberto then raise exception 'O baú de hoje já foi aberto.'; end if;
  ms := missoes_do_dia(u);
  if jsonb_array_length(ms) = 0 or exists (select 1 from jsonb_array_elements(ms) m where not (m->>'concluida')::boolean) then
    raise exception 'Complete todas as missões de hoje primeiro.';
  end if;
  update public.dias_aluno set bau_aberto = true where user_id = u and dia = hoje();
  update public.economia_aluno set moedas = economia_aluno.moedas + v_moedas where user_id = u;
  return jsonb_build_object('moedas', v_moedas, 'estado', estado_aluno());
end $$;

create or replace function public.comprar(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); it public.itens_loja; e public.economia_aluno; ec jsonb := param('economia');
begin
  select * into it from public.itens_loja where codigo = p_codigo and ativo;
  if not found then raise exception 'Item indisponível.'; end if;
  if it.tipo <> 'moedas' then raise exception 'Este item não é comprado com moedas.'; end if;
  e := regenerar_coracoes(u);
  if e.moedas < it.preco then raise exception 'Moedas insuficientes.'; end if;
  if p_codigo = 'congelador' then
    if e.congeladores >= (ec->>'maxCongeladores')::int then raise exception 'Você já tem o máximo de congeladores.'; end if;
    update public.economia_aluno set moedas = moedas - it.preco, congeladores = congeladores + 1 where user_id = u;
  elsif p_codigo = 'recarga' then
    if tem_plus(u) or e.coracoes >= (ec->>'coracoes')::int then raise exception 'Seus corações já estão cheios.'; end if;
    update public.economia_aluno set moedas = moedas - it.preco, coracoes = (ec->>'coracoes')::int, coracoes_em = now() where user_id = u;
  else
    raise exception 'Item sem efeito definido: %', p_codigo;
  end if;
  return jsonb_build_object('item', it.codigo, 'estado', estado_aluno());
end $$;

-- Admin: ativa Findout+ por N dias (ou remove com 0)
create or replace function public.ativar_plus(p_user uuid, p_dias int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  update public.perfis set findout_plus_ate = case when p_dias <= 0 then null else now() + (p_dias * interval '1 day') end where user_id = p_user;
end $$;

-- Permissões de execução
grant execute on function public.estado_aluno(), public.perder_coracao(), public.abrir_bau(uuid), public.abrir_bau_diario(), public.comprar(text), public.ativar_plus(uuid, int) to authenticated;
grant execute on function public.concluir_licao(text, uuid, uuid, text, int, int, int, int, uuid[], uuid[], boolean) to authenticated;
revoke execute on function public.regenerar_coracoes(uuid), public.preparar_dia(uuid), public.entrar_liga(uuid) from public, anon, authenticated;
