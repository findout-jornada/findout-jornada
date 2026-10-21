-- =====================================================================
-- Findout Jornada · Migration 0039 · Embaralha o gabarito das matérias novas
-- Rodar no SQL Editor depois da 0038. Pode rodar de novo (reembaralha).
--
-- Validação completa do banco de questões (1.900 questões, 383 lições):
-- nenhum erro de estrutura ou de correção. Único ajuste: as matérias
-- criadas DEPOIS da migration 0019 (Ética e Cidadania, Arte e Ciências)
-- entraram com a resposta certa quase sempre na alternativa A no banco.
-- O app e as atividades sempre embaralham antes de mostrar, então nenhum
-- aluno vê esse viés — mas, por segurança e consistência com a 0019,
-- as alternativas gravadas dessas matérias são embaralhadas aqui.
-- (Literatura e Conhecimentos Gerais já nasceram variadas; as demais
-- foram embaralhadas pela própria 0019.)
-- =====================================================================

alter table public.questoes disable trigger auditoria_questoes;
do $$
declare q record; n int; perm int[]; novo jsonb; na int;
begin
  for q in select id, dados from public.questoes where tipo = 'mc' and materia_id in ('eti', 'art', 'cie') loop
    n := coalesce(jsonb_array_length(q.dados->'opts'), 0);
    if n < 2 then continue; end if;
    select array_agg(i order by random()) into perm from generate_series(0, n - 1) i;
    select jsonb_agg(q.dados->'opts'->perm[i] order by i) into novo from generate_series(1, n) i;
    na := coalesce(array_position(perm, coalesce((q.dados->>'a')::int, 0)), 1) - 1;
    update public.questoes set dados = dados || jsonb_build_object('opts', novo, 'a', na) where id = q.id;
  end loop;
end $$;
alter table public.questoes enable trigger auditoria_questoes;

insert into public.schema_versao (versao) values (39) on conflict do nothing;
