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
- [ ] Religar "Confirm email" antes do lançamento (desligado em 10 out para testes)
- **Pronto quando:** conta criada no app, login no painel como admin, tabelas no banco

## Semanas 2–3 · Painel ligado ao banco (até 31 out)
- [ ] Trilhas, questões, missões, economia/loja, ligas lendo e gravando no Supabase
- [ ] Importar conteúdo dos protótipos
- [ ] Publicar: pacote JSON versionado + histórico + voltar versão
- [ ] Tela Alunos (buscar, ativar Findout+, ver progresso)
- [ ] Deploy do painel na Vercel
- **Pronto quando:** questão cadastrada no painel aparece na versão publicada

## Semanas 4–6 · App ligado ao banco (até 21 nov)
- [ ] Sem 4: app baixa pacote publicado (cache por versão); trilhas e progresso do servidor
- [ ] Sem 5: lição grava via `concluir_licao`; corações, XP, moedas, coroas, baú, lendária reais; erros gravados
- [ ] Sem 6: ofensiva, congelador, missões diárias, revisão diária, teste de pular, loja
- [ ] PWA: manifest, ícone, service worker, fila offline
- [ ] Deploy do app na Vercel
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

## Trilha de conteúdo (semanas 2–8, em paralelo)
Meta: 3 matérias × 3 unidades × ~5 lições × 8 questões ≈ 360 questões.
- [ ] Sem 2: árvore das 3 matérias (Claude propõe, Artur aprova)
- [ ] Sem 3–4: Matemática, 120 questões (rascunhos → revisão → publicar)
- [ ] Sem 5–6: Português, 120 questões
- [ ] Sem 7–8: terceira matéria, 120 questões
