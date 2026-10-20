-- =====================================================================
-- Findout Jornada · Migration 0021 · Publicação montada no servidor
-- Rodar no SQL Editor depois da 0020. Idempotente.
--
--  · publicar_pacote(p_nota): monta o pacote direto do banco (a fonte da
--    verdade) e só grava versão nova se o conteúdo mudou. O painel passa a
--    chamar esta função em vez de montar o pacote na memória do navegador:
--    acaba o risco de dois admins publicarem estados velhos um por cima do
--    outro e de uma escrita que falhou no banco ir ao ar mesmo assim.
--  · Excluir a conta de um professor não apaga mais as atividades dele nem
--    as notas dos alunos (professor_id vira null). Excluir um admin que já
--    publicou não trava mais (criada_por vira null).
-- =====================================================================

-- ---------------------------------------------------------------
-- Pacote montado no banco, no mesmo formato que o app já lê
-- ---------------------------------------------------------------
create or replace function public.publicar_pacote(p_nota text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare novo jsonb; ultimo jsonb; ult_versao int; v record;
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  novo := jsonb_build_object(
    'materias', coalesce((
      select jsonb_agg(jsonb_build_object('id', m.id, 'nome', m.nome, 'sigla', m.sigla, 'cor', m.cor,
        'secoes', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'titulo', s.titulo,
          'unidades', coalesce((select jsonb_agg(jsonb_build_object('id', un.id, 'titulo', un.titulo,
            'licoes', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'titulo', l.titulo, 'descricao', coalesce(l.descricao, ''),
              'questoes', coalesce((select jsonb_agg(to_jsonb(lq.questao_id) order by lq.ordem, lq.questao_id)
                 from public.licao_questoes lq join public.questoes q on q.id = lq.questao_id and q.status = 'publicada'
                 where lq.licao_id = l.id), '[]'::jsonb))
              order by l.ordem, l.titulo) from public.licoes l where l.unidade_id = un.id), '[]'::jsonb))
            order by un.ordem, un.titulo) from public.unidades un where un.secao_id = s.id), '[]'::jsonb))
          order by s.ordem, s.titulo) from public.secoes s where s.materia_id = m.id), '[]'::jsonb))
        order by m.ordem, m.nome) from public.materias m where m.ativa), '[]'::jsonb),
    'questoes', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'materia', q.materia_id, 'unidade', q.unidade_id,
        'tipo', q.tipo, 'enunciado', q.enunciado, 'imagem', q.imagem_url, 'dados', q.dados, 'explicacao', q.explicacao)
        order by q.criada_em desc, q.id) from public.questoes q where q.status = 'publicada'), '[]'::jsonb),
    'missoes', coalesce(param('missoes'), '{}'::jsonb) || jsonb_build_object('diarias',
      coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'texto', x.texto, 'tipo', x.tipo, 'meta', x.meta) order by x.ordem, x.texto)
        from public.missoes x where x.ativa), '[]'::jsonb)),
    'economia', coalesce(param('economia'), '{}'::jsonb),
    'ligas', coalesce(param('ligas'), '{}'::jsonb),
    'loja', coalesce((select jsonb_agg(jsonb_build_object('codigo', i.codigo, 'nome', i.nome, 'tipo', i.tipo, 'preco', i.preco, 'rotulo', i.rotulo_preco) order by i.ordem, i.nome)
      from public.itens_loja i where i.ativo), '[]'::jsonb)
  );
  select versao, pacote into ult_versao, ultimo from public.publicacoes order by versao desc limit 1;
  if ultimo is not null and (ultimo - 'geradoEm' - 'versao') = novo then
    return jsonb_build_object('versao', ult_versao, 'semMudanca', true);
  end if;
  insert into public.publicacoes (pacote, nota, criada_por)
    values (novo || jsonb_build_object('geradoEm', now()), left(coalesce(nullif(trim(p_nota), ''), 'Publicado pelo painel'), 200), auth.uid())
    returning versao, nota, criada_em into v;
  return jsonb_build_object('versao', v.versao, 'nota', v.nota, 'criada_em', v.criada_em);
end $$;

-- ---------------------------------------------------------------
-- Apagar contas não destrói dados dos alunos nem trava
-- ---------------------------------------------------------------
alter table public.atividades alter column professor_id drop not null;
alter table public.atividades drop constraint if exists atividades_professor_id_fkey;
alter table public.atividades add constraint atividades_professor_id_fkey
  foreign key (professor_id) references auth.users(id) on delete set null;
alter table public.publicacoes drop constraint if exists publicacoes_criada_por_fkey;
alter table public.publicacoes add constraint publicacoes_criada_por_fkey
  foreign key (criada_por) references auth.users(id) on delete set null;
