# Auditoria do projeto — 23 de outubro de 2026

Mapeamento completo + caça a falhas, feita sobre o estado do commit `1bfdb52` (59 migrations, app e painel). Três revisões independentes (banco/RLS, app do aluno, painel/edge functions) mais verificação direta de cada achado.

**Andamento (23 out):** corrigidas **F3, F8, F22** (migration 0060, commit `7eb53ef`) e **F2, F6, F7, F4** (migration 0061, commit `f4f8ea1`). Falta rodar a 0061 no SQL Editor. Pendentes: F5, F9, F10, F11–F21 e a decisão de arquitetura da observação 1 (que inclui F1 e F5).

Legenda: **ALTA** = explorável hoje, com dano real · **MÉDIA** = dano limitado ou exige condições · **BAIXA** = incômodo, fragilidade ou risco futuro.

---

## 1. Mapa do projeto

| Camada | Onde | Tamanho |
|---|---|---|
| App do aluno | `app/index.html` (IIFE único: CSS + HTML + JS) + `sw.js` | ~3.200 linhas |
| Painel de gestão | `painel/index.html` + `seed.js` | ~3.100 linhas |
| Banco | `supabase/migrations/0001` → `0059` | ~11.900 linhas SQL |
| Servidor (chave privada) | `supabase/functions/criar-aluno`, `bloquear-aluno` | 2 Edge Functions |
| Ferramentas | `ferramentas/validar-questoes*.js`, `recolorir-gif.js`, `assar-sprite.js` | — |

**Papéis:** aluno (app) · professor · coordenador (por segmento) · admin de escola · super usuário (tabela `admins`). A autorização real está no banco (RLS + funções `security definer`); o painel só espelha.

**Fluxos principais do app:** trilha/lição (`startLesson` → `grade` → `finish` → `concluir_licao`), atividade em modo prova (`abrir_atividade` → `entregar_atividade`), dinâmica ao vivo (poll de 2 s), duelo, Mapa do ENEM, avatar SVG, domínio por habilidade.

**Verificações que passaram:** as 59 RPCs chamadas pelo front existem no banco com as mesmas assinaturas · banco de questões sem erros nem avisos (1.900 questões, 16 matérias) · `concluir_licao` manteve a gravação de `tentativas` através de todas as redefinições (0046 → 0058) · `fechar_ligas` idempotente · nenhum SQL concatenado com entrada de usuário · nenhum segredo no repositório (só a anon key, pública por design) · escape consistente no app (nenhuma interpolação de dado de usuário sem `esc()`).

---

## 2. Falhas

### ALTA

**F1 · Gabarito das atividades valendo nota é recuperável pelo aluno**
`supabase/migrations/0058_liga_justa_coracoes.sql:247-248` e `:274`

O id embaralhado é `md5(atividade_id || ':' || questao_id)` — sem segredo, e o aluno conhece as duas partes. Pior: o **enunciado vai em claro**, e o pacote publicado (`publicar_pacote`, 0021) entrega `dados` (com o gabarito) e `explicacao` de **todas** as questões publicadas para qualquer aluno logado, guardado em `localStorage['fj-pacote']`. Basta casar o enunciado para gabaritar a atividade.

*Correção:* assinar o id com segredo do servidor (HMAC com chave em tabela sem policy) **e** parar de enviar o enunciado idêntico ao do banco — ou aceitar a limitação e usar só questões próprias do professor em atividades que valem nota.

**F2 · Farm ilimitado de XP, ofensiva e missões**
`supabase/migrations/0058_liga_justa_coracoes.sql:170`

A trava de ritmo mínimo (3 s por questão) só vale quando `p_acertos + p_erros > 0`. Uma chamada com ambos zerados escapa da trava, ainda recebe o bônus de "lição perfeita" (`perfeita := p_erros = 0`), acende a ofensiva, enche `licoes`/`perfeitas` do dia (missões e baú automáticos) e pode injetar até 100 linhas falsas em `tentativas` por chamada — corrompendo o motor de domínio (0048) e a revisão espaçada (0049). Moedas e XP de liga têm teto diário; **o XP do perfil e o do mês não têm**.

*Correção:* exigir `p_acertos + p_erros >= 1` para pagar XP/moedas e aplicar o ritmo mínimo também a chamadas 0/0.

**F3 · XSS de professor para super usuário no telão da dinâmica**
`painel/index.html:2147` + `supabase/migrations/0053_dinamica_desempate.sql:65-76,90`

Cadeia confirmada ponta a ponta: `criar_dinamica` valida o whitelist de `tipo` **apenas** no caminho `p_questoes` (linhas 65-69); no caminho "copiar de atividade" faz `gab := a.questoes` sem validar (linha 76) e copia `tipo` verbatim para `publicas` (linha 90). O telão renderiza `${TIPOS[pub.tipo] || pub.tipo}` **sem `esc()`** — único sink de `tipo` que escapou da revisão 0057. Como `atividades.questoes` é jsonb livre gravado pelo professor via API, e o CSP usa `unsafe-inline`, um professor executa script na sessão de quem abrir o telão (super usuário → `definir_admin`, `excluir_usuario`).

*Correção:* `esc(pub.tipo)` na linha 2147 **e** repetir o whitelist no caminho `p_atividade` da `criar_dinamica`.

### MÉDIA

**F4 · Dinâmica ao vivo entrega o id real da questão**
`supabase/migrations/0053_dinamica_desempate.sql:90` · `0032_dinamicas.sql:322`

A proteção que atividades (0058) e duelos (0057) ganharam não chegou à dinâmica: o `questaoPub` leva o id do banco, que o aluno cruza com o pacote local para acertar tudo em 1 s. Correção: mesmo `md5(dinamica:indice)` usado no duelo.

**F5 · Duelo: enunciado casável com o pacote**
`supabase/migrations/0054_duelos.sql:147-151,180`

O id ficou opaco na 0057, mas o enunciado continua idêntico ao do banco, e o sorteio usa só questões `publicada` — todas no pacote com gabarito. Vitória garantida por busca textual. O prêmio tem trava (3/dia, 1 por par), então o dano é no ranking e na justiça do jogo.

**F6 · Coração nunca volta durante a lição — contador trava em 00:00:00**
`app/index.html:3209` + `:946`

Quando o tempo do próximo coração chega a zero, o app zera `proximoCoracaoEm` e chama `recarregarEstado()`, que retorna de imediato se há lição em curso (`if (L) return`). O aluno sem corações, dentro da lição, vê o contador chegar a zero e **nada acontece** — e como o campo foi zerado, o contador nem volta. Saídas: pagar moedas, praticar erros ou abandonar a lição.

**F7 · "Pular" na última questão entrega a atividade sem confirmação**
`app/index.html:3164`

Em modo atividade, pular grava resposta nula e chama `next()`; na última questão isso cai direto em `finish()` → `entregar()`. A entrega é única e irreversível no servidor. O botão de responder avisa ("Responder e entregar"); o Pular não.

**F8 · Painel não exige a migration 0059**
`painel/index.html:835` (`ESQUEMA_ESPERADO = 58`)

A 0059 conserta justamente uma RPC que o painel chama (`editar_usuario`, que falhava com `malformed array literal: "senha"` e revertia a transação inteira). Num banco parado na 0058, o painel não avisa nada e a edição de conta falha sem diagnóstico. Deve ser 59.

**F9 · Modal descarta o que foi digitado quando a ação falha**
`painel/index.html:3123` e chamadores (`:3092`, `:3094`, `:2725`, `:2768`, `:1664`, `:2980`, `:2861`)

O modal fecha sempre que a função resolve; só exceção o mantém aberto. Vários caminhos de erro fazem `return toast('...')` — que resolve. Pior caso: "Novo aluno" com erro da edge function perde nome, e-mail e senha digitados; "Nova dinâmica" perde o formulário inteiro.

**F10 · Publicação pode marcar como publicado o que nunca chegou ao servidor**
`painel/index.html:752-769`

`publicar()` grava como `ultimoPacote` o snapshot **local** (`montarPacote()`), enquanto `publicar_pacote` monta do **banco**. Se um autosave falhou antes (o `agendar` não re-tenta), o painel passa a dizer "Tudo publicado" enquanto o app tem conteúdo antigo — e a divergência nunca mais é sinalizada. Correção: fazer `publicar_pacote` devolver o pacote gravado e usar esse.

### BAIXA

| # | Falha | Local |
|---|---|---|
| F11 | `comprar()` sem lock: duas compras simultâneas debitam duas vezes e podem deixar moedas negativas (os baús ganharam `for update` na 0052; a loja não) | `0002_funcoes.sql:358-377` |
| F12 | Respostas sem teto de tamanho em dinâmica e atividade (o duelo limita a 4 KB): aluno pode enviar megabytes e travar o painel do professor | `0032:348`, `0058:282` |
| F13 | Policies auto-referentes em `liga_participantes`/`ligas` causam "infinite recursion" em SELECT direto — inoperantes na prática (o app usa `estado_aluno`) | `0001_esquema.sql:309-314` |
| F14 | "Unidade undefined" na tela de fim ao revisar unidade de outra matéria | `app/index.html:1711,1718` |
| F15 | Match (associar pares) sempre registra acerto em `tentativas`, superestimando o domínio | `app/index.html:3157,1651` |
| F16 | Relâmpago mede tempo pelo relógio do aparelho (único timer sem offset do servidor) | `app/index.html:1516` |
| F17 | Troca de matéria com erro engolido (`.then(() => {})`) | `app/index.html:3058,942` |
| F18 | Nome do aluno com tab/quebra de linha desloca colunas no "Copiar notas" (TSV) | `painel/index.html:2946,777` |
| F19 | `fj_uma_turma_por_aluno` perdeu o `errcode '23505'` que tinha na 0056 | `0057:210` |
| F20 | Conta bloqueada continua lendo tabelas por RLS até o JWT expirar (as Edge Functions já derrubam a sessão; o acesso direto sobrevive) | `0052:147` |
| F21 | Caminho absoluto `C:/Users/Artur Morais/...` nas ferramentas de validação; `eval()` no seed | `ferramentas/validar-questoes*.js` |
| F22 | `.claude/` e `.impeccable/` fora do `.gitignore` (risco de entrarem num `git add .`) | `.gitignore` |

---

## 3. Observações (corretas, porém frágeis)

1. **Raiz de F1/F4/F5:** o pacote publicado entrega gabarito de todas as questões a qualquer aluno logado — é o que permite o app funcionar offline. Enquanto isso valer, **qualquer** superfície que mostre ao aluno uma questão do banco valendo algo (nota, duelo, dinâmica) é derrotável por casamento de conteúdo. Decisão de arquitetura a tomar antes do lançamento aberto (ver `PLANO.md`, item sobre correção no servidor × offline).
2. **`concluir_licao` confia no cliente** para `p_acertos/p_erros/p_sucesso/p_tentativas`. Os tetos e o ritmo mínimo limitam o estrago, não a fraude.
3. **Quatro funções sem `grant execute` explícito** (`publicar_pacote`, `definir_nota`, `recorrigir_atividade`, `relatorio_uso`): funcionam porque herdam `EXECUTE` de PUBLIC. Todas validam papel internamente — não há brecha, mas um hardening que revogue o padrão do PUBLIC quebraria as quatro de uma vez.
4. **`professor_da_turma` inclui `criada_por` para sempre:** o professor removido da turma mantém acesso a ela e às notas.
5. **Disciplina do professor é restrição só de UI:** `carregar()` entrega `D.questoes` completo (todas as matérias, incl. rascunhos e gabaritos) a qualquer educador. Se a confidencialidade entre disciplinas importa, tem de ir para o RLS.
6. **Tabelas de alto volume sem auditoria** (`tentativas`, `duelos`, `dinamica_respostas`, `revisao_habilidades`) — aparentemente intencional.
7. **Edge Functions sólidas:** validam JWT, exigem linha em `admins`, validam entrada, devolvem mensagem genérica, auditam, e `bloquear-aluno` derruba as sessões. Sem rate limiting (aceitável: só super chama).
8. **CSP via `<meta>`** não suporta `frame-ancestors` — o cabeçalho contra clickjacking precisa ser configurado na Vercel.

---

## 4. Ordem de correção sugerida

1. ~~**F3** (XSS professor → super): duas linhas, risco mais alto do conjunto.~~ **Feito** — migration 0060 + `esc(pub.tipo)`. O whitelist de `tipo` passou a valer para as duas origens da `criar_dinamica`.
2. ~~**F2** (farm de XP) e **F8** (esquema 58 → 59)~~ **Feito** — 0061 (F2) e `ESQUEMA_ESPERADO = 61` (F8).
3. ~~**F6** e **F7**: bugs que o aluno encontra sozinho na primeira semana de piloto.~~ **Feito** — RPC `coracoes_agora()` na 0061 (F6) e folha de confirmação do Pular (F7).
4. ~~**F4** (id da dinâmica): mesmo molde já usado no duelo.~~ **Feito** — `md5(dinamica:índice)` na 0061.
5. ~~**F22**~~ **Feito** (`.gitignore`). Restam **F9** e **F10**: higiene de painel.
6. **F1/F5** e a observação 1: exigem decisão de arquitetura — tratar junto com a estratégia de offline antes de abrir o cadastro.

Além da lista: a **observação 5** (`carregar()` entrega todas as questões, com gabaritos e rascunhos, a qualquer educador) sobe de prioridade se professores de escolas diferentes forem coexistir no mesmo banco — nesse caso é RLS, não UI, e vale tratar antes do piloto. A **observação 4** (`professor_da_turma` inclui `criada_por` para sempre) tem a mesma natureza.
