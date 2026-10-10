-- =====================================================================
-- Findout Jornada · Migration 0003 · Funções do painel (admin)
-- Rodar no SQL Editor do Supabase depois da 0002. Idempotente.
-- =====================================================================

-- Lista de alunos para a tela "Alunos" do painel (busca por nome ou e-mail).
-- O e-mail fica em auth.users, que o painel não consegue ler direto;
-- por isso a função roda como security definer e exige admin.
create or replace function public.alunos_admin(p_busca text default '', p_limite int default 50)
returns table (
  user_id uuid, nome text, email text, avatar text,
  xp int, moedas int, coracoes int, congeladores int,
  findout_plus_ate timestamptz, criado_em timestamptz, visto_em timestamptz,
  licoes int, ofensiva int
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  return query
    select p.user_id, p.nome, u.email::text, p.avatar,
      coalesce(e.xp, 0), coalesce(e.moedas, 0), coalesce(e.coracoes, 0), coalesce(e.congeladores, 0),
      p.findout_plus_ate, p.criado_em, p.visto_em,
      (select count(*) from public.progresso pr where pr.user_id = p.user_id)::int,
      public.ofensiva(p.user_id)
    from public.perfis p
    join auth.users u on u.id = p.user_id
    left join public.economia_aluno e on e.user_id = p.user_id
    where coalesce(p_busca, '') = ''
       or p.nome ilike '%' || p_busca || '%'
       or u.email ilike '%' || p_busca || '%'
    order by p.visto_em desc
    limit greatest(1, least(coalesce(p_limite, 50), 200));
end $$;

-- Números da visão geral do painel
create or replace function public.metricas_admin()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare inicio_hoje timestamptz := (hoje()::timestamp at time zone 'America/Sao_Paulo');
begin
  if not is_admin() then raise exception 'Só administradores.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'alunos', (select count(*) from public.perfis),
    'novos7d', (select count(*) from public.perfis where criado_em >= now() - interval '7 days'),
    'ativos7d', (select count(*) from public.perfis where visto_em >= now() - interval '7 days'),
    'ativosHoje', (select count(distinct user_id) from public.ofensiva_dias where dia = hoje()),
    'plus', (select count(*) from public.perfis where findout_plus_ate > now()),
    'licoesHoje', (select count(*) from public.eventos_licao where criado_em >= inicio_hoje),
    'licoes7d', (select count(*) from public.eventos_licao where criado_em >= now() - interval '7 days')
  );
end $$;

grant execute on function public.alunos_admin(text, int), public.metricas_admin() to authenticated;

-- ---------------------------------------------------------------
-- Imagens nas questões: coluna + bucket público "imagens"
-- Leitura pública (o app mostra a imagem); só admin envia/apaga.
-- ---------------------------------------------------------------
alter table public.questoes add column if not exists imagem_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('imagens', 'imagens', true, 3145728, array['image/png', 'image/jpeg', 'image/webp', 'image/gif'])
on conflict (id) do update set public = true, file_size_limit = 3145728, allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

drop policy if exists imagens_ler on storage.objects;
create policy imagens_ler on storage.objects for select using (bucket_id = 'imagens');
drop policy if exists imagens_admin_inserir on storage.objects;
create policy imagens_admin_inserir on storage.objects for insert to authenticated with check (bucket_id = 'imagens' and public.is_admin());
drop policy if exists imagens_admin_atualizar on storage.objects;
create policy imagens_admin_atualizar on storage.objects for update to authenticated using (bucket_id = 'imagens' and public.is_admin());
drop policy if exists imagens_admin_apagar on storage.objects;
create policy imagens_admin_apagar on storage.objects for delete to authenticated using (bucket_id = 'imagens' and public.is_admin());
