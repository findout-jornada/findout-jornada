-- =====================================================================
-- Findout Jornada · Migration 0008 · Admin dá moedas e corações
-- Rodar no SQL Editor do Supabase depois da 0007. Idempotente.
-- =====================================================================

-- Soma moedas e/ou corações para um ou vários alunos de uma vez (aba Alunos do painel).
-- Valores negativos tiram. Moedas nunca ficam abaixo de 0; corações ficam
-- entre 0 e o máximo do parâmetro de economia. Devolve quantos alunos mudaram.
create or replace function public.conceder_recursos(p_users uuid[], p_moedas int default 0, p_coracoes int default 0)
returns int language plpgsql security definer set search_path = public as $$
declare mx int; n int;
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  if p_users is null or array_length(p_users, 1) is null then return 0; end if;
  if coalesce(p_moedas, 0) = 0 and coalesce(p_coracoes, 0) = 0 then return 0; end if;
  mx := coalesce((param('economia')->>'coracoes')::int, 5);

  -- garante a linha de economia (contas antigas podem não ter)
  insert into public.economia_aluno (user_id)
  select p.user_id from public.perfis p where p.user_id = any(p_users)
  on conflict (user_id) do nothing;

  update public.economia_aluno e
     set moedas = greatest(0, e.moedas + coalesce(p_moedas, 0)),
         coracoes = case when coalesce(p_coracoes, 0) = 0 then e.coracoes
                         else least(mx, greatest(0, e.coracoes + p_coracoes)) end,
         -- se os corações encheram agora, a recarga por tempo recomeça do zero
         coracoes_em = case when coalesce(p_coracoes, 0) > 0 and e.coracoes + p_coracoes >= mx then now()
                            else e.coracoes_em end
   where e.user_id = any(p_users);
  get diagnostics n = row_count;
  return n;
end $$;
grant execute on function public.conceder_recursos(uuid[], int, int) to authenticated;
