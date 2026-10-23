-- =====================================================================
-- Findout Jornada · Migration 0060 · criar_dinamica valida as questões
-- copiadas da atividade
-- Rodar no SQL Editor depois da 0059. Idempotente.
--
-- A 0053 validava o whitelist de `tipo` (mc/tf/bank/order/match) só no
-- caminho p_questoes. No caminho "copiar de atividade" fazia
--   gab := a.questoes;
-- sem validar nada, e depois copiava `tipo` verbatim para `publicas`.
-- Como atividades.questoes é jsonb livre gravado pelo professor, o
-- `tipo` chegava ao telão com qualquer conteúdo — inclusive HTML, que o
-- painel interpolava sem escapar (corrigido junto, no painel).
-- Caminho: professor → telão de quem conduz a dinâmica (que pode ser o
-- super usuário, com definir_admin e excluir_usuario).
--
-- Aqui a mesma validação do caminho p_questoes passa a valer para os
-- dois: a lista é conferida depois de escolhida a origem, nunca antes.
-- Nada mais muda — mesma assinatura, mesma permissão, mesmo embaralho.
-- =====================================================================

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
      gab := p_questoes;
    else
      if p_atividade is null then raise exception 'Escolha a atividade ou monte a lista de questões.'; end if;
      select * into a from public.atividades where id = p_atividade;
      if not found or not (is_admin() or professor_da_turma(a.turma_id)) then raise exception 'Atividade não encontrada.'; end if;
      if jsonb_array_length(a.questoes) = 0 then raise exception 'Esta atividade não tem questões.'; end if;
      if jsonb_array_length(a.questoes) > 200 then raise exception 'No máximo 200 questões.'; end if;
      gab := a.questoes; usa_ativ := true;
    end if;
    -- o whitelist vale para as duas origens: nenhum `tipo` fora da lista
    -- chega a `publicas`, de onde o telão lê
    for q in select * from jsonb_array_elements(gab) loop
      if coalesce(q->>'id', '') = '' or coalesce(q->>'tipo', '') not in ('mc', 'tf', 'bank', 'order', 'match')
         or coalesce(q->>'enunciado', '') = '' or jsonb_typeof(q->'dados') <> 'object' then
        raise exception 'Questão inválida na lista.';
      end if;
    end loop;
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

insert into public.schema_versao (versao) values (60) on conflict do nothing;
