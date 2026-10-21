-- =====================================================================
-- Findout Jornada · Migration 0042 · Curso: Lógica de Programação
-- (4 seções, 8 unidades, 16 lições, 96 questões)
-- Rodar no SQL Editor do Supabase depois da 0041. Idempotente: pode rodar de novo.
-- Depois de rodar, abra o painel: ele publica a nova versão sozinho.
-- Matéria-curso: fora do Mapa do ENEM e no grupo "Cursos" do app
-- (constantes FORA_DO_MAPA e CURSOS em app/index.html ganham o id 'log').
-- Os exemplos usam pseudocódigo em português (se/então/senão, enquanto, para),
-- sem prender o aluno a uma linguagem específica.
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
('log', 'Lógica de Programação', 'LP', '#D6336C', true, 17)
on conflict (id) do nothing;

insert into public.secoes (id, materia_id, titulo, ordem) values
(md5('sec:log:pensamento')::uuid, 'log', 'Pensamento computacional', 0),
(md5('sec:log:controle')::uuid, 'log', 'Decisões e repetições', 1),
(md5('sec:log:organizacao')::uuid, 'log', 'Organizando a solução', 2),
(md5('sec:log:pratica')::uuid, 'log', 'Da lógica ao código', 3)
on conflict (id) do nothing;

insert into public.unidades (id, secao_id, titulo, ordem) values
(md5('uni:log:alg')::uuid, md5('sec:log:pensamento')::uuid, 'Algoritmos e sequências', 0),
(md5('uni:log:var')::uuid, md5('sec:log:pensamento')::uuid, 'Variáveis e dados', 1),
(md5('uni:log:cond')::uuid, md5('sec:log:controle')::uuid, 'Condicionais', 0),
(md5('uni:log:laco')::uuid, md5('sec:log:controle')::uuid, 'Laços de repetição', 1),
(md5('uni:log:func')::uuid, md5('sec:log:organizacao')::uuid, 'Funções e modularização', 0),
(md5('uni:log:lista')::uuid, md5('sec:log:organizacao')::uuid, 'Listas e coleções', 1),
(md5('uni:log:erro')::uuid, md5('sec:log:pratica')::uuid, 'Erros e depuração', 0),
(md5('uni:log:prob')::uuid, md5('sec:log:pratica')::uuid, 'Resolução de problemas', 1)
on conflict (id) do nothing;

insert into public.licoes (id, unidade_id, titulo, descricao, ordem) values
(md5('lic:log:alg:1')::uuid, md5('uni:log:alg')::uuid, 'O que é um algoritmo', 'Passos ordenados, precisos e finitos — do bolo ao código.', 0),
(md5('lic:log:alg:2')::uuid, md5('uni:log:alg')::uuid, 'Entrada, processamento e saída', 'O fluxo de todo programa e os fluxogramas.', 1),
(md5('lic:log:var:1')::uuid, md5('uni:log:var')::uuid, 'Variáveis e atribuição', 'Caixinhas com nome que guardam valores.', 0),
(md5('lic:log:var:2')::uuid, md5('uni:log:var')::uuid, 'Tipos de dados e operadores', 'Inteiro, real, texto, lógico e o resto da divisão.', 1),
(md5('lic:log:cond:1')::uuid, md5('uni:log:cond')::uuid, 'Se... então... senão', 'O programa escolhe o caminho pela condição.', 0),
(md5('lic:log:cond:2')::uuid, md5('uni:log:cond')::uuid, 'Condições compostas', 'E, OU, NÃO e as comparações.', 1),
(md5('lic:log:laco:1')::uuid, md5('uni:log:laco')::uuid, 'Repetição com contador', 'O laço para (for) e a variável que conta as voltas.', 0),
(md5('lic:log:laco:2')::uuid, md5('uni:log:laco')::uuid, 'Repetição com condição', 'O laço enquanto (while), acumuladores e o loop infinito.', 1),
(md5('lic:log:func:1')::uuid, md5('uni:log:func')::uuid, 'Funções e parâmetros', 'Blocos com nome, entradas e retorno.', 0),
(md5('lic:log:func:2')::uuid, md5('uni:log:func')::uuid, 'Dividir para conquistar', 'Decomposição, escopo e uma responsabilidade por função.', 1),
(md5('lic:log:lista:1')::uuid, md5('uni:log:lista')::uuid, 'Listas e índices', 'Vários valores numa variável só — e a contagem do zero.', 0),
(md5('lic:log:lista:2')::uuid, md5('uni:log:lista')::uuid, 'Percorrendo listas', 'Somar, achar o maior e buscar um valor.', 1),
(md5('lic:log:erro:1')::uuid, md5('uni:log:erro')::uuid, 'Tipos de erro', 'Sintaxe, lógica e execução — e o que as mensagens dizem.', 0),
(md5('lic:log:erro:2')::uuid, md5('uni:log:erro')::uuid, 'Depuração e teste de mesa', 'Seguir as variáveis passo a passo até achar a causa.', 1),
(md5('lic:log:prob:1')::uuid, md5('uni:log:prob')::uuid, 'Do problema ao algoritmo', 'Entender, planejar em pseudocódigo e só então codificar.', 0),
(md5('lic:log:prob:2')::uuid, md5('uni:log:prob')::uuid, 'Refinando a solução', 'Casos extremos, eficiência e melhoria contínua.', 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- log:alg:1 · O que é um algoritmo
-- ---------------------------------------------------------------
select public.fj_seed_q('log', 'log:alg', 'log:alg:1', 0, 'mc', $q$Um algoritmo é:$q$, $j${"opts":["Uma sequência finita e ordenada de passos para resolver um problema","Um tipo de computador","Uma linguagem de programação","Um erro no código"],"a":0}$j$, $q$Como uma receita de bolo: passos claros, em ordem e com fim.$q$, 1);
select public.fj_seed_q('log', 'log:alg', 'log:alg:1', 1, 'mc', $q$Por que a ordem dos passos importa num algoritmo?$q$, $j${"opts":["Porque executar os passos fora de ordem pode levar a um resultado errado","Porque o computador prefere listas longas","Não importa: o computador corrige sozinho","Porque deixa o código mais bonito"],"a":0}$j$, $q$Calçar o sapato antes da meia mostra bem: mesmos passos, outra ordem, outro resultado.$q$, 1);
select public.fj_seed_q('log', 'log:alg', 'log:alg:1', 2, 'mc', $q$Qual opção do dia a dia funciona como um algoritmo?$q$, $j${"opts":["A receita de um bolo: ingredientes e modo de preparo em ordem","Uma foto da cozinha","O nome do confeiteiro","O preço do bolo"],"a":0}$j$, $q$A receita diz o que usar e o que fazer, passo a passo — é um algoritmo em português.$q$, 1);
select public.fj_seed_q('log', 'log:alg', 'log:alg:1', 3, 'tf', $q$Julgue a afirmação sobre a execução$q$, $j${"stmt":"O computador executa exatamente o que o algoritmo manda — inclusive os erros.","a":true}$j$, $q$Verdadeiro: o computador não adivinha a intenção; ele faz o que está escrito.$q$, 1);
select public.fj_seed_q('log', 'log:alg', 'log:alg:1', 4, 'bank', $q$Complete a frase sobre algoritmos$q$, $j${"parts":["Um bom algoritmo precisa ser "," (sem ambiguidade em cada passo) e "," (terminar em algum momento)."],"a":["preciso","finito"],"extra":["bonito","secreto"]}$j$, $q$Passo vago não executa; algoritmo sem fim não resolve.$q$, 2);
select public.fj_seed_q('log', 'log:alg', 'log:alg:1', 5, 'order', $q$Ordene os passos para trocar uma lâmpada$q$, $j${"items":["Desligar o interruptor","Pegar a escada","Retirar a lâmpada queimada","Colocar a lâmpada nova"]}$j$, $q$Segurança primeiro, depois o acesso e então a troca — a ordem faz parte da solução.$q$, 1);

-- log:alg:2 · Entrada, processamento e saída
select public.fj_seed_q('log', 'log:alg', 'log:alg:2', 0, 'mc', $q$No esquema entrada → processamento → saída, a entrada é:$q$, $j${"opts":["Os dados que o programa recebe para trabalhar","O resultado final","O botão de ligar o computador","A tela"],"a":0}$j$, $q$Entrada = o que o programa recebe; saída = o que ele entrega.$q$, 1);
select public.fj_seed_q('log', 'log:alg', 'log:alg:2', 1, 'mc', $q$Num programa que calcula a média de duas notas, a saída é:$q$, $j${"opts":["A média calculada","As duas notas digitadas","O teclado","A fórmula da média"],"a":0}$j$, $q$As notas são a entrada; a conta é o processamento; a média mostrada é a saída.$q$, 1);
select public.fj_seed_q('log', 'log:alg', 'log:alg:2', 2, 'mc', $q$Num fluxograma, o losango representa:$q$, $j${"opts":["Uma decisão (pergunta com resposta sim ou não)","O início do programa","Uma anotação do programador","Um cálculo"],"a":0}$j$, $q$No losango o fluxo se divide: um caminho para o sim, outro para o não.$q$, 2);
select public.fj_seed_q('log', 'log:alg', 'log:alg:2', 3, 'tf', $q$Julgue a afirmação sobre o processamento$q$, $j${"stmt":"O processamento é a etapa em que o programa transforma os dados de entrada no resultado.","a":true}$j$, $q$Verdadeiro: é o miolo do programa — contas, comparações e decisões.$q$, 1);
select public.fj_seed_q('log', 'log:alg', 'log:alg:2', 4, 'bank', $q$Complete a frase sobre o fluxo$q$, $j${"parts":["No cálculo da média, as notas digitadas são a "," e a média mostrada na tela é a ","."],"a":["entrada","saída"],"extra":["memória","impressora"]}$j$, $q$Todo programa segue esse fluxo: recebe, processa e entrega.$q$, 1);
select public.fj_seed_q('log', 'log:alg', 'log:alg:2', 5, 'match', $q$Associe o símbolo do fluxograma ao seu papel$q$, $j${"pairs":[["Oval","Início ou fim"],["Retângulo","Ação ou cálculo"],["Losango","Decisão"],["Seta","Ordem dos passos"]]}$j$, $q$O fluxograma desenha o algoritmo: dá para enxergar o caminho antes de programar.$q$, 2);

-- ---------------------------------------------------------------
-- log:var:1 · Variáveis e atribuição
-- ---------------------------------------------------------------
select public.fj_seed_q('log', 'log:var', 'log:var:1', 0, 'mc', $q$Uma variável funciona como:$q$, $j${"opts":["Uma caixinha com nome que guarda um valor que pode mudar","Um cabo do computador","Um atalho do teclado","Um programa inteiro"],"a":0}$j$, $q$O nome identifica a caixinha; o valor guardado dentro pode ser trocado.$q$, 1);
select public.fj_seed_q('log', 'log:var', 'log:var:1', 1, 'mc', $q$Depois de executar idade = 15 e, em seguida, idade = 16, o valor guardado em idade é:$q$, $j${"opts":["16, porque a nova atribuição substitui o valor anterior","15","31, porque os valores se somam","Nenhum: o programa dá erro"],"a":0}$j$, $q$Atribuir de novo sobrescreve: a caixinha guarda só o último valor.$q$, 1);
select public.fj_seed_q('log', 'log:var', 'log:var:1', 2, 'mc', $q$Em programação, o sinal = em x = 10 significa:$q$, $j${"opts":["Guarde o valor 10 na variável x","Pergunte se x é igual a 10","Apague a variável x","Mostre o 10 na tela"],"a":0}$j$, $q$O = de atribuição guarda; a comparação de igualdade usa outro símbolo (como ==).$q$, 2);
select public.fj_seed_q('log', 'log:var', 'log:var:1', 3, 'tf', $q$Julgue a afirmação sobre nomes de variáveis$q$, $j${"stmt":"Dar nomes claros às variáveis, como precoTotal em vez de p, facilita entender o programa.","a":true}$j$, $q$Verdadeiro: o código é lido muito mais vezes do que é escrito — nomes bons são documentação.$q$, 1);
select public.fj_seed_q('log', 'log:var', 'log:var:1', 4, 'bank', $q$Complete a frase sobre variáveis$q$, $j${"parts":["Guardar um valor numa variável chama-se ","; usamos o "," da variável para recuperar o valor depois."],"a":["atribuição","nome"],"extra":["impressão","preço"]}$j$, $q$Atribui-se pelo nome e lê-se pelo nome — ele é o endereço da caixinha.$q$, 2);
select public.fj_seed_q('log', 'log:var', 'log:var:1', 5, 'order', $q$Ordene os passos para trocar os valores entre as variáveis a e b$q$, $j${"items":["Criar uma variável auxiliar","Guardar o valor de a na auxiliar","Copiar o valor de b para a","Copiar o valor da auxiliar para b"]}$j$, $q$Sem a auxiliar, o primeiro valor seria perdido na primeira cópia.$q$, 3);

-- log:var:2 · Tipos de dados e operadores
select public.fj_seed_q('log', 'log:var', 'log:var:2', 0, 'mc', $q$Qual destes valores é do tipo lógico (booleano)?$q$, $j${"opts":["verdadeiro","'olá'","3,14","42"],"a":0}$j$, $q$O tipo lógico só tem dois valores: verdadeiro e falso.$q$, 1);
select public.fj_seed_q('log', 'log:var', 'log:var:2', 1, 'mc', $q$O operador de resto da divisão (mod) em 10 mod 3 resulta em:$q$, $j${"opts":["1","3","0","10"],"a":0}$j$, $q$10 ÷ 3 dá 3 com resto 1 — o resto é a base de truques como saber se um número é par.$q$, 2);
select public.fj_seed_q('log', 'log:var', 'log:var:2', 2, 'mc', $q$Qual expressão verifica se um número n é par?$q$, $j${"opts":["n mod 2 = 0 (o resto da divisão por 2 é zero)","n + 2 = 0","n × 2 = 0","n − 2 = 0"],"a":0}$j$, $q$Par é todo número que dividido por 2 não deixa resto.$q$, 2);
select public.fj_seed_q('log', 'log:var', 'log:var:2', 3, 'tf', $q$Julgue a afirmação sobre tipos$q$, $j${"stmt":"O texto '7' (entre aspas) e o número 7 são o mesmo tipo de dado para o computador.","a":false}$j$, $q$Falso: '7' é texto e 7 é número — somar texto com número pode dar resultado inesperado.$q$, 2);
select public.fj_seed_q('log', 'log:var', 'log:var:2', 4, 'bank', $q$Complete a frase sobre os tipos de dados$q$, $j${"parts":["Números com casas decimais são do tipo ","; nomes e frases são do tipo ","."],"a":["real","texto"],"extra":["lógico","inteiro"]}$j$, $q$Inteiro: 42. Real: 3,14. Texto: 'Maria'. Lógico: verdadeiro/falso.$q$, 2);
select public.fj_seed_q('log', 'log:var', 'log:var:2', 5, 'match', $q$Associe o valor ao seu tipo$q$, $j${"pairs":[["42","Inteiro"],["3,14","Real"],["'Maria'","Texto"],["falso","Lógico"]]}$j$, $q$Saber o tipo evita operações sem sentido, como dividir um nome por 2.$q$, 1);

-- ---------------------------------------------------------------
-- log:cond:1 · Se... então... senão
-- ---------------------------------------------------------------
select public.fj_seed_q('log', 'log:cond', 'log:cond:1', 0, 'mc', $q$A estrutura se...então...senão serve para:$q$, $j${"opts":["Executar um caminho ou outro dependendo de uma condição","Repetir um bloco várias vezes","Guardar valores em variáveis","Desligar o programa"],"a":0}$j$, $q$É a decisão do programa: condição verdadeira segue o então; falsa, o senão.$q$, 1);
select public.fj_seed_q('log', 'log:cond', 'log:cond:1', 1, 'mc', $q$Pseudocódigo: se nota >= 6 então escreva 'Aprovado' senão escreva 'Recuperação'. Com nota = 4, o que aparece?$q$, $j${"opts":["Recuperação","Aprovado","Nada","As duas mensagens"],"a":0}$j$, $q$4 >= 6 é falso, então o programa executa o bloco do senão.$q$, 1);
select public.fj_seed_q('log', 'log:cond', 'log:cond:1', 2, 'mc', $q$Na mesma regra, o que aparece quando nota = 6?$q$, $j${"opts":["Aprovado, porque 6 >= 6 é verdadeiro","Recuperação","Erro","Depende da sorte"],"a":0}$j$, $q$O >= inclui o próprio valor: 6 >= 6 é verdadeiro — detalhe que muda tudo nos limites.$q$, 2);
select public.fj_seed_q('log', 'log:cond', 'log:cond:1', 3, 'tf', $q$Julgue a afirmação sobre o senão$q$, $j${"stmt":"O bloco do senão executa quando a condição do se é falsa.","a":true}$j$, $q$Verdadeiro: então e senão são caminhos alternativos — nunca executam os dois.$q$, 1);
select public.fj_seed_q('log', 'log:cond', 'log:cond:1', 4, 'bank', $q$Complete a frase sobre condições$q$, $j${"parts":["A condição de um se sempre resulta em "," ou ","."],"a":["verdadeiro","falso"],"extra":["talvez","zero"]}$j$, $q$Não existe meio-termo: a condição é uma pergunta de sim ou não.$q$, 1);
select public.fj_seed_q('log', 'log:cond', 'log:cond:1', 5, 'order', $q$Ordene a execução de um se...então...senão com condição falsa$q$, $j${"items":["Avaliar a condição","Constatar que ela é falsa","Pular o bloco do então","Executar o bloco do senão"]}$j$, $q$Primeiro a condição, depois o desvio: só um dos blocos roda.$q$, 2);

-- log:cond:2 · Condições compostas
select public.fj_seed_q('log', 'log:cond', 'log:cond:2', 0, 'mc', $q$A condição idade >= 16 E idade < 18 é verdadeira para qual idade?$q$, $j${"opts":["17","15","18","21"],"a":0}$j$, $q$17 satisfaz as duas partes; 15 falha na primeira e 18 falha na segunda.$q$, 2);
select public.fj_seed_q('log', 'log:cond', 'log:cond:2', 1, 'mc', $q$Com o operador OU, a condição composta é verdadeira quando:$q$, $j${"opts":["Pelo menos uma das condições é verdadeira","As duas condições são falsas","Somente quando as duas são verdadeiras","Nunca"],"a":0}$j$, $q$OU é inclusivo: basta uma condição valer para a expressão valer.$q$, 2);
select public.fj_seed_q('log', 'log:cond', 'log:cond:2', 2, 'mc', $q$O operador NÃO (negação) faz o quê?$q$, $j${"opts":["Inverte o valor lógico: verdadeiro vira falso e vice-versa","Apaga a variável","Soma 1 ao valor","Repete a condição duas vezes"],"a":0}$j$, $q$NÃO chovendo = tempo seco: a negação espelha a condição.$q$, 2);
select public.fj_seed_q('log', 'log:cond', 'log:cond:2', 3, 'tf', $q$Julgue a afirmação sobre o operador E$q$, $j${"stmt":"Com o operador E, basta uma das condições ser falsa para a expressão inteira ser falsa.","a":true}$j$, $q$Verdadeiro: o E exige todas verdadeiras — uma falha derruba o conjunto.$q$, 2);
select public.fj_seed_q('log', 'log:cond', 'log:cond:2', 4, 'bank', $q$Complete com o resultado: chove = verdadeiro e temGuardaChuva = falso$q$, $j${"parts":["A expressão chove E temGuardaChuva vale ","; a expressão chove OU temGuardaChuva vale ","."],"a":["falso","verdadeiro"],"extra":["zero","erro"]}$j$, $q$E exige as duas; OU se contenta com uma — e chove é verdadeira.$q$, 3);
select public.fj_seed_q('log', 'log:cond', 'log:cond:2', 5, 'match', $q$Associe o operador ao seu comportamento$q$, $j${"pairs":[["E","Verdadeiro só se todas as condições valem"],["OU","Verdadeiro se pelo menos uma vale"],["NÃO","Inverte o valor lógico"],["Comparadores (>, <, =)","Comparam dois valores"]]}$j$, $q$Combinando comparações com E, OU e NÃO, montamos qualquer regra.$q$, 2);

-- ---------------------------------------------------------------
-- log:laco:1 · Repetição com contador
-- ---------------------------------------------------------------
select public.fj_seed_q('log', 'log:laco', 'log:laco:1', 0, 'mc', $q$Um laço (loop) serve para:$q$, $j${"opts":["Repetir um bloco de instruções várias vezes sem reescrevê-lo","Guardar senhas","Deixar o programa mais lento de propósito","Desenhar formas na tela"],"a":0}$j$, $q$Repetição é a força do computador: o laço descreve uma vez o que será feito muitas vezes.$q$, 1);
select public.fj_seed_q('log', 'log:laco', 'log:laco:1', 1, 'mc', $q$O laço para i de 1 até 5: escreva i imprime:$q$, $j${"opts":["1 2 3 4 5","5 4 3 2 1","1 1 1 1 1","Apenas o 5"],"a":0}$j$, $q$O contador i assume cada valor do intervalo, um por volta.$q$, 1);
select public.fj_seed_q('log', 'log:laco', 'log:laco:1', 2, 'mc', $q$Quantas vezes executa o bloco de para i de 0 até 9?$q$, $j${"opts":["10 vezes","9 vezes","11 vezes","1 vez"],"a":0}$j$, $q$De 0 a 9 há 10 valores (0, 1, …, 9): contar a partir do zero engana muita gente.$q$, 3);
select public.fj_seed_q('log', 'log:laco', 'log:laco:1', 3, 'tf', $q$Julgue a afirmação sobre o contador$q$, $j${"stmt":"Num laço com contador, a variável de controle muda a cada volta até atingir o limite.","a":true}$j$, $q$Verdadeiro: é a mudança do contador que aproxima o laço do fim.$q$, 1);
select public.fj_seed_q('log', 'log:laco', 'log:laco:1', 4, 'bank', $q$Complete a frase sobre laços$q$, $j${"parts":["A variável que conta as voltas do laço é o ","; cada volta completa do laço é uma ","."],"a":["contador","iteração"],"extra":["senha","função"]}$j$, $q$Dez iterações = dez voltas do bloco, com o contador marcando o passo.$q$, 2);
select public.fj_seed_q('log', 'log:laco', 'log:laco:1', 5, 'order', $q$Ordene o funcionamento de um laço com contador$q$, $j${"items":["Iniciar o contador","Verificar se ainda está dentro do limite","Executar o bloco","Aumentar o contador e voltar à verificação"]}$j$, $q$Inicializa, testa, executa, avança — e o ciclo recomeça até o teste falhar.$q$, 2);

-- log:laco:2 · Repetição com condição
select public.fj_seed_q('log', 'log:laco', 'log:laco:2', 0, 'mc', $q$O laço enquanto (while) repete o bloco:$q$, $j${"opts":["Enquanto a condição for verdadeira","Exatamente 10 vezes, sempre","Somente uma vez","Até o computador desligar"],"a":0}$j$, $q$O enquanto serve quando não sabemos de antemão quantas voltas serão necessárias.$q$, 1);
select public.fj_seed_q('log', 'log:laco', 'log:laco:2', 1, 'mc', $q$O que é um loop infinito?$q$, $j${"opts":["Um laço cuja condição nunca fica falsa, então ele não termina","Um laço que roda exatamente mil vezes","Um laço dentro de outro laço","Um laço que termina rápido demais"],"a":0}$j$, $q$Se nada dentro do laço muda a condição, o programa trava repetindo para sempre.$q$, 2);
select public.fj_seed_q('log', 'log:laco', 'log:laco:2', 2, 'mc', $q$Pseudocódigo: enquanto senha diferente de '1234', peça a senha. Esse trecho:$q$, $j${"opts":["Continua pedindo a senha até o usuário digitar 1234","Pede a senha uma única vez","Nunca pede a senha","Aceita qualquer senha"],"a":0}$j$, $q$A cada volta a senha é pedida de novo; o laço só termina quando a condição fica falsa.$q$, 2);
select public.fj_seed_q('log', 'log:laco', 'log:laco:2', 3, 'tf', $q$Julgue a afirmação sobre o enquanto$q$, $j${"stmt":"No laço enquanto, se a condição já começa falsa, o bloco não executa nenhuma vez.","a":true}$j$, $q$Verdadeiro: o teste vem antes do bloco — pode dar zero voltas.$q$, 3);
select public.fj_seed_q('log', 'log:laco', 'log:laco:2', 4, 'bank', $q$Complete a frase sobre repetição$q$, $j${"parts":["Para evitar o loop infinito, algo dentro do laço precisa "," a condição em algum momento; a variável que vai somando valores a cada volta é o ","."],"a":["mudar","acumulador"],"extra":["colorir","teclado"]}$j$, $q$O acumulador começa (em geral) em zero e cresce a cada volta — como uma soma de compras.$q$, 2);
select public.fj_seed_q('log', 'log:laco', 'log:laco:2', 5, 'match', $q$Associe o conceito ao seu uso$q$, $j${"pairs":[["para (for)","Repetir um número conhecido de vezes"],["enquanto (while)","Repetir enquanto a condição valer"],["Contador","Conta as voltas do laço"],["Acumulador","Vai somando resultados pelo caminho"]]}$j$, $q$Escolher o laço certo deixa a intenção do código evidente.$q$, 2);

-- ---------------------------------------------------------------
-- log:func:1 · Funções e parâmetros
-- ---------------------------------------------------------------
select public.fj_seed_q('log', 'log:func', 'log:func:1', 0, 'mc', $q$Uma função em programação é:$q$, $j${"opts":["Um bloco de código com nome que pode ser chamado várias vezes","Um tipo de vírus","O manual do computador","Uma pasta de arquivos"],"a":0}$j$, $q$Define-se uma vez, chama-se quantas vezes precisar — pelo nome.$q$, 1);
select public.fj_seed_q('log', 'log:func', 'log:func:1', 1, 'mc', $q$A principal vantagem de criar funções é:$q$, $j${"opts":["Reaproveitar o código e organizar o programa em partes com nome","Aumentar o número de linhas do programa","Esconder o programa do usuário","Gastar mais memória"],"a":0}$j$, $q$Menos repetição e mais clareza: cada parte do problema ganha um nome.$q$, 1);
select public.fj_seed_q('log', 'log:func', 'log:func:1', 2, 'mc', $q$Na chamada calcularMedia(7, 9), os valores 7 e 9 são:$q$, $j${"opts":["Os argumentos passados para os parâmetros da função","Os nomes da função","Erros de digitação","Variáveis globais"],"a":0}$j$, $q$A função declara os parâmetros; na chamada, os argumentos preenchem esses espaços.$q$, 2);
select public.fj_seed_q('log', 'log:func', 'log:func:1', 3, 'tf', $q$Julgue a afirmação sobre o retorno$q$, $j${"stmt":"O retorno de uma função é o valor que ela devolve para quem a chamou.","a":true}$j$, $q$Verdadeiro: a chamada vira o valor retornado — por isso dá para guardar numa variável.$q$, 1);
select public.fj_seed_q('log', 'log:func', 'log:func:1', 4, 'bank', $q$Complete a frase sobre funções$q$, $j${"parts":["Os "," são as entradas que a função recebe; o "," é o valor que ela devolve."],"a":["parâmetros","retorno"],"extra":["laços","comentários"]}$j$, $q$Entradas pelos parâmetros, resultado pelo retorno — o contrato da função.$q$, 1);
select public.fj_seed_q('log', 'log:func', 'log:func:1', 5, 'order', $q$Ordene o que acontece em media = calcularMedia(7, 9)$q$, $j${"items":["A função é chamada com os argumentos 7 e 9","O corpo da função calcula a média","A função retorna 8","O valor 8 é guardado na variável media"]}$j$, $q$Chamada → cálculo → retorno → atribuição: o caminho de toda chamada de função.$q$, 2);

-- log:func:2 · Dividir para conquistar
select public.fj_seed_q('log', 'log:func', 'log:func:2', 0, 'mc', $q$Decompor um problema significa:$q$, $j${"opts":["Quebrá-lo em partes menores e mais fáceis de resolver","Apagá-lo e esperar que suma","Resolvê-lo todo de uma vez","Entregá-lo para outra pessoa"],"a":0}$j$, $q$Problemas grandes assustam; partes pequenas se resolvem uma a uma.$q$, 1);
select public.fj_seed_q('log', 'log:func', 'log:func:2', 1, 'mc', $q$Num sistema de notas, qual divisão em funções faz mais sentido?$q$, $j${"opts":["lerNotas, calcularMedia e mostrarResultado","funcao1, funcao2 e funcao3","umaFuncaoQueFazTudo","x, y e z"],"a":0}$j$, $q$Nomes que dizem o que cada parte faz — a decomposição aparece no próprio código.$q$, 2);
select public.fj_seed_q('log', 'log:func', 'log:func:2', 2, 'mc', $q$Uma variável criada dentro de uma função:$q$, $j${"opts":["Existe só ali dentro (escopo local)","Vale para o computador inteiro","Apaga as variáveis das outras funções","Vira um arquivo no disco"],"a":0}$j$, $q$Escopo local evita que uma função bagunce as variáveis das outras.$q$, 3);
select public.fj_seed_q('log', 'log:func', 'log:func:2', 3, 'tf', $q$Julgue a afirmação sobre responsabilidades$q$, $j${"stmt":"O ideal é que uma função tente fazer o máximo de coisas diferentes ao mesmo tempo.","a":false}$j$, $q$Falso: cada função deve fazer uma coisa bem — fica mais fácil testar, entender e reaproveitar.$q$, 2);
select public.fj_seed_q('log', 'log:func', 'log:func:2', 4, 'bank', $q$Complete a frase sobre organização$q$, $j${"parts":["Dividir o problema em partes menores é a ","; o ideal é cada função ter uma única ","."],"a":["decomposição","responsabilidade"],"extra":["compilação","senha"]}$j$, $q$Decompor + uma responsabilidade por função = programa fácil de crescer.$q$, 2);
select public.fj_seed_q('log', 'log:func', 'log:func:2', 5, 'match', $q$Associe o conceito à sua ideia$q$, $j${"pairs":[["Decomposição","Quebrar o problema em partes"],["Função","Parte com nome e papel claro"],["Escopo local","Variável vive só dentro da função"],["Reuso","Chamar a mesma função em vários lugares"]]}$j$, $q$São as quatro ideias que transformam um código amontoado em um programa organizado.$q$, 2);

-- ---------------------------------------------------------------
-- log:lista:1 · Listas e índices
-- ---------------------------------------------------------------
select public.fj_seed_q('log', 'log:lista', 'log:lista:1', 0, 'mc', $q$Uma lista (vetor) serve para:$q$, $j${"opts":["Guardar vários valores numa única variável, cada um numa posição","Guardar um único número","Conectar o computador à internet","Imprimir documentos"],"a":0}$j$, $q$Em vez de nota1, nota2, nota3… uma lista notas guarda todas, por posição.$q$, 1);
select public.fj_seed_q('log', 'log:lista', 'log:lista:1', 1, 'mc', $q$Na lista frutas = ['uva', 'maçã', 'pera'], com índice começando em 0, frutas[1] é:$q$, $j${"opts":["maçã","uva","pera","Dá erro"],"a":0}$j$, $q$Índice 0 = uva, índice 1 = maçã, índice 2 = pera.$q$, 2);
select public.fj_seed_q('log', 'log:lista', 'log:lista:1', 2, 'mc', $q$Ainda na lista frutas = ['uva', 'maçã', 'pera'], quantos elementos ela tem?$q$, $j${"opts":["3","2","4","0"],"a":0}$j$, $q$Três elementos, nos índices 0, 1 e 2 — o tamanho é 3, mas o último índice é 2.$q$, 1);
select public.fj_seed_q('log', 'log:lista', 'log:lista:1', 3, 'tf', $q$Julgue a afirmação sobre os limites$q$, $j${"stmt":"Numa lista de 3 elementos (índices 0, 1 e 2), acessar o índice 3 causa erro ou devolve algo inexistente.","a":true}$j$, $q$Verdadeiro: passar do último índice é um dos erros mais comuns de quem começa.$q$, 3);
select public.fj_seed_q('log', 'log:lista', 'log:lista:1', 4, 'bank', $q$Complete a frase sobre listas$q$, $j${"parts":["A posição de um elemento na lista chama-se ","; em muitas linguagens a contagem começa do ","."],"a":["índice","zero"],"extra":["senha","um"]}$j$, $q$Primeiro elemento no índice 0: guarde isso e evite muitos sustos.$q$, 1);
select public.fj_seed_q('log', 'log:lista', 'log:lista:1', 5, 'match', $q$Associe a operação ao seu efeito na lista [10, 20, 30]$q$, $j${"pairs":[["Acessar o índice 0","Obtém o 10"],["Adicionar 40 no fim","A lista vira [10, 20, 30, 40]"],["Remover o 20","A lista vira [10, 30]"],["Medir o tamanho","Obtém 3"]]}$j$, $q$Acessar, adicionar, remover e medir: o dia a dia com listas.$q$, 2);

-- log:lista:2 · Percorrendo listas
select public.fj_seed_q('log', 'log:lista', 'log:lista:2', 0, 'mc', $q$Para somar todos os valores de uma lista, usamos:$q$, $j${"opts":["Um laço percorrendo a lista e um acumulador somando cada valor","Uma impressora","Duas listas vazias","Um comentário no código"],"a":0}$j$, $q$Acumulador em 0, uma volta por elemento, soma a cada volta: no fim, o total.$q$, 2);
select public.fj_seed_q('log', 'log:lista', 'log:lista:2', 1, 'mc', $q$Para achar o maior valor de uma lista, a estratégia comum é:$q$, $j${"opts":["Guardar o primeiro como maior e trocar sempre que aparecer um valor maior","Escolher o último, que sempre é o maior","Somar todos e dividir por dois","Colocar a lista em ordem alfabética"],"a":0}$j$, $q$Um campeão provisório que só perde o posto para quem o supera — ao fim, é o maior.$q$, 2);
select public.fj_seed_q('log', 'log:lista', 'log:lista:2', 2, 'mc', $q$Percorrendo a lista [5, 2, 8] com um acumulador que começa em 0, o total ao final é:$q$, $j${"opts":["15","10","8","0"],"a":0}$j$, $q$0 + 5 = 5; 5 + 2 = 7; 7 + 8 = 15.$q$, 2);
select public.fj_seed_q('log', 'log:lista', 'log:lista:2', 3, 'tf', $q$Julgue a afirmação sobre o percurso$q$, $j${"stmt":"Para percorrer uma lista inteira, o laço precisa visitar cada posição uma vez.","a":true}$j$, $q$Verdadeiro: o laço anda índice por índice, do primeiro ao último.$q$, 1);
select public.fj_seed_q('log', 'log:lista', 'log:lista:2', 4, 'bank', $q$Complete a frase sobre o percurso$q$, $j${"parts":["Visitar os elementos um a um é "," a lista; procurar um valor específico nela é uma ","."],"a":["percorrer","busca"],"extra":["imprimir","senha"]}$j$, $q$Somar, contar, achar o maior, buscar: tudo começa com percorrer.$q$, 2);
select public.fj_seed_q('log', 'log:lista', 'log:lista:2', 5, 'order', $q$Ordene o algoritmo que encontra o maior valor da lista$q$, $j${"items":["Guardar o primeiro elemento como maior","Visitar o próximo elemento","Se ele for maior que o guardado, atualizar o maior","Ao fim da lista, informar o maior"]}$j$, $q$Os passos 2 e 3 se repetem para cada elemento — é o laço em ação.$q$, 3);

-- ---------------------------------------------------------------
-- log:erro:1 · Tipos de erro
-- ---------------------------------------------------------------
select public.fj_seed_q('log', 'log:erro', 'log:erro:1', 0, 'mc', $q$Um erro de sintaxe acontece quando:$q$, $j${"opts":["O código desrespeita as regras de escrita da linguagem e nem chega a rodar","O programa roda, mas dá resultado errado","O computador desliga sozinho","A internet cai"],"a":0}$j$, $q$É como errar a gramática: a linguagem não entende e se recusa a executar.$q$, 2);
select public.fj_seed_q('log', 'log:erro', 'log:erro:1', 1, 'mc', $q$Um erro de lógica acontece quando:$q$, $j${"opts":["O programa roda, mas o resultado sai diferente do esperado","O código não compila","Falta energia","O teclado quebra"],"a":0}$j$, $q$O mais traiçoeiro: nenhuma mensagem de erro, só o resultado errado.$q$, 2);
select public.fj_seed_q('log', 'log:erro', 'log:erro:1', 2, 'mc', $q$Um programa que deveria somar usa subtração por engano. Esse é um erro de:$q$, $j${"opts":["Lógica","Sintaxe","Hardware","Internet"],"a":0}$j$, $q$O código é válido e roda — só não faz o que deveria. Erro de lógica.$q$, 2);
select public.fj_seed_q('log', 'log:erro', 'log:erro:1', 3, 'tf', $q$Julgue a afirmação sobre mensagens de erro$q$, $j${"stmt":"Mensagens de erro são inúteis e devem ser ignoradas.","a":false}$j$, $q$Falso: a mensagem costuma dizer o tipo do problema e a linha — é a primeira pista da correção.$q$, 1);
select public.fj_seed_q('log', 'log:erro', 'log:erro:1', 4, 'bank', $q$Complete a frase sobre os erros$q$, $j${"parts":["O erro de "," impede o programa de rodar; o erro de "," deixa rodar, mas com resultado errado."],"a":["sintaxe","lógica"],"extra":["energia","teclado"]}$j$, $q$Sintaxe o computador acusa; lógica, só os testes (ou o usuário) revelam.$q$, 2);
select public.fj_seed_q('log', 'log:erro', 'log:erro:1', 5, 'match', $q$Associe o problema ao tipo de erro$q$, $j${"pairs":[["Esquecer de fechar um parêntese","Erro de sintaxe"],["Usar < no lugar de >","Erro de lógica"],["Dividir por zero durante a execução","Erro em tempo de execução"],["Resultado errado só com valores raros","Erro escondido em caso extremo"]]}$j$, $q$Saber o tipo do erro já aponta onde procurar a causa.$q$, 3);

-- log:erro:2 · Depuração e teste de mesa
select public.fj_seed_q('log', 'log:erro', 'log:erro:2', 0, 'mc', $q$O teste de mesa consiste em:$q$, $j${"opts":["Executar o algoritmo no papel, anotando o valor das variáveis passo a passo","Testar se a mesa aguenta o peso do computador","Apagar o programa e começar de novo","Pedir para alguém adivinhar o erro"],"a":0}$j$, $q$Você faz o papel do computador: linha a linha, anotando cada variável.$q$, 2);
select public.fj_seed_q('log', 'log:erro', 'log:erro:2', 1, 'mc', $q$Depurar (debugar) um programa é:$q$, $j${"opts":["Encontrar e corrigir a causa dos erros observando o comportamento do código","Deixar o código mais bonito","Traduzir o programa para outro idioma","Aumentar a fonte do editor"],"a":0}$j$, $q$Depurar é investigar: reproduzir o erro, localizar a causa e corrigir.$q$, 1);
select public.fj_seed_q('log', 'log:erro', 'log:erro:2', 2, 'mc', $q$Uma técnica simples de depuração é:$q$, $j${"opts":["Imprimir o valor das variáveis em pontos do programa para ver onde ele sai do esperado","Reiniciar o computador várias vezes","Trocar o mouse","Mudar o nome do arquivo"],"a":0}$j$, $q$O print revela o estado do programa — onde o valor diverge, ali mora o problema.$q$, 2);
select public.fj_seed_q('log', 'log:erro', 'log:erro:2', 3, 'tf', $q$Julgue a afirmação sobre os testes$q$, $j${"stmt":"Testar o programa com valores extremos (zero, negativo, lista vazia) ajuda a achar erros escondidos.","a":true}$j$, $q$Verdadeiro: os limites são onde os programas mais quebram.$q$, 2);
select public.fj_seed_q('log', 'log:erro', 'log:erro:2', 4, 'bank', $q$Complete a frase sobre a investigação$q$, $j${"parts":["No teste de "," acompanhamos as variáveis linha a linha; reproduzir o erro com o "," exemplo possível facilita achar a causa."],"a":["mesa","menor"],"extra":["sofá","maior"]}$j$, $q$Quanto menor o exemplo que reproduz o erro, menos lugares para a causa se esconder.$q$, 3);
select public.fj_seed_q('log', 'log:erro', 'log:erro:2', 5, 'order', $q$Ordene uma sessão de depuração$q$, $j${"items":["Reproduzir o erro","Localizar onde o valor sai do esperado","Corrigir a causa","Testar de novo para confirmar"]}$j$, $q$Sem reproduzir, não há o que investigar; sem retestar, não há como ter certeza.$q$, 2);

-- ---------------------------------------------------------------
-- log:prob:1 · Do problema ao algoritmo
-- ---------------------------------------------------------------
select public.fj_seed_q('log', 'log:prob', 'log:prob:1', 0, 'mc', $q$Qual é o primeiro passo para resolver um problema com programação?$q$, $j${"opts":["Entender bem o problema: o que entra, o que sai e quais são as regras","Escrever código o mais rápido possível","Escolher a cor do site","Comprar um computador novo"],"a":0}$j$, $q$Código para o problema errado é trabalho perdido — entender vem antes de digitar.$q$, 1);
select public.fj_seed_q('log', 'log:prob', 'log:prob:1', 1, 'mc', $q$Pseudocódigo é:$q$, $j${"opts":["Uma escrita informal do algoritmo, em português estruturado, antes do código real","Um código cheio de erros","Uma linguagem secreta de hackers","Um programa já pronto"],"a":0}$j$, $q$Pensa-se a lógica em português; a tradução para a linguagem vem depois.$q$, 2);
select public.fj_seed_q('log', 'log:prob', 'log:prob:1', 2, 'mc', $q$Problema: dizer se o aluno passou (média maior ou igual a 6). O que entra e o que sai?$q$, $j${"opts":["Entram as notas; sai a resposta: passou ou não passou","Entra o nome da escola; sai o endereço","Entra a cor preferida; sai a idade","Nada entra e nada sai"],"a":0}$j$, $q$Definir entrada e saída já é metade do algoritmo.$q$, 1);
select public.fj_seed_q('log', 'log:prob', 'log:prob:1', 3, 'tf', $q$Julgue a afirmação sobre o planejamento$q$, $j${"stmt":"Vale a pena planejar o algoritmo antes de escrever o código.","a":true}$j$, $q$Verdadeiro: errar no papel custa minutos; errar no código, horas.$q$, 1);
select public.fj_seed_q('log', 'log:prob', 'log:prob:1', 4, 'bank', $q$Complete a frase sobre o planejamento$q$, $j${"parts":["Antes do código, descrevemos a solução em ","; o diagrama com setas, retângulos e losangos é o ","."],"a":["pseudocódigo","fluxograma"],"extra":["binário","boleto"]}$j$, $q$Pseudocódigo escreve a lógica; fluxograma a desenha. Os dois planejam.$q$, 2);
select public.fj_seed_q('log', 'log:prob', 'log:prob:1', 5, 'order', $q$Ordene o caminho do problema à solução$q$, $j${"items":["Entender o problema","Planejar o algoritmo","Escrever o código","Testar com exemplos"]}$j$, $q$Entender → planejar → codificar → testar: pular etapas cobra caro depois.$q$, 1);

-- log:prob:2 · Refinando a solução
select public.fj_seed_q('log', 'log:prob', 'log:prob:2', 0, 'mc', $q$Casos extremos (casos de borda) são:$q$, $j${"opts":["Situações-limite, como lista vazia ou valor zero, que costumam quebrar soluções apressadas","Os casos mais comuns do sistema","Erros de digitação do usuário","Problemas de conexão"],"a":0}$j$, $q$A solução que funciona no caso comum pode falhar no limite — teste as bordas.$q$, 2);
select public.fj_seed_q('log', 'log:prob', 'log:prob:2', 1, 'mc', $q$Duas soluções corretas para o mesmo problema:$q$, $j${"opts":["Podem ter eficiências diferentes — uma pode exigir bem menos passos","São sempre idênticas","Gastam sempre o mesmo tempo","Não existem: só há uma solução certa"],"a":0}$j$, $q$Certo é o mínimo; entre soluções certas, vence a mais simples e eficiente.$q$, 2);
select public.fj_seed_q('log', 'log:prob', 'log:prob:2', 2, 'mc', $q$Procurar um nome numa lista ordenada abrindo sempre no meio e descartando metade é a ideia da:$q$, $j${"opts":["Busca binária","Busca cega","Impressão em série","Soma acumulada"],"a":0}$j$, $q$Em uma lista de mil nomes, a busca binária acha qualquer um em cerca de 10 passos.$q$, 3);
select public.fj_seed_q('log', 'log:prob', 'log:prob:2', 3, 'tf', $q$Julgue a afirmação sobre os testes$q$, $j${"stmt":"Se o programa funcionou com um exemplo, está garantido que funciona com todos.","a":false}$j$, $q$Falso: um teste só não cobre os extremos — varie os valores e teste os limites.$q$, 2);
select public.fj_seed_q('log', 'log:prob', 'log:prob:2', 4, 'bank', $q$Complete a frase sobre o refinamento$q$, $j${"parts":["Testar com lista vazia e com um único elemento cobre os casos ","; contar os passos de cada solução compara a ","."],"a":["extremos","eficiência"],"extra":["bonitos","cor"]}$j$, $q$Refinar é cobrir as bordas e, quando valer a pena, gastar menos passos.$q$, 3);
select public.fj_seed_q('log', 'log:prob', 'log:prob:2', 5, 'match', $q$Associe o conceito à sua ideia$q$, $j${"pairs":[["Caso extremo","Situação-limite que derruba soluções frágeis"],["Eficiência","Resolver com menos passos"],["Refinar","Melhorar a solução sem mudar o resultado"],["Busca binária","Descartar metade a cada passo"]]}$j$, $q$Resolver é o começo; refinar é o que separa o iniciante do programador maduro.$q$, 3);

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
  for q in select id, dados from public.questoes where tipo = 'mc' and materia_id = 'log' loop
    n := coalesce(jsonb_array_length(q.dados->'opts'), 0);
    if n < 2 then continue; end if;
    select array_agg(i order by random()) into perm from generate_series(0, n - 1) i;
    select jsonb_agg(q.dados->'opts'->perm[i] order by i) into novo from generate_series(1, n) i;
    na := coalesce(array_position(perm, coalesce((q.dados->>'a')::int, 0)), 1) - 1;
    update public.questoes set dados = dados || jsonb_build_object('opts', novo, 'a', na) where id = q.id;
  end loop;
end $$;
alter table public.questoes enable trigger auditoria_questoes;

insert into public.schema_versao (versao) values (42) on conflict do nothing;
