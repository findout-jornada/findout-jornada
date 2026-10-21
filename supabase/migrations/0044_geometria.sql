-- =====================================================================
-- Findout Jornada · Migration 0044 · Matéria Geometria
-- (4 seções, 8 unidades, 16 lições, 96 questões)
-- Rodar no SQL Editor do Supabase depois da 0043. Idempotente: pode rodar de novo.
-- Depois de rodar, abra o painel: ele publica a nova versão sozinho.
-- Matéria comum (grupo "Jornadas por matéria" do app), fora do Mapa do ENEM
-- como Ética/Arte/Ciências: a constante FORA_DO_MAPA em app/index.html ganha 'gmt'.
-- Trilha: fundamentos (ponto/reta/ângulos, polígonos), medidas (perímetro e
-- áreas, círculo), triângulo (Pitágoras, semelhança e Tales) e espacial +
-- analítica (sólidos e plano cartesiano).
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
('gmt', 'Geometria', 'GM', '#B8860B', true, 19)
on conflict (id) do nothing;

insert into public.secoes (id, materia_id, titulo, ordem) values
(md5('sec:gmt:fund')::uuid, 'gmt', 'Fundamentos da geometria', 0),
(md5('sec:gmt:medidas')::uuid, 'gmt', 'Medidas e áreas', 1),
(md5('sec:gmt:tri')::uuid, 'gmt', 'Geometria do triângulo', 2),
(md5('sec:gmt:espacial')::uuid, 'gmt', 'Espacial e analítica', 3)
on conflict (id) do nothing;

insert into public.unidades (id, secao_id, titulo, ordem) values
(md5('uni:gmt:base')::uuid, md5('sec:gmt:fund')::uuid, 'Ponto, reta e ângulos', 0),
(md5('uni:gmt:poli')::uuid, md5('sec:gmt:fund')::uuid, 'Polígonos', 1),
(md5('uni:gmt:per')::uuid, md5('sec:gmt:medidas')::uuid, 'Perímetro e área', 0),
(md5('uni:gmt:area')::uuid, md5('sec:gmt:medidas')::uuid, 'Áreas de outras figuras', 1),
(md5('uni:gmt:pit')::uuid, md5('sec:gmt:tri')::uuid, 'Teorema de Pitágoras', 0),
(md5('uni:gmt:sem')::uuid, md5('sec:gmt:tri')::uuid, 'Semelhança e proporção', 1),
(md5('uni:gmt:esp')::uuid, md5('sec:gmt:espacial')::uuid, 'Sólidos geométricos', 0),
(md5('uni:gmt:cart')::uuid, md5('sec:gmt:espacial')::uuid, 'Plano cartesiano', 1)
on conflict (id) do nothing;

insert into public.licoes (id, unidade_id, titulo, descricao, ordem) values
(md5('lic:gmt:base:1')::uuid, md5('uni:gmt:base')::uuid, 'Ponto, reta e plano', 'As noções primitivas e os segmentos.', 0),
(md5('lic:gmt:base:2')::uuid, md5('uni:gmt:base')::uuid, 'Ângulos', 'Agudo, reto, obtuso — e as somas de 90° e 180°.', 1),
(md5('lic:gmt:poli:1')::uuid, md5('uni:gmt:poli')::uuid, 'Triângulos', 'Classificação, soma dos ângulos e a desigualdade triangular.', 0),
(md5('lic:gmt:poli:2')::uuid, md5('uni:gmt:poli')::uuid, 'Quadriláteros e polígonos', 'Quadrado, retângulo, losango, trapézio e os nomes dos polígonos.', 1),
(md5('lic:gmt:per:1')::uuid, md5('uni:gmt:per')::uuid, 'Perímetro', 'O contorno das figuras e onde ele aparece na vida.', 0),
(md5('lic:gmt:per:2')::uuid, md5('uni:gmt:per')::uuid, 'Área de quadrados e retângulos', 'Base × altura e as unidades quadradas.', 1),
(md5('lic:gmt:area:1')::uuid, md5('uni:gmt:area')::uuid, 'Área de triângulos e paralelogramos', 'Metade de base × altura — e por quê.', 0),
(md5('lic:gmt:area:2')::uuid, md5('uni:gmt:area')::uuid, 'Círculo: comprimento e área', 'O número π, 2πr e πr².', 1),
(md5('lic:gmt:pit:1')::uuid, md5('uni:gmt:pit')::uuid, 'O teorema de Pitágoras', 'Catetos, hipotenusa e a relação mais famosa da matemática.', 0),
(md5('lic:gmt:pit:2')::uuid, md5('uni:gmt:pit')::uuid, 'Aplicações de Pitágoras', 'Escadas, diagonais e distâncias em linha reta.', 1),
(md5('lic:gmt:sem:1')::uuid, md5('uni:gmt:sem')::uuid, 'Figuras semelhantes', 'Mesma forma, lados proporcionais — e as escalas.', 0),
(md5('lic:gmt:sem:2')::uuid, md5('uni:gmt:sem')::uuid, 'O teorema de Tales', 'Paralelas, proporções e a altura pela sombra.', 1),
(md5('lic:gmt:esp:1')::uuid, md5('uni:gmt:esp')::uuid, 'Prismas e cilindros', 'Volume = área da base × altura.', 0),
(md5('lic:gmt:esp:2')::uuid, md5('uni:gmt:esp')::uuid, 'Pirâmides, cones e esferas', 'Os sólidos de ponta e os corpos redondos.', 1),
(md5('lic:gmt:cart:1')::uuid, md5('uni:gmt:cart')::uuid, 'Coordenadas no plano', 'Pares ordenados, eixos e quadrantes.', 0),
(md5('lic:gmt:cart:2')::uuid, md5('uni:gmt:cart')::uuid, 'Distâncias no plano', 'Distâncias na horizontal, na vertical e com Pitágoras.', 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- gmt:base:1 · Ponto, reta e plano
-- ---------------------------------------------------------------
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:1', 0, 'mc', $q$Na geometria, ponto, reta e plano são:$q$, $j${"opts":["Noções primitivas: aceitas sem definição e base de todas as outras","Figuras com área","Sólidos geométricos","Instrumentos de desenho"],"a":0}$j$, $q$Tudo na geometria se constrói a partir dessas três ideias básicas.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:1', 1, 'mc', $q$Um segmento de reta é:$q$, $j${"opts":["O trecho de reta limitado por dois pontos, as extremidades","Uma reta infinita nos dois sentidos","Uma curva fechada","Um ângulo de 90°"],"a":0}$j$, $q$A reta não tem fim; o segmento é o pedaço dela entre dois pontos.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:1', 2, 'mc', $q$A semirreta se diferencia da reta porque:$q$, $j${"opts":["Tem origem num ponto e se estende infinitamente num só sentido","É sempre menor que 1 cm","Tem duas extremidades","É sempre vertical"],"a":0}$j$, $q$Como um raio de luz da lanterna: nasce num ponto e segue sem fim numa direção.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:1', 3, 'tf', $q$Julgue a afirmação sobre pontos e retas$q$, $j${"stmt":"Por dois pontos distintos passa uma única reta.","a":true}$j$, $q$Verdadeiro: é um dos postulados da geometria — dois pontos determinam a reta.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:1', 4, 'bank', $q$Complete a frase sobre as figuras básicas$q$, $j${"parts":["O "," tem dois pontos como extremidades; a "," tem origem e segue infinita num só sentido."],"a":["segmento","semirreta"],"extra":["plano","curva"]}$j$, $q$Reta: infinita nos dois lados. Semirreta: num lado. Segmento: limitado nos dois.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:1', 5, 'match', $q$Associe o elemento à sua descrição$q$, $j${"pairs":[["Ponto","Posição, sem dimensão"],["Reta","Infinita nos dois sentidos"],["Segmento","Trecho entre dois pontos"],["Plano","Superfície infinita, como uma folha sem fim"]]}$j$, $q$Do ponto (dimensão zero) ao plano (duas dimensões): os tijolos da geometria.$q$, 2);

-- gmt:base:2 · Ângulos
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:2', 0, 'mc', $q$Um ângulo reto mede:$q$, $j${"opts":["90°","180°","45°","360°"],"a":0}$j$, $q$É o ângulo do canto da folha de papel e do encontro da parede com o chão.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:2', 1, 'mc', $q$Um ângulo de 35° é classificado como:$q$, $j${"opts":["Agudo, porque é menor que 90°","Obtuso","Reto","Raso"],"a":0}$j$, $q$Menor que 90°: agudo. Entre 90° e 180°: obtuso. Exatamente 180°: raso.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:2', 2, 'mc', $q$Dois ângulos complementares somam 90°. O complemento de 25° é:$q$, $j${"opts":["65°","75°","155°","25°"],"a":0}$j$, $q$90° − 25° = 65°.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:2', 3, 'tf', $q$Julgue a afirmação sobre os suplementares$q$, $j${"stmt":"Dois ângulos suplementares somam 90°.","a":false}$j$, $q$Falso: suplementares somam 180°; os que somam 90° são os complementares.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:2', 4, 'bank', $q$Complete a frase sobre as somas$q$, $j${"parts":["Ângulos que somam 90° são ","; os que somam 180° são ","."],"a":["complementares","suplementares"],"extra":["opostos","congruentes"]}$j$, $q$Dica: C vem antes de S no alfabeto, assim como 90 vem antes de 180.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:base', 'gmt:base:2', 5, 'match', $q$Associe o ângulo à sua classificação$q$, $j${"pairs":[["Agudo","Menor que 90°"],["Reto","Exatamente 90°"],["Obtuso","Entre 90° e 180°"],["Raso","Exatamente 180°"]]}$j$, $q$A régua de classificação dos ângulos vai do agudo ao raso.$q$, 1);

-- ---------------------------------------------------------------
-- gmt:poli:1 · Triângulos
-- ---------------------------------------------------------------
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:1', 0, 'mc', $q$A soma dos ângulos internos de qualquer triângulo é:$q$, $j${"opts":["180°","90°","360°","Depende do tamanho do triângulo"],"a":0}$j$, $q$Grande ou pequeno, todo triângulo fecha 180° por dentro.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:1', 1, 'mc', $q$Num triângulo, dois ângulos medem 60° e 80°. O terceiro mede:$q$, $j${"opts":["40°","60°","100°","20°"],"a":0}$j$, $q$180° − 60° − 80° = 40°.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:1', 2, 'mc', $q$O triângulo equilátero tem:$q$, $j${"opts":["Os três lados iguais e os três ângulos de 60°","Apenas dois lados iguais","Obrigatoriamente um ângulo reto","Quatro lados"],"a":0}$j$, $q$Equilátero = lados iguais; e 180° ÷ 3 = 60° em cada ângulo.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:1', 3, 'tf', $q$Julgue a afirmação sobre os lados$q$, $j${"stmt":"Existe um triângulo com lados de 2 cm, 3 cm e 10 cm.","a":false}$j$, $q$Falso: 2 + 3 = 5 < 10 — os dois lados menores nem se encontram. É a desigualdade triangular.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:1', 4, 'bank', $q$Complete a frase sobre a classificação$q$, $j${"parts":["O triângulo com três lados iguais é o ","; com exatamente dois lados iguais é o ","."],"a":["equilátero","isósceles"],"extra":["escaleno","obtuso"]}$j$, $q$Equilátero, isósceles e escaleno: a classificação pelos lados.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:1', 5, 'match', $q$Associe o triângulo à sua característica$q$, $j${"pairs":[["Equilátero","Três lados iguais"],["Isósceles","Dois lados iguais"],["Escaleno","Três lados diferentes"],["Retângulo","Tem um ângulo de 90°"]]}$j$, $q$Pelos lados: equilátero, isósceles, escaleno. Pelos ângulos: retângulo, acutângulo, obtusângulo.$q$, 2);

-- gmt:poli:2 · Quadriláteros e polígonos
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:2', 0, 'mc', $q$A soma dos ângulos internos de qualquer quadrilátero é:$q$, $j${"opts":["360°","180°","90°","720°"],"a":0}$j$, $q$Uma diagonal divide o quadrilátero em dois triângulos: 2 × 180° = 360°.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:2', 1, 'mc', $q$O quadrado é um retângulo especial porque:$q$, $j${"opts":["Tem os quatro ângulos retos e, além disso, os quatro lados iguais","Não tem ângulos retos","Tem apenas dois lados","É sempre maior que o retângulo"],"a":0}$j$, $q$Todo quadrado é retângulo (ângulos retos), mas nem todo retângulo é quadrado.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:2', 2, 'mc', $q$O trapézio se caracteriza por ter:$q$, $j${"opts":["Exatamente um par de lados paralelos","Os quatro lados sempre iguais","Nenhum lado paralelo","Cinco lados"],"a":0}$j$, $q$Dois lados paralelos (as bases) e dois não paralelos — a cara de uma rampa.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:2', 3, 'tf', $q$Julgue a afirmação sobre o losango$q$, $j${"stmt":"Todo losango tem os quatro lados iguais.","a":true}$j$, $q$Verdadeiro: essa é a definição do losango — os ângulos é que podem variar.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:2', 4, 'bank', $q$Complete a frase sobre os nomes$q$, $j${"parts":["Um polígono de cinco lados é o ","; o de seis lados é o ","."],"a":["pentágono","hexágono"],"extra":["octógono","decágono"]}$j$, $q$Penta = 5, hexa = 6, octo = 8, deca = 10: os prefixos gregos contam os lados.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:poli', 'gmt:poli:2', 5, 'match', $q$Associe o quadrilátero à sua marca registrada$q$, $j${"pairs":[["Quadrado","4 lados iguais e 4 ângulos retos"],["Retângulo","Ângulos retos, lados iguais dois a dois"],["Losango","4 lados iguais, ângulos livres"],["Trapézio","Um par de lados paralelos"]]}$j$, $q$Quatro parentes próximos — o que muda é a exigência sobre lados e ângulos.$q$, 2);

-- ---------------------------------------------------------------
-- gmt:per:1 · Perímetro
-- ---------------------------------------------------------------
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:1', 0, 'mc', $q$O perímetro de uma figura é:$q$, $j${"opts":["A soma das medidas de todos os seus lados","A medida da superfície interna","O número de vértices","A metade da área"],"a":0}$j$, $q$Perímetro é o contorno: a distância de dar uma volta completa na figura.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:1', 1, 'mc', $q$O perímetro de um retângulo de 8 m por 5 m é:$q$, $j${"opts":["26 m","40 m","13 m","80 m"],"a":0}$j$, $q$2 × (8 + 5) = 26 m. Os 40 m² seriam a área.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:1', 2, 'mc', $q$Um quadrado tem perímetro de 36 cm. Cada lado mede:$q$, $j${"opts":["9 cm","6 cm","12 cm","18 cm"],"a":0}$j$, $q$36 ÷ 4 = 9 cm: o quadrado reparte o perímetro igualmente entre os 4 lados.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:1', 3, 'tf', $q$Julgue a afirmação sobre a cerca$q$, $j${"stmt":"Para saber quanta cerca comprar para um terreno, a medida que interessa é o perímetro, não a área.","a":true}$j$, $q$Verdadeiro: a cerca acompanha o contorno — perímetro. A grama do terreno é que pede a área.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:1', 4, 'bank', $q$Complete a frase sobre as unidades$q$, $j${"parts":["O perímetro se mede em unidades de "," como o metro; a área se mede em unidades "," como o metro quadrado."],"a":["comprimento","quadradas"],"extra":["volume","cúbicas"]}$j$, $q$Metro para o contorno, metro quadrado para a superfície, metro cúbico para o espaço.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:1', 5, 'order', $q$Ordene os passos para achar o perímetro de um terreno irregular$q$, $j${"items":["Identificar todos os lados do terreno","Medir cada lado","Somar todas as medidas","Conferir a unidade do resultado"]}$j$, $q$Sem fórmula decorada: perímetro é sempre a soma do contorno.$q$, 1);

-- gmt:per:2 · Área de quadrados e retângulos
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:2', 0, 'mc', $q$A área de um retângulo é calculada por:$q$, $j${"opts":["Base × altura","Base + altura","2 × (base + altura)","Base ÷ altura"],"a":0}$j$, $q$Base vezes altura conta quantos quadradinhos de 1 × 1 cabem na figura.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:2', 1, 'mc', $q$A área de um retângulo de 7 m por 4 m é:$q$, $j${"opts":["28 m²","22 m²","11 m²","56 m²"],"a":0}$j$, $q$7 × 4 = 28 m². Os 22 m seriam o perímetro.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:2', 2, 'mc', $q$Um quadrado de lado 6 cm tem área de:$q$, $j${"opts":["36 cm²","24 cm²","12 cm²","18 cm²"],"a":0}$j$, $q$6 × 6 = 36 cm² — no quadrado, lado ao quadrado.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:2', 3, 'tf', $q$Julgue a afirmação sobre perímetro e área$q$, $j${"stmt":"Dois retângulos com o mesmo perímetro têm sempre a mesma área.","a":false}$j$, $q$Falso: 2 × 6 e 4 × 4 têm perímetro 16, mas áreas 12 e 16 — mesma cerca, gramados diferentes.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:2', 4, 'bank', $q$Complete a frase sobre o piso da sala$q$, $j${"parts":["Para saber quanto piso comprar calculamos a "," da sala; o resultado sai em metros ","."],"a":["área","quadrados"],"extra":["altura","cúbicos"]}$j$, $q$Piso cobre superfície: área, em m².$q$, 1);
select public.fj_seed_q('gmt', 'gmt:per', 'gmt:per:2', 5, 'match', $q$Associe a figura à sua área$q$, $j${"pairs":[["Quadrado de lado 5","Área 25"],["Retângulo 3 × 4","Área 12"],["Quadrado de lado 10","Área 100"],["Retângulo 2 × 9","Área 18"]]}$j$, $q$Base × altura resolve todos: 25, 12, 100 e 18.$q$, 2);

-- ---------------------------------------------------------------
-- gmt:area:1 · Área de triângulos e paralelogramos
-- ---------------------------------------------------------------
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:1', 0, 'mc', $q$A área de um triângulo é:$q$, $j${"opts":["(base × altura) ÷ 2","base × altura","base + altura","(base + altura) ÷ 2"],"a":0}$j$, $q$O triângulo é metade de um paralelogramo de mesma base e altura.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:1', 1, 'mc', $q$Um triângulo com base 10 cm e altura 6 cm tem área de:$q$, $j${"opts":["30 cm²","60 cm²","16 cm²","15 cm²"],"a":0}$j$, $q$(10 × 6) ÷ 2 = 30 cm².$q$, 2);
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:1', 2, 'mc', $q$A área do paralelogramo é o dobro da área do triângulo de mesma base e altura porque:$q$, $j${"opts":["A diagonal divide o paralelogramo em dois triângulos iguais","O paralelogramo tem mais lados","É uma coincidência numérica","O triângulo não tem altura"],"a":0}$j$, $q$Corte o paralelogramo pela diagonal: nascem dois triângulos idênticos — daí o ÷ 2.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:1', 3, 'tf', $q$Julgue a afirmação sobre a altura$q$, $j${"stmt":"Na fórmula da área do triângulo, a altura é a distância da base ao vértice oposto, medida perpendicularmente.","a":true}$j$, $q$Verdadeiro: altura forma 90° com a base — não é o lado inclinado.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:1', 4, 'bank', $q$Complete a frase sobre as fórmulas$q$, $j${"parts":["A área do triângulo é base vezes altura dividido por ","; a do paralelogramo é base vezes ","."],"a":["dois","altura"],"extra":["três","perímetro"]}$j$, $q$Paralelogramo: b × h. Triângulo: metade disso.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:1', 5, 'match', $q$Associe a figura à sua área$q$, $j${"pairs":[["Triângulo base 8, altura 5","Área 20"],["Paralelogramo base 8, altura 5","Área 40"],["Triângulo base 6, altura 4","Área 12"],["Paralelogramo base 6, altura 4","Área 24"]]}$j$, $q$Mesma base e altura: o triângulo sempre vale metade do paralelogramo.$q$, 3);

-- gmt:area:2 · Círculo: comprimento e área
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:2', 0, 'mc', $q$O número π (pi) vale, aproximadamente:$q$, $j${"opts":["3,14","2,17","1,61","4,13"],"a":0}$j$, $q$π é a razão entre o comprimento da circunferência e o diâmetro — sempre ≈ 3,14.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:2', 1, 'mc', $q$O comprimento (contorno) de uma circunferência de raio r é:$q$, $j${"opts":["2 × π × r","π × r²","r ÷ π","4 × r"],"a":0}$j$, $q$C = 2πr — o πr² é a área, não o contorno.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:2', 2, 'mc', $q$Usando π ≈ 3, a área de um círculo de raio 10 cm é aproximadamente:$q$, $j${"opts":["300 cm²","60 cm²","30 cm²","100 cm²"],"a":0}$j$, $q$A = πr² ≈ 3 × 10² = 3 × 100 = 300 cm².$q$, 3);
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:2', 3, 'tf', $q$Julgue a afirmação sobre o diâmetro$q$, $j${"stmt":"O diâmetro de uma circunferência é o dobro do raio.","a":true}$j$, $q$Verdadeiro: o diâmetro atravessa o círculo passando pelo centro — dois raios emendados.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:2', 4, 'bank', $q$Complete a frase sobre as partes do círculo$q$, $j${"parts":["A distância do centro até a borda é o ","; a corda que passa pelo centro é o ","."],"a":["raio","diâmetro"],"extra":["arco","setor"]}$j$, $q$Raio: metade do caminho. Diâmetro: a travessia completa pelo centro.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:area', 'gmt:area:2', 5, 'match', $q$Associe o elemento do círculo à sua descrição$q$, $j${"pairs":[["Raio","Do centro à borda"],["Diâmetro","Dobro do raio"],["2πr","Comprimento da circunferência"],["πr²","Área do círculo"]]}$j$, $q$Duas fórmulas, um truque: o contorno usa r; a área usa r ao quadrado.$q$, 2);

-- ---------------------------------------------------------------
-- gmt:pit:1 · O teorema de Pitágoras
-- ---------------------------------------------------------------
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:1', 0, 'mc', $q$O teorema de Pitágoras vale para:$q$, $j${"opts":["Triângulos retângulos: o quadrado da hipotenusa é a soma dos quadrados dos catetos","Qualquer triângulo","Apenas quadrados","Círculos"],"a":0}$j$, $q$Só funciona com um ângulo de 90° no triângulo — é ele que cria a relação.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:1', 1, 'mc', $q$Num triângulo retângulo com catetos 3 e 4, a hipotenusa mede:$q$, $j${"opts":["5","7","12","6"],"a":0}$j$, $q$3² + 4² = 9 + 16 = 25 = 5². O famoso 3-4-5.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:1', 2, 'mc', $q$A hipotenusa é:$q$, $j${"opts":["O maior lado do triângulo retângulo, oposto ao ângulo reto","O menor lado do triângulo","Qualquer lado escolhido","A altura do triângulo"],"a":0}$j$, $q$De frente para o ângulo de 90° está sempre o lado mais comprido: a hipotenusa.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:1', 3, 'tf', $q$Julgue a afirmação sobre o triângulo 6, 8 e 10$q$, $j${"stmt":"Um triângulo de lados 6, 8 e 10 é retângulo.","a":true}$j$, $q$Verdadeiro: 6² + 8² = 36 + 64 = 100 = 10². É o 3-4-5 dobrado.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:1', 4, 'bank', $q$Complete a frase sobre os lados$q$, $j${"parts":["Os lados que formam o ângulo reto são os ","; o lado oposto ao ângulo reto é a ","."],"a":["catetos","hipotenusa"],"extra":["raios","alturas"]}$j$, $q$Catetos se encostam no ângulo reto; a hipotenusa fica do outro lado.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:1', 5, 'order', $q$Ordene a aplicação do teorema de Pitágoras$q$, $j${"items":["Confirmar que o triângulo é retângulo","Identificar os catetos e a hipotenusa","Montar a relação: hipotenusa² = cateto² + cateto²","Resolver e conferir o resultado"]}$j$, $q$Sem o ângulo reto confirmado, o teorema nem entra em campo.$q$, 2);

-- gmt:pit:2 · Aplicações de Pitágoras
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:2', 0, 'mc', $q$Uma escada de 5 m está apoiada numa parede, com o pé a 3 m dela. A escada alcança a altura de:$q$, $j${"opts":["4 m","2 m","8 m","15 m"],"a":0}$j$, $q$5² − 3² = 25 − 9 = 16 → altura = 4 m. Escada, parede e chão formam o 3-4-5.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:2', 1, 'mc', $q$A diagonal de um retângulo de 6 cm por 8 cm mede:$q$, $j${"opts":["10 cm","14 cm","48 cm","7 cm"],"a":0}$j$, $q$A diagonal fecha um triângulo retângulo com os lados: 6² + 8² = 100 → 10 cm.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:2', 2, 'mc', $q$Pitágoras aparece no dia a dia quando queremos:$q$, $j${"opts":["Calcular distâncias em linha reta usando um ângulo reto, como a diagonal de um terreno","Pintar uma parede","Contar os lados de um polígono","Medir temperatura"],"a":0}$j$, $q$Onde houver um canto reto e uma distância inclinada, Pitágoras resolve.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:2', 3, 'tf', $q$Julgue a afirmação sobre o cateto que falta$q$, $j${"stmt":"Num triângulo retângulo com hipotenusa 13 e um cateto 5, o outro cateto mede 12.","a":true}$j$, $q$Verdadeiro: 13² − 5² = 169 − 25 = 144 = 12². A terna 5-12-13.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:2', 4, 'bank', $q$Complete a frase sobre a escada$q$, $j${"parts":["Na escada apoiada na parede, a escada é a "," do triângulo; a parede e o chão são os ","."],"a":["hipotenusa","catetos"],"extra":["base","bissetrizes"]}$j$, $q$O canto parede-chão é o ângulo reto; a escada inclinada é o lado oposto a ele.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:pit', 'gmt:pit:2', 5, 'match', $q$Associe os catetos à hipotenusa$q$, $j${"pairs":[["Catetos 3 e 4","Hipotenusa 5"],["Catetos 6 e 8","Hipotenusa 10"],["Catetos 5 e 12","Hipotenusa 13"],["Catetos 8 e 15","Hipotenusa 17"]]}$j$, $q$As ternas pitagóricas clássicas: 3-4-5, 6-8-10, 5-12-13 e 8-15-17.$q$, 3);

-- ---------------------------------------------------------------
-- gmt:sem:1 · Figuras semelhantes
-- ---------------------------------------------------------------
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:1', 0, 'mc', $q$Duas figuras são semelhantes quando:$q$, $j${"opts":["Têm a mesma forma, com ângulos iguais e lados proporcionais","Têm a mesma cor","Têm a mesma área obrigatoriamente","São idênticas em tudo"],"a":0}$j$, $q$Semelhante = mesma forma em tamanhos possivelmente diferentes.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:1', 1, 'mc', $q$Um mapa na escala 1:100.000 significa que 1 cm no mapa equivale a:$q$, $j${"opts":["1 km no terreno","100 m no terreno","10 cm no terreno","100 km no terreno"],"a":0}$j$, $q$100.000 cm = 1.000 m = 1 km.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:1', 2, 'mc', $q$Dois triângulos semelhantes têm razão 2. Se um lado do menor mede 7 cm, o lado correspondente do maior mede:$q$, $j${"opts":["14 cm","9 cm","3,5 cm","7 cm"],"a":0}$j$, $q$Razão 2 = cada lado dobra: 7 × 2 = 14 cm.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:1', 3, 'tf', $q$Julgue a afirmação sobre a foto ampliada$q$, $j${"stmt":"Ampliar uma foto sem distorcer gera uma figura semelhante à original.","a":true}$j$, $q$Verdadeiro: a ampliação mantém os ângulos e multiplica todos os lados pela mesma razão.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:1', 4, 'bank', $q$Complete a frase sobre a semelhança$q$, $j${"parts":["Figuras semelhantes têm ângulos "," e lados ","."],"a":["iguais","proporcionais"],"extra":["diferentes","paralelos"]}$j$, $q$Ângulos preservam a forma; a proporção dos lados define o tamanho.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:1', 5, 'match', $q$Associe o conceito ao seu significado$q$, $j${"pairs":[["Escala","Razão entre o desenho e o real"],["Razão de semelhança","Quociente entre lados correspondentes"],["Ampliação","Razão maior que 1"],["Redução","Razão menor que 1"]]}$j$, $q$Mapas, plantas e maquetes: a semelhança aplicada ao mundo real.$q$, 3);

-- gmt:sem:2 · O teorema de Tales
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:2', 0, 'mc', $q$O teorema de Tales trata de:$q$, $j${"opts":["Retas paralelas cortadas por transversais, que geram segmentos proporcionais","Áreas de círculos","Ângulos de polígonos","Volumes de prismas"],"a":0}$j$, $q$Paralelas fatiam as transversais na mesma proporção — essa é a essência de Tales.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:2', 1, 'mc', $q$Um poste de 2 m projeta uma sombra de 3 m. No mesmo instante, um prédio projeta uma sombra de 30 m. O prédio mede:$q$, $j${"opts":["20 m","45 m","15 m","60 m"],"a":0}$j$, $q$2/3 = altura/30 → altura = 60 ÷ 3 = 20 m.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:2', 2, 'mc', $q$A conta das sombras funciona porque:$q$, $j${"opts":["Os raios do sol chegam praticamente paralelos, criando triângulos semelhantes","O prédio e o poste têm a mesma altura","A sombra é sempre igual à altura","O sol gira em volta do poste"],"a":0}$j$, $q$Raios paralelos + chão plano = dois triângulos de mesma forma, em escalas diferentes.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:2', 3, 'tf', $q$Julgue a afirmação sobre a pirâmide$q$, $j${"stmt":"Diz a tradição que Tales mediu a altura de uma pirâmide do Egito comparando a sombra dela com a de um bastão.","a":true}$j$, $q$Verdadeiro: a proporção entre sombras foi a régua de Tales — geometria resolvendo sem escalar a pirâmide.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:2', 4, 'bank', $q$Complete a frase sobre as sombras$q$, $j${"parts":["Altura e sombra formam uma ","; os raios paralelos do sol garantem triângulos ","."],"a":["proporção","semelhantes"],"extra":["subtração","retos"]}$j$, $q$Monte a proporção altura/sombra = altura/sombra e resolva.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:sem', 'gmt:sem:2', 5, 'order', $q$Ordene o cálculo de uma altura pela sombra$q$, $j${"items":["Medir a altura e a sombra de um objeto conhecido","Medir a sombra do objeto alto","Montar a proporção entre alturas e sombras","Resolver a proporção e achar a altura"]}$j$, $q$Com um bastão e uma trena, mede-se um prédio inteiro.$q$, 2);

-- ---------------------------------------------------------------
-- gmt:esp:1 · Prismas e cilindros
-- ---------------------------------------------------------------
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:1', 0, 'mc', $q$O volume de um prisma (e também do cilindro) é:$q$, $j${"opts":["Área da base × altura","Perímetro × altura","Base + altura","Área da base ÷ altura"],"a":0}$j$, $q$Empilhe cópias da base até a altura: isso é o volume.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:1', 1, 'mc', $q$Uma caixa (paralelepípedo) de 4 m × 3 m × 2 m tem volume de:$q$, $j${"opts":["24 m³","9 m³","12 m³","32 m³"],"a":0}$j$, $q$4 × 3 × 2 = 24 m³: comprimento × largura × altura.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:1', 2, 'mc', $q$Um cubo de aresta 3 cm tem volume de:$q$, $j${"opts":["27 cm³","9 cm³","12 cm³","18 cm³"],"a":0}$j$, $q$3 × 3 × 3 = 27 cm³ — no cubo, aresta ao cubo (daí o nome!).$q$, 2);
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:1', 3, 'tf', $q$Julgue a afirmação sobre as unidades de volume$q$, $j${"stmt":"O volume se mede em unidades cúbicas, como o metro cúbico (m³).","a":true}$j$, $q$Verdadeiro: e 1 m³ = 1.000 litros — o elo entre a geometria e a caixa d'água.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:1', 4, 'bank', $q$Complete a frase sobre os objetos$q$, $j${"parts":["O dado tem a forma de um ","; a lata de refrigerante lembra um ","."],"a":["cubo","cilindro"],"extra":["cone","hexágono"]}$j$, $q$Os sólidos geométricos moram na despensa: caixas, latas, funis e bolas.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:1', 5, 'match', $q$Associe o sólido ao exemplo$q$, $j${"pairs":[["Cubo","Dado de jogar"],["Paralelepípedo","Caixa de sapato"],["Cilindro","Lata de refrigerante"],["Prisma triangular","Barraca de camping clássica"]]}$j$, $q$Prismas e cilindros: duas bases iguais e paredes retas entre elas.$q$, 2);

-- gmt:esp:2 · Pirâmides, cones e esferas
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:2', 0, 'mc', $q$A pirâmide de base quadrada tem:$q$, $j${"opts":["5 faces: a base e 4 triângulos laterais","4 faces","6 faces","8 faces"],"a":0}$j$, $q$Um quadrado embaixo e quatro triângulos subindo ao vértice.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:2', 1, 'mc', $q$O cone lembra qual objeto do dia a dia?$q$, $j${"opts":["A casquinha de sorvete","Uma caixa de sapato","Um dado","Uma folha de papel"],"a":0}$j$, $q$Base circular afunilando até um vértice: casquinha, funil, chapéu de festa.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:2', 2, 'mc', $q$A esfera se caracteriza por:$q$, $j${"opts":["Todos os pontos da superfície estarem à mesma distância do centro","Ter 6 faces","Ter arestas retas","Ter base quadrada"],"a":0}$j$, $q$É a definição da esfera — por isso a bola rola igual para qualquer lado.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:2', 3, 'tf', $q$Julgue a afirmação sobre o cubo$q$, $j${"stmt":"Um cubo tem 8 vértices e 12 arestas.","a":true}$j$, $q$Verdadeiro: 8 cantos e 12 quinas — confira num dado.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:2', 4, 'bank', $q$Complete a frase sobre as famílias de sólidos$q$, $j${"parts":["Os sólidos com todas as faces planas são os ","; cilindro, cone e esfera são os corpos ","."],"a":["poliedros","redondos"],"extra":["círculos","ângulos"]}$j$, $q$Poliedros têm faces e arestas; os corpos redondos rolam.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:esp', 'gmt:esp:2', 5, 'match', $q$Associe o sólido à sua característica$q$, $j${"pairs":[["Pirâmide","Base e faces triangulares até o topo"],["Cone","Base circular e um vértice"],["Esfera","Sem faces nem arestas"],["Cilindro","Duas bases circulares iguais"]]}$j$, $q$Pirâmide e cone afinam até um ponto; cilindro e esfera, não.$q$, 2);

-- ---------------------------------------------------------------
-- gmt:cart:1 · Coordenadas no plano
-- ---------------------------------------------------------------
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:1', 0, 'mc', $q$No plano cartesiano, o ponto (3, 5) significa:$q$, $j${"opts":["3 no eixo x (horizontal) e 5 no eixo y (vertical)","5 no eixo x e 3 no eixo y","Que 3 e 5 são o mesmo número","Um ponto fora do plano"],"a":0}$j$, $q$A ordem importa: primeiro anda no x, depois sobe no y — (3, 5) ≠ (5, 3).$q$, 1);
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:1', 1, 'mc', $q$O ponto (0, 0) é chamado de:$q$, $j${"opts":["Origem","Vértice","Centro de massa","Raiz"],"a":0}$j$, $q$É o encontro dos dois eixos: o marco zero do plano.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:1', 2, 'mc', $q$O ponto (−2, 4) está no:$q$, $j${"opts":["Segundo quadrante (x negativo, y positivo)","Primeiro quadrante","Terceiro quadrante","Quarto quadrante"],"a":0}$j$, $q$Esquerda (x < 0) e para cima (y > 0): segundo quadrante.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:1', 3, 'tf', $q$Julgue a afirmação sobre o mundo real$q$, $j${"stmt":"No GPS, nos mapas e nos jogos, as posições são representadas por coordenadas, como no plano cartesiano.","a":true}$j$, $q$Verdadeiro: latitude/longitude e as posições dos jogos são o plano cartesiano em ação.$q$, 1);
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:1', 4, 'bank', $q$Complete a frase sobre os eixos$q$, $j${"parts":["O eixo horizontal é o eixo ","; o vertical é o eixo ","."],"a":["x","y"],"extra":["z","w"]}$j$, $q$x deitado, y em pé: o endereço de cada ponto é o par (x, y).$q$, 1);
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:1', 5, 'match', $q$Associe o ponto ao seu quadrante$q$, $j${"pairs":[["(2, 3)","Primeiro quadrante"],["(−2, 3)","Segundo quadrante"],["(−2, −3)","Terceiro quadrante"],["(2, −3)","Quarto quadrante"]]}$j$, $q$Os quadrantes giram no sentido anti-horário a partir do canto superior direito.$q$, 2);

-- gmt:cart:2 · Distâncias no plano
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:2', 0, 'mc', $q$A distância entre os pontos (1, 2) e (6, 2), que estão na mesma linha horizontal, é:$q$, $j${"opts":["5","7","4","12"],"a":0}$j$, $q$Mesmo y: basta a diferença dos x → 6 − 1 = 5.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:2', 1, 'mc', $q$A distância entre (3, 1) e (3, 9) é:$q$, $j${"opts":["8","6","12","3"],"a":0}$j$, $q$Mesmo x: diferença dos y → 9 − 1 = 8.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:2', 2, 'mc', $q$Para achar a distância entre (0, 0) e (3, 4), usamos Pitágoras e obtemos:$q$, $j${"opts":["5","7","3,5","12"],"a":0}$j$, $q$Diferenças 3 e 4 viram catetos: a distância é a hipotenusa, 5.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:2', 3, 'tf', $q$Julgue a afirmação sobre o ponto médio$q$, $j${"stmt":"O ponto médio do segmento que liga (2, 4) a (8, 4) é (5, 4).","a":true}$j$, $q$Verdadeiro: o meio é a média das coordenadas — (2 + 8) ÷ 2 = 5.$q$, 3);
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:2', 4, 'bank', $q$Complete a frase sobre as distâncias simples$q$, $j${"parts":["Pontos com o mesmo y estão na mesma linha ","; a distância entre eles é a diferença dos valores de ","."],"a":["horizontal","x"],"extra":["vertical","y"]}$j$, $q$Alinhados na horizontal, a conta é uma subtração; na diagonal, entra Pitágoras.$q$, 2);
select public.fj_seed_q('gmt', 'gmt:cart', 'gmt:cart:2', 5, 'order', $q$Ordene o cálculo da distância entre dois pontos quaisquer$q$, $j${"items":["Achar a diferença dos x e a diferença dos y","Elevar as duas diferenças ao quadrado","Somar os quadrados","Tirar a raiz quadrada da soma"]}$j$, $q$É Pitágoras disfarçado: as diferenças são os catetos, a distância é a hipotenusa.$q$, 3);

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
  for q in select id, dados from public.questoes where tipo = 'mc' and materia_id = 'gmt' loop
    n := coalesce(jsonb_array_length(q.dados->'opts'), 0);
    if n < 2 then continue; end if;
    select array_agg(i order by random()) into perm from generate_series(0, n - 1) i;
    select jsonb_agg(q.dados->'opts'->perm[i] order by i) into novo from generate_series(1, n) i;
    na := coalesce(array_position(perm, coalesce((q.dados->>'a')::int, 0)), 1) - 1;
    update public.questoes set dados = dados || jsonb_build_object('opts', novo, 'a', na) where id = q.id;
  end loop;
end $$;
alter table public.questoes enable trigger auditoria_questoes;

insert into public.schema_versao (versao) values (44) on conflict do nothing;
