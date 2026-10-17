-- =====================================================================
-- Findout Jornada · Migration 0018 · Entrada por código ligada/desligada por turma
-- Rodar no SQL Editor do Supabase depois da 0017. Idempotente.
--
-- O professor liga a entrada por código no primeiro dia (a turma entra pelo código) e desliga depois.
-- Com a entrada desligada, o código não serve para nada: quem chega atrasado entra por convite.
-- =====================================================================

alter table public.turmas add column if not exists entrada_codigo boolean not null default true;

create or replace function public.entrar_turma(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := exigir_login(); t public.turmas;
begin
  select * into t from public.turmas where codigo = upper(trim(p_codigo)) and ativa;
  if not found then raise exception 'Código não encontrado. Confira com o professor.'; end if;
  if not t.entrada_codigo and not exists (select 1 from public.turma_alunos where turma_id = t.id and user_id = u) then
    raise exception 'A entrada por código está fechada na turma %. Peça ao professor um convite pelo seu e-mail.', t.nome;
  end if;
  insert into public.turma_alunos (turma_id, user_id, aceito) values (t.id, u, true)
    on conflict (turma_id, user_id) do update set aceito = true;
  return jsonb_build_object('id', t.id, 'nome', t.nome, 'estado', estado_aluno());
end $$;
