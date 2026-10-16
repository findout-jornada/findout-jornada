-- =====================================================================
-- Findout Jornada · Migration 0015 · Matéria Espanhol (4 seções, 8 unidades, 16 lições, 96 questões)
-- Rodar no SQL Editor do Supabase depois da 0014. Idempotente: pode rodar de novo.
-- Depois de rodar, abra o painel: ele publica a nova versão sozinho.
-- Regra do seed: o id da questão vem de md5(lição + enunciado); por isso cada enunciado é único dentro da lição
-- (uma só questão "Julgue a afirmação…" e uma só "Complete…" por lição).
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
('esp', 'Espanhol', 'ES', '#D94F30', true, 10)
on conflict (id) do nothing;

insert into public.secoes (id, materia_id, titulo, ordem) values
(md5('sec:esp:basico')::uuid, 'esp', 'Leitura e vocabulário', 0),
(md5('sec:esp:gramatica')::uuid, 'esp', 'Gramática essencial', 1),
(md5('sec:esp:textos')::uuid, 'esp', 'Gêneros textuais em espanhol', 2),
(md5('sec:esp:cultura')::uuid, 'esp', 'Mundo hispânico e coesão', 3)
on conflict (id) do nothing;

insert into public.unidades (id, secao_id, titulo, ordem) values
(md5('uni:esp:leitura')::uuid, md5('sec:esp:basico')::uuid, 'Estratégias de leitura', 0),
(md5('uni:esp:falsos')::uuid, md5('sec:esp:basico')::uuid, 'Falsos amigos (heterossemânticos)', 1),
(md5('uni:esp:artigos')::uuid, md5('sec:esp:gramatica')::uuid, 'Artigos, gênero e número', 0),
(md5('uni:esp:verbos')::uuid, md5('sec:esp:gramatica')::uuid, 'Verbos e tempos', 1),
(md5('uni:esp:generos')::uuid, md5('sec:esp:textos')::uuid, 'Notícia, anúncio e tirinha', 0),
(md5('uni:esp:poesia')::uuid, md5('sec:esp:textos')::uuid, 'Poesia e canção', 1),
(md5('uni:esp:mundo')::uuid, md5('sec:esp:cultura')::uuid, 'Países e variedades do espanhol', 0),
(md5('uni:esp:conectores')::uuid, md5('sec:esp:cultura')::uuid, 'Conectores e pronomes', 1)
on conflict (id) do nothing;

insert into public.licoes (id, unidade_id, titulo, descricao, ordem) values
(md5('lic:esp:leitura:1')::uuid, md5('uni:esp:leitura')::uuid, 'Cognatos e transparência', 'Palavras parecidas com o português que ajudam a entender o texto.', 0),
(md5('lic:esp:leitura:2')::uuid, md5('uni:esp:leitura')::uuid, 'Ideia principal do texto', 'Tema, tese e conectores que organizam o texto.', 1),
(md5('lic:esp:falsos:1')::uuid, md5('uni:esp:falsos')::uuid, 'Falsos amigos do dia a dia', 'Embarazada, exquisito, polvo e outras armadilhas.', 0),
(md5('lic:esp:falsos:2')::uuid, md5('uni:esp:falsos')::uuid, 'Falsos amigos nas provas', 'Taller, apellido, borrar: os que mais caem no ENEM.', 1),
(md5('lic:esp:artigos:1')::uuid, md5('uni:esp:artigos')::uuid, 'El, la, los, las e lo', 'Artigos definidos e o neutro lo.', 0),
(md5('lic:esp:artigos:2')::uuid, md5('uni:esp:artigos')::uuid, 'Heterogenéricos e plural', 'Palavras que trocam de gênero e a formação do plural.', 1),
(md5('lic:esp:verbos:1')::uuid, md5('uni:esp:verbos')::uuid, 'Presente e ser/estar', 'Conjugação no presente e a diferença entre ser e estar.', 0),
(md5('lic:esp:verbos:2')::uuid, md5('uni:esp:verbos')::uuid, 'Passado e futuro', 'Pretérito, imperfeito e as formas de futuro.', 1),
(md5('lic:esp:generos:1')::uuid, md5('uni:esp:generos')::uuid, 'Propósito do texto', 'Informar, convencer, instruir ou entreter.', 0),
(md5('lic:esp:generos:2')::uuid, md5('uni:esp:generos')::uuid, 'Humor e crítica em quadrinhos', 'Mafalda, ironia e sinais de pontuação.', 1),
(md5('lic:esp:poesia:1')::uuid, md5('uni:esp:poesia')::uuid, 'Poemas hispânicos', 'Neruda, Machado, Lorca e Mistral.', 0),
(md5('lic:esp:poesia:2')::uuid, md5('uni:esp:poesia')::uuid, 'Canções e letras', 'Guantanamera, Violeta Parra e o verbo gustar.', 1),
(md5('lic:esp:mundo:1')::uuid, md5('uni:esp:mundo')::uuid, 'Onde se fala espanhol', 'Países, capitais e línguas cooficiais.', 0),
(md5('lic:esp:mundo:2')::uuid, md5('uni:esp:mundo')::uuid, 'Voseo e variações', 'Vos, vosotros, ustedes e o vocabulário de cada país.', 1),
(md5('lic:esp:conectores:1')::uuid, md5('uni:esp:conectores')::uuid, 'Conectores do texto', 'Pero, sin embargo, además, por lo tanto.', 0),
(md5('lic:esp:conectores:2')::uuid, md5('uni:esp:conectores')::uuid, 'Pronomes e referência', 'Lo, les, su, mío: a quem o texto se refere.', 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- esp:leitura:1 · Cognatos e transparência
-- ---------------------------------------------------------------
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:1', 0, 'mc', $q$No trecho "La universidad ofrece becas para estudiantes de familias con pocos recursos", a palavra "becas" significa:$q$, $j${"opts":["Bolsas de estudo","Vagas","Bibliotecas","Mochilas"],"a":0}$j$, $q$Beca é bolsa de estudo. O contexto ajuda: a universidade oferece algo para estudantes com poucos recursos.$q$, 1);
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:1', 1, 'mc', $q$Palavras como "nación", "importante" e "problema" são chamadas de cognatas porque:$q$, $j${"opts":["Só existem no espanhol da Espanha","Têm forma e sentido parecidos com o português","São sempre falsos amigos","Não têm tradução"],"a":1}$j$, $q$Cognatos têm a mesma origem e sentido parecido nas duas línguas; são a primeira ajuda na leitura.$q$, 1);
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:1', 2, 'mc', $q$"El tren sale a las ocho de la mañana." A frase informa:$q$, $j${"opts":["O preço da passagem","O destino do trem","O horário de partida do trem","O número de passageiros"],"a":2}$j$, $q$Salir é sair, partir: o trem sai às oito da manhã.$q$, 1);
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:1', 3, 'tf', $q$Julgue a afirmação sobre cognatos$q$, $j${"stmt":"Em espanhol, \"oficina\" é cognato transparente de \"oficina\" em português e significa o mesmo.","a":false}$j$, $q$Falso: em espanhol, oficina é escritório. A oficina mecânica do português é taller.$q$, 2);
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:1', 4, 'bank', $q$Complete a frase com as palavras em espanhol$q$, $j${"parts":["Mañana tengo una "," de matemáticas y necesito un "," para escribir."],"a":["prueba","bolígrafo"],"extra":["ventana","sombrero"]}$j$, $q$Prueba é prova e bolígrafo é caneta. Ventana (janela) e sombrero (chapéu) não fazem sentido na frase.$q$, 1);
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:1', 5, 'match', $q$Associe a palavra em espanhol ao seu significado$q$, $j${"pairs":[["ciudad","cidade"],["escuela","escola"],["trabajo","trabalho"],["playa","praia"]]}$j$, $q$Quatro cognatos frequentes em textos de prova.$q$, 1);

-- esp:leitura:2 · Ideia principal do texto
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:2', 0, 'mc', $q$"Cada vez más jóvenes eligen la bicicleta para ir al trabajo: es barata, no contamina y evita los atascos." A ideia central do trecho é:$q$, $j${"opts":["O preço dos carros nas cidades","As vantagens da bicicleta para ir ao trabalho","A falta de ciclovias","A poluição das fábricas"],"a":1}$j$, $q$O trecho lista motivos (barata, não polui, evita engarrafamentos) para a escolha da bicicleta.$q$, 2);
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:2', 1, 'mc', $q$No trecho "Sin embargo, el proyecto fue rechazado por falta de presupuesto", a expressão "sin embargo" indica:$q$, $j${"opts":["Oposição (no entanto)","Causa (porque)","Adição (além disso)","Conclusão (portanto)"],"a":0}$j$, $q$Sin embargo equivale a no entanto, porém: introduz uma ideia contrária à anterior.$q$, 2);
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:2', 2, 'mc', $q$"Se buscan voluntarios para limpiar la playa el sábado. Traer guantes y agua." O texto é:$q$, $j${"opts":["Uma notícia sobre poluição","Uma receita","Uma carta pessoal","Um anúncio que convoca voluntários"],"a":3}$j$, $q$Se buscan (procuram-se) e as instruções (trazer luvas e água) são marcas de anúncio de convocação.$q$, 1);
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:2', 3, 'tf', $q$Julgue a afirmação sobre leitura$q$, $j${"stmt":"Ler o título e as primeiras frases de um texto em espanhol ajuda a prever o tema antes da leitura completa.","a":true}$j$, $q$Verdadeiro: antecipar o tema pelo título e pelo começo do texto é uma das estratégias mais úteis na prova.$q$, 1);
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:2', 4, 'bank', $q$Complete a frase do texto$q$, $j${"parts":["El autor afirma que la lectura mejora la ",", pero exige ","."],"a":["memoria","tiempo"],"extra":["ventana","queso"]}$j$, $q$A leitura melhora a memória, mas exige tempo. Pero (mas) marca a oposição entre as duas ideias.$q$, 2);
select public.fj_seed_q('esp', 'esp:leitura', 'esp:leitura:2', 5, 'order', $q$Ordene os passos para encontrar a ideia principal de um texto em espanhol$q$, $j${"items":["Leer el título y mirar las imágenes","Leer el texto completo una vez","Identificar la frase que resume el tema","Comprobar que los demás párrafos la apoyan"]}$j$, $q$Antecipar, ler, localizar a frase central e conferir se o resto do texto a sustenta.$q$, 2);

-- ---------------------------------------------------------------
-- esp:falsos:1 · Falsos amigos do dia a dia
-- ---------------------------------------------------------------
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:1', 0, 'mc', $q$Em espanhol, "estoy embarazada" significa:$q$, $j${"opts":["Estou envergonhada","Estou grávida","Estou atrasada","Estou cansada"],"a":1}$j$, $q$Embarazada é grávida. Envergonhada é avergonzada.$q$, 1);
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:1', 1, 'mc', $q$Em espanhol, "exquisito" significa:$q$, $j${"opts":["Delicioso, refinado","Esquisito, estranho","Caro","Raro"],"a":0}$j$, $q$Um plato exquisito é um prato delicioso. Esquisito, no sentido de estranho, é raro ou extraño.$q$, 1);
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:1', 2, 'mc', $q$Um cardápio na Espanha anuncia "pulpo a la gallega". O prato é feito de:$q$, $j${"opts":["Pó","Frango","Polvo","Pão"],"a":2}$j$, $q$Pulpo é polvo (o molusco). Já polvo, em espanhol, é pó, poeira.$q$, 2);
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:1', 3, 'tf', $q$Julgue a afirmação sobre falsos amigos$q$, $j${"stmt":"Em espanhol, \"vaso\" é copo, e \"copo\" é floco, como em \"copo de nieve\".","a":true}$j$, $q$Verdadeiro: un vaso de agua é um copo de água; copo de nieve é floco de neve.$q$, 2);
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:1', 4, 'bank', $q$Complete a frase sobre os falsos amigos$q$, $j${"parts":["Em espanhol, \"cachorro\" é o "," do cão, e \"cena\" é a refeição da ",", o jantar."],"a":["filhote","noite"],"extra":["dono","manhã"]}$j$, $q$Cachorro é filhote (cão adulto é perro); cena é jantar, a refeição da noite.$q$, 2);
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:1', 5, 'match', $q$Associe o falso amigo ao seu significado real$q$, $j${"pairs":[["rato","momento, instante"],["salsa","molho"],["oficina","escritório"],["largo","comprido"]]}$j$, $q$Rato é um instante (o animal é ratón), salsa é molho, oficina é escritório e largo é comprido (largura é ancho).$q$, 2);

-- esp:falsos:2 · Falsos amigos nas provas
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:2', 0, 'mc', $q$"El taller de mecánica queda cerca." A palavra "taller" significa:$q$, $j${"opts":["Talher","Oficina","Loja","Armazém"],"a":1}$j$, $q$Taller é oficina (de conserto ou de trabalho). Talher é cubierto.$q$, 1);
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:2', 1, 'mc', $q$Na frase "La niña está muy flaca", a palavra "flaca" quer dizer:$q$, $j${"opts":["Fraca","Falsa","Magra","Chata"],"a":2}$j$, $q$Flaca é magra. Fraca é débil.$q$, 1);
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:2', 2, 'mc', $q$Em um formulário em espanhol, o campo "apellido" pede o seu:$q$, $j${"opts":["Sobrenome","Apelido","Nome próprio","Assinatura"],"a":0}$j$, $q$Apellido é sobrenome. Apelido é apodo ou sobrenombre.$q$, 1);
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:2', 3, 'tf', $q$Julgue a afirmação sobre nomes$q$, $j${"stmt":"Em espanhol, \"sobrenombre\" significa apelido, enquanto \"apellido\" é o sobrenome.","a":true}$j$, $q$Verdadeiro: os dois termos trocam de lugar em relação ao português, por isso confundem tanto.$q$, 2);
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:2', 4, 'bank', $q$Complete a frase sobre os verbos e substantivos enganosos$q$, $j${"parts":["\"Borrar\" em espanhol significa ","; já \"aceite\" significa ","."],"a":["apagar","óleo"],"extra":["sujar","aceitar"]}$j$, $q$Borrar é apagar (uma borracha é goma de borrar); aceite é óleo, como em aceite de oliva.$q$, 2);
select public.fj_seed_q('esp', 'esp:falsos', 'esp:falsos:2', 5, 'order', $q$Ordene as palavras para formar a frase em espanhol que diz "Meu sobrenome é García"$q$, $j${"items":["Mi","apellido","es","García"]}$j$, $q$Mi apellido es García: apellido é sobrenome.$q$, 1);

-- ---------------------------------------------------------------
-- esp:artigos:1 · El, la, los, las e lo
-- ---------------------------------------------------------------
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:1', 0, 'mc', $q$Complete: "___ problema es grave."$q$, $j${"opts":["La","Los","El","Las"],"a":2}$j$, $q$Problema é masculino em espanhol, como em português: el problema.$q$, 1);
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:1', 1, 'mc', $q$Qual frase está correta?$q$, $j${"opts":["El leche está fría.","La leche está fría.","Lo leche está frío.","Las leche está fría."],"a":1}$j$, $q$Leche é feminino em espanhol (diferente do português): la leche está fría.$q$, 2);
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:1', 2, 'mc', $q$O artigo neutro "lo" está bem empregado em:$q$, $j${"opts":["Lo niño es alto.","Lo casa es grande.","Lo libros son nuevos.","Lo importante es participar."],"a":3}$j$, $q$Lo acompanha adjetivos e ideias abstratas (lo importante, lo mejor), nunca substantivos concretos.$q$, 2);
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:1', 3, 'tf', $q$Julgue a afirmação sobre o artigo$q$, $j${"stmt":"Em espanhol, \"el agua\" leva artigo masculino no singular porque a palavra começa com \"a\" tônico, mas continua feminina: \"el agua fría\".","a":true}$j$, $q$Verdadeiro: é uma regra de som. No plural volta o feminino normal: las aguas.$q$, 3);
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:1', 4, 'bank', $q$Complete com os artigos corretos$q$, $j${"parts":["","nariz de Juan es grande y ","árbol del jardín es alto."],"a":["La","el"],"extra":["Lo","las"]}$j$, $q$Nariz é feminino em espanhol (la nariz) e árbol é masculino (el árbol).$q$, 2);
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:1', 5, 'match', $q$Associe a palavra com artigo ao seu equivalente em português$q$, $j${"pairs":[["el puente","a ponte"],["la leche","o leite"],["la sal","o sal"],["el árbol","a árvore"]]}$j$, $q$Heterogenéricos: palavras que trocam de gênero entre as duas línguas.$q$, 2);

-- esp:artigos:2 · Heterogenéricos e plural
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:2', 0, 'mc', $q$Qual palavra é feminina em espanhol, diferentemente do português?$q$, $j${"opts":["El puente","La nariz","El color","El viaje"],"a":1}$j$, $q$La nariz é feminina em espanhol e masculina em português. Puente, color e viaje são masculinos em espanhol e femininos em português.$q$, 2);
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:2', 1, 'mc', $q$O plural de "el lápiz" é:$q$, $j${"opts":["los lápizes","las lápiz","los lápis","los lápices"],"a":3}$j$, $q$Palavras terminadas em z trocam z por c antes de -es: lápiz, lápices; vez, veces.$q$, 2);
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:2', 2, 'mc', $q$Complete: "Tengo ___ amigos en Madrid."$q$, $j${"opts":["muchos","muchas","mucho","mucha"],"a":0}$j$, $q$Mucho concorda com o substantivo: amigos é masculino plural, logo muchos.$q$, 1);
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:2', 3, 'tf', $q$Julgue a afirmação sobre o plural$q$, $j${"stmt":"Palavras terminadas em consoante formam o plural com \"-es\" em espanhol: \"ciudad\" vira \"ciudades\".","a":true}$j$, $q$Verdadeiro: vogal + s (casa, casas); consoante + es (ciudad, ciudades; papel, papeles).$q$, 1);
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:2', 4, 'bank', $q$Complete os plurais$q$, $j${"parts":["El árbol es masculino e seu plural é \"los ","\"; la flor é feminino e seu plural é \"las ","\"."],"a":["árboles","flores"],"extra":["árbols","flors"]}$j$, $q$Consoante + es: árboles, flores.$q$, 1);
select public.fj_seed_q('esp', 'esp:artigos', 'esp:artigos:2', 5, 'order', $q$Ordene as palavras para formar a frase correta em espanhol$q$, $j${"items":["Los","niños","juegan","en","el parque"]}$j$, $q$Los niños juegan en el parque: as crianças brincam no parque.$q$, 1);

-- ---------------------------------------------------------------
-- esp:verbos:1 · Presente e ser/estar
-- ---------------------------------------------------------------
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:1', 0, 'mc', $q$Complete: "Yo ___ estudiante de medicina."$q$, $j${"opts":["estoy","soy","eres","está"],"a":1}$j$, $q$Profissão e identidade pedem ser: yo soy estudiante.$q$, 1);
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:1', 1, 'mc', $q$Complete: "Ella ___ cansada después del trabajo."$q$, $j${"opts":["es","son","está","somos"],"a":2}$j$, $q$Estado passageiro pede estar: ella está cansada.$q$, 1);
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:1', 2, 'mc', $q$Em "Nosotros vivimos en Buenos Aires", o verbo está na:$q$, $j${"opts":["1ª pessoa do plural do presente","3ª pessoa do singular do passado","2ª pessoa do singular do futuro","1ª pessoa do singular do presente"],"a":0}$j$, $q$Vivimos é nosotros, presente do indicativo: nós vivemos.$q$, 2);
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:1', 3, 'tf', $q$Julgue a afirmação sobre ser e estar$q$, $j${"stmt":"Em espanhol, \"ser\" indica características permanentes e \"estar\" indica estados e localização: \"Madrid está en España\".","a":true}$j$, $q$Verdadeiro: Madrid es grande (característica), Madrid está en España (localização).$q$, 2);
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:1', 4, 'bank', $q$Complete com o verbo hablar no presente$q$, $j${"parts":["Yo "," español todos los días y mi hermano "," inglés."],"a":["hablo","habla"],"extra":["hablas","hablamos"]}$j$, $q$Yo hablo, él habla. Hablas é tú e hablamos é nosotros.$q$, 1);
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:1', 5, 'match', $q$Associe o pronome à forma do verbo tener no presente$q$, $j${"pairs":[["yo","tengo"],["tú","tienes"],["él","tiene"],["nosotros","tenemos"]]}$j$, $q$Tener é irregular: tengo, tienes, tiene, tenemos, tenéis, tienen.$q$, 2);

-- esp:verbos:2 · Passado e futuro
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:2', 0, 'mc', $q$Complete: "Ayer ___ al cine con mis amigos."$q$, $j${"opts":["voy","iré","fui","vaya"],"a":2}$j$, $q$Ayer (ontem) pede o passado: fui al cine.$q$, 1);
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:2', 1, 'mc', $q$"Mañana lloverá en toda la región." O verbo "lloverá" indica:$q$, $j${"opts":["Passado","Futuro","Presente","Imperativo"],"a":1}$j$, $q$A terminação -á marca o futuro: lloverá, choverá.$q$, 1);
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:2', 2, 'mc', $q$"Cuando era niño, jugaba en la calle." O pretérito imperfeito "jugaba" expressa:$q$, $j${"opts":["Ação habitual no passado","Ação futura","Ordem","Ação concluída num momento exato"],"a":0}$j$, $q$O imperfeito (jugaba, vivía) descreve hábitos e cenários do passado, sem momento definido.$q$, 2);
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:2', 3, 'tf', $q$Julgue a afirmação sobre o futuro$q$, $j${"stmt":"\"Vamos a viajar\" e \"viajaremos\" são duas formas de expressar o futuro em espanhol.","a":true}$j$, $q$Verdadeiro: ir a + infinitivo é o futuro mais usado na fala; viajaremos é o futuro simples.$q$, 2);
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:2', 4, 'bank', $q$Complete com o verbo viajar nos tempos certos$q$, $j${"parts":["El año pasado "," a México y el próximo año "," a Chile."],"a":["viajé","viajaré"],"extra":["viajo","viajas"]}$j$, $q$El año pasado pede o passado (viajé); el próximo año pede o futuro (viajaré).$q$, 2);
select public.fj_seed_q('esp', 'esp:verbos', 'esp:verbos:2', 5, 'order', $q$Ordene os fatos conforme os tempos verbais da frase "Estudié mucho, aprobé el examen y ahora celebro; mañana descansaré"$q$, $j${"items":["Estudié mucho","Aprobé el examen","Celebro","Descansaré"]}$j$, $q$Passado (estudié, aprobé), presente (celebro) e futuro (descansaré).$q$, 2);

-- ---------------------------------------------------------------
-- esp:generos:1 · Propósito do texto
-- ---------------------------------------------------------------
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:1', 0, 'mc', $q$"¡Oferta! Dos pizzas por el precio de una, solo este fin de semana." O propósito do texto é:$q$, $j${"opts":["Informar um fato histórico","Contar uma história","Convencer o leitor a comprar","Ensinar uma receita"],"a":2}$j$, $q$Oferta, preço e prazo curto (solo este fin de semana) são marcas da publicidade.$q$, 1);
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:1', 1, 'mc', $q$"El Gobierno anunció ayer nuevas medidas contra la inflación." O gênero do texto é:$q$, $j${"opts":["Notícia","Poema","Anúncio publicitário","Receita"],"a":0}$j$, $q$Fato recente, data (ayer) e linguagem objetiva: é uma notícia.$q$, 1);
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:1', 2, 'mc', $q$"Mezcle la harina con el azúcar y añada los huevos." O texto é:$q$, $j${"opts":["Uma notícia","Uma receita","Um poema","Uma carta de reclamação"],"a":1}$j$, $q$Ingredientes e verbos de instrução (mezcle, añada) formam uma receita.$q$, 1);
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:1', 3, 'tf', $q$Julgue a afirmação sobre os gêneros$q$, $j${"stmt":"Verbos no imperativo, como \"compre\", \"llame\" e \"disfrute\", são típicos de anúncios publicitários em espanhol.","a":true}$j$, $q$Verdadeiro: o anúncio fala diretamente com o leitor e manda agir: compre, ligue, aproveite.$q$, 1);
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:1', 4, 'bank', $q$Complete a frase sobre os gêneros$q$, $j${"parts":["Uma "," informa fatos recentes; um "," tenta vender um produto ou uma ideia."],"a":["notícia","anúncio"],"extra":["poema","diário"]}$j$, $q$Notícia informa; anúncio persuade.$q$, 1);
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:1', 5, 'match', $q$Associe o gênero ao seu propósito principal$q$, $j${"pairs":[["Noticia","Informar"],["Anuncio","Persuadir"],["Receta","Instruir"],["Cuento","Entreter"]]}$j$, $q$Identificar o propósito ajuda a prever a linguagem e a estrutura do texto.$q$, 1);

-- esp:generos:2 · Humor e crítica em quadrinhos
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:2', 0, 'mc', $q$Mafalda, personagem do argentino Quino, é conhecida por:$q$, $j${"opts":["Ser uma super-heroína","Criticar a política e o mundo adulto com humor","Adorar sopa","Viver na Espanha"],"a":1}$j$, $q$Mafalda é uma menina que questiona o mundo dos adultos; ela odeia sopa e vive na Argentina.$q$, 2);
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:2', 1, 'mc', $q$Numa tirinha, um personagem diz "¡Qué suerte!" logo depois de perder o ônibus. O recurso usado é:$q$, $j${"opts":["Ironia","Metáfora","Onomatopeia","Hipérbole"],"a":0}$j$, $q$Dizer "que sorte" numa situação de azar é ironia: o sentido real é o contrário do dito.$q$, 2);
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:2', 2, 'mc', $q$Em quadrinhos em espanhol, a interjeição "¡Ay!" expressa:$q$, $j${"opts":["Concordância","Dúvida","Dor ou surpresa","Despedida"],"a":2}$j$, $q$¡Ay! equivale a ai!: dor, susto ou surpresa.$q$, 1);
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:2', 3, 'tf', $q$Julgue a afirmação sobre a pontuação$q$, $j${"stmt":"Em espanhol, as frases exclamativas e interrogativas levam sinal também no início: \"¡Hola!\" e \"¿Cómo estás?\".","a":true}$j$, $q$Verdadeiro: os sinais invertidos de abertura são exclusivos do espanhol.$q$, 1);
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:2', 4, 'bank', $q$Complete a frase sobre os sinais invertidos$q$, $j${"parts":["O sinal \"¡\" abre uma frase ","; o sinal \"¿\" abre uma frase ","."],"a":["exclamativa","interrogativa"],"extra":["negativa","afirmativa"]}$j$, $q$¡...! para exclamação e ¿...? para pergunta, sempre com o sinal de abertura.$q$, 1);
select public.fj_seed_q('esp', 'esp:generos', 'esp:generos:2', 5, 'order', $q$Ordene os passos para interpretar uma tirinha em espanhol$q$, $j${"items":["Observar a cena e os personagens","Ler os balões na ordem dos quadrinhos","Perceber o que foge do esperado no último quadro","Relacionar o humor à crítica que a tirinha faz"]}$j$, $q$Cena, falas, virada e crítica: o caminho para entender o humor dos quadrinhos.$q$, 2);

-- ---------------------------------------------------------------
-- esp:poesia:1 · Poemas hispânicos
-- ---------------------------------------------------------------
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:1', 0, 'mc', $q$Pablo Neruda, autor de "Veinte poemas de amor y una canción desesperada", nasceu no:$q$, $j${"opts":["Chile","Argentina","Espanha","México"],"a":0}$j$, $q$Neruda é chileno e ganhou o Nobel de Literatura em 1971.$q$, 1);
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:1', 1, 'mc', $q$"Caminante, no hay camino, se hace camino al andar", de Antonio Machado, sugere que:$q$, $j${"opts":["Não se deve viajar","As estradas da Espanha são ruins","O caminho da vida é construído enquanto se vive","É preciso seguir um mapa"],"a":2}$j$, $q$O verso é uma metáfora: não há caminho pronto, ele se faz ao caminhar.$q$, 2);
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:1', 2, 'mc', $q$Federico García Lorca, poeta espanhol, é autor de:$q$, $j${"opts":["Cien años de soledad","Romancero gitano","Don Quijote","Rayuela"],"a":1}$j$, $q$Romancero gitano (1928) é de Lorca; Cien años de soledad é de García Márquez, Don Quijote é de Cervantes e Rayuela é de Cortázar.$q$, 3);
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:1', 3, 'tf', $q$Julgue a afirmação sobre a poeta chilena$q$, $j${"stmt":"Gabriela Mistral, poeta chilena, foi a primeira pessoa da América Latina a ganhar o Prêmio Nobel de Literatura, em 1945.","a":true}$j$, $q$Verdadeiro: Mistral recebeu o Nobel em 1945, antes de Neruda (1971), também chileno.$q$, 2);
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:1', 4, 'bank', $q$Complete a frase sobre recursos poéticos$q$, $j${"parts":["Em poesia, a repetição de sons consonantais é a ","; a comparação sem a palavra \"como\" é a ","."],"a":["aliteração","metáfora"],"extra":["rima","hipérbole"]}$j$, $q$Aliteração repete consoantes; metáfora compara sem conectivo. Os poemas hispânicos usam os dois recursos.$q$, 2);
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:1', 5, 'match', $q$Associe o poeta ao seu país$q$, $j${"pairs":[["Pablo Neruda","Chile"],["Octavio Paz","México"],["Jorge Luis Borges","Argentina"],["Antonio Machado","Espanha"]]}$j$, $q$Quatro nomes da poesia em língua espanhola, de três continentes literários diferentes.$q$, 2);

-- esp:poesia:2 · Canções e letras
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:2', 0, 'mc', $q$"Guantanamera", canção cubana conhecida no mundo todo, usa versos do poeta:$q$, $j${"opts":["Pablo Neruda","José Martí","Rubén Darío","Mario Benedetti"],"a":1}$j$, $q$A letra adapta os Versos sencillos de José Martí, herói da independência cubana.$q$, 3);
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:2', 1, 'mc', $q$Na letra "Gracias a la vida, que me ha dado tanto", de Violeta Parra, o eu lírico expressa:$q$, $j${"opts":["Raiva","Medo da morte","Gratidão pela vida","Saudade de um lugar"],"a":2}$j$, $q$Gracias a la vida é um agradecimento pelos sentidos, pelos afetos e pela própria vida.$q$, 1);
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:2', 2, 'mc', $q$Na canção "Me gustas tú", de Manu Chao, a frase "me gusta la moto" equivale a:$q$, $j${"opts":["Eu gosto da moto","A moto me pertence","Eu dirijo a moto","A moto é nova"],"a":0}$j$, $q$Gustar funciona ao contrário do português: a moto agrada a mim, ou seja, eu gosto da moto.$q$, 1);
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:2', 3, 'tf', $q$Julgue a afirmação sobre o verbo gustar$q$, $j${"stmt":"Em espanhol, o verbo \"gustar\" concorda com a coisa de que se gosta: \"me gusta el mar\", \"me gustan las playas\".","a":true}$j$, $q$Verdadeiro: o sujeito gramatical é o que agrada; por isso gusta no singular e gustan no plural.$q$, 2);
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:2', 4, 'bank', $q$Complete com as formas do verbo gustar$q$, $j${"parts":["Me "," la música y me "," los conciertos."],"a":["gusta","gustan"],"extra":["gusto","gustas"]}$j$, $q$La música (singular) pede gusta; los conciertos (plural) pede gustan.$q$, 2);
select public.fj_seed_q('esp', 'esp:poesia', 'esp:poesia:2', 5, 'order', $q$Ordene as partes para formar o verso "Gracias a la vida que me ha dado tanto"$q$, $j${"items":["Gracias","a la vida","que me ha dado","tanto"]}$j$, $q$Verso de abertura da canção de Violeta Parra, regravada por Mercedes Sosa e muitos outros.$q$, 1);

-- ---------------------------------------------------------------
-- esp:mundo:1 · Onde se fala espanhol
-- ---------------------------------------------------------------
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:1', 0, 'mc', $q$O país com o maior número de falantes nativos de espanhol é:$q$, $j${"opts":["Espanha","Argentina","México","Colômbia"],"a":2}$j$, $q$O México tem mais de 120 milhões de falantes, bem mais que a Espanha.$q$, 1);
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:1', 1, 'mc', $q$Qual país da América do Sul NÃO tem o espanhol como língua oficial?$q$, $j${"opts":["Peru","Brasil","Uruguai","Venezuela"],"a":1}$j$, $q$O Brasil fala português; os vizinhos citados falam espanhol.$q$, 1);
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:1', 2, 'mc', $q$Na Espanha, além do castelhano, são línguas cooficiais em suas regiões:$q$, $j${"opts":["Catalão, galego e basco","Francês e italiano","Português e inglês","Árabe e latim"],"a":0}$j$, $q$Catalão (Catalunha), galego (Galícia) e basco (País Basco) são cooficiais com o castelhano.$q$, 2);
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:1', 3, 'tf', $q$Julgue a afirmação sobre a língua espanhola$q$, $j${"stmt":"O espanhol é língua oficial em cerca de vinte países e é uma das línguas oficiais da ONU.","a":true}$j$, $q$Verdadeiro: é a segunda língua materna mais falada do mundo, atrás só do mandarim.$q$, 1);
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:1', 4, 'bank', $q$Complete a frase sobre as capitais$q$, $j${"parts":["A capital da Argentina é "," e a capital do México é a ","."],"a":["Buenos Aires","Cidade do México"],"extra":["Madri","Lima"]}$j$, $q$Buenos Aires e Cidade do México; Madri é a capital da Espanha e Lima, a do Peru.$q$, 1);
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:1', 5, 'match', $q$Associe o país à sua capital$q$, $j${"pairs":[["Espanha","Madri"],["Peru","Lima"],["Colômbia","Bogotá"],["Chile","Santiago"]]}$j$, $q$Quatro capitais do mundo hispânico.$q$, 1);

-- esp:mundo:2 · Voseo e variações
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:2', 0, 'mc', $q$Na Argentina e no Uruguai, "vos tenés" corresponde, no espanhol padrão, a:$q$, $j${"opts":["usted tiene","tú tienes","vosotros tenéis","ellos tienen"],"a":1}$j$, $q$O voseo usa vos no lugar de tú, com formas verbais próprias: vos tenés, vos sos, vos querés.$q$, 2);
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:2', 1, 'mc', $q$A palavra para "ônibus" varia: na Espanha é "autobús"; em Cuba, "guagua"; na Argentina, é comum dizer:$q$, $j${"opts":["camión","colectivo","carro","tren"],"a":1}$j$, $q$Colectivo é o ônibus na Argentina; camión é como se diz no México.$q$, 2);
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:2', 2, 'mc', $q$"Vosotros" é a forma de tratamento usada principalmente:$q$, $j${"opts":["Em todo o México","Na Argentina, no lugar de tú","Na Espanha, para \"vocês\" informal","Só na linguagem escrita"],"a":2}$j$, $q$Vosotros é típico da Espanha; na América usa-se ustedes para vocês.$q$, 2);
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:2', 3, 'tf', $q$Julgue a afirmação sobre o tratamento$q$, $j${"stmt":"Na maior parte da América hispânica, \"ustedes\" é usado tanto em situações formais quanto informais, no lugar de \"vosotros\".","a":true}$j$, $q$Verdadeiro: vosotros praticamente não existe na fala americana.$q$, 1);
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:2', 4, 'bank', $q$Complete a frase sobre o vocabulário$q$, $j${"parts":["Na Espanha, \"coche\" é ","; na América, muitos dizem \"carro\" ou \"","\"."],"a":["carro","auto"],"extra":["casa","tren"]}$j$, $q$Coche, carro e auto são a mesma coisa em regiões diferentes.$q$, 1);
select public.fj_seed_q('esp', 'esp:mundo', 'esp:mundo:2', 5, 'match', $q$Associe a palavra regional ao seu significado$q$, $j${"pairs":[["guagua (Cuba)","ônibus"],["pibe (Argentina)","menino"],["chévere (Venezuela)","legal, ótimo"],["chamba (México)","trabalho"]]}$j$, $q$O espanhol muda de país para país; o contexto ajuda a entender as palavras regionais.$q$, 3);

-- ---------------------------------------------------------------
-- esp:conectores:1 · Conectores do texto
-- ---------------------------------------------------------------
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:1', 0, 'mc', $q$"Llovía mucho; por lo tanto, cancelaron el partido." A expressão "por lo tanto" indica:$q$, $j${"opts":["Oposição","Conclusão","Adição","Tempo"],"a":1}$j$, $q$Por lo tanto é portanto: introduz a consequência da chuva.$q$, 1);
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:1', 1, 'mc', $q$"No fui a la fiesta porque estaba enfermo." A palavra "porque" expressa:$q$, $j${"opts":["Finalidade","Condição","Causa","Contraste"],"a":2}$j$, $q$Porque introduz a causa: não fui porque estava doente.$q$, 1);
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:1', 2, 'mc', $q$Qual conector completa a frase "Quería salir, ___ empezó a llover"?$q$, $j${"opts":["además","pero","porque","entonces"],"a":1}$j$, $q$Pero (mas) marca a oposição entre a vontade de sair e a chuva.$q$, 1);
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:1', 3, 'tf', $q$Julgue a afirmação sobre o conector$q$, $j${"stmt":"\"Aunque\" em espanhol introduz uma concessão, equivalente a \"embora\" em português.","a":true}$j$, $q$Verdadeiro: aunque llueva, saldré significa embora chova, sairei.$q$, 2);
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:1', 4, 'bank', $q$Complete a frase com os conectores$q$, $j${"parts":["Quería ir a la playa, "," llovió; "," me quedé en casa."],"a":["pero","entonces"],"extra":["además","aunque"]}$j$, $q$Pero marca a oposição (queria ir, mas choveu) e entonces a consequência (então fiquei em casa).$q$, 2);
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:1', 5, 'match', $q$Associe o conector em espanhol ao seu equivalente$q$, $j${"pairs":[["sin embargo","no entanto"],["además","além disso"],["por lo tanto","portanto"],["mientras","enquanto"]]}$j$, $q$Conectores organizam o raciocínio e aparecem muito nas questões de interpretação.$q$, 2);

-- esp:conectores:2 · Pronomes e referência
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:2', 0, 'mc', $q$"María compró un libro y lo leyó en un día." O pronome "lo" refere-se a:$q$, $j${"opts":["María","el libro","un día","leyó"],"a":1}$j$, $q$Lo retoma o objeto direto masculino: el libro.$q$, 1);
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:2', 1, 'mc', $q$"Les dije la verdad a mis padres." O pronome "les" substitui:$q$, $j${"opts":["la verdad","yo","a mis padres","dije"],"a":2}$j$, $q$Les é o objeto indireto plural: a eles, a mis padres.$q$, 2);
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:2', 2, 'mc', $q$Complete a pergunta: "¿___ vives? — En Lima."$q$, $j${"opts":["Cuándo","Dónde","Quién","Cuánto"],"a":1}$j$, $q$A resposta é um lugar, então a pergunta é dónde (onde).$q$, 1);
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:2', 3, 'tf', $q$Julgue a afirmação sobre o possessivo$q$, $j${"stmt":"Em espanhol, \"su\" pode significar \"dele\", \"dela\", \"deles\" ou \"do senhor\", e o contexto define o sentido.","a":true}$j$, $q$Verdadeiro: su casa pode ser a casa dele, dela, deles ou a sua (de usted).$q$, 2);
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:2', 4, 'bank', $q$Complete com os possessivos corretos$q$, $j${"parts":["Este libro es "," (de mí) y esa mochila es "," (de ti)."],"a":["mío","tuya"],"extra":["mía","tuyo"]}$j$, $q$O possessivo concorda com a coisa possuída: libro é masculino (mío), mochila é feminino (tuya).$q$, 2);
select public.fj_seed_q('esp', 'esp:conectores', 'esp:conectores:2', 5, 'order', $q$Ordene as palavras para formar a frase "Se lo di a ella ayer" (eu o dei a ela ontem)$q$, $j${"items":["Se","lo","di","a ella","ayer"]}$j$, $q$Quando há dois pronomes, le vira se antes de lo: se lo di.$q$, 3);

-- Função auxiliar não é mais necessária
drop function if exists public.fj_seed_q(text, text, text, int, text, text, jsonb, text, int);
