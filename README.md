# Findout Jornada

Módulo gamificado de estudo para o ENEM, no estilo Duolingo: trilhas por matéria, lições com 5 tipos de exercício, corações, XP, moedas, ofensiva, missões, liga semanal e loja.

## Estrutura

| Pasta | O que é | Vai para o ar como |
|---|---|---|
| `app/` | App do aluno (PWA, celular e desktop) | projeto Vercel com Root Directory `app` |
| `painel/` | Painel de gestão (trilhas, questões, missões, economia, publicação) | projeto Vercel com Root Directory `painel` |
| `supabase/migrations/` | Esquema do banco, segurança (RLS) e funções, em ordem numérica | rodar no SQL Editor do Supabase |
| `supabase/functions/` | Edge Functions (criar aluno, bloquear/liberar) usadas pelo painel | colar em Edge Functions no Supabase ([como](supabase/README.md)) |
| `conteudo/` | Rascunhos de questões e árvore das matérias | importado pelo painel |

Sem etapa de build: os dois sites são HTML + JS puros e carregam o cliente do Supabase por CDN. Para rodar localmente basta abrir `app/index.html` ou `painel/index.html` num servidor estático qualquer (por exemplo a extensão Live Server do VS Code).

## Configuração

As chaves públicas ficam em `app/config.js` e `painel/config.js`:

```js
window.FJ_CONFIG = { supabaseUrl: 'https://xxxx.supabase.co', supabaseAnonKey: 'eyJ...' };
```

A anon key é pública por design; quem protege os dados é o RLS no banco. A `service_role` key nunca entra neste repositório (as Edge Functions a leem do ambiente do Supabase).

## Acesso (fase atual: fechado)

O cadastro público está desligado no Supabase (Authentication → Sign In / Up). Contas são criadas pelo painel (aba Alunos → **Novo aluno**), já confirmadas e sem gastar o limite de e-mails. Ali também dá para **bloquear/liberar** um aluno sem apagar os dados dele. Para reabrir no lançamento: configurar SMTP próprio (ex.: Brevo) e religar o cadastro — ver [DEPOIS.md](DEPOIS.md).

## Publicar

- **Código:** `git push` na `main` (ou Commit + Push no GitHub Desktop). A Vercel publica em 1 a 2 minutos.
- **Conteúdo:** no painel, botão **Publicar**. O app baixa a versão nova na próxima abertura.

## Professores, turmas e atividades (migration 0011)

Papéis além de aluno e admin: **professor** (cria turmas e atividades no painel) e **coordenador** (cria escolas, coloca professores e vê todas as turmas da escola). O admin define o papel na aba **Alunos** do painel. Quem é só aluno não entra no painel.

Fluxo:

1. **Turma:** o professor cria em **Turmas → Nova turma**. A turma ganha um código de 6 letras. O aluno entra pelo app em **Perfil → Minhas turmas → Entrar**, ou o professor adiciona pelo e-mail da conta.
2. **Atividade:** em **Atividades → Nova atividade**, o professor escolhe turma, matéria, prazo e as questões: busca no banco por assunto, matéria, unidade ou texto, ou cria questões próprias (ficam só na atividade). Cada questão tem um valor; a nota vai de 0 a 10 proporcional aos pontos.
3. **Aluno:** vê a atividade em **Treinar → Atividades da turma** (e um aviso na trilha). Responde uma vez, sem gastar coração, e recebe a nota na hora. Ganha XP (parâmetro `xpAtividade` + 2 por acerto), e conta para ofensiva, missões e liga.
4. **Resultados:** o professor vê quem entregou, a nota de cada um, a média e as questões que a turma mais errou, e copia as notas para uma planilha.

As questões recebem o campo **assuntos** (separados por vírgula no editor) para a busca por assunto. A correção é feita no servidor (`entregar_atividade`) a partir da cópia das questões guardada na atividade, então editar a questão no banco depois não muda a atividade.

**Segmentos (migration 0012):** o admin cadastra os segmentos de ensino (Fundamental II, Ensino Médio, Pré-vestibular…) na aba Turmas. Cada turma pertence a um segmento e cada questão pode indicar para quais segmentos serve (opcional; vazio = todos). Na busca do professor, o segmento da turma entra como filtro padrão e cada questão mostra o nível (fácil, média, difícil) e o segmento.

Para ativar: rodar `supabase/migrations/0011_turmas_atividades.sql` e depois `0012_segmentos.sql` no SQL Editor. O app e o painel já estão preparados e mostram um aviso enquanto as migrations não rodam.

Plano de trabalho semana a semana: [PLANO.md](PLANO.md). O que ficou para depois do lançamento: [DEPOIS.md](DEPOIS.md).
