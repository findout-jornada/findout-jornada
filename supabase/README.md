# Banco de dados (Supabase)

## Rodar as migrations

No painel do Supabase: **SQL Editor** (ícone `>_` no menu da esquerda) → **New query** → colar o conteúdo do arquivo → **Run**. Uma de cada vez, na ordem:

1. `migrations/0001_esquema.sql` — tabelas, segurança (RLS), gatilho de novo usuário, parâmetros iniciais
2. `migrations/0002_funcoes.sql` — regras do jogo (`estado_aluno`, `concluir_licao`, corações, baús, loja)
3. `migrations/0003_admin.sql` — funções do painel (lista de alunos, métricas), coluna de imagem nas questões e bucket público `imagens` no Storage
4. `migrations/0004_admins.sql` — botão "Tornar admin" na aba Alunos do painel (função `definir_admin`)
5. `migrations/0005_conteudo.sql` — conteúdo inicial: 112 questões (Matemática, Português, Biologia, História) com trilhas, lições e explicações. Depois de rodar, abra o painel: ele publica a versão nova sozinho.

As duas podem ser rodadas de novo sem estragar nada. Se aparecer erro, copie a mensagem inteira (ela diz a linha) e mande para o Claude.

## Criar o primeiro administrador

1. **Authentication → Users → Add user → Create new user**: seu e-mail, uma senha, marcar **Auto Confirm User**.
2. No SQL Editor:

```sql
insert into public.admins (user_id)
select id from auth.users where email = 'SEU-EMAIL-AQUI'
on conflict do nothing;
```

Esse usuário entra no painel como admin e no app como aluno comum.

## Conferir

Em **Table Editor** devem aparecer as tabelas `materias`, `questoes`, `perfis`, `economia_aluno`, `ligas`, etc. Em `parametros` há 3 linhas (economia, ligas, missoes) e em `missoes` 6 linhas.

## Como o app usa o banco

- Ao abrir: `rpc('estado_aluno')` devolve tudo do aluno em uma chamada (corações já recarregados pelo tempo, missões do dia sorteadas, liga da semana).
- Conteúdo: lê a última linha de `publicacoes` (pacote JSON montado pelo painel no botão Publicar).
- Cada erro em lição que custa coração: `rpc('perder_coracao')`.
- Fim de lição: `rpc('concluir_licao', {...})` calcula XP, moedas, coroas, ofensiva, missões e erros no servidor.
- Baú da unidade, baú diário e loja: `abrir_bau`, `abrir_bau_diario`, `comprar`.

O aluno nunca escreve direto nas tabelas de progresso; só as funções (security definer) escrevem. O painel (admin) edita conteúdo direto nas tabelas, protegido pelo RLS.
