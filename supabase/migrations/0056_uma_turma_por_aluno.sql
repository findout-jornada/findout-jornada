-- =====================================================================
-- Findout Jornada · Migration 0056 · Aluno em uma turma só
-- Rodar no SQL Editor depois da 0055. Idempotente.
--
--  · Gatilho em turma_alunos: um aluno só pode estar ACEITO em uma turma ativa.
--    Vale para entrar pelo código, aceitar convite e qualquer gravação direta.
--    Convites pendentes (aceito = false) continuam podendo existir; o aluno só
--    não consegue aceitar um enquanto estiver em outra turma.
--  · O super usuário também respeita a regra (para trocar de turma, tire o aluno
--    da turma antiga primeiro: painel → turma → Alunos → Tirar).
--  · Quem já estava em duas turmas antes desta migration continua assim até o
--    professor tirar de uma; a regra só barra novas entradas.
-- =====================================================================

create or replace function public.fj_uma_turma_por_aluno()
returns trigger language plpgsql security definer set search_path = public as $$
declare outra text;
begin
  if not new.aceito then return new; end if;
  if tg_op = 'UPDATE' and old.aceito and old.turma_id = new.turma_id then return new; end if;
  select t.nome into outra
    from public.turma_alunos ta join public.turmas t on t.id = ta.turma_id
    where ta.user_id = new.user_id and ta.aceito and t.ativa and ta.turma_id <> new.turma_id
    limit 1;
  if outra is not null then
    raise exception 'Você já está na turma %. Cada aluno participa de uma turma só: peça ao professor para tirar você dela antes de entrar em outra.', outra
      using errcode = '23505';
  end if;
  return new;
end $$;

drop trigger if exists fj_uma_turma on public.turma_alunos;
create trigger fj_uma_turma before insert or update on public.turma_alunos
  for each row execute function public.fj_uma_turma_por_aluno();

insert into public.schema_versao (versao) values (56) on conflict do nothing;
