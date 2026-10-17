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

## Mapa do ENEM (volta ao mundo)

Em **Suas matérias → Mapa do ENEM** (ou Perfil → Mapa do ENEM) o aluno vê um arquipélago desenhado em SVG com uma ilha por área: Linguagens (Português, Inglês), Humanas (História, Geografia, Filosofia e Sociologia), Natureza (Biologia, Química, Física), Matemática e Redação; matérias fora dessas listas caem na ilha Atualidades. Cada ilha mostra as matérias e a porcentagem de lições concluídas; quando chega a 100% ela ganha bandeira e o barco com o avatar do aluno segue pela rota tracejada até a próxima. O castelo ENEM no centro marca a chegada: com todas as ilhas conquistadas a faixa vira "Volta ao mundo". A viagem é opcional e não trava nada: em "Suas matérias" o aluno abre qualquer matéria a qualquer hora. Dentro do mapa a ordem vale: só a ilha atual (a primeira não concluída) e as anteriores abrem matérias; as seguintes aparecem sem cor, com cadeado, até a ilha atual chegar a 100%. Na ilha de Linguagens o aluno escolhe o idioma da viagem, Inglês ou Espanhol (como no ENEM): Português sempre conta e, do idioma, só o escolhido; a escolha fica guardada no aparelho e pode ser trocada na folha da ilha. Ilhas sem lições publicadas não travam a sequência. Tocar numa ilha abre a lista de matérias dela com barra de progresso e atalho para a jornada. À noite (18h às 6h, hora do aparelho) o mar escurece e aparecem lua e estrelas. Quando o aluno volta ao mapa depois de conquistar uma ilha, o barco navega da ilha anterior até a nova, e o trecho já percorrido vira ponte de madeira. Animações: ilhas flutuando e surgindo uma a uma, ondas, nuvens, bandeiras tremulando, rota animada, barco balançando e halo na ilha atual; tudo desliga com "reduzir movimento" do sistema. A conquista de uma ilha nova (e a volta completa) é comemorada uma vez com confete, guardada em `localStorage`. As ilhas e as posições ficam na constante `ILHAS` em `app/index.html`.

## Avatar do aluno

Em **Perfil → Criar avatar** o aluno monta o próprio boneco em 18 partes: pele, formato do rosto, cabelo (13 estilos) e cor, sobrancelhas, olhos e cor, nariz, boca, detalhes (sardas, barba…), óculos, acessório de cabeça, acessório (brincos, colar, cachecol…), estilo e cor da roupa, estampa, fundo e padrão do fundo. Tem prévia ao vivo, sortear tudo ou só uma parte, desfazer e cancelar. O avatar é desenhado em SVG (sem imagens) e fica salvo como um JSON curto na coluna `perfis.avatar`, que já existia; não precisa de migration. Partes novas que o aluno ainda não escolheu ficam na opção neutra, então avatares antigos continuam válidos. Aparece no perfil, no ranking da liga e na lista de alunos do painel (quem ainda não montou continua com as iniciais). O trecho de desenho fica entre os marcadores `AV-START` e `AV-END` em `app/index.html` e é copiado igual em `painel/index.html`.

## Professores, turmas e atividades (migration 0011)

Papéis além de aluno e admin: **professor** (cria turmas e atividades no painel) e **coordenador** (cria escolas, coloca professores e vê todas as turmas da escola). O admin define o papel na aba **Alunos** do painel. Quem é só aluno não entra no painel.

**Disciplina do professor (migration 0016):** ao tornar alguém professor, o admin (ou o coordenador, ao adicioná-lo à escola) informa a disciplina dele. Com disciplina, o professor vê só as turmas em que dá aula e, nelas, só as atividades da sua disciplina ou criadas por ele; a matéria da atividade, a busca no banco de questões e a matéria dele na turma ficam travadas na disciplina. O coordenador enxerga todas as turmas e atividades da escola, mas continua sem as abas de conteúdo, questões, publicação e auditoria, que são só do admin. As regras valem no banco (RLS), não só na tela.

Fluxo:

1. **Turma:** o professor cria em **Turmas → Nova turma**. A turma ganha um código de 6 letras. O aluno entra pelo app em **Perfil → Minhas turmas → Entrar**, ou o professor adiciona pelo e-mail da conta.
2. **Atividade:** em **Atividades → Nova atividade**, o professor escolhe turma, matéria, prazo e as questões: busca no banco por assunto, matéria, unidade ou texto, ou cria questões próprias (ficam só na atividade). Cada questão tem um valor; a nota vai de 0 a 10 proporcional aos pontos.
3. **Aluno:** vê a atividade na aba **Turma** da barra de baixo (com um contador de pendentes e um aviso na trilha). Responde uma vez, sem gastar coração, e recebe a nota na hora. Ganha XP (parâmetro `xpAtividade` + 2 por acerto), e conta para ofensiva, missões e liga.
4. **Resultados:** o professor vê quem entregou, a nota de cada um, a média e as questões que a turma mais errou, e copia as notas para uma planilha. O botão **Ver respostas** ao lado de cada aluno abre questão por questão: o que ele marcou, a resposta certa (quando errou) e a explicação. Coordenador e admin veem o mesmo; cada consulta fica na auditoria.

As questões recebem o campo **assuntos** (separados por vírgula no editor) para a busca por assunto. A correção é feita no servidor (`entregar_atividade`) a partir da cópia das questões guardada na atividade, então editar a questão no banco depois não muda a atividade.

**Segmentos (migration 0012):** o admin cadastra os segmentos de ensino (Fundamental II, Ensino Médio, Pré-vestibular…) na aba Turmas. Cada turma pertence a um segmento e cada questão pode indicar para quais segmentos serve (opcional; vazio = todos). Na busca do professor, o segmento da turma entra como filtro padrão e cada questão mostra o nível (fácil, média, difícil) e o segmento.

Para ativar: rodar `supabase/migrations/0011_turmas_atividades.sql` e depois `0012_segmentos.sql` no SQL Editor. O app e o painel já estão preparados e mostram um aviso enquanto as migrations não rodam.

## Auditoria (migration 0014)

Tudo que acontece no painel fica registrado na tabela `auditoria`, consultável pelo admin na aba **Auditoria**: alterações de dados (gatilhos nas tabelas de conteúdo, turmas, atividades, perfis e admins, com o antes e o depois de cada campo) e eventos do painel (login, saída, tela aberta, busca de alunos, turma aberta, resultados vistos, cópia de notas e do JSON). Os gatilhos valem mesmo para alterações feitas fora do painel. O que os alunos fazem no app (lições, moedas, ofensiva) não entra, só mudanças de perfil e entrada em turma.

## Banco de questões

As questões vivem nas migrations de conteúdo (`0005`, `0006`, `0007`, `0013` e `0015`), gravadas por uma função auxiliar que deriva os ids dos títulos, por isso cada arquivo pode ser rodado de novo sem duplicar. A migration `0013` revisou o banco (8 questões quase repetidas trocadas, 1 enunciado corrigido) e acrescentou 2 seções por matéria; a `0015` criou a matéria Espanhol (4 seções, 8 unidades, 16 lições e 96 questões: leitura, falsos amigos, artigos e gênero, verbos, gêneros textuais, poesia e canção, países e variedades, conectores e pronomes). Ao todo são 74 seções, 144 unidades, 303 lições e 1.420 questões publicadas em 11 matérias. Regra para novas questões: uma só de verdadeiro/falso e uma só de completar por lição, com enunciados diferentes entre si, porque o id vem do texto do enunciado.

Plano de trabalho semana a semana: [PLANO.md](PLANO.md). O que ficou para depois do lançamento: [DEPOIS.md](DEPOIS.md).
