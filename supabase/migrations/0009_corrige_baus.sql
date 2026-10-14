-- =====================================================================
-- Findout Jornada · Migration 0009 · Conserta a abertura dos baús
-- Rodar no SQL Editor do Supabase depois da 0008. Idempotente.
--
-- O erro 'missing FROM-clause entry for table "abrir_bau"' acontecia
-- porque a variável interna "moedas" era referenciada como
-- "abrir_bau.moedas", que o Postgres lia como tabela.coluna.
-- Aqui a variável vira v_moedas, sem ambiguidade.
-- =====================================================================

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

grant execute on function public.abrir_bau(uuid), public.abrir_bau_diario() to authenticated;
