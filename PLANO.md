# Plano de lançamento — até 31 de dezembro de 2026

Equipe: Artur (produto, conteúdo, testes, contas) + Claude (código, migrations, rascunhos de questões).
Stack: sites estáticos na Vercel + Supabase (Postgres, Auth). Custo zero.

Regras: uma entrega testável por semana (sexta); fora do escopo vai para `DEPOIS.md`; se atrasar, corta-se escopo da semana seguinte, nunca o piloto.

## Fase 0 · Preparação (9–11 out)
- [x] E-mail e contas dedicadas (GitHub org `findout-jornada`, Supabase, Vercel)
- [x] Repositório clonado em `C:\Users\Carol\Documents\GitHub\findout-jornada`
- [x] Projeto Supabase `findout-jornada` (São Paulo)
- [x] Estrutura do repositório
- [ ] Terceira matéria do lançamento definida
- [ ] Git instalado (opcional)

## Semana 1 · Banco e login (até 17 out)
- [x] Migration 0001: esquema de conteúdo e do aluno, RLS, trigger de novo usuário
- [x] Migration 0002: funções de jogo (`concluir_licao`, corações, loja, baús)
- [x] Rodar migrations no SQL Editor (10 out)
- [x] Login e-mail/senha no app e no painel (Google: configurar após URLs da Vercel)
- [x] Marcar Artur como admin (10 out)
- [ ] Religar "Confirm email" antes do lançamento (desligado em 10 out para testes). Junto: configurar SMTP próprio (Resend/Brevo) no Supabase, o padrão manda só ~2 e-mails/hora
- [x] Google Cloud: projeto `findout-jornada`, cliente OAuth criado, provider Google salvo no Supabase (10 out)
- [ ] Google: Branding com página inicial + privacidade + termos, depois "Publicar app" (hoje está "Testando", só testadores entram)
- [x] Páginas `app/privacidade.html` e `app/termos.html` criadas (10 out); publicar pelo GitHub Desktop
- **Pronto quando:** conta criada no app, login no painel como admin, tabelas no banco

## Semanas 2–3 · Painel ligado ao banco (até 31 out)
- [x] Trilhas, questões, missões, economia/loja, ligas lendo e gravando no Supabase (código pronto em 10 out; testar no ar)
- [x] Questões com imagem (upload para o Storage), fonte e dificuldade; filtros por matéria/unidade/tipo/status
- [x] Importar conteúdo dos protótipos (botão na Visão geral quando o banco está vazio)
- [x] Publicar: pacote JSON versionado + histórico + voltar versão
- [x] Tela Alunos (buscar, ativar Findout+, ver progresso) e métricas na Visão geral
- [x] Rodar `0003_admin.sql` no SQL Editor (10 out)
- [x] Painel no ar e funcionando (10 out); migration `0004_admins.sql` + botão "Tornar admin" na aba Alunos
- [ ] Testar "Tornar admin" com uma segunda conta
- [x] Deploy do painel na Vercel: https://findout-jornada-painel.vercel.app (10 out)
- [x] Deploy do app na Vercel: https://findout-jornada-app.vercel.app (10 out)
- [x] Supabase → Authentication → URL Configuration (Site URL = app; redirect = app e painel) (10 out)
- [x] Entrar com Google funcionando em modo teste (10 out); falta Branding + Publicar app para liberar a todos
- **Pronto quando:** questão cadastrada no painel aparece na versão publicada

## Semanas 4–6 · App ligado ao banco (até 21 nov)
- [x] App baixa pacote publicado (cache por versão); trilhas e progresso do servidor (código em 10 out)
- [x] Lição grava via `concluir_licao`; corações, XP, moedas, coroas, baú, lendária reais; erros gravados
- [x] Ofensiva, congelador, missões diárias, revisão diária, teste de pular, loja, relâmpago, perfil
- [x] PWA: manifest, ícones, service worker (casca offline). Fila offline de lições fica para depois
- [x] Deploy do app na Vercel (publicar pelo GitHub Desktop)
- [ ] Testar no celular com conteúdo publicado e corrigir o que aparecer
- **Pronto quando:** lição no celular, progresso aparece no computador

## Semanas 7–8 · Liga, loja, acabamento (até 5 dez)
- [ ] Liga semanal com pg_cron (fecha domingo, promove 7, rebaixa 5, paga top 3)
- [ ] Findout+ manual (painel ativa; app mostra Pix/contato)
- [ ] Métricas no painel
- [ ] Boas-vindas, termos de uso, revisão de textos/sons/animações
- [ ] Domínio próprio (opcional)
- **Pronto quando:** dois usuários na mesma liga, ranking muda ao fazer lição

## Semanas 9–10 · Piloto (8–19 dez)
- [ ] 10 a 30 pessoas por link, 7 dias
- [ ] Sentry ligado; correções diárias
- [ ] Ajuste de economia pelos números
- **Pronto quando:** uma semana sem bug bloqueante; metade do piloto volta no dia seguinte

## Semanas 11–12 · Lançamento (22–31 dez)
- [ ] Congelar código
- [ ] Conteúdo final publicado
- [ ] Checklist: Google login no domínio final, PWA instala em iPhone e Android, backup do Supabase, e-mail de recuperação, página pública com botão Abrir
- [ ] Divulgar o link

## Motor de aprendizagem personalizada (out–nov, derivado do "Prompt Mestre")

Decisões: sem migração de stack (fica HTML+JS+Supabase); correção da trilha no servidor só será decidida junto com a estratégia offline, antes do lançamento aberto. Cada fase é uma entrega independente (migration + painel + app) e pode rodar em sessões paralelas.

- [x] **Fase A — Tentativa por questão** (migration 0046): tabela `tentativas` (questão, acertou, tempo, nº da vez, resposta) alimentada pelo `concluir_licao`; app instrumentado com tempo por questão e fallback se a migration não rodou. Atividades de turma já tinham esse grão.
- [x] **Fase B — Habilidades** (migration 0047): tabelas `habilidades` (código BNCC/ENEM cadastrado, nunca inventado), `questao_habilidades` e `habilidade_prerequisitos`; aba Habilidades no painel (CRUD, pré-requisitos por código, contagem de questões) e campo "Habilidades" no editor de questão. Falta: popular o cadastro com os códigos oficiais (trabalho de conteúdo, não de código).
- [x] **Fase C — Domínio por habilidade** (migration 0048): função `dominio_habilidades` agrega `tentativas` × `questao_habilidades` nos estados sem evidência → evidência insuficiente → em desenvolvimento → dominada → precisa de revisão (limiares em `parametros.dominio`, explicáveis; nunca declara domínio com 1 resposta). No app: Perfil → "Domínio por habilidade". No painel: bloco no raio-x do aluno (mesma permissão do relatorio_aluno).
- [x] **Fase D — Revisão e recomendação** (migration 0049): tabela `revisao_habilidades` (fila de revisão espaçada por aluno × habilidade, intervalos 1-3-7-16-35-60 dias em `parametros.revisao_espacada`), mantida por gatilho sobre `tentativas`; `revisao_do_dia()` alimenta a Revisão Diária do app (fila primeiro, depois erros + mistura); `recomendacoes(p_user)` gera sugestões por regras com justificativa ("sugerimos X porque você está errando Y, e X é pré-requisito dela") — visíveis na aba Treinar do app e no raio-x do aluno no painel. Sem habilidades vinculadas, tudo se comporta como antes.
- [ ] **Fase E — Diagnóstico e Modo B**: diagnóstico opcional de entrada (por objetivo: ENEM, série, reforço) que semeia o domínio inicial; trilha personalizada sugerida a partir do diagnóstico (a tela "Por qual disciplina vamos começar?" é a porta).
- [ ] **Engenharia (paralelo)**: testes SQL das funções críticas (correção, XP, ofensiva, ligas) rodáveis no SQL Editor; segundo projeto Supabase como homologação; começar a fatiar `app/index.html` e `painel/index.html` em módulos.

## Trilha de conteúdo (semanas 2–8, em paralelo)
Meta: 3 matérias × 3 unidades × ~5 lições × 8 questões ≈ 360 questões.
- [x] Sem 2: árvore inicial das matérias + 112 questões de partida (`0005_conteudo.sql`, 10 out): Matemática 44, Português 28, Biologia 24, História 16 (História foi criada pelo Artur no painel)
- [ ] Sem 3–4: Matemática, 120 questões (rascunhos → revisão → publicar)
- [ ] Sem 5–6: Português, 120 questões
- [ ] Sem 7–8: terceira matéria, 120 questões
