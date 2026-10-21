-- =====================================================================
-- Findout Jornada · Migration 0043 · Curso: Análise e Ciência de Dados
-- (conceitos e fundamentos — 4 seções, 8 unidades, 16 lições, 96 questões)
-- Rodar no SQL Editor do Supabase depois da 0042. Idempotente: pode rodar de novo.
-- Depois de rodar, abra o painel: ele publica a nova versão sozinho.
-- Matéria-curso: fora do Mapa do ENEM e no grupo "Cursos" do app
-- (constantes FORA_DO_MAPA e CURSOS em app/index.html ganham o id 'dat').
-- Trilha conceitual: dado → informação, tipos e qualidade dos dados,
-- estatística descritiva, amostras, correlação × causalidade, análise
-- exploratória, indicadores, visualização (e gráficos que enganam),
-- machine learning (conceitos) e ética/LGPD.
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
('dat', 'Análise e Ciência de Dados', 'CD', '#0CA678', true, 18)
on conflict (id) do nothing;

insert into public.secoes (id, materia_id, titulo, ordem) values
(md5('sec:dat:fundamentos')::uuid, 'dat', 'Fundamentos de dados', 0),
(md5('sec:dat:estatistica')::uuid, 'dat', 'Estatística para dados', 1),
(md5('sec:dat:analise')::uuid, 'dat', 'Análise e visualização', 2),
(md5('sec:dat:pratica')::uuid, 'dat', 'Ciência de dados na prática', 3)
on conflict (id) do nothing;

insert into public.unidades (id, secao_id, titulo, ordem) values
(md5('uni:dat:dado')::uuid, md5('sec:dat:fundamentos')::uuid, 'Dados, informação e conhecimento', 0),
(md5('uni:dat:coleta')::uuid, md5('sec:dat:fundamentos')::uuid, 'Coleta e qualidade dos dados', 1),
(md5('uni:dat:desc')::uuid, md5('sec:dat:estatistica')::uuid, 'Estatística descritiva', 0),
(md5('uni:dat:amostra')::uuid, md5('sec:dat:estatistica')::uuid, 'Amostras, correlação e causalidade', 1),
(md5('uni:dat:eda')::uuid, md5('sec:dat:analise')::uuid, 'Análise exploratória e indicadores', 0),
(md5('uni:dat:viz')::uuid, md5('sec:dat:analise')::uuid, 'Visualização de dados', 1),
(md5('uni:dat:ml')::uuid, md5('sec:dat:pratica')::uuid, 'Machine learning: conceitos', 0),
(md5('uni:dat:etica')::uuid, md5('sec:dat:pratica')::uuid, 'Ética e decisões com dados', 1)
on conflict (id) do nothing;

insert into public.licoes (id, unidade_id, titulo, descricao, ordem) values
(md5('lic:dat:dado:1')::uuid, md5('uni:dat:dado')::uuid, 'Dado, informação e conhecimento', 'Do registro bruto à decisão.', 0),
(md5('lic:dat:dado:2')::uuid, md5('uni:dat:dado')::uuid, 'Tipos de dados', 'Quantitativo e qualitativo, discreto e contínuo, estruturado e não estruturado.', 1),
(md5('lic:dat:coleta:1')::uuid, md5('uni:dat:coleta')::uuid, 'Fontes e coleta', 'Pesquisas, sensores, logs e a diferença entre censo e amostra.', 0),
(md5('lic:dat:coleta:2')::uuid, md5('uni:dat:coleta')::uuid, 'Qualidade e limpeza', 'Faltantes, duplicados, outliers e padronização.', 1),
(md5('lic:dat:desc:1')::uuid, md5('uni:dat:desc')::uuid, 'Média, mediana e moda', 'As medidas de tendência central e quando cada uma engana.', 0),
(md5('lic:dat:desc:2')::uuid, md5('uni:dat:desc')::uuid, 'Dispersão', 'Amplitude, desvio padrão e por que a média sozinha não basta.', 1),
(md5('lic:dat:amostra:1')::uuid, md5('uni:dat:amostra')::uuid, 'População e amostra', 'Representatividade e viés de seleção.', 0),
(md5('lic:dat:amostra:2')::uuid, md5('uni:dat:amostra')::uuid, 'Correlação e causalidade', 'Variar junto não é causar — e o papel do terceiro fator.', 1),
(md5('lic:dat:eda:1')::uuid, md5('uni:dat:eda')::uuid, 'Análise exploratória', 'Perguntas, resumos e comparações entre grupos.', 0),
(md5('lic:dat:eda:2')::uuid, md5('uni:dat:eda')::uuid, 'Indicadores e métricas', 'Taxas, percentuais e KPIs que medem o que importa.', 1),
(md5('lic:dat:viz:1')::uuid, md5('uni:dat:viz')::uuid, 'O gráfico certo para cada pergunta', 'Barras, linhas, pizza e dispersão.', 0),
(md5('lic:dat:viz:2')::uuid, md5('uni:dat:viz')::uuid, 'Gráficos que enganam', 'Eixo cortado, escala distorcida e recorte conveniente.', 1),
(md5('lic:dat:ml:1')::uuid, md5('uni:dat:ml')::uuid, 'O que é machine learning', 'Aprender com exemplos, treino e teste.', 0),
(md5('lic:dat:ml:2')::uuid, md5('uni:dat:ml')::uuid, 'Classificação e previsão', 'Categoria ou número, acurácia e overfitting.', 1),
(md5('lic:dat:etica:1')::uuid, md5('uni:dat:etica')::uuid, 'Privacidade e LGPD', 'Dados pessoais, anonimização e consentimento.', 0),
(md5('lic:dat:etica:2')::uuid, md5('uni:dat:etica')::uuid, 'Decisões orientadas por dados', 'Evidência com senso crítico — e os vieses herdados.', 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- dat:dado:1 · Dado, informação e conhecimento
-- ---------------------------------------------------------------
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:1', 0, 'mc', $q$Qual é a diferença entre dado e informação?$q$, $j${"opts":["O dado é o registro bruto; a informação é o dado organizado num contexto que faz sentido","São exatamente a mesma coisa","A informação vem antes do dado","Dado é só o que está no papel"],"a":0}$j$, $q$38 é um dado; 38 °C de febre do João é informação.$q$, 1);
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:1', 1, 'mc', $q$O número 38 sozinho é um dado. Ele vira informação quando:$q$, $j${"opts":["Ganha contexto: 38 °C é a temperatura do paciente João agora","É digitado duas vezes","É apagado da planilha","Vira um número par"],"a":0}$j$, $q$Contexto (o quê, de quem, quando, em que unidade) é o que dá significado ao número.$q$, 1);
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:1', 2, 'mc', $q$A análise de dados serve principalmente para:$q$, $j${"opts":["Transformar dados em respostas que apoiam decisões","Deixar as planilhas mais coloridas","Substituir qualquer conversa com clientes","Gerar relatórios que ninguém lê"],"a":0}$j$, $q$O destino da análise é a decisão: sem pergunta e sem ação, o dado fica parado.$q$, 1);
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:1', 3, 'tf', $q$Julgue a afirmação sobre o conhecimento$q$, $j${"stmt":"Conhecimento é o que se constrói quando informações são interpretadas e conectadas à experiência.","a":true}$j$, $q$Verdadeiro: dado → informação → conhecimento → decisão, cada nível agrega contexto.$q$, 2);
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:1', 4, 'bank', $q$Complete a frase sobre a base da análise$q$, $j${"parts":["O "," é o registro bruto, sem contexto; a "," é esse registro organizado e com significado."],"a":["dado","informação"],"extra":["gráfico","boleto"]}$j$, $q$A matéria-prima é o dado; o produto com significado é a informação.$q$, 1);
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:1', 5, 'match', $q$Associe cada nível a um exemplo$q$, $j${"pairs":[["Dado","38"],["Informação","38 °C de febre do paciente João"],["Conhecimento","Febre acima de 38 °C pede atenção"],["Decisão","Levar o paciente ao médico"]]}$j$, $q$A pirâmide completa: do número solto à ação.$q$, 2);

-- dat:dado:2 · Tipos de dados
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:2', 0, 'mc', $q$Idade e altura são dados:$q$, $j${"opts":["Quantitativos: representam quantidades que podem ser medidas","Qualitativos","Sem utilidade para análise","Sempre sigilosos"],"a":0}$j$, $q$Quantitativo é tudo que se expressa em números mensuráveis.$q$, 1);
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:2', 1, 'mc', $q$Cor preferida e estado civil são dados:$q$, $j${"opts":["Qualitativos: descrevem categorias, não quantidades","Quantitativos contínuos","Sempre numéricos","Aleatórios"],"a":0}$j$, $q$Qualitativo classifica em categorias — não faz sentido somar cores.$q$, 1);
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:2', 2, 'mc', $q$Número de filhos é discreto e altura é contínua porque:$q$, $j${"opts":["Filhos se contam em valores inteiros; a altura pode assumir qualquer valor num intervalo","A altura é sempre um número inteiro","É possível ter 2,5 filhos","Não há diferença entre os dois"],"a":0}$j$, $q$Discreto se conta (0, 1, 2…); contínuo se mede (1,72 m, 1,725 m…).$q$, 2);
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:2', 3, 'tf', $q$Julgue a afirmação sobre a estrutura$q$, $j${"stmt":"Uma tabela com linhas e colunas é um dado estruturado; fotos, áudios e textos livres são não estruturados.","a":true}$j$, $q$Verdadeiro: o estruturado já vem organizado em campos; o não estruturado exige processamento extra.$q$, 2);
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:2', 4, 'bank', $q$Complete a frase sobre os tipos$q$, $j${"parts":["Dados "," representam quantidades (idade, preço); dados "," representam categorias (cor, cidade)."],"a":["quantitativos","qualitativos"],"extra":["falsos","gigantes"]}$j$, $q$Saber o tipo define o que faz sentido: média de preço sim, média de cidade não.$q$, 1);
select public.fj_seed_q('dat', 'dat:dado', 'dat:dado:2', 5, 'match', $q$Associe o dado ao seu tipo$q$, $j${"pairs":[["Número de filhos","Quantitativo discreto"],["Altura","Quantitativo contínuo"],["Cor preferida","Qualitativo nominal"],["Nível de escolaridade","Qualitativo ordinal"]]}$j$, $q$Ordinal tem ordem natural (fundamental < médio < superior); nominal não.$q$, 3);

-- ---------------------------------------------------------------
-- dat:coleta:1 · Fontes e coleta
-- ---------------------------------------------------------------
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:1', 0, 'mc', $q$São exemplos de fontes de dados:$q$, $j${"opts":["Pesquisas com questionários, sensores, registros de sistemas e bases públicas","Somente as redes sociais","Apenas livros impressos","Só o que sai no noticiário"],"a":0}$j$, $q$Dados nascem em muitos lugares — e cada fonte tem seus limites e cuidados.$q$, 1);
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:1', 1, 'mc', $q$Censo e amostra se diferenciam porque:$q$, $j${"opts":["O censo coleta de toda a população; a amostra, de uma parte escolhida para representá-la","A amostra é sempre maior que o censo","O censo usa só dez pessoas","São a mesma coisa"],"a":0}$j$, $q$Censo é completo e caro; amostra bem escolhida responde quase o mesmo por muito menos.$q$, 2);
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:1', 2, 'mc', $q$Por que empresas analisam os registros (logs) dos seus sistemas?$q$, $j${"opts":["Porque eles contam como os usuários realmente usam o produto","Para gastar espaço em disco","Porque deixa o sistema mais bonito","Para esconder informações"],"a":0}$j$, $q$O questionário diz o que a pessoa acha; o log mostra o que ela de fato fez.$q$, 2);
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:1', 3, 'tf', $q$Julgue a afirmação sobre a coleta$q$, $j${"stmt":"A forma de coletar influencia os dados: uma pergunta mal formulada gera respostas distorcidas.","a":true}$j$, $q$Verdadeiro: pergunta induzida, resposta induzida — o viés começa na coleta.$q$, 2);
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:1', 4, 'bank', $q$Complete a frase sobre o alcance$q$, $j${"parts":["Estudar toda a população é fazer um ","; estudar uma parte representativa é usar uma ","."],"a":["censo","amostra"],"extra":["palpite","mediana"]}$j$, $q$O IBGE faz censo de dez em dez anos; no resto do tempo, pesquisas por amostra.$q$, 2);
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:1', 5, 'match', $q$Associe a fonte ao que ela fornece$q$, $j${"pairs":[["Questionário","O que as pessoas dizem"],["Sensor","Medições automáticas do ambiente"],["Log de sistema","O que os usuários fazem no software"],["Base pública","Dados abertos de governos e institutos"]]}$j$, $q$Combinar fontes diferentes dá uma visão mais completa do problema.$q$, 2);

-- dat:coleta:2 · Qualidade e limpeza
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:2', 0, 'mc', $q$Limpeza de dados é:$q$, $j${"opts":["Tratar valores faltantes, duplicados e erros antes da análise","Apagar a base inteira e recomeçar","Imprimir e guardar na gaveta","Colorir as células da planilha"],"a":0}$j$, $q$Analistas gastam boa parte do tempo aqui — e é tempo bem gasto.$q$, 1);
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:2', 1, 'mc', $q$Um cliente cadastrado duas vezes na base causa:$q$, $j${"opts":["Contagens infladas e análises distorcidas","Nenhum problema","Mais segurança para a empresa","Lucro em dobro"],"a":0}$j$, $q$Duplicado conta duas vezes: a base diz 1.000 clientes onde existem 900.$q$, 1);
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:2', 2, 'mc', $q$Um valor muito fora do padrão (ex.: idade 220) é chamado de:$q$, $j${"opts":["Outlier (valor atípico) — pode ser erro de digitação ou um caso real raro","Média","Mediana","Rótulo"],"a":0}$j$, $q$Antes de excluir um outlier, investigue: às vezes ele é o achado mais importante.$q$, 2);
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:2', 3, 'tf', $q$Julgue a afirmação sobre a qualidade$q$, $j${"stmt":"Análise feita sobre dados errados leva a conclusões erradas, por melhor que seja a ferramenta.","a":true}$j$, $q$Verdadeiro: lixo entra, lixo sai — nenhum gráfico conserta dado ruim.$q$, 1);
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:2', 4, 'bank', $q$Complete a frase sobre os problemas comuns$q$, $j${"parts":["Registros repetidos são ","; campos vazios são valores ","."],"a":["duplicados","faltantes"],"extra":["outliers","gráficos"]}$j$, $q$Duplicados, faltantes e outliers: o trio que toda limpeza procura primeiro.$q$, 1);
select public.fj_seed_q('dat', 'dat:coleta', 'dat:coleta:2', 5, 'order', $q$Ordene uma preparação de dados típica$q$, $j${"items":["Reunir os dados das fontes","Procurar problemas: duplicados, faltantes e valores estranhos","Corrigir ou remover os registros com problema","Conferir o resultado antes de analisar"]}$j$, $q$Só depois da conferência os dados estão prontos para responder perguntas.$q$, 2);

-- ---------------------------------------------------------------
-- dat:desc:1 · Média, mediana e moda
-- ---------------------------------------------------------------
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:1', 0, 'mc', $q$A média das notas 4, 6 e 8 é:$q$, $j${"opts":["6","4","8","18"],"a":0}$j$, $q$(4 + 6 + 8) ÷ 3 = 18 ÷ 3 = 6.$q$, 1);
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:1', 1, 'mc', $q$A mediana é:$q$, $j${"opts":["O valor do meio quando os dados estão em ordem","A soma de todos os valores","O valor que mais se repete","O maior valor do conjunto"],"a":0}$j$, $q$Metade dos dados fica abaixo dela, metade acima.$q$, 1);
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:1', 2, 'mc', $q$Nos salários 2.000, 2.100, 2.300 e 25.000, por que a mediana representa melhor o valor típico?$q$, $j${"opts":["Porque o 25.000 é um valor extremo que puxa a média para cima","Porque a mediana é sempre maior que a média","Porque a média está matematicamente errada","Porque salários não podem ser somados"],"a":0}$j$, $q$A média dá 7.850, longe de quase todos; a mediana (2.200) resiste ao extremo.$q$, 2);
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:1', 3, 'tf', $q$Julgue a afirmação sobre a moda$q$, $j${"stmt":"A moda é o valor que mais se repete no conjunto de dados.","a":true}$j$, $q$Verdadeiro: num conjunto de tamanhos de camiseta, a moda é o tamanho mais vendido.$q$, 1);
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:1', 4, 'bank', $q$Complete a frase sobre as medidas centrais$q$, $j${"parts":["A "," soma tudo e divide pela quantidade; a "," é o valor central dos dados ordenados."],"a":["média","mediana"],"extra":["moda","amostra"]}$j$, $q$Com valores extremos no conjunto, desconfie da média e olhe a mediana.$q$, 1);
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:1', 5, 'match', $q$Associe a medida à sua definição$q$, $j${"pairs":[["Média","Soma dividida pela quantidade"],["Mediana","Valor do meio"],["Moda","Valor mais frequente"],["Amplitude","Maior valor menos o menor"]]}$j$, $q$Cada medida conta uma parte da história — o ideal é olhar mais de uma.$q$, 2);

-- dat:desc:2 · Dispersão
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:2', 0, 'mc', $q$Duas turmas têm média 7, mas numa as notas vão de 6,5 a 7,5 e na outra de 3 a 10. O que as diferencia?$q$, $j${"opts":["A dispersão: na segunda turma as notas estão muito mais espalhadas","A média","O número de alunos","Nada as diferencia"],"a":0}$j$, $q$Mesma média, realidades opostas: uma turma homogênea e outra com extremos.$q$, 2);
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:2', 1, 'mc', $q$A amplitude de um conjunto de dados é:$q$, $j${"opts":["A diferença entre o maior e o menor valor","A soma de todos os valores","O valor do meio","A quantidade de dados"],"a":0}$j$, $q$Notas de 3 a 10: amplitude 7. É a medida de dispersão mais simples.$q$, 1);
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:2', 2, 'mc', $q$Um desvio padrão pequeno indica que:$q$, $j${"opts":["Os valores estão próximos da média","Os valores estão muito espalhados","A média está errada","Os dados são qualitativos"],"a":0}$j$, $q$O desvio padrão mede o afastamento típico em relação à média.$q$, 2);
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:2', 3, 'tf', $q$Julgue a afirmação sobre a média sozinha$q$, $j${"stmt":"Olhar só a média, sem a dispersão, pode esconder diferenças enormes entre os dados.","a":true}$j$, $q$Verdadeiro: um rio com média de 1 metro de profundidade pode ter poços de 5 metros.$q$, 2);
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:2', 4, 'bank', $q$Complete a frase sobre as medidas de dispersão$q$, $j${"parts":["O desvio "," mede o afastamento típico em relação à média; a "," é a diferença entre o maior e o menor valor."],"a":["padrão","amplitude"],"extra":["lateral","mediana"]}$j$, $q$Amplitude olha só os extremos; o desvio padrão considera todos os valores.$q$, 2);
select public.fj_seed_q('dat', 'dat:desc', 'dat:desc:2', 5, 'match', $q$Associe o conceito ao seu significado$q$, $j${"pairs":[["Amplitude","Maior menos o menor"],["Desvio padrão","Afastamento típico da média"],["Baixa dispersão","Valores próximos entre si"],["Alta dispersão","Valores bem espalhados"]]}$j$, $q$Centro + dispersão: juntas, as duas famílias de medidas resumem o conjunto.$q$, 2);

-- ---------------------------------------------------------------
-- dat:amostra:1 · População e amostra
-- ---------------------------------------------------------------
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:1', 0, 'mc', $q$Em estatística, população é:$q$, $j${"opts":["Todo o conjunto que queremos estudar (pessoas, produtos ou eventos)","Apenas os habitantes de um país","Os seguidores de uma rede social","O time de análise de dados"],"a":0}$j$, $q$População pode ser clientes, peças produzidas, partidas de futebol — o todo de interesse.$q$, 2);
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:1', 1, 'mc', $q$Uma amostra representativa é aquela que:$q$, $j${"opts":["Reflete as características da população, sem privilegiar um grupo","Tem só voluntários do mesmo bairro","É a maior possível, não importa como foi escolhida","Inclui apenas quem respondeu primeiro"],"a":0}$j$, $q$O sorteio aleatório é o jeito clássico de dar a todos a mesma chance de entrar.$q$, 2);
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:1', 2, 'mc', $q$Pesquisar a satisfação só com quem segue a marca nas redes é um exemplo de:$q$, $j${"opts":["Viés de seleção: o grupo pesquisado não representa todos os clientes","Amostra aleatória perfeita","Censo","Dado contínuo"],"a":0}$j$, $q$Quem segue a marca já gosta dela — os insatisfeitos ficaram de fora da conta.$q$, 2);
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:1', 3, 'tf', $q$Julgue a afirmação sobre o tamanho da amostra$q$, $j${"stmt":"Aumentar o tamanho da amostra corrige qualquer viés de seleção.","a":false}$j$, $q$Falso: amostra enviesada continua enviesada mesmo gigante — o problema é como ela foi escolhida.$q$, 3);
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:1', 4, 'bank', $q$Complete a frase sobre os conjuntos$q$, $j${"parts":["O conjunto completo que queremos estudar é a ","; a parte selecionada para o estudo é a ","."],"a":["população","amostra"],"extra":["média","moda"]}$j$, $q$Conclusões sobre a população dependem de uma amostra bem escolhida.$q$, 1);
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:1', 5, 'match', $q$Associe o conceito ao exemplo$q$, $j${"pairs":[["População","Todos os clientes da empresa"],["Amostra","500 clientes sorteados"],["Viés de seleção","Ouvir só os fãs da marca"],["Sorteio aleatório","Todos com a mesma chance de entrar"]]}$j$, $q$Representatividade vale mais do que tamanho.$q$, 2);

-- dat:amostra:2 · Correlação e causalidade
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:2', 0, 'mc', $q$Correlação entre duas variáveis significa que:$q$, $j${"opts":["Elas variam juntas, numa relação que pode ser positiva ou negativa","Uma com certeza causa a outra","Elas são a mesma variável","Não existe relação nenhuma"],"a":0}$j$, $q$Correlação descreve o andar junto — não diz quem move quem.$q$, 2);
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:2', 1, 'mc', $q$Vendas de sorvete e afogamentos aumentam juntos no verão. A explicação mais provável é:$q$, $j${"opts":["Um terceiro fator (o calor) influencia os dois","Sorvete causa afogamento","Afogamento aumenta a venda de sorvete","Pura coincidência impossível de explicar"],"a":0}$j$, $q$O calor leva mais gente à praia e à sorveteria: é a variável de confusão clássica.$q$, 2);
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:2', 2, 'mc', $q$Para investigar se algo realmente causa um efeito, o caminho clássico é:$q$, $j${"opts":["Um experimento controlado, comparando grupos semelhantes com e sem o fator","Olhar um gráfico bonito","Perguntar a uma única pessoa","Confiar na intuição"],"a":0}$j$, $q$Grupos comparáveis em tudo, exceto no fator estudado: a diferença que sobrar é o efeito.$q$, 3);
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:2', 3, 'tf', $q$Julgue a afirmação sobre a prova$q$, $j${"stmt":"Correlação forte entre duas variáveis prova que uma causa a outra.","a":false}$j$, $q$Falso: pode haver coincidência, causa invertida ou um terceiro fator por trás.$q$, 2);
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:2', 4, 'bank', $q$Complete a frase sobre os sentidos da correlação$q$, $j${"parts":["Quando as duas variáveis crescem juntas, a correlação é ","; quando uma cresce e a outra cai, é ","."],"a":["positiva","negativa"],"extra":["falsa","perfeita"]}$j$, $q$Estudo × nota: positiva. Faltas × nota: negativa.$q$, 2);
select public.fj_seed_q('dat', 'dat:amostra', 'dat:amostra:2', 5, 'match', $q$Associe o conceito à sua descrição$q$, $j${"pairs":[["Correlação positiva","As duas crescem juntas"],["Correlação negativa","Uma sobe, a outra desce"],["Variável de confusão","Terceiro fator que influencia as duas"],["Causalidade","Uma variável de fato provoca a outra"]]}$j$, $q$A frase a guardar para sempre: correlação não implica causalidade.$q$, 3);

-- ---------------------------------------------------------------
-- dat:eda:1 · Análise exploratória
-- ---------------------------------------------------------------
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:1', 0, 'mc', $q$A análise exploratória de dados serve para:$q$, $j${"opts":["Conhecer os dados: distribuições, padrões, grupos e surpresas","Formatar o relatório final","Esconder os valores atípicos","Substituir a coleta de dados"],"a":0}$j$, $q$Antes de modelar ou concluir, explora-se: o que os dados têm a dizer?$q$, 2);
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:1', 1, 'mc', $q$Uma boa análise começa por:$q$, $j${"opts":["Uma pergunta clara, como: quais turmas têm menor engajamento?","Abrir todos os gráficos possíveis sem critério","O modelo mais complexo disponível","A escolha das cores do relatório"],"a":0}$j$, $q$A pergunta guia o que medir, comparar e mostrar — sem ela, a análise vira passeio.$q$, 2);
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:1', 2, 'mc', $q$Agrupar as vendas por mês e por região serve para:$q$, $j${"opts":["Comparar segmentos e enxergar onde o comportamento muda","Esconder os detalhes dos dados","Aumentar as vendas automaticamente","Reduzir o tamanho do arquivo"],"a":0}$j$, $q$O agregado geral esconde; o recorte por grupo revela onde está a diferença.$q$, 2);
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:1', 3, 'tf', $q$Julgue a afirmação sobre as surpresas$q$, $j${"stmt":"Na análise exploratória, encontrar uma surpresa nos dados pode valer mais do que confirmar o esperado.","a":true}$j$, $q$Verdadeiro: o inesperado é onde moram os problemas escondidos e as oportunidades.$q$, 2);
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:1', 4, 'bank', $q$Complete a frase sobre a exploração$q$, $j${"parts":["A análise exploratória resume os dados com estatísticas e ","; comparar turmas, regiões ou meses é analisar por ","."],"a":["gráficos","grupos"],"extra":["senhas","sorte"]}$j$, $q$Resumir e comparar: os dois movimentos básicos de quem explora dados.$q$, 2);
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:1', 5, 'order', $q$Ordene uma análise exploratória simples$q$, $j${"items":["Definir a pergunta","Preparar e limpar os dados","Resumir com estatísticas e gráficos","Registrar os achados e as novas perguntas"]}$j$, $q$E o ciclo recomeça: boas análises terminam com perguntas melhores.$q$, 2);

-- dat:eda:2 · Indicadores e métricas
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:2', 0, 'mc', $q$Um KPI (indicador-chave de desempenho) é:$q$, $j${"opts":["Uma métrica escolhida por refletir um objetivo importante do negócio","Qualquer número que aparece na planilha","Um tipo de gráfico","Uma senha do sistema"],"a":0}$j$, $q$Métricas existem aos montes; KPI é a que mede o que realmente importa.$q$, 2);
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:2', 1, 'mc', $q$Se 40 dos 200 alunos ficaram de recuperação, a taxa é:$q$, $j${"opts":["20%","40%","5%","80%"],"a":0}$j$, $q$40 ÷ 200 = 0,2 → 20%.$q$, 2);
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:2', 2, 'mc', $q$Por que olhar a taxa (20%) além do número absoluto (40 alunos)?$q$, $j${"opts":["A taxa permite comparar grupos de tamanhos diferentes","O número absoluto é sempre melhor","A taxa esconde a verdade","Tanto faz: dizem o mesmo"],"a":0}$j$, $q$40 em 200 (20%) é muito pior que 40 em 2.000 (2%) — a taxa dá a proporção.$q$, 2);
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:2', 3, 'tf', $q$Julgue a afirmação sobre o efeito das métricas$q$, $j${"stmt":"Uma métrica mal escolhida pode incentivar o comportamento errado — otimiza-se o que se mede.","a":true}$j$, $q$Verdadeiro: medir só velocidade de atendimento, por exemplo, pode derrubar a qualidade.$q$, 3);
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:2', 4, 'bank', $q$Complete a frase sobre os indicadores$q$, $j${"parts":["Dividir a parte pelo todo e multiplicar por 100 dá o ","; o indicador escolhido para acompanhar um objetivo é o ","."],"a":["percentual","KPI"],"extra":["desvio","outlier"]}$j$, $q$Percentuais comparam; KPIs direcionam.$q$, 2);
select public.fj_seed_q('dat', 'dat:eda', 'dat:eda:2', 5, 'match', $q$Associe o indicador ao seu cálculo ou papel$q$, $j${"pairs":[["Taxa de entrega","Entregas divididas pelo total de alunos"],["Média de notas","Soma das notas pela quantidade"],["Alunos ativos","Quantos usaram o app no período"],["Meta","Valor que o indicador deve alcançar"]]}$j$, $q$Indicador bom tem definição clara: qualquer um calcula e chega ao mesmo número.$q$, 2);

-- ---------------------------------------------------------------
-- dat:viz:1 · O gráfico certo para cada pergunta
-- ---------------------------------------------------------------
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:1', 0, 'mc', $q$Para comparar as vendas entre 5 lojas, o gráfico mais indicado é o de:$q$, $j${"opts":["Barras","Pizza com vinte fatias","Linha do tempo","Dispersão"],"a":0}$j$, $q$Barras lado a lado tornam a comparação entre categorias imediata.$q$, 1);
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:1', 1, 'mc', $q$Para mostrar a evolução das vendas mês a mês, o melhor é o gráfico de:$q$, $j${"opts":["Linhas","Pizza","Texto corrido","Barras com cinquenta categorias"],"a":0}$j$, $q$A linha evidencia a tendência: subindo, caindo ou estável.$q$, 1);
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:1', 2, 'mc', $q$O gráfico de dispersão (pontos) serve para:$q$, $j${"opts":["Ver a relação entre duas variáveis, como horas de estudo × nota","Mostrar um único número grande","Listar nomes em ordem alfabética","Decorar a capa do relatório"],"a":0}$j$, $q$Cada ponto é um caso; o desenho da nuvem revela a correlação.$q$, 2);
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:1', 3, 'tf', $q$Julgue a afirmação sobre a pizza$q$, $j${"stmt":"O gráfico de pizza funciona melhor com poucas categorias que somam um todo.","a":true}$j$, $q$Verdadeiro: com muitas fatias parecidas, o olho não compara — melhor usar barras.$q$, 2);
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:1', 4, 'bank', $q$Complete a frase sobre a escolha$q$, $j${"parts":["Para comparar categorias usamos ","; para mostrar a evolução no tempo usamos ","."],"a":["barras","linhas"],"extra":["pizza","molduras"]}$j$, $q$O gráfico certo responde a pergunta sem precisar de legenda explicando.$q$, 2);
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:1', 5, 'match', $q$Associe o gráfico ao seu melhor uso$q$, $j${"pairs":[["Barras","Comparar categorias"],["Linhas","Evolução no tempo"],["Pizza","Partes de um todo"],["Dispersão","Relação entre duas variáveis"]]}$j$, $q$Pergunta primeiro, gráfico depois — nunca o contrário.$q$, 1);

-- dat:viz:2 · Gráficos que enganam
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:2', 0, 'mc', $q$Um gráfico de barras com o eixo começando em 90 (em vez de 0) pode:$q$, $j${"opts":["Exagerar visualmente diferenças que são pequenas","Deixar as diferenças menores do que são","Não mudar nada na leitura","Corrigir os dados automaticamente"],"a":0}$j$, $q$De 95 para 100 parece o dobro quando o eixo começa em 90 — no total, foi só 5%.$q$, 2);
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:2', 1, 'mc', $q$Mostrar só o trecho do gráfico que favorece um argumento é:$q$, $j${"opts":["Recorte conveniente (cherry-picking), que distorce a conclusão","Boa prática de visualização","Obrigatório em relatórios executivos","Um tipo de média"],"a":0}$j$, $q$A ação que subiu na semana pode estar despencando no ano — o recorte muda a história.$q$, 2);
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:2', 2, 'mc', $q$Diante de um gráfico impressionante, a primeira pergunta deve ser:$q$, $j${"opts":["Qual é a fonte, o período completo e como os eixos foram montados?","Qual fonte de letra foi usada?","Quem desenhou o slide?","Qual é a cor predominante?"],"a":0}$j$, $q$Fonte, período e eixos: o checklist de três itens contra gráficos enganosos.$q$, 2);
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:2', 3, 'tf', $q$Julgue a afirmação sobre a honestidade visual$q$, $j${"stmt":"Um gráfico pode estar tecnicamente correto e, mesmo assim, induzir ao erro pela escala e pelo recorte.","a":true}$j$, $q$Verdadeiro: os números podem ser verdadeiros e a impressão visual, enganosa.$q$, 3);
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:2', 4, 'bank', $q$Complete a frase sobre as armadilhas$q$, $j${"parts":["Cortar o "," do gráfico exagera as diferenças; escolher só o "," favorável distorce a história."],"a":["eixo","período"],"extra":["título","papel"]}$j$, $q$Eixo no zero e período completo: o padrão honesto de quem apresenta dados.$q$, 3);
select public.fj_seed_q('dat', 'dat:viz', 'dat:viz:2', 5, 'match', $q$Associe a armadilha ao seu efeito$q$, $j${"pairs":[["Eixo cortado","Diferenças parecem maiores"],["Escala distorcida","Comparação visual enganosa"],["Recorte de período","Esconde a tendência completa"],["Fonte citada","Permite conferir os dados"]]}$j$, $q$Três armadilhas e um antídoto: sempre cite a fonte e confira as dos outros.$q$, 3);

-- ---------------------------------------------------------------
-- dat:ml:1 · O que é machine learning
-- ---------------------------------------------------------------
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:1', 0, 'mc', $q$Machine learning (aprendizado de máquina) é:$q$, $j${"opts":["Fazer o computador aprender padrões a partir de exemplos, em vez de programar cada regra","Digitar as regras uma a uma no código","Apenas um computador mais rápido","Uma planilha muito grande"],"a":0}$j$, $q$Em vez de escrever a regra do spam, mostramos milhares de exemplos e o modelo aprende o padrão.$q$, 2);
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:1', 1, 'mc', $q$Para um modelo aprender a identificar spam, ele precisa de:$q$, $j${"opts":["Muitos exemplos de e-mails já marcados como spam e como não spam","Um único e-mail de exemplo","Nenhum dado","Uma impressora nova"],"a":0}$j$, $q$Exemplos rotulados são o combustível do aprendizado supervisionado.$q$, 2);
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:1', 2, 'mc', $q$Por que separamos dados de treino e de teste?$q$, $j${"opts":["Para avaliar o modelo em dados que ele não viu, medindo se ele generaliza","Para gastar mais tempo no projeto","Porque os dados não cabem juntos na memória","Para esconder os dados da equipe"],"a":0}$j$, $q$Avaliar no próprio treino é como corrigir a prova com a cola na mão.$q$, 3);
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:1', 3, 'tf', $q$Julgue a afirmação sobre o supervisionado$q$, $j${"stmt":"No aprendizado supervisionado, o modelo aprende com exemplos que já vêm com a resposta certa (o rótulo).","a":true}$j$, $q$Verdadeiro: o rótulo é o gabarito — o modelo ajusta-se para acertá-lo em casos novos.$q$, 2);
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:1', 4, 'bank', $q$Complete a frase sobre os conjuntos$q$, $j${"parts":["Os dados usados para o modelo aprender formam o conjunto de ","; os dados reservados para medir o desempenho formam o conjunto de ","."],"a":["treino","teste"],"extra":["lixo","backup"]}$j$, $q$Treina-se numa parte, avalia-se na outra: só assim a nota do modelo é honesta.$q$, 2);
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:1', 5, 'match', $q$Associe o conceito à sua descrição$q$, $j${"pairs":[["Exemplo rotulado","E-mail já marcado como spam ou não"],["Treino","Fase em que o modelo aprende"],["Teste","Medição com dados nunca vistos"],["Generalizar","Acertar em casos novos"]]}$j$, $q$O objetivo final é sempre generalizar: acertar no mundo real, não no passado.$q$, 2);

-- dat:ml:2 · Classificação e previsão
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:2', 0, 'mc', $q$Prever se um e-mail é spam ou não é um problema de:$q$, $j${"opts":["Classificação: a resposta é uma categoria","Regressão: a resposta é um número","Ordenação alfabética","Compressão de arquivos"],"a":0}$j$, $q$Duas categorias possíveis (spam / não spam) = classificação.$q$, 2);
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:2', 1, 'mc', $q$Prever o preço de uma casa é um problema de:$q$, $j${"opts":["Regressão: a resposta é um valor numérico","Classificação","Tradução automática","Limpeza de dados"],"a":0}$j$, $q$Resposta numérica contínua (350 mil, 420 mil…) = regressão.$q$, 2);
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:2', 2, 'mc', $q$Um modelo que decora os dados de treino e erra nos dados novos sofre de:$q$, $j${"opts":["Sobreajuste (overfitting)","Falta de memória","Excesso de acurácia","Viés positivo"],"a":0}$j$, $q$Como o aluno que decorou a lista de exercícios: nota alta no ensaio, nota baixa na prova.$q$, 3);
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:2', 3, 'tf', $q$Julgue a afirmação sobre a acurácia$q$, $j${"stmt":"Um modelo com 95% de acerto nos dados de treino necessariamente terá 95% de acerto em dados novos.","a":false}$j$, $q$Falso: o que vale é o desempenho no teste — no treino, o modelo pode ter apenas decorado.$q$, 3);
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:2', 4, 'bank', $q$Complete a frase sobre os tipos de problema$q$, $j${"parts":["Quando a resposta é uma categoria, o problema é de ","; quando a resposta é um número, é de ","."],"a":["classificação","regressão"],"extra":["repetição","sorte"]}$j$, $q$Aprovado/reprovado: classificação. Nota de 0 a 10: regressão.$q$, 2);
select public.fj_seed_q('dat', 'dat:ml', 'dat:ml:2', 5, 'match', $q$Associe o caso ao conceito$q$, $j${"pairs":[["Spam ou não spam","Classificação"],["Preço da casa","Regressão"],["Acurácia","Percentual de acertos"],["Overfitting","Decorar o treino e errar no novo"]]}$j$, $q$Identificar o tipo do problema é o primeiro passo de qualquer projeto de ML.$q$, 3);

-- ---------------------------------------------------------------
-- dat:etica:1 · Privacidade e LGPD
-- ---------------------------------------------------------------
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:1', 0, 'mc', $q$Dados pessoais são:$q$, $j${"opts":["Informações que identificam ou podem identificar uma pessoa, como nome, CPF e localização","Apenas as senhas","Somente fotos de documentos","Qualquer número de uma planilha"],"a":0}$j$, $q$Até dados que, combinados, identificam alguém (CEP + idade + profissão) entram na regra.$q$, 2);
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:1', 1, 'mc', $q$A LGPD é:$q$, $j${"opts":["A lei brasileira que define regras para coleta, uso e guarda de dados pessoais","Um formato de arquivo de dados","Uma linguagem de programação","Um tipo de gráfico"],"a":0}$j$, $q$Lei Geral de Proteção de Dados: vale para empresas e órgãos que tratam dados de pessoas no Brasil.$q$, 2);
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:1', 2, 'mc', $q$Anonimizar dados significa:$q$, $j${"opts":["Remover ou transformar o que identifica as pessoas, mantendo a utilidade da análise","Apagar a base inteira","Trocar a fonte do relatório","Imprimir sem o nome na capa"],"a":0}$j$, $q$A análise de turma não precisa do nome de cada aluno — agregado e anônimo costuma bastar.$q$, 2);
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:1', 3, 'tf', $q$Julgue a afirmação sobre os direitos$q$, $j${"stmt":"Pela LGPD, a pessoa tem direito de saber quais dados uma empresa guarda sobre ela.","a":true}$j$, $q$Verdadeiro: acesso, correção e exclusão estão entre os direitos do titular dos dados.$q$, 2);
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:1', 4, 'bank', $q$Complete a frase sobre os princípios$q$, $j${"parts":["Usar os dados só para o fim informado respeita o princípio da ","; pedir "," ao titular é uma das bases legais para tratar dados pessoais."],"a":["finalidade","consentimento"],"extra":["velocidade","propaganda"]}$j$, $q$Coletou para entrega? Não pode virar lista de marketing sem nova base legal.$q$, 3);
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:1', 5, 'match', $q$Associe o conceito ao exemplo$q$, $j${"pairs":[["Dado pessoal","Nome, CPF, localização"],["Anonimização","Remover o que identifica"],["Consentimento","Autorização dada pelo titular"],["Vazamento","Dados expostos sem autorização"]]}$j$, $q$Quem analisa dados de pessoas carrega responsabilidade legal e ética.$q$, 2);

-- dat:etica:2 · Decisões orientadas por dados
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:2', 0, 'mc', $q$Ser orientado por dados (data-driven) significa:$q$, $j${"opts":["Usar evidências dos dados para apoiar decisões, com senso crítico sobre os limites deles","Obedecer cegamente a qualquer número","Decidir sempre pela intuição","Coletar dados e nunca usá-los"],"a":0}$j$, $q$O dado informa a decisão; quem decide — e responde por ela — continua sendo gente.$q$, 2);
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:2', 1, 'mc', $q$Um modelo treinado com dados históricos enviesados tende a:$q$, $j${"opts":["Repetir e até amplificar o viés nas suas previsões","Corrigir o viés sozinho","Ficar automaticamente neutro","Parar de funcionar"],"a":0}$j$, $q$O modelo aprende o passado como ele foi — injustiças históricas viram padrão aprendido.$q$, 3);
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:2', 2, 'mc', $q$Os dados mostram QUE as vendas caíram, mas não dizem POR QUÊ. O que fazer?$q$, $j${"opts":["Investigar hipóteses com mais dados e com quem vive o problema no dia a dia","Esconder o resultado da diretoria","Culpar o gráfico","Trocar de ferramenta de planilha"],"a":0}$j$, $q$Número aponta o onde; o porquê sai de hipóteses testadas e de conversas com a ponta.$q$, 2);
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:2', 3, 'tf', $q$Julgue a afirmação sobre o papel humano$q$, $j${"stmt":"Dados ajudam a decidir, mas interpretar o contexto continua sendo trabalho humano.","a":true}$j$, $q$Verdadeiro: o dado não conhece a estratégia, a ética nem o que ficou de fora da base.$q$, 1);
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:2', 4, 'bank', $q$Complete a frase sobre o equilíbrio$q$, $j${"parts":["Decidir com base em evidências combina "," com interpretação e contexto; os modelos herdam os "," presentes nos dados de treino."],"a":["dados","vieses"],"extra":["palpites","gráficos"]}$j$, $q$Evidência sem contexto cega; contexto sem evidência chuta.$q$, 3);
select public.fj_seed_q('dat', 'dat:etica', 'dat:etica:2', 5, 'match', $q$Associe o conceito ao seu papel na decisão$q$, $j${"pairs":[["Evidência","O que os dados mostram"],["Hipótese","Possível explicação a ser testada"],["Viés nos dados","Distorção herdada do histórico"],["Senso crítico","Questionar fonte, recorte e limites"]]}$j$, $q$O ciclo saudável: evidência gera hipótese, hipótese pede teste, teste gera nova evidência.$q$, 3);

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
  for q in select id, dados from public.questoes where tipo = 'mc' and materia_id = 'dat' loop
    n := coalesce(jsonb_array_length(q.dados->'opts'), 0);
    if n < 2 then continue; end if;
    select array_agg(i order by random()) into perm from generate_series(0, n - 1) i;
    select jsonb_agg(q.dados->'opts'->perm[i] order by i) into novo from generate_series(1, n) i;
    na := coalesce(array_position(perm, coalesce((q.dados->>'a')::int, 0)), 1) - 1;
    update public.questoes set dados = dados || jsonb_build_object('opts', novo, 'a', na) where id = q.id;
  end loop;
end $$;
alter table public.questoes enable trigger auditoria_questoes;

insert into public.schema_versao (versao) values (43) on conflict do nothing;
