-- =====================================================================
-- Findout Jornada · Migration 0045 · Matéria Raciocínio Lógico
-- (4 seções, 8 unidades, 16 lições, 96 questões)
-- Rodar no SQL Editor do Supabase depois da 0044. Idempotente: pode rodar de novo.
-- Depois de rodar, abra o painel: ele publica a nova versão sozinho.
-- Matéria comum (grupo "Jornadas por matéria" do app), fora do Mapa do ENEM
-- como Ética/Arte/Ciências: a constante FORA_DO_MAPA em app/index.html ganha 'rac'.
-- Trilha: lógica proposicional (proposições, conectivos, argumentos e
-- falácias), sequências e padrões (numéricas, figuras, analogias, conjuntos),
-- problemas clássicos (verdade e mentira, associação, contagem, casa dos
-- pombos) e lógica aplicada (quantificadores, negação, estratégias).
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
('rac', 'Raciocínio Lógico', 'RL', '#9C36B5', true, 20)
on conflict (id) do nothing;

insert into public.secoes (id, materia_id, titulo, ordem) values
(md5('sec:rac:logica')::uuid, 'rac', 'Lógica proposicional', 0),
(md5('sec:rac:padroes')::uuid, 'rac', 'Sequências e padrões', 1),
(md5('sec:rac:classicos')::uuid, 'rac', 'Problemas clássicos', 2),
(md5('sec:rac:aplicada')::uuid, 'rac', 'Lógica aplicada', 3)
on conflict (id) do nothing;

insert into public.unidades (id, secao_id, titulo, ordem) values
(md5('uni:rac:prop')::uuid, md5('sec:rac:logica')::uuid, 'Proposições e conectivos', 0),
(md5('uni:rac:arg')::uuid, md5('sec:rac:logica')::uuid, 'Argumentos', 1),
(md5('uni:rac:seq')::uuid, md5('sec:rac:padroes')::uuid, 'Sequências', 0),
(md5('uni:rac:conj')::uuid, md5('sec:rac:padroes')::uuid, 'Analogias e conjuntos', 1),
(md5('uni:rac:verd')::uuid, md5('sec:rac:classicos')::uuid, 'Verdade e mentira', 0),
(md5('uni:rac:cont')::uuid, md5('sec:rac:classicos')::uuid, 'Contagem esperta', 1),
(md5('uni:rac:quant')::uuid, md5('sec:rac:aplicada')::uuid, 'Quantificadores e negação', 0),
(md5('uni:rac:estr')::uuid, md5('sec:rac:aplicada')::uuid, 'Estratégias de resolução', 1)
on conflict (id) do nothing;

insert into public.licoes (id, unidade_id, titulo, descricao, ordem) values
(md5('lic:rac:prop:1')::uuid, md5('uni:rac:prop')::uuid, 'Proposições', 'Frases que podem ser julgadas verdadeiras ou falsas.', 0),
(md5('lic:rac:prop:2')::uuid, md5('uni:rac:prop')::uuid, 'E, OU e implicação', 'Os conectivos e quando cada composição é verdadeira.', 1),
(md5('lic:rac:arg:1')::uuid, md5('uni:rac:arg')::uuid, 'Dedução e validade', 'Premissas, conclusão e o que decorre do quê.', 0),
(md5('lic:rac:arg:2')::uuid, md5('uni:rac:arg')::uuid, 'Falácias comuns', 'Ad hominem, generalização apressada e falsa causa.', 1),
(md5('lic:rac:seq:1')::uuid, md5('uni:rac:seq')::uuid, 'Sequências numéricas', 'Descobrir o padrão e prever o próximo termo.', 0),
(md5('lic:rac:seq:2')::uuid, md5('uni:rac:seq')::uuid, 'Padrões de figuras e letras', 'Alternâncias, saltos e blocos que se repetem.', 1),
(md5('lic:rac:conj:1')::uuid, md5('uni:rac:conj')::uuid, 'Analogias', 'A está para B assim como C está para…', 0),
(md5('lic:rac:conj:2')::uuid, md5('uni:rac:conj')::uuid, 'Conjuntos e diagramas', 'União, interseção e o diagrama de Venn.', 1),
(md5('lic:rac:verd:1')::uuid, md5('uni:rac:verd')::uuid, 'Quem diz a verdade', 'Cavaleiros, mentirosos e suposições que se testam.', 0),
(md5('lic:rac:verd:2')::uuid, md5('uni:rac:verd')::uuid, 'Associação lógica', 'Quem tem o quê: resolvendo com tabelas.', 1),
(md5('lic:rac:cont:1')::uuid, md5('uni:rac:cont')::uuid, 'Princípio multiplicativo', 'Contar combinações sem listar uma por uma.', 0),
(md5('lic:rac:cont:2')::uuid, md5('uni:rac:cont')::uuid, 'Casa dos pombos e paridade', 'Garantias de repetição e o jogo do par ou ímpar.', 1),
(md5('lic:rac:quant:1')::uuid, md5('uni:rac:quant')::uuid, 'Todo, algum e nenhum', 'Os quantificadores e o que cada um afirma.', 0),
(md5('lic:rac:quant:2')::uuid, md5('uni:rac:quant')::uuid, 'Negando proposições', 'A negação do E, do OU e das comparações.', 1),
(md5('lic:rac:estr:1')::uuid, md5('uni:rac:estr')::uuid, 'Problemas do dia a dia', 'Idades, balanças e o aquário que dobra.', 0),
(md5('lic:rac:estr:2')::uuid, md5('uni:rac:estr')::uuid, 'Eliminação e caminho inverso', 'Desfazer operações e descartar impossíveis.', 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- rac:prop:1 · Proposições
-- ---------------------------------------------------------------
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:1', 0, 'mc', $q$Em lógica, uma proposição é:$q$, $j${"opts":["Uma frase declarativa que pode ser classificada como verdadeira ou falsa","Qualquer pergunta","Uma ordem ou pedido","Um número qualquer"],"a":0}$j$, $q$Se dá para perguntar é verdadeiro ou falso?, é proposição.$q$, 2);
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:1', 1, 'mc', $q$Qual das frases é uma proposição?$q$, $j${"opts":["Brasília é a capital do Brasil","Que horas são?","Feche a porta!","Tomara que chova amanhã"],"a":0}$j$, $q$Perguntas, ordens e desejos não são julgáveis como V ou F — a afirmação sobre Brasília é.$q$, 2);
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:1', 2, 'mc', $q$A negação da proposição 'Está chovendo' é:$q$, $j${"opts":["Não está chovendo","Está garoando","Choveu ontem","Vai chover amanhã"],"a":0}$j$, $q$Negar é dizer o contrário exato — não é trocar por outra afirmação parecida.$q$, 1);
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:1', 3, 'tf', $q$Julgue a afirmação sobre a negação$q$, $j${"stmt":"Uma proposição e a sua negação sempre têm valores lógicos opostos.","a":true}$j$, $q$Verdadeiro: se uma é V, a outra é F — nunca as duas juntas.$q$, 2);
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:1', 4, 'bank', $q$Complete a frase sobre a definição$q$, $j${"parts":["Proposição é uma frase "," que pode ser julgada como verdadeira ou ","."],"a":["declarativa","falsa"],"extra":["interrogativa","engraçada"]}$j$, $q$Declara algo sobre o mundo — e o mundo diz se é V ou F.$q$, 2);
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:1', 5, 'match', $q$Associe cada frase à sua classificação$q$, $j${"pairs":[["Dois é um número par","Proposição verdadeira"],["Três é um número par","Proposição falsa"],["Feche a janela!","Não é proposição: ordem"],["Qual é o seu nome?","Não é proposição: pergunta"]]}$j$, $q$Só o que afirma pode ser julgado; ordem e pergunta ficam de fora.$q$, 2);

-- rac:prop:2 · E, OU e implicação
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:2', 0, 'mc', $q$A proposição composta 'chove E faz frio' é verdadeira quando:$q$, $j${"opts":["As duas partes são verdadeiras ao mesmo tempo","Pelo menos uma parte é verdadeira","As duas partes são falsas","Em nenhuma situação"],"a":0}$j$, $q$O E é exigente: uma parte falsa derruba a frase inteira.$q$, 2);
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:2', 1, 'mc', $q$'Passo no teste OU vou de carona' é falsa somente quando:$q$, $j${"opts":["As duas partes são falsas","As duas partes são verdadeiras","Apenas a primeira é verdadeira","Apenas a segunda é verdadeira"],"a":0}$j$, $q$O OU é generoso: basta uma parte valer. Só cai quando as duas falham.$q$, 2);
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:2', 2, 'mc', $q$A implicação 'se estudo, então passo' garante que:$q$, $j${"opts":["Quando a condição acontece, a consequência acontece","Quem não estuda nunca passa","Estudar é a única forma de passar","A frase é sempre falsa"],"a":0}$j$, $q$Ela só promete algo quando a condição ocorre; sobre quem não estuda, nada diz.$q$, 3);
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:2', 3, 'tf', $q$Julgue a afirmação sobre a implicação$q$, $j${"stmt":"Na implicação 'se A, então B', quando A é verdadeira e B é falsa, a implicação é falsa.","a":true}$j$, $q$Verdadeiro: é o único caso que quebra a promessa — condição cumprida, consequência não.$q$, 3);
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:2', 4, 'bank', $q$Complete a frase sobre os conectivos$q$, $j${"parts":["O conectivo "," exige as duas partes verdadeiras; o "," se contenta com uma."],"a":["E","OU"],"extra":["NÃO","SE"]}$j$, $q$E restringe; OU amplia — a base de toda proposição composta.$q$, 2);
select public.fj_seed_q('rac', 'rac:prop', 'rac:prop:2', 5, 'match', $q$Associe o conectivo ao seu comportamento$q$, $j${"pairs":[["E","As duas partes precisam valer"],["OU","Basta uma parte valer"],["NÃO","Inverte o valor lógico"],["Se... então...","Condição e consequência"]]}$j$, $q$Quatro conectivos montam qualquer raciocínio formal.$q$, 2);

-- ---------------------------------------------------------------
-- rac:arg:1 · Dedução e validade
-- ---------------------------------------------------------------
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:1', 0, 'mc', $q$'Todo mamífero é animal. A baleia é mamífero. Logo:'$q$, $j${"opts":["A baleia é animal","A baleia é peixe","Todo animal é baleia","Nada se conclui"],"a":0}$j$, $q$O silogismo clássico: se todo M é A, e x é M, então x é A.$q$, 2);
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:1', 1, 'mc', $q$Um argumento é válido quando:$q$, $j${"opts":["A conclusão decorre necessariamente das premissas","A conclusão é simpática","As premissas são longas","Todo mundo concorda com ele"],"a":0}$j$, $q$Validade é sobre a forma: aceitas as premissas, a conclusão é inevitável.$q$, 3);
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:1', 2, 'mc', $q$'Se chove, a rua molha. Choveu. Logo:'$q$, $j${"opts":["A rua molhou","A rua secou","Não choveu","A rua nunca molha"],"a":0}$j$, $q$Condição confirmada, consequência garantida — a dedução mais básica que existe.$q$, 2);
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:1', 3, 'tf', $q$Julgue a conclusão: 'Se chove, a rua molha. A rua está molhada. Logo, choveu.'$q$, $j${"stmt":"Essa conclusão é garantida pela lógica.","a":false}$j$, $q$Falso: a rua pode ter molhado por outro motivo (lavagem, cano…). Afirmar o consequente é um erro clássico.$q$, 3);
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:1', 4, 'bank', $q$Complete a frase sobre a estrutura$q$, $j${"parts":["As afirmações de partida são as ","; o que se deduz delas é a ","."],"a":["premissas","conclusão"],"extra":["dúvidas","legendas"]}$j$, $q$Premissas são o alicerce; a conclusão é o que se constrói sobre elas.$q$, 2);
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:1', 5, 'order', $q$Ordene a análise de um argumento$q$, $j${"items":["Identificar as premissas","Identificar a conclusão","Verificar se a conclusão decorre das premissas","Aceitar ou rejeitar o argumento"]}$j$, $q$Separar o que foi assumido do que foi concluído é metade do trabalho.$q$, 2);

-- rac:arg:2 · Falácias comuns
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:2', 0, 'mc', $q$Atacar quem fala em vez do argumento apresentado é a falácia:$q$, $j${"opts":["Ad hominem","Generalização apressada","Falsa causa","Apelo à novidade"],"a":0}$j$, $q$Desqualificar a pessoa não desmonta o argumento dela.$q$, 3);
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:2', 1, 'mc', $q$'Conheci dois pernambucanos tímidos, logo todo pernambucano é tímido' é um exemplo de:$q$, $j${"opts":["Generalização apressada: poucos casos virando regra geral","Argumento válido","Estatística confiável","Dedução correta"],"a":0}$j$, $q$Dois casos não autorizam o todo — amostra minúscula, conclusão gigante.$q$, 2);
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:2', 2, 'mc', $q$'Usei uma pulseira nova e o time ganhou: a pulseira dá sorte' é a falácia da:$q$, $j${"opts":["Falsa causa: tratar coincidência como causa","Autoridade","Dedução","Analogia"],"a":0}$j$, $q$Aconteceu junto não significa que um causou o outro.$q$, 2);
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:2', 3, 'tf', $q$Julgue a afirmação sobre o convencimento$q$, $j${"stmt":"Um argumento pode parecer muito convincente e, ainda assim, ser uma falácia.","a":true}$j$, $q$Verdadeiro: falácias sobrevivem justamente porque soam bem — o treino é para desmascará-las.$q$, 2);
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:2', 4, 'bank', $q$Complete a frase sobre as falácias$q$, $j${"parts":["A falácia ad "," ataca a pessoa em vez do argumento; a "," apressada transforma poucos casos em regra geral."],"a":["hominem","generalização"],"extra":["infinitum","multiplicação"]}$j$, $q$Duas das falácias mais comuns em discussões — inclusive nas redes.$q$, 3);
select public.fj_seed_q('rac', 'rac:arg', 'rac:arg:2', 5, 'match', $q$Associe a falácia ao seu mecanismo$q$, $j${"pairs":[["Ad hominem","Atacar a pessoa, não o argumento"],["Generalização apressada","Poucos casos viram regra"],["Falsa causa","Coincidência tratada como causa"],["Apelo à popularidade","Todo mundo faz, então é certo"]]}$j$, $q$Nomear a falácia é o primeiro passo para não cair nela.$q$, 3);

-- ---------------------------------------------------------------
-- rac:seq:1 · Sequências numéricas
-- ---------------------------------------------------------------
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:1', 0, 'mc', $q$Na sequência 2, 5, 8, 11, …, o próximo termo é:$q$, $j${"opts":["14","13","15","12"],"a":0}$j$, $q$O padrão é somar 3: 11 + 3 = 14.$q$, 1);
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:1', 1, 'mc', $q$Na sequência 3, 6, 12, 24, …, o próximo termo é:$q$, $j${"opts":["48","36","30","27"],"a":0}$j$, $q$Cada termo dobra: 24 × 2 = 48.$q$, 2);
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:1', 2, 'mc', $q$Na sequência 1, 1, 2, 3, 5, 8, …, cada termo é a soma dos dois anteriores. O próximo é:$q$, $j${"opts":["13","11","12","16"],"a":0}$j$, $q$5 + 8 = 13. É a sequência de Fibonacci, que aparece até nas flores.$q$, 2);
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:1', 3, 'tf', $q$Julgue a afirmação sobre a sequência 20, 17, 14, 11, …$q$, $j${"stmt":"O próximo termo da sequência é 9.","a":false}$j$, $q$Falso: o padrão é subtrair 3, então 11 − 3 = 8, não 9.$q$, 2);
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:1', 4, 'bank', $q$Complete a frase sobre os padrões$q$, $j${"parts":["Na sequência 2, 5, 8, 11 o padrão é somar ","; na sequência 3, 6, 12, 24 é multiplicar por ","."],"a":["três","dois"],"extra":["cinco","dez"]}$j$, $q$Somar sempre o mesmo ou multiplicar sempre pelo mesmo: os dois padrões mais comuns.$q$, 2);
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:1', 5, 'order', $q$Ordene a resolução de uma questão de sequência$q$, $j${"items":["Observar os primeiros termos","Testar uma regra (soma, multiplicação…)","Conferir a regra em todos os termos dados","Aplicar a regra para achar o próximo"]}$j$, $q$Regra que só funciona em parte dos termos não é a regra — confira em todos.$q$, 2);

-- rac:seq:2 · Padrões de figuras e letras
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:2', 0, 'mc', $q$Na sequência de letras A, C, E, G, …, a próxima é:$q$, $j${"opts":["I","H","J","K"],"a":0}$j$, $q$Pula-se uma letra a cada passo: depois do G, pula o H e vem o I.$q$, 2);
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:2', 1, 'mc', $q$Numa sequência que alterna círculo, quadrado, círculo, quadrado…, a 9ª figura é:$q$, $j${"opts":["Círculo, porque as posições ímpares são círculos","Quadrado","Triângulo","Impossível saber"],"a":0}$j$, $q$Ímpar = círculo, par = quadrado; 9 é ímpar.$q$, 2);
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:2', 2, 'mc', $q$Um padrão repete bola, bola, estrela (blocos de 3). A 10ª figura é:$q$, $j${"opts":["Bola, porque 10 dividido por 3 deixa resto 1, e o resto 1 é a primeira figura do bloco","Estrela","Nada: a sequência acaba antes","Quadrado"],"a":0}$j$, $q$10 = 3 × 3 + 1: três blocos completos e recomeça — a 10ª é a primeira do bloco.$q$, 3);
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:2', 3, 'tf', $q$Julgue a afirmação sobre blocos repetidos$q$, $j${"stmt":"Em padrões que se repetem em bloco, o resto da divisão da posição pelo tamanho do bloco revela a figura.","a":true}$j$, $q$Verdadeiro: o resto diz em que ponto do bloco a posição cai — resto 0 é a última figura.$q$, 3);
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:2', 4, 'bank', $q$Complete a frase sobre as técnicas$q$, $j${"parts":["Na sequência A, C, E, G pulamos "," letra por vez; padrões em bloco se resolvem com o "," da divisão."],"a":["uma","resto"],"extra":["duas","dobro"]}$j$, $q$Letras viram números (A = 1, B = 2…) e o padrão aparece.$q$, 2);
select public.fj_seed_q('rac', 'rac:seq', 'rac:seq:2', 5, 'match', $q$Associe a sequência ao seu padrão$q$, $j${"pairs":[["A, B, A, B…","Alternância simples"],["A, C, E, G…","Pula uma letra"],["1, 4, 9, 16…","Quadrados perfeitos"],["2, 4, 8, 16…","Dobra a cada passo"]]}$j$, $q$Reconhecer padrões famosos economiza tempo de prova.$q$, 2);

-- ---------------------------------------------------------------
-- rac:conj:1 · Analogias
-- ---------------------------------------------------------------
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:1', 0, 'mc', $q$Luva está para mão assim como meia está para:$q$, $j${"opts":["Pé","Braço","Sapato","Dedo"],"a":0}$j$, $q$A relação é veste tal parte do corpo: luva/mão, meia/pé.$q$, 1);
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:1', 1, 'mc', $q$Médico está para hospital assim como professor está para:$q$, $j${"opts":["Escola","Caneta","Prova","Férias"],"a":0}$j$, $q$A relação é profissional e seu local de trabalho.$q$, 1);
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:1', 2, 'mc', $q$Resolver uma analogia exige descobrir:$q$, $j${"opts":["A relação entre o primeiro par e aplicá-la ao segundo","O tamanho das palavras","A ordem alfabética","Um sinônimo qualquer"],"a":0}$j$, $q$O segredo nunca está nas palavras em si, e sim no vínculo entre elas.$q$, 2);
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:1', 3, 'tf', $q$Julgue a afirmação sobre as analogias$q$, $j${"stmt":"Numa analogia, a relação entre as palavras importa mais do que as palavras em si.","a":true}$j$, $q$Verdadeiro: identifique o tipo de vínculo (oposição, função, lugar, parte) e transfira.$q$, 2);
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:1', 4, 'bank', $q$Complete a frase sobre as relações$q$, $j${"parts":["Em quente/frio, a relação é de ","; em carro/garagem, é o lugar onde se ","."],"a":["oposição","guarda"],"extra":["igualdade","come"]}$j$, $q$Nomear a relação em voz alta evita cair em alternativas que só parecem combinar.$q$, 2);
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:1', 5, 'match', $q$Associe o par à relação entre as palavras$q$, $j${"pairs":[["Quente / Frio","Opostos"],["Carro / Garagem","Objeto e seu lugar"],["Pintor / Quadro","Profissional e sua obra"],["Livro / Capítulo","Todo e parte"]]}$j$, $q$Oposição, lugar, obra e parte: quatro relações que despencam em provas.$q$, 2);

-- rac:conj:2 · Conjuntos e diagramas
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:2', 0, 'mc', $q$Numa turma, 20 alunos jogam futebol, 15 jogam vôlei e 5 jogam os dois. Quantos jogam pelo menos um esporte?$q$, $j${"opts":["30","35","40","25"],"a":0}$j$, $q$20 + 15 conta os 5 do meio duas vezes: 35 − 5 = 30.$q$, 3);
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:2', 1, 'mc', $q$O diagrama de Venn serve para:$q$, $j${"opts":["Visualizar conjuntos e suas interseções","Medir ângulos","Calcular porcentagens","Desenhar mapas geográficos"],"a":0}$j$, $q$Os círculos que se cruzam mostram quem está em um, no outro ou nos dois.$q$, 1);
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:2', 2, 'mc', $q$A interseção de dois conjuntos contém:$q$, $j${"opts":["Os elementos que pertencem aos dois ao mesmo tempo","Todos os elementos dos dois","Os elementos de nenhum dos dois","Só os elementos do maior conjunto"],"a":0}$j$, $q$Interseção é o miolo do diagrama: quem está nos dois círculos.$q$, 2);
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:2', 3, 'tf', $q$Julgue a afirmação sobre a contagem$q$, $j${"stmt":"Ao somar dois grupos que têm elementos em comum, é preciso descontar a interseção para não contar ninguém duas vezes.","a":true}$j$, $q$Verdadeiro: união = A + B − interseção. É a fórmula da inclusão-exclusão.$q$, 2);
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:2', 4, 'bank', $q$Complete a frase sobre as operações$q$, $j${"parts":["Os elementos comuns aos dois conjuntos formam a ","; todos os elementos juntos formam a ","."],"a":["interseção","união"],"extra":["diferença","moldura"]}$j$, $q$Interseção: e. União: ou. As preposições da teoria dos conjuntos.$q$, 2);
select public.fj_seed_q('rac', 'rac:conj', 'rac:conj:2', 5, 'match', $q$Associe a região do diagrama ao seu significado$q$, $j${"pairs":[["União","Tudo que está em A ou em B"],["Interseção","O que está em A e em B"],["Só em A","A sem a parte comum"],["Fora dos dois","Não pertence a A nem a B"]]}$j$, $q$Quatro regiões, quatro perguntas possíveis de prova.$q$, 2);

-- ---------------------------------------------------------------
-- rac:verd:1 · Quem diz a verdade
-- ---------------------------------------------------------------
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:1', 0, 'mc', $q$Ana diz: 'Bia está mentindo'. Se Ana diz a verdade, então:$q$, $j${"opts":["Bia mente","Bia diz a verdade","As duas mentem","Nada se conclui"],"a":0}$j$, $q$Se a afirmação de Ana é verdadeira, o que ela afirma (Bia mente) vale.$q$, 2);
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:1', 1, 'mc', $q$Numa ilha, cavaleiros só dizem verdades e mentirosos só mentem. Alguém diz: 'Eu sou mentiroso'. Isso é:$q$, $j${"opts":["Impossível: o cavaleiro não diria isso e, na boca do mentiroso, seria uma verdade","Normal para um cavaleiro","Normal para um mentiroso","Prova de que ele é cavaleiro"],"a":0}$j$, $q$Cavaleiro mentiria ao dizer isso; mentiroso falaria a verdade — contradição dos dois lados.$q$, 3);
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:1', 2, 'mc', $q$Pedro afirma: 'Hoje é sexta'. João afirma: 'Hoje não é sexta'. Sobre os dois:$q$, $j${"opts":["Exatamente um deles diz a verdade","Os dois podem estar certos","Os dois podem estar errados","Nada se conclui"],"a":0}$j$, $q$As afirmações são opostas: uma é V e a outra é F, obrigatoriamente.$q$, 2);
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:1', 3, 'tf', $q$Julgue a afirmação sobre a ferramenta básica$q$, $j${"stmt":"Se uma afirmação é falsa, a sua negação é verdadeira.","a":true}$j$, $q$Verdadeiro: é o princípio que destrava todos os problemas de verdade e mentira.$q$, 1);
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:1', 4, 'bank', $q$Complete a frase sobre a ilha$q$, $j${"parts":["Nos problemas de ilha, o "," sempre diz a verdade e o "," sempre mente."],"a":["cavaleiro","mentiroso"],"extra":["turista","capitão"]}$j$, $q$Com os papéis fixos, cada frase dita vira uma pista lógica.$q$, 1);
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:1', 5, 'order', $q$Ordene a resolução de um problema de verdade e mentira$q$, $j${"items":["Supor que uma pessoa diz a verdade","Deduzir as consequências da suposição","Procurar contradições","Se houver contradição, trocar a suposição"]}$j$, $q$Suposição, dedução, teste: o método funciona em qualquer enigma do gênero.$q$, 3);

-- rac:verd:2 · Associação lógica
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:2', 0, 'mc', $q$Ana, Bia e Caio têm um gato, um cão e um peixe, um animal cada. Ana não tem gato; Bia tem o peixe. Conclui-se que:$q$, $j${"opts":["Caio tem o gato e Ana tem o cão","Ana tem o gato","Bia tem o cão","Nada se conclui"],"a":0}$j$, $q$Bia tem o peixe; Ana, sem gato e sem peixe, fica com o cão; sobra o gato para Caio.$q$, 3);
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:2', 1, 'mc', $q$Nos problemas de associação (quem mora onde, quem tem o quê), a ferramenta clássica é:$q$, $j${"opts":["Uma tabela cruzando as possibilidades e marcando o que é impossível","Um dado de seis faces","Uma régua","Um mapa"],"a":0}$j$, $q$Pessoas nas linhas, itens nas colunas: cada pista fecha células da tabela.$q$, 2);
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:2', 2, 'mc', $q$Quando uma linha da tabela fica com uma única possibilidade:$q$, $j${"opts":["Ela é a resposta daquela pessoa, e a coluna fecha para as demais","A tabela está errada","O problema não tem solução","Tudo precisa recomeçar"],"a":0}$j$, $q$Cada certeza elimina possibilidades nas outras linhas — efeito dominó.$q$, 3);
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:2', 3, 'tf', $q$Julgue a afirmação sobre as pistas$q$, $j${"stmt":"Mesmo as pistas negativas, como 'Ana não tem gato', eliminam possibilidades e ajudam a resolver.","a":true}$j$, $q$Verdadeiro: saber o que não é também fecha caminhos — às vezes resolve sozinho.$q$, 2);
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:2', 4, 'bank', $q$Complete a frase sobre o quadro$q$, $j${"parts":["No quadro de associação marcamos "," para o impossível e "," quando a ligação é certa."],"a":["não","sim"],"extra":["talvez","zero"]}$j$, $q$Quando uma linha só tem um sim possível, ele é a resposta.$q$, 2);
select public.fj_seed_q('rac', 'rac:verd', 'rac:verd:2', 5, 'order', $q$Ordene a resolução por tabela$q$, $j${"items":["Montar a tabela com pessoas e itens","Marcar o que as pistas proíbem","Fechar as linhas que ficarem com uma só opção","Conferir a solução contra todas as pistas"]}$j$, $q$A conferência final pega erros de marcação — nunca a pule.$q$, 2);

-- ---------------------------------------------------------------
-- rac:cont:1 · Princípio multiplicativo
-- ---------------------------------------------------------------
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:1', 0, 'mc', $q$Com 3 camisas e 2 calças, quantos conjuntos diferentes dá para montar?$q$, $j${"opts":["6","5","9","12"],"a":0}$j$, $q$Para cada camisa há 2 calças: 3 × 2 = 6.$q$, 2);
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:1', 1, 'mc', $q$Um restaurante oferece 4 pratos e 3 sobremesas. Quantas refeições (prato + sobremesa) são possíveis?$q$, $j${"opts":["12","7","4","3"],"a":0}$j$, $q$4 × 3 = 12. Somar (7) seria escolher prato OU sobremesa, não os dois.$q$, 2);
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:1', 2, 'mc', $q$Uma senha tem 2 dígitos, cada um de 0 a 9. Quantas senhas são possíveis?$q$, $j${"opts":["100","20","10","90"],"a":0}$j$, $q$10 opções para cada posição: 10 × 10 = 100 (de 00 a 99).$q$, 3);
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:1', 3, 'tf', $q$Julgue a afirmação sobre o princípio$q$, $j${"stmt":"No princípio multiplicativo, as opções de cada etapa independente se multiplicam.","a":true}$j$, $q$Verdadeiro: etapa a etapa, as possibilidades se combinam multiplicando.$q$, 2);
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:1', 4, 'bank', $q$Complete a frase sobre a contagem$q$, $j${"parts":["Escolhas em etapas independentes se ","; 3 camisas e 2 calças dão "," combinações."],"a":["multiplicam","seis"],"extra":["somam","cinco"]}$j$, $q$Multiplicar conta tudo sem listar — o atalho contra a enumeração infinita.$q$, 2);
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:1', 5, 'match', $q$Associe as etapas ao total de combinações$q$, $j${"pairs":[["2 opções e 3 opções","6 combinações"],["4 opções e 5 opções","20 combinações"],["10 opções e 10 opções","100 combinações"],["2, 2 e 2 opções","8 combinações"]]}$j$, $q$Multiplique as opções de cada etapa: 6, 20, 100 e 8.$q$, 3);

-- rac:cont:2 · Casa dos pombos e paridade
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:2', 0, 'mc', $q$Numa gaveta há meias pretas e brancas misturadas. No escuro, quantas meias garantem um par da mesma cor?$q$, $j${"opts":["3","2","4","10"],"a":0}$j$, $q$Com 2 pode vir uma de cada; com 3, alguma cor obrigatoriamente se repete.$q$, 3);
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:2', 1, 'mc', $q$O princípio da casa dos pombos diz que:$q$, $j${"opts":["Com mais pombos que casas, alguma casa terá dois ou mais pombos","Pombos preferem casas vazias","Cada casa tem sempre um pombo","Pombos não usam casas"],"a":0}$j$, $q$Simples e poderoso: 13 pombos em 12 casas = alguma casa repete.$q$, 2);
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:2', 2, 'mc', $q$A soma de dois números ímpares é sempre:$q$, $j${"opts":["Par","Ímpar","Zero","Negativa"],"a":0}$j$, $q$3 + 5 = 8, 7 + 9 = 16… ímpar + ímpar = par, sempre.$q$, 2);
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:2', 3, 'tf', $q$Julgue a afirmação sobre os aniversários$q$, $j${"stmt":"Em qualquer grupo de 13 pessoas, pelo menos duas fazem aniversário no mesmo mês.","a":true}$j$, $q$Verdadeiro: 13 pessoas para 12 meses — casa dos pombos em ação.$q$, 3);
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:2', 4, 'bank', $q$Complete a frase sobre as garantias$q$, $j${"parts":["Com 13 pessoas e 12 meses, algum mês se repete: é a casa dos ","; e a soma ímpar + ímpar dá sempre ","."],"a":["pombos","par"],"extra":["gatos","ímpar"]}$j$, $q$Dois clássicos que resolvem questões sem nenhuma conta grande.$q$, 3);
select public.fj_seed_q('rac', 'rac:cont', 'rac:cont:2', 5, 'match', $q$Associe a operação à paridade do resultado$q$, $j${"pairs":[["Par + par","Par"],["Ímpar + ímpar","Par"],["Par + ímpar","Ímpar"],["Par × ímpar","Par"]]}$j$, $q$Na soma, iguais dão par e diferentes dão ímpar; com um fator par, o produto é par.$q$, 3);

-- ---------------------------------------------------------------
-- rac:quant:1 · Todo, algum e nenhum
-- ---------------------------------------------------------------
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:1', 0, 'mc', $q$'Todo A é B' significa que:$q$, $j${"opts":["Não existe A que não seja B","Existe um A que é B e um que não é","B é igual a A","Nenhum A é B"],"a":0}$j$, $q$Todo = sem exceção: qualquer A que você pegar será B.$q$, 3);
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:1', 1, 'mc', $q$Se 'todo estudante da sala gosta de música' é falsa, então:$q$, $j${"opts":["Pelo menos um estudante da sala não gosta de música","Nenhum estudante gosta de música","Todos odeiam música","A sala está vazia"],"a":0}$j$, $q$Para derrubar o todo, basta uma exceção — a negação é algum não, não nenhum.$q$, 3);
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:1', 2, 'mc', $q$'Algum atleta é vegetariano' afirma que:$q$, $j${"opts":["Existe pelo menos um atleta vegetariano","Todos os atletas são vegetarianos","Nenhum atleta é vegetariano","Os vegetarianos não gostam de esporte"],"a":0}$j$, $q$Algum = pelo menos um — pode até serem todos, mas um já basta.$q$, 2);
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:1', 3, 'tf', $q$Julgue a afirmação sobre a negação do nenhum$q$, $j${"stmt":"A negação de 'nenhum aluno faltou' é 'algum aluno faltou'.","a":true}$j$, $q$Verdadeiro: nenhum nega-se com algum (e não com todos faltaram).$q$, 3);
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:1', 4, 'bank', $q$Complete a frase sobre as negações$q$, $j${"parts":["A negação de 'todo A é B' é 'algum A "," é B'; a negação de 'algum A é B' é '"," A é B'."],"a":["não","nenhum"],"extra":["sempre","todo"]}$j$, $q$Todo nega-se com algum não; algum nega-se com nenhum. Decore o par.$q$, 3);
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:1', 5, 'match', $q$Associe o quantificador ao seu significado$q$, $j${"pairs":[["Todo","Vale para todos, sem exceção"],["Algum","Vale para pelo menos um"],["Nenhum","Não vale para ninguém"],["Negação de todo","Algum não"]]}$j$, $q$Três palavrinhas que decidem o valor lógico de frases inteiras.$q$, 3);

-- rac:quant:2 · Negando proposições
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:2', 0, 'mc', $q$A negação de 'chove E faz frio' é:$q$, $j${"opts":["Não chove OU não faz frio","Não chove E não faz frio","Chove OU faz frio","Faz calor"],"a":0}$j$, $q$Negar o E vira OU com as partes negadas — basta uma falhar para o E cair.$q$, 3);
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:2', 1, 'mc', $q$A negação de 'estudo OU trabalho' é:$q$, $j${"opts":["Não estudo E não trabalho","Não estudo OU não trabalho","Estudo E trabalho","Só estudo"],"a":0}$j$, $q$Para o OU ser falso, as duas partes precisam falhar: E com as negações.$q$, 3);
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:2', 2, 'mc', $q$A negação de 'a nota é maior que 7' é:$q$, $j${"opts":["A nota é menor ou igual a 7","A nota é menor que 7","A nota é igual a 7","A nota é maior ou igual a 7"],"a":0}$j$, $q$O contrário de passar de 7 inclui o próprio 7: menor OU igual.$q$, 3);
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:2', 3, 'tf', $q$Julgue a afirmação sobre a regra$q$, $j${"stmt":"Ao negar uma proposição composta, o E vira OU (e vice-versa), com as duas partes negadas.","a":true}$j$, $q$Verdadeiro: são as leis de De Morgan — valem na lógica e na programação.$q$, 3);
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:2', 4, 'bank', $q$Complete a frase sobre as trocas$q$, $j${"parts":["A negação troca E por "," e nega as partes; negar 'maior que' dá 'menor ou "," a'."],"a":["OU","igual"],"extra":["SE","diferente"]}$j$, $q$Os dois tropeços clássicos de prova: esquecer a troca do conectivo e esquecer o igual.$q$, 3);
select public.fj_seed_q('rac', 'rac:quant', 'rac:quant:2', 5, 'match', $q$Associe a proposição à sua negação$q$, $j${"pairs":[["Chove E venta","Não chove OU não venta"],["Chove OU venta","Não chove E não venta"],["x é maior que 5","x é menor ou igual a 5"],["Todos passaram","Algum não passou"]]}$j$, $q$Negar bem é metade das questões de lógica dos concursos.$q$, 3);

-- ---------------------------------------------------------------
-- rac:estr:1 · Problemas do dia a dia
-- ---------------------------------------------------------------
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:1', 0, 'mc', $q$Pai e filho somam 50 anos, e o pai tem 4 vezes a idade do filho. O filho tem:$q$, $j${"opts":["10 anos","12 anos","8 anos","15 anos"],"a":0}$j$, $q$Filho = x, pai = 4x: x + 4x = 50 → 5x = 50 → x = 10.$q$, 3);
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:1', 1, 'mc', $q$Numa balança, 2 maçãs equilibram 1 pera, e 1 pera equilibra 3 ameixas. Quantas ameixas equilibram 2 maçãs?$q$, $j${"opts":["3","2","6","4"],"a":0}$j$, $q$2 maçãs = 1 pera e 1 pera = 3 ameixas: logo, 2 maçãs = 3 ameixas.$q$, 3);
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:1', 2, 'mc', $q$As plantas de um aquário dobram a cada dia e o cobrem por completo no dia 10. Em que dia ele estava pela metade?$q$, $j${"opts":["No dia 9","No dia 5","No dia 2","No dia 8"],"a":0}$j$, $q$Se dobra por dia, a véspera do cheio é a metade: dia 9. A intuição grita 5 — e erra.$q$, 3);
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:1', 3, 'tf', $q$Julgue a afirmação sobre a tradução$q$, $j${"stmt":"Traduzir o enunciado para um esquema (desenho, tabela ou equação) facilita a resolução.","a":true}$j$, $q$Verdadeiro: no papel, o problema mostra a estrutura que o texto esconde.$q$, 1);
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:1', 4, 'bank', $q$Complete a frase sobre as estratégias$q$, $j${"parts":["Transformar o texto num esquema é "," o problema; testar valores possíveis é a estratégia de "," e erro."],"a":["modelar","tentativa"],"extra":["decorar","soma"]}$j$, $q$Modelar organiza; tentativa e erro destrava quando a equação não aparece.$q$, 2);
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:1', 5, 'order', $q$Ordene a resolução de um problema de idades$q$, $j${"items":["Ler e anotar os dados","Chamar a idade desconhecida de x","Montar a equação com as condições","Resolver e conferir no enunciado"]}$j$, $q$Conferir no enunciado pega o erro clássico de responder o x errado (pai × filho).$q$, 2);

-- rac:estr:2 · Eliminação e caminho inverso
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:2', 0, 'mc', $q$Pensei num número, multipliquei por 2, somei 6 e obtive 20. O número era:$q$, $j${"opts":["7","10","13","8"],"a":0}$j$, $q$De trás para frente: 20 − 6 = 14; 14 ÷ 2 = 7.$q$, 2);
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:2', 1, 'mc', $q$Resolver de trás para frente (caminho inverso) funciona quando:$q$, $j${"opts":["Conhecemos o resultado final e as operações feitas, e as desfazemos na ordem contrária","Não sabemos nada do problema","O problema não tem números","Queremos chutar mais rápido"],"a":0}$j$, $q$Como desfazer um nó: solta-se primeiro a última laçada.$q$, 2);
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:2', 2, 'mc', $q$Em questões de múltipla escolha, eliminar as alternativas impossíveis:$q$, $j${"opts":["Aumenta a chance de acerto e economiza tempo","É proibido pelas bancas","Só funciona em matemática","Diminui a nota"],"a":0}$j$, $q$Cada alternativa eliminada com certeza vale ouro — sobram menos candidatas.$q$, 1);
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:2', 3, 'tf', $q$Julgue a afirmação sobre o caminho inverso$q$, $j${"stmt":"No caminho inverso, a operação que foi soma vira subtração, e a que foi multiplicação vira divisão.","a":true}$j$, $q$Verdadeiro: desfazer é aplicar a operação contrária, na ordem contrária.$q$, 2);
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:2', 4, 'bank', $q$Complete a frase sobre as duas táticas$q$, $j${"parts":["Desfazer as operações do fim para o começo é o caminho ","; descartar as opções impossíveis é a ","."],"a":["inverso","eliminação"],"extra":["curto","sorte"]}$j$, $q$Duas táticas que resolvem questões inteiras sem equação nenhuma.$q$, 2);
select public.fj_seed_q('rac', 'rac:estr', 'rac:estr:2', 5, 'order', $q$Ordene o caminho inverso de: multipliquei por 3, somei 5 e deu 26$q$, $j${"items":["Partir do resultado 26","Subtrair 5, obtendo 21","Dividir por 3, obtendo 7","Conferir: 7 × 3 + 5 = 26"]}$j$, $q$O último passo (conferir) transforma um palpite em certeza.$q$, 3);

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
  for q in select id, dados from public.questoes where tipo = 'mc' and materia_id = 'rac' loop
    n := coalesce(jsonb_array_length(q.dados->'opts'), 0);
    if n < 2 then continue; end if;
    select array_agg(i order by random()) into perm from generate_series(0, n - 1) i;
    select jsonb_agg(q.dados->'opts'->perm[i] order by i) into novo from generate_series(1, n) i;
    na := coalesce(array_position(perm, coalesce((q.dados->>'a')::int, 0)), 1) - 1;
    update public.questoes set dados = dados || jsonb_build_object('opts', novo, 'a', na) where id = q.id;
  end loop;
end $$;
alter table public.questoes enable trigger auditoria_questoes;

insert into public.schema_versao (versao) values (45) on conflict do nothing;
