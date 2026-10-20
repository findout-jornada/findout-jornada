-- =====================================================================
-- Findout Jornada · Migration 0025 · Recorrigir atualiza as questões do banco
-- Rodar no SQL Editor depois da 0024. Idempotente.
--
--  · recorrigir_atividade() agora, antes de corrigir, atualiza as questões
--    da atividade que vieram do banco com a versão atual delas (enunciado,
--    alternativas, gabarito, explicação, imagem). Fluxo para consertar um
--    gabarito errado: corrige a questão na aba Questões → Recorrigir.
--    O valor de cada questão na atividade e as questões próprias do
--    professor ficam como estão; notas manuais e XP pago não mudam.
--  · Respostas antigas de múltipla escolha guardadas por índice são
--    convertidas para o texto da alternativa (pela cópia antiga) antes da
--    recorreção, então mudar a ordem das alternativas não prejudica ninguém.
-- =====================================================================

create or replace function public.recorrigir_atividade(p_atividade uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := exigir_login(); a public.atividades; e record; c jsonb; q jsonb; r jsonb; sel jsonb; b public.questoes;
  antigas jsonb; novas jsonb := '[]'::jsonb; resp jsonb;
  n int := 0; mud int := 0; atualizadas int := 0;
begin
  select * into a from public.atividades where id = p_atividade;
  if not found then raise exception 'Atividade não encontrada.'; end if;
  if not acesso_atividade(a.turma_id, a.materia_id, a.professor_id) then raise exception 'Sem permissão nesta atividade.' using errcode = '42501'; end if;
  antigas := a.questoes;

  -- 1) atualiza as cópias que vieram do banco com a versão atual da questão
  --    (o valor definido na atividade é mantido; questão própria fica como está)
  for q in select * from jsonb_array_elements(antigas) loop
    if (q->>'id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      select * into b from public.questoes where id = (q->>'id')::uuid;
      if found then
        atualizadas := atualizadas + 1;
        q := q || jsonb_build_object('tipo', b.tipo, 'enunciado', b.enunciado, 'dados', b.dados,
          'explicacao', coalesce(b.explicacao, ''), 'imagem', b.imagem_url, 'materia', b.materia_id, 'origem', 'banco');
      end if;
    end if;
    novas := novas || q;
  end loop;
  update public.atividades set questoes = novas, atualizada_em = now() where id = a.id;

  -- 2) recorrige cada entrega com o gabarito novo
  for e in select * from public.atividade_entregas where atividade_id = a.id and entregue_em is not null and not nota_manual for update loop
    resp := '[]'::jsonb;
    for r in select * from jsonb_array_elements(e.respostas) loop
      -- resposta antiga de múltipla escolha por índice: vira o texto da
      -- alternativa na cópia antiga (sobrevive a qualquer reordenação)
      if jsonb_typeof(r->'resposta') = 'number' then
        sel := (select aq->'dados'->'opts'->((r->>'resposta')::int) from jsonb_array_elements(antigas) aq
                where aq->>'id' = r->>'id' and aq->>'tipo' = 'mc' limit 1);
        if sel is not null then r := r || jsonb_build_object('resposta', sel); end if;
      end if;
      resp := resp || r;
    end loop;
    c := fj_corrige_respostas(novas, resp);
    n := n + 1;
    if (c->>'nota')::numeric is distinct from e.nota then mud := mud + 1; end if;
    update public.atividade_entregas
      set respostas = c->'corrigidas', acertos = (c->>'acertos')::int, total = (c->>'total')::int,
          pontos = (c->>'pontos')::numeric, pontos_total = (c->>'pontosTotal')::numeric, nota = (c->>'nota')::numeric
      where atividade_id = e.atividade_id and user_id = e.user_id;
  end loop;

  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', 'recorrecao', 'resultados', a.id::text, left('Recorrigiu as entregas de ' || a.titulo, 200),
            jsonb_build_object('entregas', n, 'mudaramDeNota', mud, 'questoesAtualizadas', atualizadas));
  return jsonb_build_object('entregas', n, 'mudaram', mud, 'atualizadas', atualizadas);
end $$;

insert into public.schema_versao (versao) values (25) on conflict do nothing;
