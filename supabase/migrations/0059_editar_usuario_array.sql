-- =====================================================================
-- Findout Jornada · Migration 0059 · Conserta editar_usuario
-- Rodar no SQL Editor depois da 0058. Idempotente.
--
-- A 0034 montava a lista de mudanças com `mudancas := mudancas || 'senha'`.
-- Para o Postgres isso é ambíguo: o operador || existe como
-- array||elemento E como array||array, e com um literal sem tipo ele
-- escolhe array||array e tenta ler 'senha' como um array — daí o erro
--   malformed array literal: "senha"
-- Como o erro acontece DEPOIS do update, a transação inteira voltava
-- atrás: a senha nunca mudava. O mesmo valia para trocar só o nome
-- ('malformed array literal: "nome"') ou só o e-mail.
--
-- Aqui a função é a mesma, com array_append() no lugar do || — que só
-- tem uma leitura possível. Nada mais muda: mesmas permissões, mesmas
-- validações, mesma auditoria (que nunca guarda a senha).
-- =====================================================================

create or replace function public.editar_usuario(p_user uuid, p_nome text default null, p_email text default null, p_senha text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  u uuid := exigir_login(); alvo_email text; alvo_nome text; novo_email text; mudancas text[] := '{}'; dados jsonb := '{}'::jsonb;
begin
  if not is_admin() then raise exception 'Só o super usuário edita contas.' using errcode = '42501'; end if;
  if p_user <> u and exists (select 1 from public.admins where user_id = p_user) then
    raise exception 'Esta conta é super usuário. Tire o acesso dela primeiro.';
  end if;
  select us.email::text, pf.nome into alvo_email, alvo_nome
    from auth.users us left join public.perfis pf on pf.user_id = us.id where us.id = p_user;
  if alvo_email is null then raise exception 'Conta não encontrada.'; end if;

  if p_nome is not null and trim(p_nome) <> '' and trim(p_nome) is distinct from alvo_nome then
    update public.perfis set nome = left(trim(p_nome), 60) where user_id = p_user;
    mudancas := array_append(mudancas, 'nome'); dados := dados || jsonb_build_object('nomeAntes', alvo_nome, 'nomeDepois', left(trim(p_nome), 60));
    alvo_nome := left(trim(p_nome), 60);
  end if;

  novo_email := lower(trim(coalesce(p_email, '')));
  if novo_email <> '' and novo_email is distinct from lower(alvo_email) then
    if novo_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'E-mail inválido.'; end if;
    if exists (select 1 from auth.users where lower(email) = novo_email and id <> p_user) then
      raise exception 'Já existe uma conta com o e-mail %.', novo_email;
    end if;
    update auth.users set email = novo_email, email_confirmed_at = coalesce(email_confirmed_at, now()), updated_at = now()
      where id = p_user;
    update auth.identities set identity_data = identity_data || jsonb_build_object('email', novo_email), updated_at = now()
      where user_id = p_user and provider = 'email';
    mudancas := array_append(mudancas, 'email'); dados := dados || jsonb_build_object('emailAntes', alvo_email, 'emailDepois', novo_email);
    alvo_email := novo_email;
  end if;

  if p_senha is not null and p_senha <> '' then
    if length(p_senha) < 8 then raise exception 'A senha precisa de pelo menos 8 caracteres.'; end if;
    update auth.users set encrypted_password = extensions.crypt(p_senha, extensions.gen_salt('bf')), updated_at = now()
      where id = p_user;
    mudancas := array_append(mudancas, 'senha');
  end if;

  if array_length(mudancas, 1) is null then raise exception 'Nada para mudar.'; end if;
  insert into public.auditoria (user_id, origem, acao, tabela, registro, resumo, dados)
    values (u, 'painel', 'edicao_conta', 'alunos', p_user::text,
            left('Editou a conta de ' || coalesce(alvo_nome, alvo_email) || ' (' || array_to_string(mudancas, ', ') || ')', 200),
            dados);
  return jsonb_build_object('ok', true, 'nome', alvo_nome, 'email', alvo_email, 'mudou', to_jsonb(mudancas));
end $$;
grant execute on function public.editar_usuario(uuid, text, text, text) to authenticated;

insert into public.schema_versao (versao) values (59) on conflict do nothing;
