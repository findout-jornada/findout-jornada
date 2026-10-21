-- =====================================================================
-- Findout Jornada · Migration 0041 · Curso: Desenvolvimento de Software
-- (4 seções, 8 unidades = os 8 módulos do curso, 16 lições, 96 questões)
-- Rodar no SQL Editor do Supabase depois da 0040. Idempotente: pode rodar de novo.
-- Depois de rodar, abra o painel: ele publica a nova versão sozinho.
-- A matéria fica FORA do Mapa do ENEM (aparece só em "Suas matérias"), como as
-- demais da constante FORA_DO_MAPA em app/index.html (que ganha o id 'dev').
-- Módulos do curso → unidades: 01 TypeScript · 02 Arquitetura de software ·
-- 03 Banco de dados · 04 Backend e APIs · 05 Engenharia de software ·
-- 06 Docker, deploy e infraestrutura · 07 IA aplicada · 08 Dados e BI.
-- Regra do seed: o id da questão vem de md5(lição + enunciado); por isso cada enunciado é único dentro da lição.
-- As alternativas de múltipla escolha são escritas com a resposta na posição A e
-- embaralhadas no fim do arquivo (mesmo molde da 0019/0039) — nada a fazer depois.
-- =====================================================================

create or replace function public.fj_seed_q(p_mat text, p_uni text, p_lic text, p_ordem int, p_tipo text, p_enun text, p_dados jsonb, p_expl text, p_dif int default 2)
returns void language plpgsql as $$
declare uni uuid := md5('uni:' || p_uni)::uuid; lic uuid := md5('lic:' || p_lic)::uuid; qid uuid := md5('q:' || p_lic || '|' || p_enun)::uuid;
begin
  insert into public.questoes (id, materia_id, unidade_id, tipo, enunciado, dados, explicacao, status)
  values (qid, p_mat, uni, p_tipo, p_enun, p_dados || jsonb_build_object('dificuldade', p_dif), p_expl, 'publicada')
  on conflict (id) do nothing;
  insert into public.licao_questoes (licao_id, questao_id, ordem) values (lic, qid, p_ordem) on conflict do nothing;
end $$;

insert into public.materias (id, nome, sigla, cor, ativa, ordem) values
('dev', 'Desenvolvimento de Software', 'DV', '#5B6CFA', true, 16)
on conflict (id) do nothing;

insert into public.secoes (id, materia_id, titulo, ordem) values
(md5('sec:dev:fundamentos')::uuid, 'dev', 'Programação e arquitetura', 0),
(md5('sec:dev:dados')::uuid, 'dev', 'Dados e backend', 1),
(md5('sec:dev:engenharia')::uuid, 'dev', 'Engenharia e operação', 2),
(md5('sec:dev:ia')::uuid, 'dev', 'IA e dados', 3)
on conflict (id) do nothing;

insert into public.unidades (id, secao_id, titulo, ordem) values
(md5('uni:dev:ts')::uuid, md5('sec:dev:fundamentos')::uuid, 'TypeScript e desenvolvimento moderno', 0),
(md5('uni:dev:arq')::uuid, md5('sec:dev:fundamentos')::uuid, 'Fundamentos de arquitetura de software', 1),
(md5('uni:dev:bd')::uuid, md5('sec:dev:dados')::uuid, 'Banco de dados e arquitetura de dados', 0),
(md5('uni:dev:api')::uuid, md5('sec:dev:dados')::uuid, 'Backend e APIs', 1),
(md5('uni:dev:eng')::uuid, md5('sec:dev:engenharia')::uuid, 'Engenharia de software', 0),
(md5('uni:dev:infra')::uuid, md5('sec:dev:engenharia')::uuid, 'Docker, deploy e infraestrutura', 1),
(md5('uni:dev:ia')::uuid, md5('sec:dev:ia')::uuid, 'IA aplicada ao desenvolvimento', 0),
(md5('uni:dev:bi')::uuid, md5('sec:dev:ia')::uuid, 'Engenharia de dados e Business Intelligence', 1)
on conflict (id) do nothing;

insert into public.licoes (id, unidade_id, titulo, descricao, ordem) values
(md5('lic:dev:ts:1')::uuid, md5('uni:dev:ts')::uuid, 'Tipos e variáveis', 'Tipagem estática, inferência e os tipos básicos do TypeScript.', 0),
(md5('lic:dev:ts:2')::uuid, md5('uni:dev:ts')::uuid, 'Funções e recursos modernos', 'Arrow functions, async/await, desestruturação e módulos.', 1),
(md5('lic:dev:arq:1')::uuid, md5('uni:dev:arq')::uuid, 'Modularização e responsabilidades', 'Coesão, acoplamento e separação em camadas.', 0),
(md5('lic:dev:arq:2')::uuid, md5('uni:dev:arq')::uuid, 'Padrões e decisões arquiteturais', 'MVC, injeção de dependência, monólito × microsserviços e trade-offs.', 1),
(md5('lic:dev:bd:1')::uuid, md5('uni:dev:bd')::uuid, 'SQL essencial', 'SELECT, JOIN, GROUP BY, chaves e índices.', 0),
(md5('lic:dev:bd:2')::uuid, md5('uni:dev:bd')::uuid, 'Modelagem e integridade', 'Normalização, relacionamentos, constraints e transações.', 1),
(md5('lic:dev:api:1')::uuid, md5('uni:dev:api')::uuid, 'APIs REST', 'Verbos HTTP, códigos de status e desenho de rotas.', 0),
(md5('lic:dev:api:2')::uuid, md5('uni:dev:api')::uuid, 'Autenticação e integrações', 'Autenticação × autorização, JWT, senhas e webhooks.', 1),
(md5('lic:dev:eng:1')::uuid, md5('uni:dev:eng')::uuid, 'Git e trabalho em equipe', 'Commits, branches, merge e revisão de código.', 0),
(md5('lic:dev:eng:2')::uuid, md5('uni:dev:eng')::uuid, 'Testes e qualidade', 'Testes unitários e de integração, TDD e dívida técnica.', 1),
(md5('lic:dev:infra:1')::uuid, md5('uni:dev:infra')::uuid, 'Contêineres e ambientes', 'Docker, imagens, variáveis de ambiente e os ambientes de dev a produção.', 0),
(md5('lic:dev:infra:2')::uuid, md5('uni:dev:infra')::uuid, 'CI/CD e operação', 'Pipelines, deploy, rollback, logs e monitoramento.', 1),
(md5('lic:dev:ia:1')::uuid, md5('uni:dev:ia')::uuid, 'LLMs e embeddings', 'Como os modelos de linguagem funcionam: tokens, prompts e busca semântica.', 0),
(md5('lic:dev:ia:2')::uuid, md5('uni:dev:ia')::uuid, 'RAG, agentes e avaliação', 'RAG, agentes com ferramentas, fine-tuning e como avaliar.', 1),
(md5('lic:dev:bi:1')::uuid, md5('uni:dev:bi')::uuid, 'ETL e SQL analítico', 'Pipelines de dados, data warehouse e agregações.', 0),
(md5('lic:dev:bi:2')::uuid, md5('uni:dev:bi')::uuid, 'BI, Python e estatística', 'Dashboards no Power BI, pandas e estatística básica.', 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- dev:ts:1 · Tipos e variáveis
-- ---------------------------------------------------------------
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:1', 0, 'mc', $q$Qual é a principal vantagem da tipagem estática do TypeScript em relação ao JavaScript puro?$q$, $j${"opts":["Erros de tipo são apontados antes de o código rodar","O código executa mais rápido no navegador","Não é mais preciso escrever funções","Os arquivos finais ficam menores"],"a":0}$j$, $q$O compilador confere os tipos enquanto você escreve; ao rodar, o TypeScript vira JavaScript comum.$q$, 2);
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:1', 1, 'mc', $q$Qual declaração cria uma variável que NÃO pode ser reatribuída?$q$, $j${"opts":["const limite = 10","let limite = 10","var limite = 10","limite = 10"],"a":0}$j$, $q$const impede a reatribuição; let e var permitem trocar o valor depois.$q$, 1);
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:1', 2, 'mc', $q$Na linha let nome = 'Ana', o TypeScript entende que nome é do tipo string sem você declarar. Esse recurso chama-se:$q$, $j${"opts":["Inferência de tipos","Herança","Compilação","Minificação"],"a":0}$j$, $q$O compilador deduz o tipo pelo valor inicial — por isso nem tudo precisa de anotação.$q$, 2);
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:1', 3, 'tf', $q$Julgue a afirmação sobre union types$q$, $j${"stmt":"No TypeScript, o tipo string | number aceita tanto textos quanto números.","a":true}$j$, $q$Verdadeiro: a barra vertical cria uma união de tipos — o valor pode ser um ou outro.$q$, 2);
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:1', 4, 'bank', $q$Complete a frase sobre os tipos básicos$q$, $j${"parts":["O tipo "," representa textos e o tipo "," representa verdadeiro ou falso."],"a":["string","boolean"],"extra":["number","array"]}$j$, $q$string = texto; boolean = true/false; number = números; arrays guardam listas.$q$, 1);
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:1', 5, 'match', $q$Associe o valor ao seu tipo no TypeScript$q$, $j${"pairs":[["'Olá'","string"],["42","number"],["true","boolean"],["[1, 2, 3]","array de number"]]}$j$, $q$Texto entre aspas é string; 42 é number; true é boolean; a lista é um array de números.$q$, 1);

-- dev:ts:2 · Funções e recursos modernos
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:2', 0, 'mc', $q$Qual sintaxe define corretamente uma arrow function que dobra um número?$q$, $j${"opts":["const dobro = (n) => n * 2","function => dobro(n) { n * 2 }","arrow dobro(n) = n * 2","const dobro -> (n) { return n * 2 }"],"a":0}$j$, $q$Arrow function: parâmetros, a seta => e a expressão de retorno.$q$, 2);
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:2', 1, 'mc', $q$Para que serve o async/await?$q$, $j${"opts":["Escrever código assíncrono (como chamadas de rede) de forma parecida com código comum, esperando promessas","Deixar o código mais bonito, sem mudar o comportamento","Criar laços de repetição","Declarar constantes"],"a":0}$j$, $q$await pausa a função até a Promise resolver, sem travar o resto do programa.$q$, 2);
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:2', 2, 'mc', $q$No código const {nome, email} = usuario, o que acontece?$q$, $j${"opts":["Desestruturação: as propriedades nome e email do objeto viram variáveis","O objeto usuario é apagado","Um novo objeto vazio é criado","As variáveis recebem sempre null"],"a":0}$j$, $q$A desestruturação extrai propriedades do objeto direto para variáveis com o mesmo nome.$q$, 2);
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:2', 3, 'tf', $q$Julgue a afirmação sobre funções async$q$, $j${"stmt":"Uma função declarada com async sempre devolve uma Promise.","a":true}$j$, $q$Verdadeiro: mesmo que retorne um valor simples, ele chega embrulhado numa Promise.$q$, 3);
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:2', 4, 'bank', $q$Complete a frase sobre módulos$q$, $j${"parts":["Para disponibilizar uma função a outros arquivos usamos ","; para usá-la em outro arquivo usamos ","."],"a":["export","import"],"extra":["return","await"]}$j$, $q$export publica; import consome — é assim que o código se divide em módulos.$q$, 2);
select public.fj_seed_q('dev', 'dev:ts', 'dev:ts:2', 5, 'order', $q$Ordene o que acontece quando uma função async busca dados$q$, $j${"items":["A função é chamada","O await pausa a função até a resposta chegar","A resposta chega do servidor","O código seguinte usa os dados"]}$j$, $q$Chamada → await aguarda → resposta chega → a execução continua com os dados.$q$, 2);

-- ---------------------------------------------------------------
-- dev:arq:1 · Modularização e responsabilidades
-- ---------------------------------------------------------------
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:1', 0, 'mc', $q$O princípio da responsabilidade única (SRP) diz que:$q$, $j${"opts":["Cada módulo ou classe deve ter um único motivo para mudar","Cada sistema deve ter um único programador","Todo código deve ficar em um único arquivo","Cada empresa deve ter um único sistema"],"a":0}$j$, $q$Se um módulo muda por vários motivos diferentes, ele acumula responsabilidades demais.$q$, 2);
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:1', 1, 'mc', $q$Em um bom design de software, buscamos módulos com:$q$, $j${"opts":["Alta coesão e baixo acoplamento","Alto acoplamento e baixa coesão","O máximo de dependências entre si","Um módulo central que faz tudo"],"a":0}$j$, $q$Coeso por dentro (faz uma coisa bem) e independente por fora (depende pouco dos outros).$q$, 2);
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:1', 2, 'mc', $q$Separar o sistema em camadas (apresentação, negócio, dados) ajuda principalmente a:$q$, $j${"opts":["Mudar uma parte sem quebrar as outras","Eliminar a necessidade de testes","Reduzir o número de arquivos","Dispensar o banco de dados"],"a":0}$j$, $q$Cada camada tem um papel: trocar a tela não deveria mexer na regra de negócio, e vice-versa.$q$, 2);
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:1', 3, 'tf', $q$Julgue a afirmação sobre acoplamento$q$, $j${"stmt":"Quanto mais um módulo depende dos detalhes internos dos outros, mais fácil é mantê-lo.","a":false}$j$, $q$Falso: alto acoplamento dificulta a manutenção — mudar um módulo arrasta mudanças nos outros.$q$, 2);
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:1', 4, 'bank', $q$Complete a frase sobre coesão e acoplamento$q$, $j${"parts":["Um módulo com alta "," reúne responsabilidades que fazem sentido juntas; o "," mede o quanto um módulo depende dos outros."],"a":["coesão","acoplamento"],"extra":["latência","compilação"]}$j$, $q$Coesão olha para dentro do módulo; acoplamento olha para as dependências entre módulos.$q$, 2);
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:1', 5, 'match', $q$Associe a camada à sua responsabilidade$q$, $j${"pairs":[["Apresentação","Telas e interação com o usuário"],["Negócio","Regras e decisões do domínio"],["Dados","Guardar e buscar informações"],["Integração","Conversar com serviços externos"]]}$j$, $q$Cada camada cuida de uma preocupação — e conversa com a vizinha por interfaces claras.$q$, 2);

-- dev:arq:2 · Padrões e decisões arquiteturais
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:2', 0, 'mc', $q$No padrão MVC, o papel do Controller é:$q$, $j${"opts":["Receber as requisições e coordenar Model e View","Guardar os dados no banco","Desenhar a interface","Substituir o servidor"],"a":0}$j$, $q$O Controller recebe a entrada, aciona o Model (dados e regras) e escolhe a View (resposta).$q$, 2);
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:2', 1, 'mc', $q$Injeção de dependência consiste em:$q$, $j${"opts":["Entregar as dependências prontas a um módulo em vez de ele criá-las por conta própria","Instalar pacotes com o npm","Copiar código de outro projeto","Esconder erros do usuário"],"a":0}$j$, $q$Quem usa recebe a dependência de fora (pelo construtor, por exemplo) — fica fácil trocar e testar.$q$, 3);
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:2', 2, 'mc', $q$Uma vantagem do monólito em relação aos microsserviços é:$q$, $j${"opts":["Ser mais simples de desenvolver, testar e publicar no início do projeto","Escalar cada parte de forma independente","Usar uma linguagem diferente em cada módulo","Nunca sair do ar"],"a":0}$j$, $q$Um deploy só, sem rede entre as partes: para times pequenos e produtos novos, costuma ser o melhor começo.$q$, 3);
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:2', 3, 'tf', $q$Julgue a afirmação sobre decisões de arquitetura$q$, $j${"stmt":"Toda decisão arquitetural envolve trade-offs: ganhar em um critério normalmente custa em outro.","a":true}$j$, $q$Verdadeiro: não existe escolha grátis — flexibilidade pode custar complexidade, por exemplo.$q$, 2);
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:2', 4, 'bank', $q$Complete a frase sobre padrões e registros$q$, $j${"parts":["O padrão "," isola o acesso ao banco de dados atrás de uma interface; um ADR é um registro de "," de arquitetura, com o contexto e o porquê."],"a":["Repository","decisão"],"extra":["Singleton","senha"]}$j$, $q$Repository esconde o banco do resto do código; o ADR documenta a decisão para o futuro do time.$q$, 3);
select public.fj_seed_q('dev', 'dev:arq', 'dev:arq:2', 5, 'match', $q$Associe o conceito à sua ideia central$q$, $j${"pairs":[["MVC","Separa modelo, visão e controle"],["Microsserviços","Vários serviços pequenos e independentes"],["Monólito","Uma aplicação única implantada junta"],["Injeção de dependência","Dependências chegam prontas de fora"]]}$j$, $q$Padrões são vocabulário: nomeiam soluções que se repetem, cada uma com seus trade-offs.$q$, 2);

-- ---------------------------------------------------------------
-- dev:bd:1 · SQL essencial
-- ---------------------------------------------------------------
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:1', 0, 'mc', $q$Qual comando SQL lista o nome dos alunos maiores de 18 anos?$q$, $j${"opts":["SELECT nome FROM alunos WHERE idade > 18","GET nome OF alunos IF idade > 18","SHOW alunos.nome WHEN idade > 18","FIND nome IN alunos idade > 18"],"a":0}$j$, $q$SELECT escolhe as colunas, FROM diz a tabela e WHERE filtra as linhas.$q$, 1);
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:1', 1, 'mc', $q$Para combinar linhas de duas tabelas relacionadas (ex.: pedidos com seus clientes) usamos:$q$, $j${"opts":["JOIN","GROUP BY","ORDER BY","DELETE"],"a":0}$j$, $q$O JOIN liga as tabelas pela coluna em comum — normalmente a chave estrangeira.$q$, 2);
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:1', 2, 'mc', $q$A cláusula GROUP BY serve para:$q$, $j${"opts":["Agrupar linhas e aplicar agregações como COUNT e AVG por grupo","Ordenar o resultado","Apagar duplicatas do banco","Criar tabelas novas"],"a":0}$j$, $q$Com GROUP BY, cada grupo vira uma linha do resultado, com suas contagens, somas e médias.$q$, 2);
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:1', 3, 'tf', $q$Julgue a afirmação sobre índices$q$, $j${"stmt":"Um índice acelera as buscas na coluna indexada, mas ocupa espaço e deixa as escritas um pouco mais lentas.","a":true}$j$, $q$Verdadeiro: índice é como o índice de um livro — ótimo para achar, mas precisa ser atualizado a cada escrita.$q$, 3);
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:1', 4, 'bank', $q$Complete a frase sobre chaves$q$, $j${"parts":["A chave "," identifica cada linha de uma tabela; a chave "," aponta para uma linha de outra tabela."],"a":["primária","estrangeira"],"extra":["mestra","secreta"]}$j$, $q$Primary key identifica; foreign key relaciona — é ela que amarra pedidos a clientes.$q$, 1);
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:1', 5, 'order', $q$Ordene as cláusulas na forma usual de escrita de uma consulta SQL$q$, $j${"items":["SELECT","FROM","WHERE","ORDER BY"]}$j$, $q$Escolhe as colunas, diz a tabela, filtra as linhas e ordena o resultado.$q$, 2);

-- dev:bd:2 · Modelagem e integridade
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:2', 0, 'mc', $q$Normalizar um banco de dados significa, principalmente:$q$, $j${"opts":["Organizar as tabelas para evitar repetição e inconsistência de dados","Deixar todas as tabelas com o mesmo número de colunas","Converter os dados para letras minúsculas","Apagar os dados antigos"],"a":0}$j$, $q$Cada fato guardado em um lugar só: sem cópias que podem divergir com o tempo.$q$, 2);
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:2', 1, 'mc', $q$Um aluno pode estar em várias turmas e uma turma tem vários alunos. Esse relacionamento N:N é modelado com:$q$, $j${"opts":["Uma tabela intermediária (ex.: turma_alunos) ligando as duas","Uma coluna a mais na tabela de alunos","Uma coluna de texto com os nomes separados por vírgula","Um arquivo fora do banco"],"a":0}$j$, $q$A tabela de ligação guarda os pares (turma, aluno) — um relacionamento por linha.$q$, 2);
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:2', 2, 'mc', $q$Uma constraint UNIQUE em uma coluna garante que:$q$, $j${"opts":["Não existam duas linhas com o mesmo valor nessa coluna","A coluna nunca fique vazia","A coluna só aceite números","A tabela tenha uma única linha"],"a":0}$j$, $q$UNIQUE barra duplicatas — por exemplo, dois cadastros com o mesmo e-mail.$q$, 2);
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:2', 3, 'tf', $q$Julgue a afirmação sobre transações$q$, $j${"stmt":"Se uma transação falha no meio, as operações que ela já tinha executado permanecem gravadas no banco.","a":false}$j$, $q$Falso: a transação é atômica — ou tudo é confirmado (commit), ou tudo é desfeito (rollback).$q$, 2);
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:2', 4, 'bank', $q$Complete a frase sobre integridade$q$, $j${"parts":["A sigla "," resume as garantias das transações (atomicidade, consistência, isolamento e durabilidade); a restrição NOT "," impede que a coluna fique sem valor."],"a":["ACID","NULL"],"extra":["HTTP","JOIN"]}$j$, $q$ACID é o contrato do banco com os seus dados; NOT NULL obriga o preenchimento.$q$, 2);
select public.fj_seed_q('dev', 'dev:bd', 'dev:bd:2', 5, 'match', $q$Associe o recurso do PostgreSQL à sua função$q$, $j${"pairs":[["PRIMARY KEY","Identifica cada linha"],["FOREIGN KEY","Garante que a referência exista"],["CHECK","Valida uma condição no dado"],["DEFAULT","Preenche um valor quando nada é informado"]]}$j$, $q$Constraints colocam as regras dentro do banco — ninguém grava dado inválido, nem por engano.$q$, 2);

-- ---------------------------------------------------------------
-- dev:api:1 · APIs REST
-- ---------------------------------------------------------------
select public.fj_seed_q('dev', 'dev:api', 'dev:api:1', 0, 'mc', $q$Numa API REST, qual verbo HTTP normalmente cria um recurso novo?$q$, $j${"opts":["POST","GET","DELETE","HEAD"],"a":0}$j$, $q$POST cria; GET lê; PUT/PATCH atualizam; DELETE remove.$q$, 1);
select public.fj_seed_q('dev', 'dev:api', 'dev:api:1', 1, 'mc', $q$O código de status 404 significa:$q$, $j${"opts":["Recurso não encontrado","Sucesso","Erro interno do servidor","Não autorizado"],"a":0}$j$, $q$404 Not Found: a rota ou o recurso pedido não existe. 200 é sucesso; 500, erro do servidor; 401, sem login.$q$, 1);
select public.fj_seed_q('dev', 'dev:api', 'dev:api:1', 2, 'mc', $q$Qual rota segue melhor o estilo REST para buscar o pedido de número 42?$q$, $j${"opts":["GET /pedidos/42","GET /buscarPedidoPorId?x=42","POST /pegaPedido42","GET /api?acao=pedido&n=42"],"a":0}$j$, $q$REST usa substantivos na rota (o recurso) e o verbo HTTP para a ação.$q$, 2);
select public.fj_seed_q('dev', 'dev:api', 'dev:api:1', 3, 'tf', $q$Julgue a afirmação sobre o formato JSON$q$, $j${"stmt":"JSON é o formato de texto mais comum para enviar e receber dados em APIs web.","a":true}$j$, $q$Verdadeiro: leve, legível e entendido por praticamente toda linguagem.$q$, 1);
select public.fj_seed_q('dev', 'dev:api', 'dev:api:1', 4, 'bank', $q$Complete a frase sobre os códigos de status$q$, $j${"parts":["Códigos de status iniciados em 2 indicam ","; iniciados em 5 indicam erro do ","."],"a":["sucesso","servidor"],"extra":["redirecionamento","navegador"]}$j$, $q$2xx = deu certo; 4xx = erro de quem pediu; 5xx = erro de quem responde.$q$, 2);
select public.fj_seed_q('dev', 'dev:api', 'dev:api:1', 5, 'match', $q$Associe o verbo HTTP à sua ação típica$q$, $j${"pairs":[["GET","Ler dados"],["POST","Criar um recurso"],["PUT","Atualizar um recurso"],["DELETE","Remover um recurso"]]}$j$, $q$Os verbos dão o significado da operação sobre o recurso da rota.$q$, 1);

-- dev:api:2 · Autenticação e integrações
select public.fj_seed_q('dev', 'dev:api', 'dev:api:2', 0, 'mc', $q$Qual é a diferença entre autenticação e autorização?$q$, $j${"opts":["Autenticação confirma quem você é; autorização define o que você pode fazer","São sinônimos","A autorização sempre vem antes da autenticação","Autenticação só existe em aplicativos de banco"],"a":0}$j$, $q$Primeiro o sistema confirma a identidade (login); depois confere as permissões de cada ação.$q$, 2);
select public.fj_seed_q('dev', 'dev:api', 'dev:api:2', 1, 'mc', $q$Como uma senha deve ser guardada no banco de dados?$q$, $j${"opts":["Como um hash gerado por algoritmo próprio para senhas, como o bcrypt","Em texto puro, para facilitar o suporte","Numa cifra reversível com a chave no mesmo banco","Nos logs do servidor"],"a":0}$j$, $q$Hash de senha não tem volta: mesmo que o banco vaze, a senha original não aparece.$q$, 2);
select public.fj_seed_q('dev', 'dev:api', 'dev:api:2', 2, 'mc', $q$Um JWT (JSON Web Token) é:$q$, $j${"opts":["Um token assinado que carrega informações do usuário e é verificado pelo servidor","Um tipo de banco de dados","Uma linguagem de programação","Um antivírus"],"a":0}$j$, $q$O servidor assina o token; depois, basta verificar a assinatura para confiar no conteúdo.$q$, 2);
select public.fj_seed_q('dev', 'dev:api', 'dev:api:2', 3, 'tf', $q$Julgue a afirmação sobre rate limiting$q$, $j${"stmt":"Limitar o número de requisições por usuário (rate limit) ajuda a proteger a API contra abuso e sobrecarga.","a":true}$j$, $q$Verdadeiro: sem limite, um cliente com defeito (ou má intenção) derruba o serviço para todos.$q$, 2);
select public.fj_seed_q('dev', 'dev:api', 'dev:api:2', 4, 'bank', $q$Complete a frase sobre integrações$q$, $j${"parts":["Um "," é uma chamada que outro sistema faz à sua API quando algo acontece lá; para se identificar em APIs de terceiros normalmente usamos uma chave de ","."],"a":["webhook","API"],"extra":["cookie","CSS"]}$j$, $q$Webhook: em vez de você perguntar toda hora, o outro sistema avisa. A chave de API identifica quem chama.$q$, 2);
select public.fj_seed_q('dev', 'dev:api', 'dev:api:2', 5, 'order', $q$Ordene o fluxo de um login com token$q$, $j${"items":["O usuário envia e-mail e senha","O servidor confere as credenciais","O servidor devolve um token assinado","O app envia o token nas próximas requisições"]}$j$, $q$Credenciais uma vez, token nas demais: o servidor valida a assinatura em cada chamada.$q$, 2);

-- ---------------------------------------------------------------
-- dev:eng:1 · Git e trabalho em equipe
-- ---------------------------------------------------------------
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:1', 0, 'mc', $q$No Git, um commit é:$q$, $j${"opts":["Uma fotografia das mudanças, com autor, data e mensagem","O envio do código para produção","Um backup do computador inteiro","A exclusão de um arquivo"],"a":0}$j$, $q$Cada commit registra um passo do trabalho — dá para voltar, comparar e entender o histórico.$q$, 1);
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:1', 1, 'mc', $q$Criar uma branch serve para:$q$, $j${"opts":["Desenvolver uma mudança isolada sem mexer na linha principal","Apagar o histórico do projeto","Duplicar o repositório no disco","Acelerar o computador"],"a":0}$j$, $q$A branch é uma linha paralela de trabalho; quando pronta, é integrada com um merge.$q$, 2);
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:1', 2, 'mc', $q$Um pull request (ou merge request) é:$q$, $j${"opts":["Um pedido para revisar e integrar suas mudanças à branch principal","Um comando que desinstala o Git","Uma mensagem privada ao chefe do projeto","Um tipo de teste automatizado"],"a":0}$j$, $q$O PR mostra o diff, recebe comentários dos colegas e, aprovado, vira merge.$q$, 2);
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:1', 3, 'tf', $q$Julgue a afirmação sobre revisão de código$q$, $j${"stmt":"A revisão de código serve para encontrar problemas cedo e espalhar conhecimento no time, não para apontar culpados.","a":true}$j$, $q$Verdadeiro: revisar é cuidar da qualidade e aprender junto — crítica é ao código, não à pessoa.$q$, 1);
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:1', 4, 'bank', $q$Complete a frase sobre o fluxo no Git$q$, $j${"parts":["O comando git "," registra as mudanças no repositório local; o git "," envia os commits para o repositório remoto."],"a":["commit","push"],"extra":["pull","clone"]}$j$, $q$commit grava localmente; push publica; pull traz o que os outros publicaram.$q$, 2);
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:1', 5, 'order', $q$Ordene o fluxo de uma mudança até a branch principal$q$, $j${"items":["Criar uma branch","Fazer commits na branch","Abrir o pull request","Revisar e fazer o merge"]}$j$, $q$Isola, desenvolve, pede revisão e integra — o ciclo básico do trabalho em equipe.$q$, 2);

-- dev:eng:2 · Testes e qualidade
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:2', 0, 'mc', $q$Um teste unitário verifica:$q$, $j${"opts":["Uma pequena unidade do código (ex.: uma função) de forma isolada","O sistema inteiro na visão do usuário","Apenas o visual das telas","A velocidade da internet"],"a":0}$j$, $q$Unitário = pequeno, rápido e isolado: entra um valor, confere-se a saída.$q$, 2);
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:2', 1, 'mc', $q$No TDD (desenvolvimento guiado por testes), a ordem é:$q$, $j${"opts":["Escrever o teste que falha, fazer o código passar e então refatorar","Escrever todo o sistema e testar no final","Testar só quando aparecer um bug","Pedir para o usuário testar"],"a":0}$j$, $q$Vermelho → verde → refatora: o teste nasce antes do código que ele valida.$q$, 2);
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:2', 2, 'mc', $q$Dívida técnica é:$q$, $j${"opts":["O custo futuro de soluções rápidas e malfeitas que precisarão ser retrabalhadas","O valor da licença do editor de código","O salário do time de desenvolvimento","Um imposto sobre software"],"a":0}$j$, $q$Como dívida de dinheiro: o atalho de hoje cobra juros em manutenção amanhã.$q$, 2);
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:2', 3, 'tf', $q$Julgue a afirmação sobre cobertura de testes$q$, $j${"stmt":"Cobertura de 100% garante que o sistema não tem bugs.","a":false}$j$, $q$Falso: cobertura mede o que os testes executam, não se todos os casos e combinações foram verificados.$q$, 3);
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:2', 4, 'bank', $q$Complete a frase sobre os tipos de teste$q$, $j${"parts":["O teste de "," confere módulos conversando entre si; o teste de ponta a "," simula o caminho do usuário no sistema inteiro."],"a":["integração","ponta"],"extra":["mesa","fumaça"]}$j$, $q$Unitário testa a peça; integração, o encaixe; ponta a ponta, a jornada completa.$q$, 2);
select public.fj_seed_q('dev', 'dev:eng', 'dev:eng:2', 5, 'match', $q$Associe a prática ao seu objetivo$q$, $j${"pairs":[["Teste unitário","Validar uma função isolada"],["Teste de integração","Validar módulos trabalhando juntos"],["Documentação","Explicar como usar e por quê"],["Refatoração","Melhorar o código sem mudar o comportamento"]]}$j$, $q$Qualidade é um conjunto de práticas — testes, documentação e melhoria contínua.$q$, 2);

-- ---------------------------------------------------------------
-- dev:infra:1 · Contêineres e ambientes
-- ---------------------------------------------------------------
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:1', 0, 'mc', $q$Qual é a diferença entre imagem e contêiner no Docker?$q$, $j${"opts":["A imagem é o modelo imutável; o contêiner é a imagem em execução","São exatamente a mesma coisa","O contêiner é o arquivo e a imagem é o processo","A imagem só existe em produção"],"a":0}$j$, $q$Como classe e objeto: da mesma imagem nascem vários contêineres rodando isolados.$q$, 2);
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:1', 1, 'mc', $q$O Dockerfile serve para:$q$, $j${"opts":["Descrever, passo a passo, como construir a imagem da aplicação","Guardar as senhas do sistema","Editar o código em produção","Fazer backup do banco de dados"],"a":0}$j$, $q$É a receita da imagem: base, dependências, código e o comando de início.$q$, 2);
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:1', 2, 'mc', $q$Configurações que mudam entre ambientes (ex.: o endereço do banco) devem ficar:$q$, $j${"opts":["Em variáveis de ambiente, fora do código","Fixas no código-fonte","Num comentário do arquivo principal","No histórico do Git"],"a":0}$j$, $q$O mesmo código roda em qualquer ambiente; o que muda vem de fora — e segredos nunca vão para o repositório.$q$, 2);
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:1', 3, 'tf', $q$Julgue a afirmação sobre contêineres$q$, $j${"stmt":"Um contêiner não leva as dependências da aplicação junto, por isso ela se comporta diferente em cada máquina.","a":false}$j$, $q$Falso: o contêiner empacota a aplicação COM as dependências — rodar igual em qualquer lugar é justamente o objetivo.$q$, 2);
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:1', 4, 'bank', $q$Complete a frase sobre os ambientes$q$, $j${"parts":["No ambiente de "," os desenvolvedores trabalham e podem errar à vontade; o ambiente de "," é o que os usuários reais usam."],"a":["desenvolvimento","produção"],"extra":["backup","marketing"]}$j$, $q$Entre os dois costuma existir a homologação, onde o cliente valida antes de ir ao ar.$q$, 1);
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:1', 5, 'match', $q$Associe o conceito ao seu papel$q$, $j${"pairs":[["Imagem","Modelo pronto da aplicação"],["Contêiner","Aplicação em execução isolada"],["Dockerfile","Receita para construir a imagem"],["Registry","Onde as imagens são publicadas"]]}$j$, $q$Dockerfile gera a imagem; a imagem vai ao registry; do registry, vira contêiner em qualquer servidor.$q$, 2);

-- dev:infra:2 · CI/CD e operação
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:2', 0, 'mc', $q$Integração contínua (CI) significa:$q$, $j${"opts":["A cada mudança enviada, o sistema roda build e testes automaticamente","Internet contínua no escritório","Integrar o time em reuniões diárias","Instalar as atualizações do sistema operacional"],"a":0}$j$, $q$Integrar cedo e sempre: o robô avisa na hora se a mudança quebrou algo.$q$, 2);
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:2', 1, 'mc', $q$A entrega contínua (CD) tem como objetivo:$q$, $j${"opts":["Publicar mudanças pequenas com frequência e segurança, de forma automatizada","Gravar o sistema em discos físicos","Publicar uma única vez por ano","Evitar qualquer mudança no sistema"],"a":0}$j$, $q$Lotes pequenos e automação: menos risco em cada deploy e rollback mais fácil.$q$, 2);
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:2', 2, 'mc', $q$Se um deploy quebra a produção, a reação mais segura costuma ser:$q$, $j${"opts":["Rollback: voltar rapidamente para a versão anterior","Desligar o servidor por uma semana","Apagar os logs do erro","Esconder o problema dos usuários"],"a":0}$j$, $q$Primeiro estabiliza (volta a versão boa), depois investiga com calma usando os logs.$q$, 2);
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:2', 3, 'tf', $q$Julgue a afirmação sobre monitoramento$q$, $j${"stmt":"Logs e métricas servem para o time descobrir problemas antes (ou assim que) os usuários os sentirem.","a":true}$j$, $q$Verdadeiro: operar é observar — sem logs e métricas, o primeiro alerta é a reclamação do usuário.$q$, 1);
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:2', 4, 'bank', $q$Complete a frase sobre o pipeline$q$, $j${"parts":["O "," é a sequência automatizada de etapas (build, testes, deploy); fazer "," regular do banco permite recuperar os dados num desastre."],"a":["pipeline","backup"],"extra":["firewall","layout"]}$j$, $q$Pipeline automatiza o caminho até produção; backup é o plano B dos dados — teste a restauração!$q$, 2);
select public.fj_seed_q('dev', 'dev:infra', 'dev:infra:2', 5, 'order', $q$Ordene um pipeline típico de CI/CD$q$, $j${"items":["Enviar o código (push)","Rodar build e testes","Publicar em homologação","Publicar em produção"]}$j$, $q$O código só avança de etapa se a anterior passou — produção é a última parada.$q$, 2);

-- ---------------------------------------------------------------
-- dev:ia:1 · LLMs e embeddings
-- ---------------------------------------------------------------
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:1', 0, 'mc', $q$Um LLM (grande modelo de linguagem) gera texto:$q$, $j${"opts":["Prevendo o próximo token com base no contexto, repetidas vezes","Copiando respostas prontas de um banco de perguntas","Executando o texto como se fosse código","Consultando um humano a cada palavra"],"a":0}$j$, $q$O modelo aprende padrões da linguagem e gera a resposta token a token.$q$, 2);
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:1', 1, 'mc', $q$O prompt é:$q$, $j${"opts":["A instrução ou contexto que você dá ao modelo para orientar a resposta","O nome do servidor da IA","Um tipo de placa de vídeo","O relatório de erros do modelo"],"a":0}$j$, $q$Prompt bom = contexto claro, tarefa definida e formato esperado da resposta.$q$, 1);
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:1', 2, 'mc', $q$Embeddings são:$q$, $j${"opts":["Vetores de números que representam o significado de um texto","Imagens geradas pela IA","Senhas criptografadas","Comentários no código"],"a":0}$j$, $q$Textos de significado parecido ficam com vetores próximos — a base da busca semântica.$q$, 2);
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:1', 3, 'tf', $q$Julgue a afirmação sobre alucinação$q$, $j${"stmt":"Um LLM pode afirmar com confiança algo factualmente errado — por isso respostas importantes devem ser verificadas.","a":true}$j$, $q$Verdadeiro: o modelo gera texto plausível, não verdade garantida. Confiar, mas conferir.$q$, 2);
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:1', 4, 'bank', $q$Complete a frase sobre o funcionamento$q$, $j${"parts":["O texto é dividido em "," antes de entrar no modelo; a "," controla o quanto a resposta varia (quanto maior, mais criativa)."],"a":["tokens","temperatura"],"extra":["pixels","voltagem"]}$j$, $q$Tokens são os pedacinhos de texto; temperatura baixa = resposta mais previsível.$q$, 2);
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:1', 5, 'match', $q$Associe o conceito à sua descrição$q$, $j${"pairs":[["Token","Pedacinho de texto que o modelo processa"],["Embedding","Vetor que representa significado"],["Busca semântica","Encontra textos pelo sentido, não pela palavra exata"],["Janela de contexto","Quanto o modelo consegue ler de uma vez"]]}$j$, $q$Esses quatro conceitos aparecem em praticamente todo sistema com LLM.$q$, 2);

-- dev:ia:2 · RAG, agentes e avaliação
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:2', 0, 'mc', $q$RAG (geração aumentada por recuperação) consiste em:$q$, $j${"opts":["Buscar trechos relevantes numa base de conhecimento e entregá-los ao modelo junto com a pergunta","Treinar o modelo do zero a cada pergunta","Aumentar a memória RAM do servidor","Gerar imagens em alta resolução"],"a":0}$j$, $q$O modelo responde com base nos trechos recuperados — respostas atualizadas e com fonte.$q$, 2);
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:2', 1, 'mc', $q$Um agente de IA se diferencia de um chat simples porque:$q$, $j${"opts":["Pode usar ferramentas (buscar, executar, consultar) em vários passos para cumprir um objetivo","Responde mais rápido","Não usa modelo de linguagem","Funciona sem conexão com nada"],"a":0}$j$, $q$O agente decide, age com ferramentas, observa o resultado e continua — em ciclo, até concluir.$q$, 2);
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:2', 2, 'mc', $q$Quando a base de conhecimento muda toda semana, costuma ser melhor:$q$, $j${"opts":["Usar RAG, que busca na base sempre atualizada, em vez de fine-tuning","Refazer o fine-tuning do modelo toda semana","Aumentar a temperatura do modelo","Trocar a linguagem de programação"],"a":0}$j$, $q$RAG lê a base na hora da pergunta; fine-tuning congela o conhecimento nos pesos do modelo.$q$, 3);
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:2', 3, 'tf', $q$Julgue a afirmação sobre fine-tuning$q$, $j${"stmt":"Fine-tuning ajusta os pesos de um modelo já treinado usando exemplos específicos do seu caso.","a":true}$j$, $q$Verdadeiro: parte-se do modelo pronto e especializa-se com dados próprios — útil para estilo e formato.$q$, 3);
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:2', 4, 'bank', $q$Complete a frase sobre avaliação$q$, $j${"parts":["Para saber se o sistema de IA funciona de verdade, montamos um conjunto de "," com casos reais e medimos a qualidade das "," antes e depois de cada mudança."],"a":["avaliação","respostas"],"extra":["senhas","impressoras"]}$j$, $q$Sem avaliação, cada mudança no prompt é um palpite; com ela, é um experimento medido.$q$, 2);
select public.fj_seed_q('dev', 'dev:ia', 'dev:ia:2', 5, 'order', $q$Ordene o fluxo de uma resposta com RAG$q$, $j${"items":["O usuário faz a pergunta","O sistema busca os trechos mais parecidos na base","Os trechos entram no prompt junto com a pergunta","O modelo gera a resposta com base neles"]}$j$, $q$Pergunta → recuperação → montagem do prompt → geração: por isso o nome recuperação + geração.$q$, 2);

-- ---------------------------------------------------------------
-- dev:bi:1 · ETL e SQL analítico
-- ---------------------------------------------------------------
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:1', 0, 'mc', $q$Em um pipeline de dados, a sigla ETL significa:$q$, $j${"opts":["Extrair, transformar e carregar os dados","Executar, testar e lançar","Enviar, telefonar e logar","Editar tabelas livremente"],"a":0}$j$, $q$Extract, Transform, Load: tira da origem, limpa/transforma e carrega no destino.$q$, 1);
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:1', 1, 'mc', $q$A diferença do ELT para o ETL é:$q$, $j${"opts":["No ELT os dados brutos são carregados primeiro e transformados dentro do próprio destino","No ELT não existe transformação","ETL serve apenas para planilhas","Não há diferença nenhuma"],"a":0}$j$, $q$Com bancos analíticos potentes, compensa carregar cru e transformar lá dentro (em SQL).$q$, 3);
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:1', 2, 'mc', $q$Um data warehouse é:$q$, $j${"opts":["Um banco voltado a análise, que reúne dados históricos de várias fontes","O depósito físico dos servidores","Um aplicativo de mensagens","Uma linguagem de programação"],"a":0}$j$, $q$O warehouse junta vendas, sistema, planilhas… tudo organizado para perguntas analíticas.$q$, 2);
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:1', 3, 'tf', $q$Julgue a afirmação sobre SQL analítico$q$, $j${"stmt":"Funções de agregação como SUM, AVG e COUNT resumem muitas linhas em um resultado por grupo.","a":true}$j$, $q$Verdadeiro: com GROUP BY, milhões de linhas viram um resumo por categoria, mês ou cliente.$q$, 1);
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:1', 4, 'bank', $q$Complete a consulta analítica$q$, $j${"parts":["SELECT turma, AVG(nota) FROM notas GROUP BY "," calcula a média por turma; para manter só os grupos com média alta usamos a cláusula ","."],"a":["turma","HAVING"],"extra":["nota","WHERE"]}$j$, $q$Agrupa-se pela coluna fora da agregação; HAVING filtra depois de agrupar (WHERE filtra antes).$q$, 3);
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:1', 5, 'match', $q$Associe o termo ao seu significado$q$, $j${"pairs":[["ETL","Extrai, transforma e carrega"],["Data warehouse","Banco para análise histórica"],["Dashboard","Painel visual de indicadores"],["KPI","Indicador-chave de desempenho"]]}$j$, $q$O dado sai da origem (ETL), mora no warehouse e aparece no dashboard como KPI.$q$, 2);

-- dev:bi:2 · BI, Python e estatística
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:2', 0, 'mc', $q$No Power BI, um dashboard serve para:$q$, $j${"opts":["Mostrar indicadores e gráficos atualizados para apoiar decisões","Escrever o código do sistema","Enviar e-mails em massa","Hospedar o site da empresa"],"a":0}$j$, $q$O dashboard transforma dados em visão: números-chave e gráficos que respondem perguntas do negócio.$q$, 1);
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:2', 1, 'mc', $q$Em Python, a biblioteca mais usada para trabalhar com tabelas de dados (linhas e colunas) é:$q$, $j${"opts":["pandas","tkinter","pygame","requests"],"a":0}$j$, $q$O pandas traz o DataFrame: filtrar, agrupar, juntar e resumir dados com poucas linhas.$q$, 2);
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:2', 2, 'mc', $q$Nos salários 2.000, 2.200, 2.400 e 20.000, qual medida representa melhor o valor típico?$q$, $j${"opts":["A mediana, pois o 20.000 puxa a média para cima","A média","O valor máximo","A soma de todos"],"a":0}$j$, $q$A média dá 6.650, longe de quase todos; a mediana (2.300) resiste ao valor extremo.$q$, 3);
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:2', 3, 'tf', $q$Julgue a afirmação sobre correlação$q$, $j${"stmt":"Se duas variáveis crescem juntas, isso prova que uma causa a outra.","a":false}$j$, $q$Falso: correlação não implica causalidade — pode ser coincidência ou efeito de um terceiro fator.$q$, 3);
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:2', 4, 'bank', $q$Complete a frase sobre medidas estatísticas$q$, $j${"parts":["A "," é a soma dos valores dividida pela quantidade; a "," é o valor do meio quando os dados estão em ordem."],"a":["média","mediana"],"extra":["moda","variância"]}$j$, $q$Média soma e divide; mediana é o centro; moda é o valor mais frequente.$q$, 1);
select public.fj_seed_q('dev', 'dev:bi', 'dev:bi:2', 5, 'match', $q$Associe a ferramenta ao seu papel no time de dados$q$, $j${"pairs":[["Power BI","Visualizar dados e montar dashboards"],["Python","Automatizar análises e transformar dados"],["SQL","Consultar os bancos de dados"],["Estatística","Interpretar os números com rigor"]]}$j$, $q$As ferramentas se complementam: SQL busca, Python transforma, o BI mostra e a estatística dá o rigor.$q$, 2);

-- Função auxiliar não é mais necessária
drop function if exists public.fj_seed_q(text, text, text, int, text, text, jsonb, text, int);

-- ---------------------------------------------------------------
-- Embaralha as alternativas de múltipla escolha desta matéria
-- (escritas acima com a resposta na posição A; mesmo molde da 0019/0039)
-- ---------------------------------------------------------------
alter table public.questoes disable trigger auditoria_questoes;
do $$
declare q record; n int; perm int[]; novo jsonb; na int;
begin
  for q in select id, dados from public.questoes where tipo = 'mc' and materia_id = 'dev' loop
    n := coalesce(jsonb_array_length(q.dados->'opts'), 0);
    if n < 2 then continue; end if;
    select array_agg(i order by random()) into perm from generate_series(0, n - 1) i;
    select jsonb_agg(q.dados->'opts'->perm[i] order by i) into novo from generate_series(1, n) i;
    na := coalesce(array_position(perm, coalesce((q.dados->>'a')::int, 0)), 1) - 1;
    update public.questoes set dados = dados || jsonb_build_object('opts', novo, 'a', na) where id = q.id;
  end loop;
end $$;
alter table public.questoes enable trigger auditoria_questoes;

insert into public.schema_versao (versao) values (41) on conflict do nothing;
