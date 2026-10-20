-- =====================================================================
-- Findout Jornada · Migration 0022 · Hora do servidor e versão do esquema
-- Rodar no SQL Editor depois da 0021. Idempotente.
--
--  · estado_aluno() passa a mandar o bloco "tempo": o dia de hoje, a hora
--    em que as missões renovam (meia-noite de Brasília) e o fim da liga
--    (segunda 00h de Brasília). O app usava a hora do aparelho, então
--    contadores e calendário ficavam errados fora do fuso de Brasília ou
--    com o relógio do celular errado.
--  · Tabela schema_versao: cada migration daqui em diante registra o seu
--    número no fim do arquivo. O painel confere no login e avisa o admin
--    quando falta migration (a 0014 ficou meses sem rodar e ninguém viu).
-- =====================================================================

-- ---------------------------------------------------------------
-- Versão do esquema (o painel confere no login)
-- ---------------------------------------------------------------
create table if not exists public.schema_versao (
  versao int primary key,
  aplicada_em timestamptz not null default now()
);
alter table public.schema_versao enable row level security;
drop policy if exists schema_versao_ler on public.schema_versao;
create policy schema_versao_ler on public.schema_versao for select to authenticated using (public.eh_educador());
-- marca todas as migrations aplicadas até aqui
insert into public.schema_versao (versao) select generate_series(1, 22) on conflict do nothing;

-- ---------------------------------------------------------------
-- estado_aluno com o bloco "tempo" (substitui a versão da 0017)
-- ---------------------------------------------------------------
create or replace function public.estado_aluno()
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); e public.economia_aluno; d public.dias_aluno; lid uuid; pf public.perfis; mx int; hrs numeric;
begin
  e := regenerar_coracoes(u);
  d := preparar_dia(u);
  lid := entrar_liga(u);
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set visto_em = now() where user_id = u returning * into pf;
  mx := coalesce((param('economia')->>'coracoes')::int, 5);
  hrs := coalesce((param('economia')->>'horasCoracao')::numeric, 5);
  return jsonb_build_object(
    'perfil', jsonb_build_object('nome', pf.nome, 'avatar', pf.avatar, 'materia', pf.materia_atual, 'plus', tem_plus(u), 'plusAte', pf.findout_plus_ate, 'admin', is_admin(), 'papel', pf.papel),
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
    'versaoConteudo', (select max(versao) from public.publicacoes),
    'turmas', turmas_do_aluno(u),
    'convites', convites_do_aluno(u),
    'atividades', atividades_do_aluno(u),
    -- horário oficial (Brasília): o app usa isto em vez do relógio do aparelho
    'tempo', jsonb_build_object(
      'hoje', hoje(),
      'renovaEm', ((hoje() + 1)::timestamp at time zone 'America/Sao_Paulo'),
      'fimSemana', ((semana_atual() + 7)::timestamp at time zone 'America/Sao_Paulo'))
  );
end $$;
