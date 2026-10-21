-- =====================================================================
-- Findout Jornada · Migration 0050 · Nova seção nas matérias novas e cursos
-- Rodar no SQL Editor do Supabase depois da 0049. Idempotente: pode rodar de novo.
-- Depois de rodar, abra o painel: ele publica a nova versão sozinho.
--
-- Cada uma das 5 matérias recentes ganha uma 5ª seção com 2 unidades,
-- 4 lições e 24 questões (total: 10 unidades, 20 lições, 120 questões):
--   gmt · Círculo e transformações (elementos do círculo, setores; simetria e transformações)
--   rac · Lógica e incerteza (probabilidade no cotidiano; falácias comuns)
--   dev · Qualidade e colaboração (Git e versionamento; segurança de aplicações)
--   log · Estruturas e abstrações (matrizes e tabelas; recursão e divisão de problemas)
--   dat · Preparação e indicadores (limpeza de dados; métricas e KPIs)
--
-- Regra do seed: o id da questão vem de md5(lição + enunciado); cada enunciado é único dentro da lição.
-- As alternativas de múltipla escolha são escritas com a resposta na posição A e
-- embaralhadas no fim do arquivo, APENAS nas unidades novas (molde da 0019/0039).
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

insert into public.secoes (id, materia_id, titulo, ordem) values
(md5('sec:gmt:circtrans')::uuid, 'gmt', 'Círculo e transformações', 4),
(md5('sec:rac:incerteza')::uuid, 'rac', 'Lógica e incerteza', 4),
(md5('sec:dev:qualidade')::uuid, 'dev', 'Qualidade e colaboração', 4),
(md5('sec:log:estruturas')::uuid, 'log', 'Estruturas e abstrações', 4),
(md5('sec:dat:preparacao')::uuid, 'dat', 'Preparação e indicadores', 4)
on conflict (id) do nothing;

insert into public.unidades (id, secao_id, titulo, ordem) values
(md5('uni:gmt:circ')::uuid, md5('sec:gmt:circtrans')::uuid, 'Elementos do círculo', 0),
(md5('uni:gmt:trans')::uuid, md5('sec:gmt:circtrans')::uuid, 'Simetria e transformações', 1),
(md5('uni:rac:prob')::uuid, md5('sec:rac:incerteza')::uuid, 'Probabilidade no cotidiano', 0),
(md5('uni:rac:fal')::uuid, md5('sec:rac:incerteza')::uuid, 'Falácias comuns', 1),
(md5('uni:dev:git')::uuid, md5('sec:dev:qualidade')::uuid, 'Git e versionamento', 0),
(md5('uni:dev:seg')::uuid, md5('sec:dev:qualidade')::uuid, 'Segurança de aplicações', 1),
(md5('uni:log:mat')::uuid, md5('sec:log:estruturas')::uuid, 'Matrizes e tabelas', 0),
(md5('uni:log:rec')::uuid, md5('sec:log:estruturas')::uuid, 'Recursão e divisão de problemas', 1),
(md5('uni:dat:limp')::uuid, md5('sec:dat:preparacao')::uuid, 'Limpeza e preparação de dados', 0),
(md5('uni:dat:ind')::uuid, md5('sec:dat:preparacao')::uuid, 'Métricas e indicadores', 1)
on conflict (id) do nothing;

insert into public.licoes (id, unidade_id, titulo, descricao, ordem) values
(md5('lic:gmt:circ:1')::uuid, md5('uni:gmt:circ')::uuid, 'Raio, corda e arco', 'As peças do círculo: raio, diâmetro, corda, arco e tangente.', 0),
(md5('lic:gmt:circ:2')::uuid, md5('uni:gmt:circ')::uuid, 'Setores e ângulo central', 'A volta de 360° e as fatias do círculo.', 1),
(md5('lic:gmt:trans:1')::uuid, md5('uni:gmt:trans')::uuid, 'Simetria', 'Eixos de simetria e o reflexo no espelho.', 0),
(md5('lic:gmt:trans:2')::uuid, md5('uni:gmt:trans')::uuid, 'Rotação, translação e escala', 'Deslizar, girar e ampliar mantendo a forma.', 1),
(md5('lic:rac:prob:1')::uuid, md5('uni:rac:prob')::uuid, 'Chance e probabilidade', 'Casos favoráveis sobre casos possíveis.', 0),
(md5('lic:rac:prob:2')::uuid, md5('uni:rac:prob')::uuid, 'Complementar e armadilhas da chance', 'O evento complementar e a moeda sem memória.', 1),
(md5('lic:rac:fal:1')::uuid, md5('uni:rac:fal')::uuid, 'Generalização e falsa causa', 'Poucos casos não fazem regra; depois de não é por causa de.', 0),
(md5('lic:rac:fal:2')::uuid, md5('uni:rac:fal')::uuid, 'Apelos e ataques', 'Ad hominem, "todo mundo faz" e o falso dilema.', 1),
(md5('lic:dev:git:1')::uuid, md5('uni:dev:git')::uuid, 'Commits e histórico', 'O diário do projeto: commits, mensagens e o repositório remoto.', 0),
(md5('lic:dev:git:2')::uuid, md5('uni:dev:git')::uuid, 'Branches e colaboração', 'Trabalhar em paralelo: branch, merge, conflito e pull request.', 1),
(md5('lic:dev:seg:1')::uuid, md5('uni:dev:seg')::uuid, 'Senhas e dados', 'Hash de senha, HTTPS e quem pode fazer o quê.', 0),
(md5('lic:dev:seg:2')::uuid, md5('uni:dev:seg')::uuid, 'Ataques comuns', 'SQL injection, XSS, phishing e o menor privilégio.', 1),
(md5('lic:log:mat:1')::uuid, md5('uni:log:mat')::uuid, 'Linhas e colunas', 'A matriz como tabela: endereço por linha e coluna.', 0),
(md5('lic:log:mat:2')::uuid, md5('uni:log:mat')::uuid, 'Percorrendo tabelas', 'Laços aninhados para visitar a tabela inteira.', 1),
(md5('lic:log:rec:1')::uuid, md5('uni:log:rec')::uuid, 'A função que chama a si mesma', 'Recursão, caso base e o fatorial.', 0),
(md5('lic:log:rec:2')::uuid, md5('uni:log:rec')::uuid, 'Dividir para conquistar', 'Quebrar o problema no meio: a busca binária.', 1),
(md5('lic:dat:limp:1')::uuid, md5('uni:dat:limp')::uuid, 'Dados sujos', 'Ausentes, duplicatas e valores fora do padrão.', 0),
(md5('lic:dat:limp:2')::uuid, md5('uni:dat:limp')::uuid, 'Tratando os problemas', 'Imputação, outliers e decisões documentadas.', 1),
(md5('lic:dat:ind:1')::uuid, md5('uni:dat:ind')::uuid, 'KPIs do dia a dia', 'Conversão, ticket médio e o que faz um indicador ser chave.', 0),
(md5('lic:dat:ind:2')::uuid, md5('uni:dat:ind')::uuid, 'Lendo indicadores com cuidado', 'Metas, sazonalidade e a média móvel.', 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- gmt:circ:1 · Raio, corda e arco
-- ---------------------------------------------------------------
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:1', 0, 'mc', $q$Um círculo tem raio de 7 cm. Seu diâmetro mede:$q$, $j${"opts":["14 cm","7 cm","21 cm","49 cm"],"a":0}$j$, $q$O diâmetro é o dobro do raio: 2 × 7 = 14 cm.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:1', 1, 'mc', $q$A maior corda de uma circunferência é:$q$, $j${"opts":["O diâmetro, que passa pelo centro","O raio","Qualquer arco","A tangente"],"a":0}$j$, $q$Corda liga dois pontos da circunferência; a mais comprida possível atravessa o centro — é o diâmetro.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:1', 2, 'mc', $q$Uma reta tangente à circunferência é a que:$q$, $j${"opts":["Toca a circunferência em exatamente um ponto","Corta a circunferência em dois pontos","Passa pelo centro","Nunca encosta na circunferência"],"a":0}$j$, $q$Como a estrada que encosta na roda: tangente toca num único ponto.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:1', 3, 'tf', $q$Julgue a afirmação sobre cordas$q$, $j${"stmt":"Todo diâmetro é uma corda que passa pelo centro.","a":true}$j$, $q$Verdadeiro: o diâmetro é um caso especial de corda — a que atravessa o centro.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:1', 4, 'bank', $q$Complete a frase sobre os elementos do círculo$q$, $j${"parts":["O segmento do centro até a circunferência é o ","; a corda que passa pelo centro é o ","."],"a":["raio","diâmetro"],"extra":["arco","setor"]}$j$, $q$Raio: metade do caminho. Diâmetro: a travessia completa pelo centro.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:1', 5, 'match', $q$Associe o elemento do círculo à sua descrição$q$, $j${"pairs":[["Raio","Do centro até a borda"],["Corda","Liga dois pontos da circunferência"],["Arco","Pedaço da circunferência"],["Tangente","Reta que toca num único ponto"]]}$j$, $q$Raio e corda são segmentos; arco é curva; tangente é reta que só encosta.$q$, 2);

-- gmt:circ:2 · Setores e ângulo central
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:2', 0, 'mc', $q$Uma pizza foi dividida em 8 fatias iguais. O ângulo central de cada fatia mede:$q$, $j${"opts":["45°","36°","60°","90°"],"a":0}$j$, $q$360° ÷ 8 = 45° por fatia.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:2', 1, 'mc', $q$Um círculo tem área de 40 cm². Um setor de 90° desse círculo tem área de:$q$, $j${"opts":["10 cm²","20 cm²","4 cm²","160 cm²"],"a":0}$j$, $q$90° é 1/4 de 360°, então o setor vale 1/4 da área: 40 ÷ 4 = 10 cm².$q$, 3);
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:2', 2, 'mc', $q$Às 3 horas em ponto, o ângulo entre os ponteiros do relógio é:$q$, $j${"opts":["90°","45°","60°","120°"],"a":0}$j$, $q$Cada hora no mostrador vale 360° ÷ 12 = 30°; de 12 até 3 são 3 × 30° = 90°.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:2', 3, 'tf', $q$Julgue a afirmação sobre o semicírculo$q$, $j${"stmt":"O semicírculo corresponde a um ângulo central de 180°.","a":true}$j$, $q$Verdadeiro: metade da volta completa de 360°.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:2', 4, 'bank', $q$Complete a frase sobre a volta completa$q$, $j${"parts":["O círculo completo tem "," graus; a fatia limitada por dois raios chama-se ","."],"a":["360","setor"],"extra":["180","corda"]}$j$, $q$A volta inteira mede 360°; cada fatia dela é um setor circular.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:circ', 'gmt:circ:2', 5, 'order', $q$Ordene os passos para calcular a área de um setor circular$q$, $j${"items":["Identificar o ângulo central do setor","Dividir o ângulo por 360° para achar a fração do círculo","Calcular a área do círculo inteiro (πr²)","Multiplicar a área pela fração"]}$j$, $q$O setor é uma fração do círculo: ângulo/360° vezes a área total.$q$, 3);

-- ---------------------------------------------------------------
-- gmt:trans:1 · Simetria
-- ---------------------------------------------------------------
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:1', 0, 'mc', $q$Uma figura tem eixo de simetria quando:$q$, $j${"opts":["Uma metade é o reflexo exato da outra em relação a uma linha","Tem quatro lados iguais","Pode ser girada","Tem área maior que o perímetro"],"a":0}$j$, $q$Dobre a figura no eixo: as metades coincidem, como num espelho.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:1', 1, 'mc', $q$Quantos eixos de simetria tem um quadrado?$q$, $j${"opts":["4","2","1","8"],"a":0}$j$, $q$Dois pelos meios dos lados e dois pelas diagonais: 4 eixos.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:1', 2, 'mc', $q$Qual destas letras maiúsculas tem eixo de simetria vertical?$q$, $j${"opts":["A","F","G","J"],"a":0}$j$, $q$O A dobrado ao meio na vertical coincide; F, G e J não têm essa simetria.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:1', 3, 'tf', $q$Julgue a afirmação sobre o círculo$q$, $j${"stmt":"O círculo tem infinitos eixos de simetria.","a":true}$j$, $q$Verdadeiro: qualquer reta que passe pelo centro é um eixo de simetria.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:1', 4, 'bank', $q$Complete a frase sobre o espelho$q$, $j${"parts":["A linha que divide a figura em duas metades espelhadas é o eixo de ","; a imagem no espelho é um exemplo de ","."],"a":["simetria","reflexão"],"extra":["rotação","translação"]}$j$, $q$Simetria de reflexão: o que está de um lado do eixo aparece espelhado do outro.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:1', 5, 'match', $q$Associe a figura ao número de eixos de simetria$q$, $j${"pairs":[["Quadrado","4 eixos"],["Retângulo não quadrado","2 eixos"],["Triângulo equilátero","3 eixos"],["Círculo","Infinitos eixos"]]}$j$, $q$Quanto mais regular a figura, mais eixos de simetria ela tem.$q$, 3);

-- gmt:trans:2 · Rotação, translação e escala
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:2', 0, 'mc', $q$Uma peça desliza pelo tabuleiro sem girar nem mudar de tamanho. Ela sofreu uma:$q$, $j${"opts":["Translação","Rotação","Reflexão","Ampliação"],"a":0}$j$, $q$Translação é o deslizamento: muda o lugar, mantém forma, tamanho e orientação.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:2', 1, 'mc', $q$O movimento do ponteiro do relógio em torno do centro é uma:$q$, $j${"opts":["Rotação","Translação","Reflexão","Dilatação do tamanho"],"a":0}$j$, $q$Rotação: giro em torno de um ponto fixo — aqui, o centro do relógio.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:2', 2, 'mc', $q$Uma foto foi ampliada 3 vezes. O que acontece com a figura?$q$, $j${"opts":["Os lados triplicam e os ângulos não mudam","Os lados e os ângulos triplicam","Só os ângulos aumentam","Nada muda"],"a":0}$j$, $q$Ampliação é uma semelhança: multiplica as medidas dos lados e preserva os ângulos.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:2', 3, 'tf', $q$Julgue a afirmação sobre a translação$q$, $j${"stmt":"Na translação, a figura muda de tamanho.","a":false}$j$, $q$Falso: a translação só muda a posição; quem muda o tamanho é a ampliação ou redução.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:2', 4, 'bank', $q$Complete a frase sobre os movimentos$q$, $j${"parts":["Deslizar sem girar é a ","; girar em torno de um ponto é a ","."],"a":["translação","rotação"],"extra":["reflexão","ampliação"]}$j$, $q$Translação desliza, rotação gira, reflexão espelha, ampliação muda o tamanho.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:trans', 'gmt:trans:2', 5, 'match', $q$Associe a transformação ao seu efeito$q$, $j${"pairs":[["Translação","Desliza mantendo a forma"],["Rotação","Gira em torno de um ponto"],["Reflexão","Espelha em relação a um eixo"],["Ampliação","Muda o tamanho mantendo a forma"]]}$j$, $q$As três primeiras preservam o tamanho; a ampliação preserva só a forma.$q$, 2);

-- ---------------------------------------------------------------
-- rac:prob:1 · Chance e probabilidade
-- ---------------------------------------------------------------
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:1', 0, 'mc', $q$Ao lançar um dado comum de 6 faces, a probabilidade de sair o número 5 é:$q$, $j${"opts":["1/6","1/5","5/6","1/2"],"a":0}$j$, $q$Um caso favorável (o 5) entre seis possíveis: 1/6.$q$, 1);
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:1', 1, 'mc', $q$Num dado comum, a probabilidade de sair um número par é:$q$, $j${"opts":["1/2","1/6","1/3","2/3"],"a":0}$j$, $q$Pares: 2, 4 e 6 — três favoráveis em seis possíveis = 3/6 = 1/2.$q$, 2);
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:1', 2, 'mc', $q$Uma urna tem 3 bolas vermelhas e 7 azuis. A probabilidade de tirar uma vermelha é:$q$, $j${"opts":["3/10","7/10","1/3","3/7"],"a":0}$j$, $q$3 favoráveis entre 3 + 7 = 10 possíveis: 3/10.$q$, 2);
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:1', 3, 'tf', $q$Julgue a afirmação sobre os limites da probabilidade$q$, $j${"stmt":"Uma probabilidade pode ser maior que 1.","a":false}$j$, $q$Falso: ela vai de 0 (impossível) a 1 (certo) — ou de 0% a 100%.$q$, 1);
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:1', 4, 'bank', $q$Complete a definição de probabilidade$q$, $j${"parts":["A probabilidade é a razão entre os casos "," e os casos ","."],"a":["favoráveis","possíveis"],"extra":["impossíveis","repetidos"]}$j$, $q$Favoráveis em cima, possíveis embaixo — contando tudo o que pode acontecer.$q$, 1);
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:1', 5, 'match', $q$Associe o evento à sua probabilidade$q$, $j${"pairs":[["Evento certo","1"],["Evento impossível","0"],["Cara no lançamento de uma moeda","1/2"],["Sair 3 num dado comum","1/6"]]}$j$, $q$Do impossível (0) ao certo (1), tudo tem um lugar na régua da probabilidade.$q$, 2);

-- rac:prob:2 · Complementar e armadilhas da chance
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:2', 0, 'mc', $q$A previsão diz 30% de chance de chover. A chance de NÃO chover é:$q$, $j${"opts":["70%","30%","50%","É impossível saber"],"a":0}$j$, $q$Chover e não chover são complementares: 100% − 30% = 70%.$q$, 1);
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:2', 1, 'mc', $q$Uma moeda honesta deu cara 5 vezes seguidas. No próximo lançamento, a chance de cara é:$q$, $j${"opts":["1/2 — a moeda não guarda memória dos lançamentos","Menor que 1/2, porque cara já saiu demais","Maior que 1/2, porque está numa sequência","Zero"],"a":0}$j$, $q$Cada lançamento é independente: o passado não muda a moeda. Achar que muda é a falácia do jogador.$q$, 3);
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:2', 2, 'mc', $q$Numa rifa de 100 números, comprei 5. Minha chance de ganhar é:$q$, $j${"opts":["5%","20%","0,5%","10%"],"a":0}$j$, $q$5 favoráveis em 100 possíveis = 5/100 = 5%.$q$, 2);
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:2', 3, 'tf', $q$Julgue a afirmação sobre números atrasados$q$, $j${"stmt":"Num sorteio honesto, um número que não sai há muito tempo tem mais chance de sair agora.","a":false}$j$, $q$Falso: cada sorteio é independente; o "número atrasado" é uma ilusão famosa.$q$, 3);
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:2', 4, 'bank', $q$Complete a frase sobre o complementar$q$, $j${"parts":["A soma da probabilidade de um evento com a do seu "," é sempre ","."],"a":["complementar","1"],"extra":["dobro","0"]}$j$, $q$Ou acontece, ou não acontece: as duas chances juntas fecham 1 (100%).$q$, 2);
select public.fj_seed_q('rac', 'rac:prob', 'rac:prob:2', 5, 'order', $q$Ordene os passos para calcular a probabilidade de um evento simples$q$, $j${"items":["Contar todos os casos possíveis","Contar os casos favoráveis ao evento","Dividir os favoráveis pelos possíveis","Interpretar o resultado entre 0 e 1"]}$j$, $q$Contar, contar, dividir: a receita básica da probabilidade.$q$, 2);

-- ---------------------------------------------------------------
-- rac:fal:1 · Generalização e falsa causa
-- ---------------------------------------------------------------
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:1', 0, 'mc', $q$"Conheci dois cariocas apressados; logo, todo carioca é apressado." Esse raciocínio é uma:$q$, $j${"opts":["Generalização apressada: poucos casos virando regra geral","Dedução válida","Definição correta","Probabilidade bem calculada"],"a":0}$j$, $q$Dois exemplos não sustentam uma conclusão sobre milhões de pessoas.$q$, 2);
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:1', 1, 'mc', $q$"Usei uma pulseira nova e o time ganhou; a pulseira dá sorte." O erro desse raciocínio é:$q$, $j${"opts":["Falsa causa: uma coisa aconteceu depois da outra, não por causa dela","Generalizar a partir de muitos casos","Usar estatística demais","Não torcer o suficiente"],"a":0}$j$, $q$Vir depois não é ser causado por: o time ganharia com ou sem a pulseira.$q$, 2);
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:1', 2, 'mc', $q$Vendas de sorvete e casos de afogamento sobem juntos no ano. A explicação mais provável é:$q$, $j${"opts":["Uma terceira causa, o calor do verão, aumenta os dois","O sorvete causa os afogamentos","Os afogamentos causam a venda de sorvete","É pura coincidência sem explicação possível"],"a":0}$j$, $q$Correlação não é causalidade: no verão, mais gente toma sorvete E mais gente nada.$q$, 3);
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:1', 3, 'tf', $q$Julgue a afirmação sobre causa e tempo$q$, $j${"stmt":"Se B aconteceu logo depois de A, então A com certeza causou B.","a":false}$j$, $q$Falso: essa é a falácia da falsa causa (post hoc) — a ordem no tempo não prova a causa.$q$, 2);
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:1', 4, 'bank', $q$Complete a frase sobre os dois erros$q$, $j${"parts":["Tirar regra geral de poucos exemplos é a "," apressada; confundir 'depois de' com 'por causa de' é a falsa ","."],"a":["generalização","causa"],"extra":["conclusão","premissa"]}$j$, $q$Dois clássicos do raciocínio torto: amostras pequenas e causas inventadas.$q$, 2);
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:1', 5, 'match', $q$Associe o conceito à sua descrição$q$, $j${"pairs":[["Generalização apressada","Poucos casos viram regra geral"],["Falsa causa","Aconteceu depois, então foi por causa"],["Correlação","Duas coisas variam juntas"],["Causalidade","Uma coisa realmente provoca a outra"]]}$j$, $q$Separar o que anda junto do que de fato causa é o coração do raciocínio crítico.$q$, 3);

-- rac:fal:2 · Apelos e ataques
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:2', 0, 'mc', $q$"Não acredite no argumento dele: ele é jovem demais." Essa resposta comete a falácia:$q$, $j${"opts":["Ad hominem: ataca a pessoa em vez do argumento","Falso dilema","Generalização apressada","Apelo à popularidade"],"a":0}$j$, $q$A idade de quem fala não diz se o argumento é bom ou ruim.$q$, 2);
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:2', 1, 'mc', $q$"Todo mundo usa esse aplicativo, então ele é seguro." Esse raciocínio é um:$q$, $j${"opts":["Apelo à popularidade: muita gente fazer não torna verdadeiro","Argumento válido","Apelo à autoridade legítima","Caso base de recursão"],"a":0}$j$, $q$Popularidade mede uso, não segurança: milhões já usaram apps inseguros.$q$, 2);
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:2', 2, 'mc', $q$"Ou você está 100% comigo, ou está contra mim." Essa frase comete o:$q$, $j${"opts":["Falso dilema: apresenta só duas opções quando existem outras","Ad hominem","Apelo à tradição","Raciocínio por analogia"],"a":0}$j$, $q$Entre o 100% a favor e o contra existe um mundo de posições intermediárias.$q$, 2);
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:2', 3, 'tf', $q$Julgue a afirmação sobre a fama$q$, $j${"stmt":"Se um ator famoso recomenda um remédio, isso garante que o remédio funciona.","a":false}$j$, $q$Falso: é apelo à autoridade indevida — fama em uma área não é competência em outra.$q$, 2);
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:2', 4, 'bank', $q$Complete a frase sobre os apelos$q$, $j${"parts":["Atacar quem fala em vez do argumento é o ataque ","; dizer que algo é verdade porque todo mundo concorda é o apelo à ","."],"a":["pessoal","popularidade"],"extra":["lógico","evidência"]}$j$, $q$Ad hominem mira a pessoa; o apelo à popularidade mira a maioria — nenhum olha o argumento.$q$, 2);
select public.fj_seed_q('rac', 'rac:fal', 'rac:fal:2', 5, 'match', $q$Associe a falácia ao seu exemplo$q$, $j${"pairs":[["Ad hominem","Ataca a pessoa, não a ideia"],["Apelo à popularidade","Todo mundo faz, então está certo"],["Falso dilema","Só apresenta duas opções"],["Autoridade indevida","Famoso opinando fora da área dele"]]}$j$, $q$Reconhecer a falácia pelo nome ajuda a desarmá-la na hora do debate.$q$, 3);

-- ---------------------------------------------------------------
-- dev:git:1 · Commits e histórico
-- ---------------------------------------------------------------
select public.fj_seed_q('dev', 'dev:git', 'dev:git:1', 0, 'mc', $q$No Git, um commit é:$q$, $j${"opts":["Um registro das mudanças com uma mensagem, que entra no histórico do projeto","Uma cópia de segurança em pen drive","O nome do servidor","Um erro de compilação"],"a":0}$j$, $q$Cada commit é uma foto das mudanças: o histórico do projeto é a sequência delas.$q$, 1);
select public.fj_seed_q('dev', 'dev:git', 'dev:git:1', 1, 'mc', $q$A mensagem do commit serve principalmente para:$q$, $j${"opts":["Explicar o que mudou e por quê, para quem ler o histórico depois","Deixar o código mais rápido","Compilar o projeto","Impedir conflitos para sempre"],"a":0}$j$, $q$Semanas depois, a mensagem é o que conta a história — inclusive para você mesmo.$q$, 2);
select public.fj_seed_q('dev', 'dev:git', 'dev:git:1', 2, 'mc', $q$Qual comando envia os commits locais para o repositório remoto (ex.: GitHub)?$q$, $j${"opts":["git push","git pull","git status","git log"],"a":0}$j$, $q$Push empurra para o remoto; pull puxa de lá; status e log só consultam.$q$, 2);
select public.fj_seed_q('dev', 'dev:git', 'dev:git:1', 3, 'tf', $q$Julgue a afirmação sobre o controle de versão$q$, $j${"stmt":"Com o controle de versão, é possível voltar a uma versão anterior do código.","a":true}$j$, $q$Verdadeiro: cada commit fica guardado, e dá para inspecionar ou restaurar qualquer ponto do histórico.$q$, 1);
select public.fj_seed_q('dev', 'dev:git', 'dev:git:1', 4, 'bank', $q$Complete a frase sobre o fluxo básico$q$, $j${"parts":["O "," registra as mudanças com uma mensagem; o "," envia esses registros ao repositório remoto."],"a":["commit","push"],"extra":["pull","branch"]}$j$, $q$Commit grava localmente; push publica no remoto para o time ver.$q$, 2);
select public.fj_seed_q('dev', 'dev:git', 'dev:git:1', 5, 'match', $q$Associe o comando do Git à sua função$q$, $j${"pairs":[["git status","Mostra o que mudou e ainda não foi registrado"],["git log","Lista o histórico de commits"],["git push","Envia os commits ao remoto"],["git pull","Traz as novidades do remoto"]]}$j$, $q$Status e log olham; push e pull movem commits entre o local e o remoto.$q$, 2);

-- dev:git:2 · Branches e colaboração
select public.fj_seed_q('dev', 'dev:git', 'dev:git:2', 0, 'mc', $q$Uma branch serve para:$q$, $j${"opts":["Desenvolver uma mudança isolada sem mexer na linha principal do projeto","Apagar o histórico","Acelerar o computador","Substituir os testes"],"a":0}$j$, $q$A branch é uma linha paralela: você trabalha nela e só integra quando estiver pronto.$q$, 1);
select public.fj_seed_q('dev', 'dev:git', 'dev:git:2', 1, 'mc', $q$Um conflito de merge acontece quando:$q$, $j${"opts":["Duas branches alteram o mesmo trecho do arquivo e o Git não decide sozinho","O computador fica sem internet","A mensagem do commit é longa","O projeto não tem testes"],"a":0}$j$, $q$O Git junta o que consegue; quando o mesmo trecho mudou dos dois lados, quem decide é você.$q$, 2);
select public.fj_seed_q('dev', 'dev:git', 'dev:git:2', 2, 'mc', $q$Um pull request (PR) é:$q$, $j${"opts":["Um pedido para integrar a branch, com revisão do código pelos colegas","Um comando que desinstala o Git","Um tipo de banco de dados","Um backup automático"],"a":0}$j$, $q$O PR mostra as mudanças, permite comentários e só integra depois da aprovação.$q$, 2);
select public.fj_seed_q('dev', 'dev:git', 'dev:git:2', 3, 'tf', $q$Julgue a afirmação sobre os conflitos$q$, $j${"stmt":"Um conflito de merge significa que o repositório quebrou de forma irreversível.","a":false}$j$, $q$Falso: conflito é normal — resolve-se escolhendo ou combinando as alterações e fazendo um novo commit.$q$, 2);
select public.fj_seed_q('dev', 'dev:git', 'dev:git:2', 4, 'bank', $q$Complete a frase sobre o trabalho em paralelo$q$, $j${"parts":["Uma "," isola o trabalho da linha principal; o "," junta as mudanças de volta."],"a":["branch","merge"],"extra":["clone","commit"]}$j$, $q$Branch separa para trabalhar em paz; merge reúne quando está pronto.$q$, 2);
select public.fj_seed_q('dev', 'dev:git', 'dev:git:2', 5, 'order', $q$Ordene o fluxo típico de colaboração com Git$q$, $j${"items":["Criar uma branch a partir da principal","Fazer commits com a mudança","Abrir um pull request para revisão","Fazer o merge na principal após a aprovação"]}$j$, $q$Isolar, registrar, revisar, integrar: o ciclo de quase todo time de software.$q$, 2);

-- ---------------------------------------------------------------
-- dev:seg:1 · Senhas e dados
-- ---------------------------------------------------------------
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:1', 0, 'mc', $q$A forma correta de guardar senhas de usuários num sistema é:$q$, $j${"opts":["Armazenar apenas o hash da senha, nunca o texto puro","Salvar a senha num arquivo de texto","Guardar a senha na URL do site","Mandar a senha por e-mail para o suporte"],"a":0}$j$, $q$O hash é uma transformação sem volta: o sistema confere a senha sem nunca conhecê-la.$q$, 2);
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:1', 1, 'mc', $q$O HTTPS (o cadeado do navegador) garante que:$q$, $j${"opts":["Os dados trafegam cifrados entre o navegador e o servidor","O site nunca sai do ar","O site não tem anúncios","O servidor é rápido"],"a":0}$j$, $q$HTTPS cifra o caminho: quem interceptar o tráfego não lê senhas nem cartões.$q$, 1);
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:1', 2, 'mc', $q$Qual a diferença entre autenticação e autorização?$q$, $j${"opts":["Autenticação confirma quem você é; autorização define o que você pode fazer","São sinônimos","Autorização vem sempre antes da autenticação","Autenticação é só para administradores"],"a":0}$j$, $q$Primeiro o sistema sabe quem é você (login); depois decide o que liberar (permissões).$q$, 2);
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:1', 3, 'tf', $q$Julgue a afirmação sobre vazamentos$q$, $j${"stmt":"Se o banco de dados vaza mas as senhas estavam com hash forte, os invasores não leem as senhas originais diretamente.","a":true}$j$, $q$Verdadeiro: o hash não tem volta — por isso sites sérios redefinem a senha em vez de "recuperá-la".$q$, 3);
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:1', 4, 'bank', $q$Complete a frase sobre as proteções$q$, $j${"parts":["Senha se guarda como ","; o cadeado do navegador indica ","."],"a":["hash","HTTPS"],"extra":["texto puro","FTP"]}$j$, $q$Hash no banco, HTTPS no caminho: as duas proteções básicas de qualquer login.$q$, 2);
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:1', 5, 'match', $q$Associe o conceito de segurança à sua descrição$q$, $j${"pairs":[["Autenticação","Confirma a identidade"],["Autorização","Define as permissões"],["Hash","Transformação sem volta da senha"],["HTTPS","Tráfego cifrado entre navegador e servidor"]]}$j$, $q$Identidade, permissão, senha protegida e canal cifrado: o kit básico da segurança.$q$, 2);

-- dev:seg:2 · Ataques comuns
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:2', 0, 'mc', $q$No ataque de SQL injection, o invasor:$q$, $j${"opts":["Envia um texto que vira comando no banco de dados; a defesa é usar consultas parametrizadas","Desliga o servidor da tomada","Adivinha a senha do administrador por sorte","Troca o navegador da vítima"],"a":0}$j$, $q$Entrada de usuário nunca pode virar comando: parâmetros separam dado de instrução.$q$, 2);
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:2', 1, 'mc', $q$No ataque XSS (cross-site scripting), o invasor:$q$, $j${"opts":["Injeta um script malicioso que executa na página de outra pessoa; a defesa é escapar o que o usuário envia","Rouba o notebook do desenvolvedor","Corta o cabo de internet","Faz muitas requisições ao mesmo tempo"],"a":0}$j$, $q$Se o site exibe texto de usuário sem escapar, um comentário pode carregar um script espião.$q$, 3);
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:2', 2, 'mc', $q$O princípio do menor privilégio diz que:$q$, $j${"opts":["Cada usuário ou sistema deve ter apenas as permissões mínimas de que precisa","Todo usuário deve ser administrador para facilitar","As permissões devem ser iguais para todos","Privilégios só importam em sistemas grandes"],"a":0}$j$, $q$Quanto menos portas abertas, menor o estrago se uma conta for comprometida.$q$, 2);
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:2', 3, 'tf', $q$Julgue a afirmação sobre a validação$q$, $j${"stmt":"Validar os dados apenas no navegador (frontend) é suficiente para proteger o sistema.","a":false}$j$, $q$Falso: o navegador pode ser burlado; o servidor precisa validar tudo de novo.$q$, 3);
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:2', 4, 'bank', $q$Complete a frase sobre os ataques$q$, $j${"parts":["Entrada do usuário que vira comando no banco é o SQL ","; o script malicioso executado na página da vítima é o ","."],"a":["injection","XSS"],"extra":["backup","deploy"]}$j$, $q$Os dois ataques clássicos da web nascem do mesmo erro: confiar na entrada do usuário.$q$, 2);
select public.fj_seed_q('dev', 'dev:seg', 'dev:seg:2', 5, 'match', $q$Associe a ameaça ou princípio à sua descrição$q$, $j${"pairs":[["SQL injection","Entrada vira comando no banco"],["XSS","Script injetado na página"],["Phishing","Mensagem falsa para roubar dados"],["Menor privilégio","Só a permissão necessária"]]}$j$, $q$Injection e XSS atacam o código; phishing ataca a pessoa; o menor privilégio limita o estrago.$q$, 3);

-- ---------------------------------------------------------------
-- log:mat:1 · Linhas e colunas
-- ---------------------------------------------------------------
select public.fj_seed_q('log', 'log:mat', 'log:mat:1', 0, 'mc', $q$Uma matriz de 3 linhas e 4 colunas guarda quantos elementos?$q$, $j${"opts":["12","7","4","34"],"a":0}$j$, $q$3 × 4 = 12 posições, como uma tabela de 3 linhas com 4 casas cada.$q$, 1);
select public.fj_seed_q('log', 'log:mat', 'log:mat:1', 1, 'mc', $q$Na matriz M, o elemento M[2][3] fica:$q$, $j${"opts":["Na linha 2, coluna 3","Na linha 3, coluna 2","Na diagonal","Na última posição da matriz"],"a":0}$j$, $q$A convenção é linha primeiro, coluna depois: M[linha][coluna].$q$, 2);
select public.fj_seed_q('log', 'log:mat', 'log:mat:1', 2, 'mc', $q$Qual estrutura é a mais natural para guardar o mapa de assentos de um cinema (fileiras × poltronas)?$q$, $j${"opts":["Uma matriz: fileiras como linhas e poltronas como colunas","Uma única variável numérica","Uma função sem parâmetros","Um laço infinito"],"a":0}$j$, $q$Duas dimensões no mundo real pedem duas dimensões na estrutura: a matriz.$q$, 2);
select public.fj_seed_q('log', 'log:mat', 'log:mat:1', 3, 'tf', $q$Julgue a afirmação sobre o formato da matriz$q$, $j${"stmt":"Numa matriz, todas as linhas têm o mesmo número de colunas.","a":true}$j$, $q$Verdadeiro: a matriz é retangular — é isso que permite endereçar por linha e coluna.$q$, 2);
select public.fj_seed_q('log', 'log:mat', 'log:mat:1', 4, 'bank', $q$Complete a frase sobre os índices$q$, $j${"parts":["Numa matriz, o primeiro índice indica a "," e o segundo indica a ","."],"a":["linha","coluna"],"extra":["cor","página"]}$j$, $q$M[linha][coluna]: primeiro desce, depois anda para o lado.$q$, 1);
select public.fj_seed_q('log', 'log:mat', 'log:mat:1', 5, 'match', $q$Associe a estrutura ao seu papel$q$, $j${"pairs":[["Lista","Uma sequência única de valores"],["Matriz","Tabela com linhas e colunas"],["Elemento","Um valor guardado na estrutura"],["Índice","A posição do elemento"]]}$j$, $q$A lista é uma fila; a matriz é uma planilha; o índice é o endereço.$q$, 2);

-- log:mat:2 · Percorrendo tabelas
select public.fj_seed_q('log', 'log:mat', 'log:mat:2', 0, 'mc', $q$Para visitar todos os elementos de uma matriz, usamos:$q$, $j${"opts":["Dois laços aninhados: um para as linhas e outro para as colunas","Uma única condição se/senão","Uma variável sem laço","Um comando de imprimir"],"a":0}$j$, $q$O laço de fora escolhe a linha; o de dentro percorre cada coluna dela.$q$, 2);
select public.fj_seed_q('log', 'log:mat', 'log:mat:2', 1, 'mc', $q$No pseudocódigo "para linha de 1 até 3: para coluna de 1 até 2: soma ← soma + M[linha][coluna]", quantas somas são feitas?$q$, $j${"opts":["6","5","9","12"],"a":0}$j$, $q$3 linhas × 2 colunas = 6 voltas do laço de dentro, uma soma em cada.$q$, 3);
select public.fj_seed_q('log', 'log:mat', 'log:mat:2', 2, 'mc', $q$Para somar apenas os valores da 2ª linha de uma matriz, devemos:$q$, $j${"opts":["Fixar a linha em 2 e variar só a coluna","Variar a linha e fixar a coluna em 2","Percorrer a matriz inteira sempre","Usar recursão obrigatoriamente"],"a":0}$j$, $q$Linha fixa, coluna andando: um laço só resolve.$q$, 2);
select public.fj_seed_q('log', 'log:mat', 'log:mat:2', 3, 'tf', $q$Julgue a afirmação sobre os laços aninhados$q$, $j${"stmt":"Num laço aninhado, o laço de dentro completa todas as suas voltas a cada volta do laço de fora.","a":true}$j$, $q$Verdadeiro: para cada linha, o laço de dentro varre todas as colunas antes de a linha mudar.$q$, 2);
select public.fj_seed_q('log', 'log:mat', 'log:mat:2', 4, 'bank', $q$Complete a frase sobre a varredura$q$, $j${"parts":["Para percorrer a matriz inteira, o laço de fora varre as "," e o de dentro varre as ","."],"a":["linhas","colunas"],"extra":["funções","variáveis"]}$j$, $q$Como ler um livro: linha por linha, palavra por palavra dentro de cada linha.$q$, 2);
select public.fj_seed_q('log', 'log:mat', 'log:mat:2', 5, 'order', $q$Ordene os passos para somar todos os valores de uma tabela$q$, $j${"items":["Começar a soma em zero","Percorrer cada linha","Dentro dela, percorrer cada coluna","Somar o elemento atual ao total","Mostrar a soma no fim"]}$j$, $q$Acumulador zerado, dois laços e a soma dentro: o esqueleto de quase todo relatório.$q$, 2);

-- ---------------------------------------------------------------
-- log:rec:1 · A função que chama a si mesma
-- ---------------------------------------------------------------
select public.fj_seed_q('log', 'log:rec', 'log:rec:1', 0, 'mc', $q$Uma função recursiva é aquela que:$q$, $j${"opts":["Chama a si mesma, cada vez com um problema menor","Nunca retorna valor","Só funciona com números pares","Roda apenas uma vez"],"a":0}$j$, $q$A recursão resolve o grande apoiando-se na própria solução do pequeno.$q$, 1);
select public.fj_seed_q('log', 'log:rec', 'log:rec:1', 1, 'mc', $q$O caso base de uma recursão serve para:$q$, $j${"opts":["Dizer quando parar, evitando chamadas infinitas","Deixar o código mais bonito","Aumentar o número de chamadas","Transformar a função em laço"],"a":0}$j$, $q$Sem a condição de parada, a função se chamaria para sempre.$q$, 2);
select public.fj_seed_q('log', 'log:rec', 'log:rec:1', 2, 'mc', $q$O fatorial de 4 (isto é, 4 × 3 × 2 × 1) vale:$q$, $j${"opts":["24","12","10","16"],"a":0}$j$, $q$4 × 3 = 12; 12 × 2 = 24; 24 × 1 = 24. E fatorial(4) = 4 × fatorial(3): recursão pura.$q$, 2);
select public.fj_seed_q('log', 'log:rec', 'log:rec:1', 3, 'tf', $q$Julgue a afirmação sobre a parada$q$, $j${"stmt":"Uma recursão sem caso base para sozinha depois de algumas chamadas.","a":false}$j$, $q$Falso: sem caso base ela não para por conta própria — estoura o limite de chamadas e dá erro.$q$, 2);
select public.fj_seed_q('log', 'log:rec', 'log:rec:1', 4, 'bank', $q$Complete a frase sobre a receita da recursão$q$, $j${"parts":["A condição que encerra a recursão é o caso ","; cada chamada deve trabalhar com um problema ","."],"a":["base","menor"],"extra":["especial","maior"]}$j$, $q$Encolher o problema a cada chamada e saber onde parar: as duas regras de ouro.$q$, 2);
select public.fj_seed_q('log', 'log:rec', 'log:rec:1', 5, 'match', $q$Associe o conceito de recursão à sua descrição$q$, $j${"pairs":[["Caso base","Onde a recursão para"],["Chamada recursiva","A função chamando a si mesma"],["Fatorial","Exemplo clássico de recursão"],["Recursão infinita","O que acontece sem caso base"]]}$j$, $q$Todo exemplo recursivo tem esses quatro personagens.$q$, 2);

-- log:rec:2 · Dividir para conquistar
select public.fj_seed_q('log', 'log:rec', 'log:rec:2', 0, 'mc', $q$A estratégia "dividir para conquistar" consiste em:$q$, $j${"opts":["Quebrar o problema em partes menores, resolver cada uma e combinar os resultados","Resolver tudo de uma vez só","Ignorar os casos difíceis","Copiar a solução de outro problema"],"a":0}$j$, $q$Problemas grandes assustam; metades e quartos, não.$q$, 1);
select public.fj_seed_q('log', 'log:rec', 'log:rec:2', 1, 'mc', $q$Procurar uma palavra no dicionário abrindo no meio e descartando a metade errada é o mesmo princípio da:$q$, $j${"opts":["Busca binária","Busca linear, item por item","Ordenação por sorteio","Recursão infinita"],"a":0}$j$, $q$Cada aberta no meio elimina metade do dicionário: poucas tentativas acham qualquer palavra.$q$, 2);
select public.fj_seed_q('log', 'log:rec', 'log:rec:2', 2, 'mc', $q$A busca binária só funciona se a lista estiver:$q$, $j${"opts":["Ordenada","Vazia","Duplicada","Guardada numa matriz"],"a":0}$j$, $q$Descartar uma metade só é seguro quando a ordem garante de que lado o alvo está.$q$, 2);
select public.fj_seed_q('log', 'log:rec', 'log:rec:2', 3, 'tf', $q$Julgue a afirmação sobre a eficiência$q$, $j${"stmt":"Na busca binária, cada passo descarta cerca de metade dos candidatos restantes.","a":true}$j$, $q$Verdadeiro: por isso ela acha 1 nome entre 1 milhão em cerca de 20 passos.$q$, 3);
select public.fj_seed_q('log', 'log:rec', 'log:rec:2', 4, 'bank', $q$Complete a frase sobre a busca esperta$q$, $j${"parts":["A busca que abre no meio e descarta metade é a busca ","; ela exige lista ","."],"a":["binária","ordenada"],"extra":["linear","vazia"]}$j$, $q$Binária porque divide em duas; ordenada porque senão não dá para descartar.$q$, 2);
select public.fj_seed_q('log', 'log:rec', 'log:rec:2', 5, 'order', $q$Ordene os passos da busca binária numa lista ordenada$q$, $j${"items":["Olhar o elemento do meio da lista","Se for o procurado, terminar","Se o procurado for menor, seguir na metade da esquerda; se maior, na da direita","Repetir até achar ou os candidatos acabarem"]}$j$, $q$Meio, compara, descarta metade, repete: o algoritmo do dicionário.$q$, 3);

-- ---------------------------------------------------------------
-- dat:limp:1 · Dados sujos
-- ---------------------------------------------------------------
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:1', 0, 'mc', $q$Um cadastro tem "SP", "São Paulo" e "sao paulo" na mesma coluna. Esse é um problema de:$q$, $j${"opts":["Padronização: o mesmo valor escrito de formas diferentes","Valor ausente","Outlier","Falta de gráfico"],"a":0}$j$, $q$Para o computador são três valores distintos; qualquer contagem por estado sai errada.$q$, 1);
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:1', 1, 'mc', $q$Uma duplicata na base de clientes é perigosa porque:$q$, $j${"opts":["O mesmo cliente é contado duas vezes, inflando os números","Deixa o arquivo mais bonito","Melhora a média automaticamente","Impede o uso de gráficos"],"a":0}$j$, $q$Registro repetido vira gente repetida nas contagens — e decisões erradas.$q$, 2);
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:1', 2, 'mc', $q$A expressão "garbage in, garbage out" significa que:$q$, $j${"opts":["Dados ruins na entrada produzem análises ruins na saída","Todo dado deve ser descartado","Lixo eletrônico polui o data center","Quanto mais dados, melhor, mesmo sujos"],"a":0}$j$, $q$Nenhuma análise sofisticada salva uma base suja: a qualidade começa na entrada.$q$, 2);
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:1', 3, 'tf', $q$Julgue a afirmação sobre o tempo de trabalho$q$, $j${"stmt":"A limpeza e a preparação costumam tomar grande parte do tempo de um projeto de dados.","a":true}$j$, $q$Verdadeiro: analistas passam boa parte do projeto preparando os dados antes de qualquer gráfico.$q$, 2);
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:1', 4, 'bank', $q$Complete a frase sobre os defeitos da base$q$, $j${"parts":["Registro repetido é uma ","; campo sem valor é um dado ","."],"a":["duplicata","ausente"],"extra":["média","amostra"]}$j$, $q$Duplicata infla; ausente esconde — os dois distorcem a análise.$q$, 1);
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:1', 5, 'match', $q$Associe o problema de dados ao seu exemplo$q$, $j${"pairs":[["Valor ausente","Campo vazio no registro"],["Duplicata","O mesmo registro duas vezes"],["Fora do padrão","SP e São Paulo na mesma coluna"],["Tipo errado","Número guardado como texto"]]}$j$, $q$Os quatro defeitos mais comuns de qualquer base recém-coletada.$q$, 2);

-- dat:limp:2 · Tratando os problemas
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:2', 0, 'mc', $q$A coluna de renda tem valores ausentes. Uma atitude razoável é:$q$, $j${"opts":["Remover as linhas ou preencher com um valor de referência (como a mediana), documentando a escolha","Inventar valores altos para melhorar a média","Trocar a coluna inteira por zeros sem avisar ninguém","Ignorar o problema e publicar o relatório"],"a":0}$j$, $q$Remover ou imputar são ambos válidos — o essencial é ter critério e registrar a decisão.$q$, 2);
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:2', 1, 'mc', $q$Um cadastro registra um cliente com 190 anos de idade. O mais provável é que seja:$q$, $j${"opts":["Um erro de digitação, que deve ser investigado e corrigido","Um cliente muito fiel","Um dado correto que não precisa de atenção","Um bom valor para a média"],"a":0}$j$, $q$Valores impossíveis denunciam erro na entrada — 19 ou 90 viraram 190.$q$, 1);
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:2', 2, 'mc', $q$Antes de excluir um outlier da análise, deve-se:$q$, $j${"opts":["Investigar se é um erro de registro ou um caso real importante","Excluir sempre, sem olhar","Dobrar o valor dele","Escondê-lo do gráfico e manter nos cálculos"],"a":0}$j$, $q$Um outlier pode ser erro — ou a descoberta mais valiosa da base. Primeiro entenda, depois decida.$q$, 2);
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:2', 3, 'tf', $q$Julgue a afirmação sobre os outliers$q$, $j${"stmt":"Todo outlier deve ser apagado automaticamente da base.","a":false}$j$, $q$Falso: a fraude no cartão e o cliente gigante também são outliers — apagar sem olhar joga fora informação.$q$, 2);
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:2', 4, 'bank', $q$Complete a frase sobre os tratamentos$q$, $j${"parts":["Preencher um valor ausente com a mediana é uma forma de ","; o valor muito distante dos demais é o ","."],"a":["imputação","outlier"],"extra":["amostragem","gráfico"]}$j$, $q$Imputar é preencher com critério; o outlier é o ponto fora da curva que merece investigação.$q$, 3);
select public.fj_seed_q('dat', 'dat:limp', 'dat:limp:2', 5, 'order', $q$Ordene a preparação de uma base para análise$q$, $j${"items":["Conferir os tipos e padronizar os formatos","Tratar os valores ausentes com critério documentado","Remover as duplicatas","Investigar os outliers","Só então começar a análise"]}$j$, $q$Padronizar, completar, deduplicar, investigar — e só depois analisar.$q$, 3);

-- ---------------------------------------------------------------
-- dat:ind:1 · KPIs do dia a dia
-- ---------------------------------------------------------------
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:1', 0, 'mc', $q$Uma loja online recebeu 200 visitantes e fez 10 vendas. A taxa de conversão foi de:$q$, $j${"opts":["5%","10%","20%","2%"],"a":0}$j$, $q$10 ÷ 200 = 0,05 = 5% dos visitantes viraram compradores.$q$, 2);
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:1', 1, 'mc', $q$Uma loja faturou R$ 5.000 em 25 vendas. O ticket médio foi de:$q$, $j${"opts":["R$ 200","R$ 125","R$ 250","R$ 500"],"a":0}$j$, $q$5.000 ÷ 25 = R$ 200 por venda, em média.$q$, 2);
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:1', 2, 'mc', $q$Um KPI (indicador-chave) se diferencia de um número qualquer porque:$q$, $j${"opts":["Está ligado diretamente a um objetivo do negócio e orienta decisões","É sempre uma porcentagem","É calculado por inteligência artificial","Muda todos os dias"],"a":0}$j$, $q$KPI é o indicador escolhido a dedo: mede o que importa para a meta, não tudo o que dá para medir.$q$, 2);
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:1', 3, 'tf', $q$Julgue a afirmação sobre a quantidade de indicadores$q$, $j${"stmt":"Quanto mais indicadores uma empresa acompanhar, melhor, mesmo sem ligação com os objetivos.","a":false}$j$, $q$Falso: excesso de números sem foco vira ruído — poucos KPIs bem escolhidos orientam mais.$q$, 2);
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:1', 4, 'bank', $q$Complete a frase sobre as duas contas$q$, $j${"parts":["Compradores divididos por visitantes dão a taxa de ","; receita dividida pelo número de vendas dá o ticket ","."],"a":["conversão","médio"],"extra":["churn","anual"]}$j$, $q$Conversão mede o funil; ticket médio mede o tamanho de cada venda.$q$, 2);
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:1', 5, 'match', $q$Associe o indicador ao que ele mede$q$, $j${"pairs":[["Taxa de conversão","Visitantes que viraram compradores"],["Ticket médio","Valor médio por venda"],["Churn","Clientes que cancelaram"],["Retenção","Clientes que continuaram"]]}$j$, $q$Quatro medidores clássicos: entrada, valor, saída e permanência dos clientes.$q$, 2);

-- dat:ind:2 · Lendo indicadores com cuidado
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:2', 0, 'mc', $q$As vendas foram de 200 unidades para 250. O crescimento foi de:$q$, $j${"opts":["25%","50%","20%","125%"],"a":0}$j$, $q$Aumento de 50 sobre a base 200: 50 ÷ 200 = 25%.$q$, 3);
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:2', 1, 'mc', $q$Uma sorveteria quer avaliar se julho foi um bom mês. A comparação mais justa é com:$q$, $j${"opts":["Julho do ano anterior, por causa da sazonalidade","Dezembro do mesmo ano","O melhor dia da história da loja","Uma loja de roupas"],"a":0}$j$, $q$Sorvete vende com o calor: comparar julho com dezembro mistura estações e engana.$q$, 2);
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:2', 2, 'mc', $q$A média móvel (por exemplo, dos últimos 7 dias) serve para:$q$, $j${"opts":["Suavizar as oscilações diárias e mostrar a tendência","Substituir todos os outros indicadores","Aumentar os valores da série","Esconder os dados ruins"],"a":0}$j$, $q$Um dia bom ou ruim balança pouco a média da semana: sobra a tendência.$q$, 2);
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:2', 3, 'tf', $q$Julgue a afirmação sobre o contexto$q$, $j${"stmt":"Um indicador isolado, sem meta nem comparação, já conta a história toda.","a":false}$j$, $q$Falso: 100 vendas é muito ou pouco? Só a meta e o histórico respondem.$q$, 2);
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:2', 4, 'bank', $q$Complete a frase sobre as leituras$q$, $j${"parts":["Vender mais no verão que no inverno é efeito da ","; para suavizar as oscilações e ver a tendência usamos a média ","."],"a":["sazonalidade","móvel"],"extra":["conversão","ponderada"]}$j$, $q$Sazonalidade é o ritmo das estações; a média móvel filtra o sobe-e-desce do dia a dia.$q$, 3);
select public.fj_seed_q('dat', 'dat:ind', 'dat:ind:2', 5, 'match', $q$Associe o conceito à sua função na leitura dos números$q$, $j${"pairs":[["Meta","O valor que se quer alcançar"],["Sazonalidade","Padrão que se repete nas estações"],["Média móvel","Suaviza as oscilações"],["Variação percentual","Quanto subiu ou caiu em %"]]}$j$, $q$Indicador bom é indicador com contexto: meta, época do ano e tendência.$q$, 2);

-- Função auxiliar não é mais necessária
drop function if exists public.fj_seed_q(text, text, text, int, text, text, jsonb, text, int);

-- ---------------------------------------------------------------
-- Embaralha as alternativas de múltipla escolha APENAS das unidades
-- novas deste arquivo (escritas acima com a resposta na posição A;
-- mesmo molde da 0019/0039 — as unidades antigas já foram embaralhadas)
-- ---------------------------------------------------------------
alter table public.questoes disable trigger auditoria_questoes;
do $$
declare q record; n int; perm int[]; novo jsonb; na int;
begin
  for q in select id, dados from public.questoes where tipo = 'mc' and unidade_id in (
    md5('uni:gmt:circ')::uuid, md5('uni:gmt:trans')::uuid,
    md5('uni:rac:prob')::uuid, md5('uni:rac:fal')::uuid,
    md5('uni:dev:git')::uuid, md5('uni:dev:seg')::uuid,
    md5('uni:log:mat')::uuid, md5('uni:log:rec')::uuid,
    md5('uni:dat:limp')::uuid, md5('uni:dat:ind')::uuid) loop
    n := coalesce(jsonb_array_length(q.dados->'opts'), 0);
    if n < 2 then continue; end if;
    select array_agg(i order by random()) into perm from generate_series(0, n - 1) i;
    select jsonb_agg(q.dados->'opts'->perm[i] order by i) into novo from generate_series(1, n) i;
    na := coalesce(array_position(perm, coalesce((q.dados->>'a')::int, 0)), 1) - 1;
    update public.questoes set dados = dados || jsonb_build_object('opts', novo, 'a', na) where id = q.id;
  end loop;
end $$;
alter table public.questoes enable trigger auditoria_questoes;

insert into public.schema_versao (versao) values (50) on conflict do nothing;
