-- =====================================================================
-- Findout Jornada · Migration 0051 · Cadastro de habilidades das matérias novas
-- Rodar no SQL Editor do Supabase depois da 0050. Idempotente: pode rodar de novo.
--
-- Popula o cadastro da 0047 para as 5 matérias recentes (gmt, rac, dev,
-- log, dat): 50 habilidades — UMA POR UNIDADE —, os pré-requisitos entre
-- elas e o vínculo questão ↔ habilidade de TODAS as questões dessas
-- unidades (as 480 + as 120 da 0050). Com isso o domínio (0048), a
-- revisão espaçada e as recomendações (0049) passam a funcionar de
-- verdade nessas matérias.
--
-- Códigos: referencial 'propria' com formato MAT-UNIDADE (ex.: LOG-ALG).
-- Esses conteúdos não têm código BNCC/ENEM próprio (cursos técnicos) ou
-- exigiriam copiar do documento oficial — e a regra do projeto é nunca
-- inventar código oficial. Para recodificar depois (ex.: Geometria em
-- códigos BNCC), basta editar o campo código na aba Habilidades.
--
-- id da habilidade = md5('hab:' || codigo) para a migration ser idempotente.
-- =====================================================================

-- auditoria da 0047 desligada durante a carga em massa (religada no fim)
alter table public.habilidades disable trigger auditoria_habilidades;
alter table public.questao_habilidades disable trigger auditoria_questao_habilidades;
alter table public.habilidade_prerequisitos disable trigger auditoria_habilidade_prerequisitos;

insert into public.habilidades (id, codigo, nome, descricao, materia_id, referencial) values
-- Geometria
(md5('hab:GMT-BASE')::uuid,  'GMT-BASE',  'Elementos fundamentais da geometria', 'Reconhecer ponto, reta, plano e segmentos e classificar ângulos (agudo, reto, obtuso, raso; complementares e suplementares).', 'gmt', 'propria'),
(md5('hab:GMT-POLI')::uuid,  'GMT-POLI',  'Polígonos e triângulos', 'Classificar polígonos e triângulos e aplicar a soma dos ângulos internos e a desigualdade triangular.', 'gmt', 'propria'),
(md5('hab:GMT-PER')::uuid,   'GMT-PER',   'Perímetro e área de retângulos', 'Calcular perímetro e área de quadrados e retângulos em situações concretas, com as unidades corretas.', 'gmt', 'propria'),
(md5('hab:GMT-AREA')::uuid,  'GMT-AREA',  'Áreas de triângulos, paralelogramos e círculo', 'Calcular áreas com base × altura, metade de base × altura e πr², e o comprimento 2πr.', 'gmt', 'propria'),
(md5('hab:GMT-PIT')::uuid,   'GMT-PIT',   'Teorema de Pitágoras', 'Identificar catetos e hipotenusa e aplicar a relação de Pitágoras para calcular distâncias.', 'gmt', 'propria'),
(md5('hab:GMT-SEM')::uuid,   'GMT-SEM',   'Semelhança e Tales', 'Usar proporções entre figuras semelhantes, escalas e o teorema de Tales.', 'gmt', 'propria'),
(md5('hab:GMT-ESP')::uuid,   'GMT-ESP',   'Geometria espacial', 'Reconhecer sólidos geométricos e calcular volumes de prismas, cubos e cilindros.', 'gmt', 'propria'),
(md5('hab:GMT-CART')::uuid,  'GMT-CART',  'Plano cartesiano', 'Localizar pontos e quadrantes e calcular distâncias e pontos médios no plano.', 'gmt', 'propria'),
(md5('hab:GMT-CIRC')::uuid,  'GMT-CIRC',  'Elementos do círculo', 'Identificar raio, diâmetro, corda, arco e tangente e calcular ângulos centrais e setores.', 'gmt', 'propria'),
(md5('hab:GMT-TRANS')::uuid, 'GMT-TRANS', 'Simetria e transformações', 'Reconhecer eixos de simetria e os efeitos de reflexão, rotação, translação e ampliação.', 'gmt', 'propria'),
-- Raciocínio Lógico
(md5('hab:RAC-PROP')::uuid,  'RAC-PROP',  'Proposições e conectivos', 'Identificar proposições e operar com e, ou, não e se…então.', 'rac', 'propria'),
(md5('hab:RAC-ARG')::uuid,   'RAC-ARG',   'Validade de argumentos', 'Separar premissas de conclusão e reconhecer deduções válidas e inválidas.', 'rac', 'propria'),
(md5('hab:RAC-SEQ')::uuid,   'RAC-SEQ',   'Sequências e padrões', 'Descobrir a regra de formação de sequências numéricas e de figuras.', 'rac', 'propria'),
(md5('hab:RAC-CONJ')::uuid,  'RAC-CONJ',  'Analogias e conjuntos', 'Resolver analogias e problemas de pertencimento com diagramas de conjuntos.', 'rac', 'propria'),
(md5('hab:RAC-VERD')::uuid,  'RAC-VERD',  'Verdade e mentira', 'Resolver enigmas de personagens que sempre falam a verdade ou sempre mentem.', 'rac', 'propria'),
(md5('hab:RAC-CONT')::uuid,  'RAC-CONT',  'Contagem esperta', 'Usar o princípio multiplicativo e contagens organizadas sem listar tudo.', 'rac', 'propria'),
(md5('hab:RAC-QUANT')::uuid, 'RAC-QUANT', 'Quantificadores e negação', 'Negar corretamente frases com todo, algum e nenhum.', 'rac', 'propria'),
(md5('hab:RAC-ESTR')::uuid,  'RAC-ESTR',  'Estratégias de resolução', 'Escolher estratégias: testar casos, montar tabela, resolver de trás para frente.', 'rac', 'propria'),
(md5('hab:RAC-PROB')::uuid,  'RAC-PROB',  'Probabilidade básica', 'Calcular probabilidades de eventos simples e usar o evento complementar, evitando a falácia do jogador.', 'rac', 'propria'),
(md5('hab:RAC-FAL')::uuid,   'RAC-FAL',   'Reconhecer falácias', 'Identificar generalização apressada, falsa causa, ad hominem, apelo à popularidade e falso dilema.', 'rac', 'propria'),
-- Desenvolvimento de Software
(md5('hab:DEV-TS')::uuid,    'DEV-TS',    'TypeScript e JavaScript moderno', 'Entender tipagem estática, transpilação e os recursos modernos da linguagem.', 'dev', 'propria'),
(md5('hab:DEV-ARQ')::uuid,   'DEV-ARQ',   'Arquitetura de software', 'Reconhecer camadas, acoplamento, coesão e padrões básicos de organização.', 'dev', 'propria'),
(md5('hab:DEV-BD')::uuid,    'DEV-BD',    'Bancos de dados', 'Modelar tabelas, chaves e relacionamentos e comparar SQL e NoSQL.', 'dev', 'propria'),
(md5('hab:DEV-API')::uuid,   'DEV-API',   'Backend e APIs', 'Entender HTTP, REST, autenticação e o ciclo requisição-resposta.', 'dev', 'propria'),
(md5('hab:DEV-ENG')::uuid,   'DEV-ENG',   'Engenharia de software', 'Aplicar testes, boas práticas e processos de desenvolvimento em equipe.', 'dev', 'propria'),
(md5('hab:DEV-INFRA')::uuid, 'DEV-INFRA', 'Docker, deploy e infraestrutura', 'Entender contêineres, ambientes e o caminho do código até a produção.', 'dev', 'propria'),
(md5('hab:DEV-IA')::uuid,    'DEV-IA',    'IA aplicada ao desenvolvimento', 'Usar IA no fluxo de trabalho com senso crítico e revisão humana.', 'dev', 'propria'),
(md5('hab:DEV-BI')::uuid,    'DEV-BI',    'Engenharia de dados e BI', 'Entender pipelines, ETL e painéis de Business Intelligence.', 'dev', 'propria'),
(md5('hab:DEV-GIT')::uuid,   'DEV-GIT',   'Git e versionamento', 'Usar commits, branches, merges e pull requests para colaborar com segurança.', 'dev', 'propria'),
(md5('hab:DEV-SEG')::uuid,   'DEV-SEG',   'Segurança de aplicações', 'Proteger senhas com hash, usar HTTPS e prevenir SQL injection, XSS e phishing.', 'dev', 'propria'),
-- Lógica de Programação
(md5('hab:LOG-ALG')::uuid,   'LOG-ALG',   'Algoritmos e sequências', 'Descrever soluções como passos ordenados, finitos e sem ambiguidade.', 'log', 'propria'),
(md5('hab:LOG-VAR')::uuid,   'LOG-VAR',   'Variáveis e dados', 'Usar variáveis, tipos e atribuições em pseudocódigo.', 'log', 'propria'),
(md5('hab:LOG-COND')::uuid,  'LOG-COND',  'Condicionais', 'Construir decisões com se/senão e condições compostas.', 'log', 'propria'),
(md5('hab:LOG-LACO')::uuid,  'LOG-LACO',  'Laços de repetição', 'Usar enquanto e para, com contadores e acumuladores.', 'log', 'propria'),
(md5('hab:LOG-FUNC')::uuid,  'LOG-FUNC',  'Funções e modularização', 'Dividir a solução em funções com parâmetros e retorno.', 'log', 'propria'),
(md5('hab:LOG-LISTA')::uuid, 'LOG-LISTA', 'Listas e coleções', 'Guardar, acessar e percorrer coleções de valores.', 'log', 'propria'),
(md5('hab:LOG-ERRO')::uuid,  'LOG-ERRO',  'Erros e depuração', 'Localizar e corrigir erros de lógica e de execução testando hipóteses.', 'log', 'propria'),
(md5('hab:LOG-PROB')::uuid,  'LOG-PROB',  'Resolução de problemas', 'Montar soluções completas combinando variáveis, condições, laços e funções.', 'log', 'propria'),
(md5('hab:LOG-MAT')::uuid,   'LOG-MAT',   'Matrizes e tabelas', 'Endereçar elementos por linha e coluna e percorrer tabelas com laços aninhados.', 'log', 'propria'),
(md5('hab:LOG-REC')::uuid,   'LOG-REC',   'Recursão e divisão de problemas', 'Entender caso base, chamada recursiva e a estratégia dividir para conquistar.', 'log', 'propria'),
-- Análise e Ciência de Dados
(md5('hab:DAT-DADO')::uuid,  'DAT-DADO',  'Dado, informação e conhecimento', 'Diferenciar dado bruto, informação e conhecimento e os tipos de dados.', 'dat', 'propria'),
(md5('hab:DAT-COLETA')::uuid,'DAT-COLETA','Coleta e qualidade de dados', 'Avaliar fontes, formas de coleta e a qualidade do que foi coletado.', 'dat', 'propria'),
(md5('hab:DAT-DESC')::uuid,  'DAT-DESC',  'Estatística descritiva', 'Calcular e interpretar média, mediana, moda e medidas de dispersão.', 'dat', 'propria'),
(md5('hab:DAT-AMOSTRA')::uuid,'DAT-AMOSTRA','Amostras e correlação', 'Entender amostragem representativa e distinguir correlação de causalidade.', 'dat', 'propria'),
(md5('hab:DAT-EDA')::uuid,   'DAT-EDA',   'Análise exploratória', 'Explorar bases com perguntas, agregações, comparações e indicadores.', 'dat', 'propria'),
(md5('hab:DAT-VIZ')::uuid,   'DAT-VIZ',   'Visualização de dados', 'Escolher o gráfico certo para cada mensagem e ler gráficos criticamente.', 'dat', 'propria'),
(md5('hab:DAT-ML')::uuid,    'DAT-ML',    'Machine learning: conceitos', 'Entender treino e teste, classificação, regressão e os limites dos modelos.', 'dat', 'propria'),
(md5('hab:DAT-ETICA')::uuid, 'DAT-ETICA', 'Ética e decisões com dados', 'Reconhecer vieses, privacidade e o uso responsável de dados.', 'dat', 'propria'),
(md5('hab:DAT-LIMP')::uuid,  'DAT-LIMP',  'Limpeza e preparação de dados', 'Tratar ausentes, duplicatas, padronização e outliers com critério documentado.', 'dat', 'propria'),
(md5('hab:DAT-IND')::uuid,   'DAT-IND',   'Métricas e indicadores', 'Calcular e interpretar KPIs como conversão e ticket médio, com meta, sazonalidade e tendência.', 'dat', 'propria')
on conflict do nothing;

-- Pré-requisitos (o que o aluno precisa dominar antes), por código
insert into public.habilidade_prerequisitos (habilidade_id, prerequisito_id)
select h.id, p.id from (values
  -- Geometria: dos elementos às aplicações
  ('GMT-POLI', 'GMT-BASE'), ('GMT-PER', 'GMT-POLI'), ('GMT-AREA', 'GMT-PER'),
  ('GMT-PIT', 'GMT-POLI'), ('GMT-SEM', 'GMT-POLI'), ('GMT-ESP', 'GMT-AREA'),
  ('GMT-CART', 'GMT-PIT'), ('GMT-CIRC', 'GMT-AREA'), ('GMT-TRANS', 'GMT-SEM'),
  -- Raciocínio Lógico
  ('RAC-ARG', 'RAC-PROP'), ('RAC-CONJ', 'RAC-PROP'), ('RAC-VERD', 'RAC-PROP'),
  ('RAC-QUANT', 'RAC-PROP'), ('RAC-ESTR', 'RAC-ARG'), ('RAC-PROB', 'RAC-CONT'),
  ('RAC-FAL', 'RAC-ARG'),
  -- Desenvolvimento de Software
  ('DEV-ARQ', 'DEV-TS'), ('DEV-API', 'DEV-BD'), ('DEV-API', 'DEV-TS'),
  ('DEV-ENG', 'DEV-ARQ'), ('DEV-INFRA', 'DEV-ENG'), ('DEV-IA', 'DEV-ENG'),
  ('DEV-BI', 'DEV-BD'), ('DEV-SEG', 'DEV-API'),
  -- Lógica de Programação: a escada clássica
  ('LOG-VAR', 'LOG-ALG'), ('LOG-COND', 'LOG-VAR'), ('LOG-LACO', 'LOG-COND'),
  ('LOG-FUNC', 'LOG-LACO'), ('LOG-LISTA', 'LOG-VAR'), ('LOG-ERRO', 'LOG-COND'),
  ('LOG-PROB', 'LOG-FUNC'), ('LOG-PROB', 'LOG-LISTA'),
  ('LOG-MAT', 'LOG-LISTA'), ('LOG-MAT', 'LOG-LACO'), ('LOG-REC', 'LOG-FUNC'),
  -- Análise e Ciência de Dados
  ('DAT-COLETA', 'DAT-DADO'), ('DAT-DESC', 'DAT-DADO'), ('DAT-AMOSTRA', 'DAT-DESC'),
  ('DAT-EDA', 'DAT-DESC'), ('DAT-VIZ', 'DAT-DESC'), ('DAT-ML', 'DAT-AMOSTRA'),
  ('DAT-ETICA', 'DAT-COLETA'), ('DAT-LIMP', 'DAT-COLETA'), ('DAT-IND', 'DAT-EDA')
) v(c, pc)
join public.habilidades h on h.codigo = v.c
join public.habilidades p on p.codigo = v.pc
on conflict do nothing;

-- Vínculo questão ↔ habilidade: toda questão de cada unidade recebe a
-- habilidade da unidade (vale também para questões criadas no painel
-- dentro dessas unidades; rodar de novo vincula as que surgirem depois)
insert into public.questao_habilidades (questao_id, habilidade_id)
select q.id, h.id
from (values
  ('uni:gmt:base', 'GMT-BASE'), ('uni:gmt:poli', 'GMT-POLI'), ('uni:gmt:per', 'GMT-PER'),
  ('uni:gmt:area', 'GMT-AREA'), ('uni:gmt:pit', 'GMT-PIT'), ('uni:gmt:sem', 'GMT-SEM'),
  ('uni:gmt:esp', 'GMT-ESP'), ('uni:gmt:cart', 'GMT-CART'), ('uni:gmt:circ', 'GMT-CIRC'), ('uni:gmt:trans', 'GMT-TRANS'),
  ('uni:rac:prop', 'RAC-PROP'), ('uni:rac:arg', 'RAC-ARG'), ('uni:rac:seq', 'RAC-SEQ'),
  ('uni:rac:conj', 'RAC-CONJ'), ('uni:rac:verd', 'RAC-VERD'), ('uni:rac:cont', 'RAC-CONT'),
  ('uni:rac:quant', 'RAC-QUANT'), ('uni:rac:estr', 'RAC-ESTR'), ('uni:rac:prob', 'RAC-PROB'), ('uni:rac:fal', 'RAC-FAL'),
  ('uni:dev:ts', 'DEV-TS'), ('uni:dev:arq', 'DEV-ARQ'), ('uni:dev:bd', 'DEV-BD'),
  ('uni:dev:api', 'DEV-API'), ('uni:dev:eng', 'DEV-ENG'), ('uni:dev:infra', 'DEV-INFRA'),
  ('uni:dev:ia', 'DEV-IA'), ('uni:dev:bi', 'DEV-BI'), ('uni:dev:git', 'DEV-GIT'), ('uni:dev:seg', 'DEV-SEG'),
  ('uni:log:alg', 'LOG-ALG'), ('uni:log:var', 'LOG-VAR'), ('uni:log:cond', 'LOG-COND'),
  ('uni:log:laco', 'LOG-LACO'), ('uni:log:func', 'LOG-FUNC'), ('uni:log:lista', 'LOG-LISTA'),
  ('uni:log:erro', 'LOG-ERRO'), ('uni:log:prob', 'LOG-PROB'), ('uni:log:mat', 'LOG-MAT'), ('uni:log:rec', 'LOG-REC'),
  ('uni:dat:dado', 'DAT-DADO'), ('uni:dat:coleta', 'DAT-COLETA'), ('uni:dat:desc', 'DAT-DESC'),
  ('uni:dat:amostra', 'DAT-AMOSTRA'), ('uni:dat:eda', 'DAT-EDA'), ('uni:dat:viz', 'DAT-VIZ'),
  ('uni:dat:ml', 'DAT-ML'), ('uni:dat:etica', 'DAT-ETICA'), ('uni:dat:limp', 'DAT-LIMP'), ('uni:dat:ind', 'DAT-IND')
) m(uni, cod)
join public.questoes q on q.unidade_id = md5(m.uni)::uuid
join public.habilidades h on h.codigo = m.cod
on conflict do nothing;

alter table public.habilidades enable trigger auditoria_habilidades;
alter table public.questao_habilidades enable trigger auditoria_questao_habilidades;
alter table public.habilidade_prerequisitos enable trigger auditoria_habilidade_prerequisitos;

insert into public.schema_versao (versao) values (51) on conflict do nothing;
