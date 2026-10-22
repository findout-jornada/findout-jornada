-- =====================================================================
-- Findout Jornada · Migration 0052 · Bloqueio de escolas
-- Rodar no SQL Editor depois da 0051. Idempotente.
--
--  · escolas ganha bloqueada_em, bloqueio_motivo e bloqueada_por. Escola bloqueada =
--    bloqueada_em preenchido. Só o super usuário bloqueia e desbloqueia (bloquear_escola),
--    e cada bloqueio/desbloqueio fica na auditoria com o motivo.
--  · Gatilhos barram QUALQUER gravação ligada a uma escola bloqueada (turmas, membros,
--    professores e alunos das turmas, atividades, entregas e dinâmicas), venha de RPC
--    ou de insert/update/delete direto. O super usuário continua podendo mexer (precisa
--    para desbloquear, arquivar ou dar suporte).
--  · No app: as turmas da escola bloqueada continuam na lista com a marca bloqueada,
--    as atividades dela somem do aluno e o código da turma não aceita entrada.
--  · No painel: aviso na escola e nas turmas dela; educadores que só têm escolas
--    bloqueadas veem uma tela de bloqueio e não entram no painel.
-- =====================================================================

alter table public.escolas
  add column if not exists bloqueada_em timestamptz,
  add column if not exists bloqueio_motivo text,
  add column if not exists bloqueada_por uuid references auth.users(id) on delete set null;

create or replace function public.escola_bloqueada(p_escola uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select bloqueada_em is not null from public.escolas where id = p_escola), false);
$$;
grant execute on function public.escola_bloqueada(uuid) to authenticated;

-- Bloquear / desbloquear (só o super). p_bloquear = true bloqueia; false libera.
create or replace function public.bloquear_escola(p_escola uuid, p_bloquear boolean, p_motivo text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); e public.escolas;
begin
  if not is_admin() then raise exception 'Só o super usuário bloqueia ou libera escolas.' using errcode = '42501'; end if;
  select * into e from public.escolas where id = p_escola;
  if not found then raise exception 'Escola não encontrada.'; end if;
  if p_bloquear then
    update public.escolas set bloqueada_em = coalesce(bloqueada_em, now()), bloqueio_motivo = nullif(trim(coalesce(p_motivo, '')), ''), bloqueada_por = u where id = p_escola returning * into e;
  else
    update public.escolas set bloqueada_em = null, bloqueio_motivo = null, bloqueada_por = null where id = p_escola returning * into e;
  end if;
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', case when p_bloquear then 'bloqueio_escola' else 'desbloqueio_escola' end, 'escolas', p_escola::text,
            left(case when p_bloquear then 'Bloqueou a escola ' else 'Liberou a escola ' end || e.nome || coalesce(' · ' || e.bloqueio_motivo, ''), 200),
            jsonb_build_object('bloqueada', p_bloquear, 'motivo', e.bloqueio_motivo));
  return to_jsonb(e);
end $$;
grant execute on function public.bloquear_escola(uuid, boolean, text) to authenticated;

-- Gatilho: nada se grava numa escola bloqueada (exceto pelo super usuário)
create or replace function public.fj_barra_escola_bloqueada()
returns trigger language plpgsql security definer set search_path = public as $$
declare esc uuid; tid uuid;
begin
  if is_admin() then if tg_op = 'DELETE' then return old; else return new; end if; end if;
  if tg_table_name = 'escolas' then esc := case when tg_op = 'DELETE' then old.id else new.id end;
  elsif tg_table_name in ('turmas', 'escola_membros') then esc := case when tg_op = 'DELETE' then old.escola_id else new.escola_id end;
  elsif tg_table_name = 'atividade_entregas' then
    select t.escola_id into esc from public.atividades a join public.turmas t on t.id = a.turma_id where a.id = case when tg_op = 'DELETE' then old.atividade_id else new.atividade_id end;
  else
    tid := case when tg_op = 'DELETE' then old.turma_id else new.turma_id end;
    select escola_id into esc from public.turmas where id = tid;
  end if;
  if esc is not null and escola_bloqueada(esc) then
    raise exception 'Escola bloqueada. Fale com o suporte da Findout.' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then return old; else return new; end if;
end $$;

do $$
declare t text;
begin
  foreach t in array array['escolas', 'escola_membros', 'turmas', 'turma_alunos', 'turma_professores', 'atividades', 'atividade_entregas', 'dinamicas'] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists fj_bloqueio_%I on public.%I', t, t);
      execute format('create trigger fj_bloqueio_%I before insert or update or delete on public.%I for each row execute function public.fj_barra_escola_bloqueada()', t, t);
    end if;
  end loop;
end $$;

-- App: turmas trazem a marca; atividades de escola bloqueada somem; código não aceita entrada
create or replace function public.turmas_do_aluno(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'nome', t.nome, 'escola', es.nome, 'codigo', t.codigo, 'bloqueada', es.bloqueada_em is not null) order by t.nome), '[]'::jsonb)
  from public.turma_alunos ta join public.turmas t on t.id = ta.turma_id left join public.escolas es on es.id = t.escola_id
  where ta.user_id = p_user and ta.aceito and t.ativa;
$$;

create or replace function public.atividades_do_aluno(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'titulo', a.titulo, 'descricao', a.descricao, 'materia', a.materia_id, 'prazo', a.prazo,
    'turma', t.nome, 'turmaId', t.id, 'questoes', jsonb_array_length(a.questoes),
    'status', case when e.entregue_em is not null then 'entregue'
                   when a.status = 'encerrada' or (a.prazo is not null and a.prazo < now()) then 'encerrada'
                   else 'pendente' end,
    'nota', e.nota, 'acertos', e.acertos, 'total', e.total, 'entregueEm', e.entregue_em
  ) order by (e.entregue_em is not null), a.prazo asc nulls last, a.criada_em desc), '[]'::jsonb)
  from public.atividades a
  join public.turmas t on t.id = a.turma_id and t.ativa
  left join public.escolas es on es.id = t.escola_id
  join public.turma_alunos ta on ta.turma_id = a.turma_id and ta.user_id = p_user and ta.aceito
  left join public.atividade_entregas e on e.atividade_id = a.id and e.user_id = p_user
  where a.status <> 'rascunho' and (es.id is null or es.bloqueada_em is null);
$$;

-- Entrada por código com limite de tentativas (auditoria: força bruta no código de 6 letras).
-- O erro de código errado volta como {erro: ...} em vez de exceção, senão a contagem seria desfeita junto com a transação.
create table if not exists public.tentativas_codigo (
  user_id uuid primary key references auth.users(id) on delete cascade,
  n int not null default 0,
  janela timestamptz not null default now()
);
alter table public.tentativas_codigo enable row level security;   -- sem policy: só as funções mexem

create or replace function public.entrar_turma(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); t public.turmas; tent int;
begin
  insert into public.tentativas_codigo (user_id) values (u)
    on conflict (user_id) do update
      set n = case when tentativas_codigo.janela < now() - interval '10 minutes' then 0 else tentativas_codigo.n end,
          janela = case when tentativas_codigo.janela < now() - interval '10 minutes' then now() else tentativas_codigo.janela end
    returning n into tent;
  if tent >= 10 then return jsonb_build_object('erro', 'Muitas tentativas. Espere 10 minutos e confira o código com o professor.'); end if;
  select * into t from public.turmas where codigo = upper(trim(p_codigo)) and ativa;
  if not found then
    update public.tentativas_codigo set n = n + 1 where user_id = u;
    return jsonb_build_object('erro', 'Código não encontrado. Confira com o professor.');
  end if;
  if t.escola_id is not null and escola_bloqueada(t.escola_id) then raise exception 'A escola desta turma está bloqueada. Fale com o seu professor.'; end if;
  if not t.entrada_codigo and not exists (select 1 from public.turma_alunos where turma_id = t.id and user_id = u) then
    raise exception 'A entrada por código está fechada na turma %. Peça ao professor um convite pelo seu e-mail.', t.nome;
  end if;
  insert into public.turma_alunos (turma_id, user_id, aceito) values (t.id, u, true)
    on conflict (turma_id, user_id) do update set aceito = true;
  delete from public.tentativas_codigo where user_id = u;
  return jsonb_build_object('id', t.id, 'nome', t.nome, 'estado', estado_aluno());
end $$;

-- =====================================================================
-- Correções da auditoria de segurança (22 out 2026)
-- =====================================================================

-- (1) Conta bloqueada no Auth (botão Bloquear do painel) cai na hora, não só no próximo login:
--     exigir_login(), chamado por todas as RPCs, passa a conferir banned_until.
create or replace function public.exigir_login()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Faça login para continuar.' using errcode = '42501'; end if;
  if exists (select 1 from auth.users where id = u and banned_until is not null and banned_until > now()) then
    raise exception 'Conta bloqueada. Fale com o suporte.' using errcode = '42501';
  end if;
  return u;
end $$;

-- (2) Isolamento entre escolas: o professor não move a turma para outra escola nem troca o criador.
--     Só quem coordena (ou é admin) a escola de origem E a de destino muda escola_id.
create or replace function public.fj_turma_protege_colunas()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if is_admin() then return new; end if;
  if new.criada_por is distinct from old.criada_por then raise exception 'Não dá para mudar quem criou a turma.' using errcode = '42501'; end if;
  if new.escola_id is distinct from old.escola_id then
    if new.escola_id is not null and not coord_da_escola(new.escola_id) then raise exception 'Só o coordenador ou o admin da escola de destino pode mover a turma para ela.' using errcode = '42501'; end if;
    if old.escola_id is not null and not coord_da_escola(old.escola_id) then raise exception 'Só o coordenador ou o admin da escola pode tirar a turma dela.' using errcode = '42501'; end if;
  end if;
  return new;
end $$;
drop trigger if exists fj_turma_protege on public.turmas;
create trigger fj_turma_protege before update on public.turmas for each row execute function public.fj_turma_protege_colunas();

-- (3) As colunas de bloqueio da escola só mudam pelo super (coordenador/admin da escola têm UPDATE em escolas)
create or replace function public.fj_escola_protege_colunas()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() and (new.bloqueada_em is distinct from old.bloqueada_em or new.bloqueio_motivo is distinct from old.bloqueio_motivo or new.bloqueada_por is distinct from old.bloqueada_por) then
    raise exception 'Só o super usuário bloqueia ou libera escolas.' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists fj_escola_protege on public.escolas;
create trigger fj_escola_protege before update on public.escolas for each row execute function public.fj_escola_protege_colunas();

-- (4) Professor não promove conta de aluno a professor: adicionar à turma só aceita quem já é educador,
--     a não ser que quem adiciona seja coordenador/admin da escola (ou super), que podem promover.
create or replace function public.adicionar_professor_turma(p_turma uuid, p_email text, p_materia text default null, p_materias text[] default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare alvo uuid; nome_alvo text; esc uuid; arr text[]; disc text; papel_alvo text;
begin
  perform exigir_login();
  if not (is_admin() or coord_da_turma(p_turma) or professor_da_turma(p_turma)) then raise exception 'Sem permissão nesta turma.' using errcode = '42501'; end if;
  select id into alvo from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if alvo is null then raise exception 'Nenhuma conta com o e-mail %. A pessoa precisa criar a conta no app primeiro.', trim(p_email); end if;
  select papel, disciplina_id into papel_alvo, disc from public.perfis where user_id = alvo;
  if coalesce(papel_alvo, 'aluno') = 'aluno' and not (is_admin() or coord_da_turma(p_turma)) then
    raise exception 'Essa conta ainda é de aluno. Peça ao coordenador ou ao admin da escola para cadastrá-la como professor.' using errcode = '42501';
  end if;
  arr := fj_normalizar_materias(p_materias, p_materia);
  if arr = '{}' and disc is not null then arr := array[disc]; end if;
  insert into public.turma_professores (turma_id, user_id, materia_id, materias)
    values (p_turma, alvo, case when cardinality(arr) = 1 then arr[1] else null end, arr)
    on conflict (turma_id, user_id) do update set materia_id = excluded.materia_id, materias = excluded.materias;
  select escola_id into esc from public.turmas where id = p_turma;
  if esc is not null then insert into public.escola_membros (escola_id, user_id, papel) values (esc, alvo, 'professor') on conflict do nothing; end if;
  perform set_config('fj.liberar_perfil', '1', true);
  update public.perfis set papel = case when papel = 'aluno' then 'professor' else papel end where user_id = alvo returning nome into nome_alvo;
  return jsonb_build_object('user_id', alvo, 'nome', nome_alvo);
end $$;
grant execute on function public.adicionar_professor_turma(uuid, text, text, text[]) to authenticated;

-- (5) Educador só lê os perfis que têm a ver com ele (alunos e professores das suas turmas, membros da sua escola),
--     não a plataforma inteira. O aluno continua lendo só o próprio.
create or replace function public.ve_perfil(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select is_admin() or p_user = auth.uid()
    or exists (select 1 from public.turma_alunos ta where ta.user_id = p_user and (professor_da_turma(ta.turma_id) or coord_da_turma(ta.turma_id)))
    or exists (select 1 from public.turma_professores tp where tp.user_id = p_user and (professor_da_turma(tp.turma_id) or coord_da_turma(tp.turma_id)))
    or exists (select 1 from public.escola_membros em where em.user_id = p_user and membro_da_escola(em.escola_id));
$$;
grant execute on function public.ve_perfil(uuid) to authenticated;
drop policy if exists perfis_ler on public.perfis;
create policy perfis_ler on public.perfis for select to authenticated using (public.ve_perfil(user_id));

-- (6) Apagar turma ou atividade (apaga as notas junto): só quem criou, o coordenador/admin da escola ou o super.
drop policy if exists turmas_apagar on public.turmas;
create policy turmas_apagar on public.turmas for delete to authenticated using (public.is_admin() or criada_por = auth.uid() or public.coord_da_turma(id));
drop policy if exists atividades_apagar on public.atividades;
create policy atividades_apagar on public.atividades for delete to authenticated using (public.is_admin() or professor_id = auth.uid() or public.coord_da_turma(turma_id));

-- (7) Baús: tranca a linha de economia antes de conferir, para duas chamadas simultâneas não pagarem duas vezes.
create or replace function public.abrir_bau(p_unidade uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); total int; feitas int; precisa int; v_moedas int := (param('economia')->>'moedasBau')::int;
begin
  perform 1 from public.economia_aluno where user_id = u for update;
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
  perform 1 from public.economia_aluno where user_id = u for update;
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

-- (8) Perfil: nome limitado a 60 caracteres e sem caracteres de controle (ranking e painel mostram o nome);
--     o gatilho ganha search_path fixo.
create or replace function public.perfis_protege_colunas()
returns trigger language plpgsql set search_path = public as $$
begin
  if (new.papel is distinct from old.papel or new.findout_plus_ate is distinct from old.findout_plus_ate or new.disciplina_id is distinct from old.disciplina_id)
     and not public.is_admin() and coalesce(current_setting('fj.liberar_perfil', true), '') <> '1' then
    raise exception 'Você não pode alterar este campo do perfil.' using errcode = '42501';
  end if;
  new.nome := left(trim(regexp_replace(coalesce(new.nome, ''), '[[:cntrl:]]', '', 'g')), 60);
  if new.nome = '' then new.nome := old.nome; end if;
  return new;
end $$;

-- (9) Pessoas da escola para o admin/coordenador da escola: a mesma lista da aba Contas do super,
--     só com quem é membro da escola ou aluno das turmas dela (o coordenador limitado a segmentos
--     recebe só os alunos das turmas dos segmentos dele). Nunca marca super usuário.
create or replace function public.pessoas_da_escola(p_escola uuid)
returns table (
  user_id uuid, nome text, email text, avatar text,
  xp int, moedas int, coracoes int, congeladores int,
  findout_plus_ate timestamptz, criado_em timestamptz, visto_em timestamptz,
  licoes int, ofensiva int, admin boolean, banido boolean, papel text
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform exigir_login();
  if not (is_admin() or coord_da_escola(p_escola)) then raise exception 'Só o admin ou o coordenador da escola.' using errcode = '42501'; end if;
  return query
    select p.user_id, p.nome, u.email::text, p.avatar,
      coalesce(e.xp, 0), coalesce(e.moedas, 0), coalesce(e.coracoes, 0), coalesce(e.congeladores, 0),
      p.findout_plus_ate, p.criado_em, p.visto_em,
      (select count(*) from public.progresso pr where pr.user_id = p.user_id)::int,
      public.ofensiva(p.user_id),
      false,
      coalesce(u.banned_until > now(), false),
      p.papel
    from public.perfis p
    join auth.users u on u.id = p.user_id
    left join public.economia_aluno e on e.user_id = p.user_id
    where p.user_id in (
        select em.user_id from public.escola_membros em where em.escola_id = p_escola
        union
        select ta.user_id from public.turma_alunos ta join public.turmas t on t.id = ta.turma_id
          where t.escola_id = p_escola and ta.aceito and (is_admin() or coord_da_turma(t.id)))
      and not exists (select 1 from public.admins a where a.user_id = p.user_id)
    order by case p.papel when 'admin' then 0 when 'coordenador' then 1 when 'professor' then 2 else 3 end, p.nome;
end $$;
grant execute on function public.pessoas_da_escola(uuid) to authenticated;

insert into public.schema_versao (versao) values (52) on conflict do nothing;
