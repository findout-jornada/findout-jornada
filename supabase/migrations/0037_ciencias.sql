-- =====================================================================
-- Findout Jornada · Migration 0037 · Matéria Ciências (4 seções, 8 unidades, 16 lições, 96 questões)
-- Rodar no SQL Editor do Supabase depois da 0036. Idempotente: pode rodar de novo.
-- Depois de rodar, abra o painel: ele publica a nova versão sozinho.
-- Ciências fica FORA do Mapa do ENEM (aparece só em "Suas matérias"), como matéria
-- do ensino fundamental: a lista fora do mapa é a constante FORA_DO_MAPA em app/index.html.
-- Regra do seed: o id da questão vem de md5(lição + enunciado); por isso cada enunciado é único dentro da lição.
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
('cie', 'Ciências', 'CI', '#3B7DD8', true, 15)
on conflict (id) do nothing;

insert into public.secoes (id, materia_id, titulo, ordem) values
(md5('sec:cie:vida')::uuid, 'cie', 'Vida e corpo humano', 0),
(md5('sec:cie:materia')::uuid, 'cie', 'Matéria e energia', 1),
(md5('sec:cie:terra')::uuid, 'cie', 'Terra e universo', 2),
(md5('sec:cie:ambiente')::uuid, 'cie', 'Ambiente e saúde', 3)
on conflict (id) do nothing;

insert into public.unidades (id, secao_id, titulo, ordem) values
(md5('uni:cie:celula')::uuid, md5('sec:cie:vida')::uuid, 'Células e seres vivos', 0),
(md5('uni:cie:corpo')::uuid, md5('sec:cie:vida')::uuid, 'Corpo humano', 1),
(md5('uni:cie:materia')::uuid, md5('sec:cie:materia')::uuid, 'Matéria e transformações', 0),
(md5('uni:cie:energia')::uuid, md5('sec:cie:materia')::uuid, 'Energia', 1),
(md5('uni:cie:terra')::uuid, md5('sec:cie:terra')::uuid, 'Planeta Terra', 0),
(md5('uni:cie:universo')::uuid, md5('sec:cie:terra')::uuid, 'Sistema Solar', 1),
(md5('uni:cie:eco')::uuid, md5('sec:cie:ambiente')::uuid, 'Ecologia', 0),
(md5('uni:cie:saude')::uuid, md5('sec:cie:ambiente')::uuid, 'Saúde', 1)
on conflict (id) do nothing;

insert into public.licoes (id, unidade_id, titulo, descricao, ordem) values
(md5('lic:cie:celula:1')::uuid, md5('uni:cie:celula')::uuid, 'A célula', 'A menor unidade da vida e suas organelas.', 0),
(md5('lic:cie:celula:2')::uuid, md5('uni:cie:celula')::uuid, 'Classificação dos seres vivos', 'Produtores, consumidores, vertebrados e invertebrados.', 1),
(md5('lic:cie:corpo:1')::uuid, md5('uni:cie:corpo')::uuid, 'Digestão e respiração', 'O caminho do alimento e do ar.', 0),
(md5('lic:cie:corpo:2')::uuid, md5('uni:cie:corpo')::uuid, 'Circulação e sistema nervoso', 'Coração, sangue, cérebro e neurônios.', 1),
(md5('lic:cie:materia:1')::uuid, md5('uni:cie:materia')::uuid, 'Estados físicos da matéria', 'Sólido, líquido, gasoso e as mudanças de estado.', 0),
(md5('lic:cie:materia:2')::uuid, md5('uni:cie:materia')::uuid, 'Misturas e transformações', 'Homogêneas, heterogêneas e separação de misturas.', 1),
(md5('lic:cie:energia:1')::uuid, md5('uni:cie:energia')::uuid, 'Formas de energia', 'Cinética, química, renováveis e não renováveis.', 0),
(md5('lic:cie:energia:2')::uuid, md5('uni:cie:energia')::uuid, 'Eletricidade no dia a dia', 'Circuitos, condutores e segurança.', 1),
(md5('lic:cie:terra:1')::uuid, md5('uni:cie:terra')::uuid, 'Camadas e rochas', 'Crosta, manto, núcleo e os tipos de rocha.', 0),
(md5('lic:cie:terra:2')::uuid, md5('uni:cie:terra')::uuid, 'Água e atmosfera', 'O ciclo da água e os gases do ar.', 1),
(md5('lic:cie:universo:1')::uuid, md5('uni:cie:universo')::uuid, 'Sol, planetas e Lua', 'O Sistema Solar e seus corpos.', 0),
(md5('lic:cie:universo:2')::uuid, md5('uni:cie:universo')::uuid, 'Movimentos da Terra', 'Rotação, translação e estações do ano.', 1),
(md5('lic:cie:eco:1')::uuid, md5('uni:cie:eco')::uuid, 'Cadeias alimentares', 'Produtores, consumidores e decompositores no ecossistema.', 0),
(md5('lic:cie:eco:2')::uuid, md5('uni:cie:eco')::uuid, 'Impactos ambientais', 'Efeito estufa, desmatamento e poluição.', 1),
(md5('lic:cie:saude:1')::uuid, md5('uni:cie:saude')::uuid, 'Alimentação e hábitos saudáveis', 'Nutrientes e vida saudável.', 0),
(md5('lic:cie:saude:2')::uuid, md5('uni:cie:saude')::uuid, 'Vacinas e prevenção', 'Como o corpo se defende e como ajudá-lo.', 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- cie:celula:1 · A célula
-- ---------------------------------------------------------------
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:1', 0, 'mc', $q$A menor unidade estrutural e funcional dos seres vivos é:$q$, $j${"opts":["A célula","O órgão","O tecido","O organismo"],"a":0}$j$, $q$Tudo que é vivo é feito de células: célula → tecido → órgão → sistema → organismo.$q$, 1);
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:1', 1, 'mc', $q$A organela responsável por produzir a maior parte da energia da célula é:$q$, $j${"opts":["A mitocôndria","O núcleo","A parede celular","O vacúolo"],"a":0}$j$, $q$A mitocôndria faz a respiração celular, liberando a energia dos nutrientes.$q$, 2);
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:1', 2, 'mc', $q$Uma diferença da célula vegetal em relação à animal é que a vegetal tem:$q$, $j${"opts":["Parede celular e cloroplastos","Núcleo","Membrana plasmática","Citoplasma"],"a":0}$j$, $q$A parede celular dá rigidez e os cloroplastos fazem a fotossíntese — exclusividades da célula vegetal.$q$, 2);
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:1', 3, 'tf', $q$Julgue a afirmação sobre o núcleo$q$, $j${"stmt":"O núcleo guarda o material genético (DNA) e comanda as atividades da célula.","a":true}$j$, $q$Verdadeiro: o núcleo é o centro de controle, onde fica o DNA.$q$, 1);
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:1', 4, 'bank', $q$Complete a frase sobre as partes da célula$q$, $j${"parts":["A célula é envolvida pela "," plasmática; o interior gelatinoso onde ficam as organelas é o ","."],"a":["membrana","citoplasma"],"extra":["casca","esqueleto"]}$j$, $q$Membrana: controla o que entra e sai. Citoplasma: onde as organelas trabalham.$q$, 1);
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:1', 5, 'order', $q$Ordene os níveis de organização do corpo, do menor para o maior$q$, $j${"items":["Célula","Tecido","Órgão","Sistema"]}$j$, $q$Células formam tecidos; tecidos formam órgãos; órgãos formam sistemas.$q$, 1);

-- cie:celula:2 · Classificação dos seres vivos
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:2', 0, 'mc', $q$Os seres vivos que produzem o próprio alimento pela fotossíntese são chamados de:$q$, $j${"opts":["Produtores, como as plantas","Consumidores","Decompositores","Predadores"],"a":0}$j$, $q$Plantas e algas usam a luz do Sol para produzir alimento: são a base das cadeias alimentares.$q$, 1);
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:2', 1, 'mc', $q$Fungos e bactérias que decompõem restos de seres vivos e devolvem nutrientes ao solo são:$q$, $j${"opts":["Decompositores","Produtores","Carnívoros","Polinizadores"],"a":0}$j$, $q$Os decompositores reciclam a matéria orgânica: sem eles, os nutrientes não voltariam ao solo.$q$, 1);
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:2', 2, 'mc', $q$Animais vertebrados são os que possuem:$q$, $j${"opts":["Coluna vertebral, como peixes, aves e mamíferos","Concha","Asas","Oito patas"],"a":0}$j$, $q$Vertebrados têm esqueleto interno com coluna: peixes, anfíbios, répteis, aves e mamíferos.$q$, 1);
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:2', 3, 'tf', $q$Julgue a afirmação sobre a baleia$q$, $j${"stmt":"A baleia é um peixe, porque vive na água.","a":false}$j$, $q$Falso: a baleia é mamífero — respira por pulmões, tem sangue quente e amamenta os filhotes.$q$, 1);
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:2', 4, 'bank', $q$Complete a frase sobre os grupos de animais$q$, $j${"parts":["Os "," são animais de pele seca com escamas, como cobras e lagartos; os "," têm pele úmida e vivem parte da vida na água, como sapos e rãs."],"a":["répteis","anfíbios"],"extra":["mamíferos","insetos"]}$j$, $q$Répteis rastejam em pele seca; anfíbios (anfi = dupla vida) vivem entre a água e a terra.$q$, 2);
select public.fj_seed_q('cie', 'cie:celula', 'cie:celula:2', 5, 'match', $q$Associe o grupo de animais à sua característica$q$, $j${"pairs":[["Mamíferos","Mamam quando filhotes"],["Aves","Penas e bico"],["Peixes","Brânquias para respirar na água"],["Insetos","Seis patas e corpo em três partes"]]}$j$, $q$Cada grupo tem características que ajudam a classificá-lo.$q$, 1);

-- ---------------------------------------------------------------
-- cie:corpo:1 · Digestão e respiração
-- ---------------------------------------------------------------
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:1', 0, 'mc', $q$A digestão começa:$q$, $j${"opts":["Na boca, com a mastigação e a saliva","No estômago","No intestino grosso","No coração"],"a":0}$j$, $q$Mastigar tritura o alimento e a saliva já inicia a digestão do amido.$q$, 1);
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:1', 1, 'mc', $q$O órgão em que a maior parte dos nutrientes é absorvida é:$q$, $j${"opts":["O intestino delgado","O estômago","O esôfago","O pulmão"],"a":0}$j$, $q$No intestino delgado, as vilosidades absorvem os nutrientes para o sangue.$q$, 2);
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:1', 2, 'mc', $q$Nos pulmões, o sangue:$q$, $j${"opts":["Recebe oxigênio e libera gás carbônico","Recebe gás carbônico e libera oxigênio","É produzido","É filtrado para virar urina"],"a":0}$j$, $q$Nos alvéolos acontece a troca: entra oxigênio no sangue, sai gás carbônico.$q$, 2);
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:1', 3, 'tf', $q$Julgue a afirmação sobre o diafragma$q$, $j${"stmt":"O diafragma é um músculo que participa da respiração: quando ele se contrai, o ar entra nos pulmões.","a":true}$j$, $q$Verdadeiro: o diafragma desce, o tórax aumenta e o ar entra (inspiração).$q$, 2);
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:1', 4, 'bank', $q$Complete a frase sobre o caminho do ar$q$, $j${"parts":["O ar entra pelo nariz, passa pela "," e pelos brônquios até chegar aos "," dos pulmões, onde ocorre a troca de gases."],"a":["traqueia","alvéolos"],"extra":["aorta","neurônios"]}$j$, $q$Nariz → faringe → laringe → traqueia → brônquios → alvéolos.$q$, 2);
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:1', 5, 'order', $q$Ordene o caminho do alimento no corpo$q$, $j${"items":["Boca","Esôfago","Estômago","Intestinos"]}$j$, $q$Da boca ao intestino: mastigação, transporte, digestão e absorção.$q$, 1);

-- cie:corpo:2 · Circulação e sistema nervoso
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:2', 0, 'mc', $q$O órgão que bombeia o sangue para todo o corpo é:$q$, $j${"opts":["O coração","O fígado","O pulmão","O rim"],"a":0}$j$, $q$O coração é uma bomba dupla: manda sangue para os pulmões e para o resto do corpo.$q$, 1);
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:2', 1, 'mc', $q$Os vasos que levam o sangue do coração para o corpo são:$q$, $j${"opts":["As artérias","As veias","Os alvéolos","Os neurônios"],"a":0}$j$, $q$Artérias saem do coração; veias voltam para ele; capilares fazem as trocas nos tecidos.$q$, 2);
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:2', 2, 'mc', $q$O órgão que comanda o corpo, recebendo informações dos sentidos e enviando ordens, é:$q$, $j${"opts":["O cérebro","O estômago","O pâncreas","O baço"],"a":0}$j$, $q$O cérebro processa as informações e comanda movimentos, memória e emoções.$q$, 1);
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:2', 3, 'tf', $q$Julgue a afirmação sobre os neurônios$q$, $j${"stmt":"Os neurônios são as células do sistema nervoso e transmitem informações na forma de impulsos elétricos.","a":true}$j$, $q$Verdadeiro: bilhões de neurônios se comunicam por sinapses, em impulsos elétricos e químicos.$q$, 2);
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:2', 4, 'bank', $q$Complete a frase sobre o sangue$q$, $j${"parts":["Os glóbulos "," transportam o oxigênio no sangue; os glóbulos "," defendem o corpo contra invasores."],"a":["vermelhos","brancos"],"extra":["azuis","dourados"]}$j$, $q$Glóbulos vermelhos (hemácias) carregam oxigênio; os brancos são a defesa; as plaquetas ajudam na coagulação.$q$, 1);
select public.fj_seed_q('cie', 'cie:corpo', 'cie:corpo:2', 5, 'match', $q$Associe o órgão à sua função$q$, $j${"pairs":[["Coração","Bombeia o sangue"],["Rins","Filtram o sangue e formam a urina"],["Cérebro","Centro de comando do corpo"],["Medula espinhal","Leva mensagens entre o cérebro e o corpo"]]}$j$, $q$Cada órgão tem sua função, e todos trabalham integrados.$q$, 2);

-- ---------------------------------------------------------------
-- cie:materia:1 · Estados físicos da matéria
-- ---------------------------------------------------------------
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:1', 0, 'mc', $q$Os três estados físicos mais comuns da matéria são:$q$, $j${"opts":["Sólido, líquido e gasoso","Quente, frio e morno","Doce, salgado e azedo","Grande, médio e pequeno"],"a":0}$j$, $q$A mesma substância pode existir nos três estados: gelo, água e vapor.$q$, 1);
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:1', 1, 'mc', $q$A passagem do estado líquido para o gasoso, como a água fervendo, chama-se:$q$, $j${"opts":["Vaporização","Fusão","Solidificação","Condensação"],"a":0}$j$, $q$Vaporização: líquido vira gás — por evaporação (lenta) ou ebulição (fervura).$q$, 2);
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:1', 2, 'mc', $q$O derretimento do gelo (sólido para líquido) é a:$q$, $j${"opts":["Fusão","Sublimação","Condensação","Combustão"],"a":0}$j$, $q$Fusão é o sólido virando líquido; a da água acontece a 0 °C ao nível do mar.$q$, 1);
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:1', 3, 'tf', $q$Julgue a afirmação sobre o copo gelado$q$, $j${"stmt":"A condensação é a passagem do vapor para o líquido — é o que forma as gotinhas do lado de fora de um copo gelado.","a":true}$j$, $q$Verdadeiro: o vapor de água do ar esfria ao tocar o copo e condensa em gotinhas.$q$, 2);
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:1', 4, 'bank', $q$Complete a frase sobre os estados$q$, $j${"parts":["No estado "," as partículas estão organizadas e o objeto tem forma própria; no estado "," elas estão bem soltas e ocupam todo o recipiente."],"a":["sólido","gasoso"],"extra":["líquido","doce"]}$j$, $q$Sólido: forma própria. Líquido: forma do recipiente. Gasoso: ocupa todo o espaço.$q$, 2);
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:1', 5, 'match', $q$Associe a mudança de estado ao que acontece$q$, $j${"pairs":[["Fusão","Sólido vira líquido"],["Vaporização","Líquido vira gás"],["Condensação","Gás vira líquido"],["Solidificação","Líquido vira sólido"]]}$j$, $q$As mudanças de estado dependem de ganhar ou perder calor.$q$, 2);

-- cie:materia:2 · Misturas e transformações
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:2', 0, 'mc', $q$Água com sal totalmente dissolvido é um exemplo de mistura:$q$, $j${"opts":["Homogênea","Heterogênea","Gasosa","Impossível"],"a":0}$j$, $q$Homogênea: uma única fase visível, não dá para distinguir os componentes.$q$, 2);
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:2', 1, 'mc', $q$Água e óleo formam uma mistura:$q$, $j${"opts":["Heterogênea, com fases visíveis","Homogênea","Química","Radioativa"],"a":0}$j$, $q$O óleo não se dissolve na água: ficam duas fases separadas, uma sobre a outra.$q$, 1);
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:2', 2, 'mc', $q$Qual é um exemplo de transformação química?$q$, $j${"opts":["O prego enferrujando","O gelo derretendo","A água evaporando","O vidro quebrando"],"a":0}$j$, $q$A ferrugem é uma substância nova (óxido de ferro); derreter, evaporar e quebrar só mudam o estado ou a forma.$q$, 2);
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:2', 3, 'tf', $q$Julgue a afirmação sobre as transformações$q$, $j${"stmt":"Na transformação física não surgem novas substâncias; na química, sim — como na queima do papel, que vira cinzas e fumaça.","a":true}$j$, $q$Verdadeiro: queimar transforma as substâncias; amassar ou rasgar, não.$q$, 2);
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:2', 4, 'bank', $q$Complete a frase sobre a separação de misturas$q$, $j${"parts":["Para separar a areia da água usamos a ","; para recuperar o sal dissolvido na água usamos a ","."],"a":["filtração","evaporação"],"extra":["imantação","pintura"]}$j$, $q$Filtro retém o que não se dissolveu; evaporando a água, o sal fica no fundo — como nas salinas.$q$, 2);
select public.fj_seed_q('cie', 'cie:materia', 'cie:materia:2', 5, 'match', $q$Associe o método de separação ao seu uso$q$, $j${"pairs":[["Filtração","Separa sólido não dissolvido do líquido"],["Evaporação","Recupera o sal da água"],["Imantação","Separa materiais com ferro"],["Decantação","Separa líquidos que não se misturam"]]}$j$, $q$Cada mistura pede um método: filtrar, evaporar, usar ímã ou deixar decantar.$q$, 3);

-- ---------------------------------------------------------------
-- cie:energia:1 · Formas de energia
-- ---------------------------------------------------------------
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:1', 0, 'mc', $q$A energia associada ao movimento é chamada de:$q$, $j${"opts":["Cinética","Nuclear","Sonora","Luminosa"],"a":0}$j$, $q$Tudo que se move tem energia cinética — quanto mais rápido e pesado, mais energia.$q$, 2);
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:1', 1, 'mc', $q$As plantas transformam a energia luminosa do Sol em energia química por meio da:$q$, $j${"opts":["Fotossíntese","Respiração","Digestão","Combustão"],"a":0}$j$, $q$Na fotossíntese, luz + água + gás carbônico viram alimento (glicose) e oxigênio.$q$, 1);
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:1', 2, 'mc', $q$São fontes renováveis de energia:$q$, $j${"opts":["Sol, vento e água","Petróleo, carvão e gás natural","Gasolina e diesel","Pilhas descartáveis"],"a":0}$j$, $q$Renováveis se recompõem na natureza; os combustíveis fósseis demoram milhões de anos para se formar.$q$, 1);
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:1', 3, 'tf', $q$Julgue a afirmação sobre a energia$q$, $j${"stmt":"A energia não é criada nem destruída: ela se transforma de uma forma em outra.","a":true}$j$, $q$Verdadeiro: é o princípio da conservação da energia — a elétrica vira luz, calor e movimento, por exemplo.$q$, 2);
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:1', 4, 'bank', $q$Complete a frase sobre as usinas$q$, $j${"parts":["A usina "," usa a força da água dos rios para gerar eletricidade; a usina "," usa a força do vento."],"a":["hidrelétrica","eólica"],"extra":["nuclear","térmica"]}$j$, $q$O Brasil gera a maior parte da sua eletricidade em hidrelétricas; a energia eólica cresce no Nordeste.$q$, 1);
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:1', 5, 'match', $q$Associe a fonte de energia à sua origem$q$, $j${"pairs":[["Energia solar","Painéis que captam a luz do Sol"],["Energia eólica","Força do vento"],["Hidrelétrica","Força da água"],["Combustíveis fósseis","Petróleo, carvão e gás"]]}$j$, $q$Quanto mais renovável a fonte, menor o impacto no clima.$q$, 1);

-- cie:energia:2 · Eletricidade no dia a dia
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:2', 0, 'mc', $q$Para uma lâmpada acender, a corrente elétrica precisa percorrer um:$q$, $j${"opts":["Circuito fechado","Circuito aberto","Cano de água","Espelho"],"a":0}$j$, $q$O interruptor fecha o circuito e a corrente circula; aberto, a corrente para.$q$, 2);
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:2', 1, 'mc', $q$São bons condutores de eletricidade:$q$, $j${"opts":["Metais, como o cobre dos fios","Borracha e plástico","Madeira seca","Vidro"],"a":0}$j$, $q$Metais conduzem bem; por isso os fios são de cobre, encapados com plástico isolante.$q$, 2);
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:2', 2, 'mc', $q$Qual atitude economiza energia elétrica?$q$, $j${"opts":["Apagar a luz ao sair do ambiente","Deixar a TV ligada o dia todo","Abrir a geladeira várias vezes à toa","Tomar banhos bem demorados no chuveiro elétrico"],"a":0}$j$, $q$Luz apagada, banho curto e geladeira bem fechada: economia na conta e no planeta.$q$, 1);
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:2', 3, 'tf', $q$Julgue a afirmação sobre a segurança$q$, $j${"stmt":"É seguro mexer em tomadas e aparelhos ligados com as mãos molhadas.","a":false}$j$, $q$Falso: a água facilita a passagem da corrente pelo corpo e aumenta muito o risco de choque.$q$, 1);
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:2', 4, 'bank', $q$Complete a frase sobre os materiais$q$, $j${"parts":["Os materiais que deixam a corrente passar são ","; os que bloqueiam a corrente, como a borracha, são ","."],"a":["condutores","isolantes"],"extra":["imãs","transparentes"]}$j$, $q$Condutores levam a corrente; isolantes protegem — por isso o encapamento dos fios.$q$, 1);
select public.fj_seed_q('cie', 'cie:energia', 'cie:energia:2', 5, 'order', $q$Ordene o caminho da energia elétrica até a sua casa$q$, $j${"items":["Geração na usina","Transmissão em linhas de alta tensão","Distribuição pelos postes da cidade","Uso nos aparelhos da casa"]}$j$, $q$Da usina à tomada: geração, transmissão, distribuição e consumo.$q$, 2);

-- ---------------------------------------------------------------
-- cie:terra:1 · Camadas e rochas
-- ---------------------------------------------------------------
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:1', 0, 'mc', $q$As três grandes camadas da Terra são:$q$, $j${"opts":["Crosta, manto e núcleo","Céu, mar e terra","Casca, polpa e semente","Norte, Sul e Equador"],"a":0}$j$, $q$Crosta (onde vivemos), manto (rochas pastosas) e núcleo (metais em alta temperatura).$q$, 1);
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:1', 1, 'mc', $q$As rochas formadas pelo resfriamento do magma, como o basalto e o granito, são:$q$, $j${"opts":["Magmáticas","Sedimentares","Metamórficas","Artificiais"],"a":0}$j$, $q$Magmáticas (ou ígneas): nascem do magma resfriado, dentro ou fora da crosta.$q$, 2);
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:1', 2, 'mc', $q$Terremotos e vulcões estão relacionados principalmente:$q$, $j${"opts":["Ao movimento das placas tectônicas","À força dos ventos","Às marés","À poluição"],"a":0}$j$, $q$A crosta é dividida em placas que se movem; nos encontros delas acontecem terremotos e vulcões.$q$, 2);
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:1', 3, 'tf', $q$Julgue a afirmação sobre o solo$q$, $j${"stmt":"O solo se forma lentamente pela decomposição das rochas e de restos de seres vivos.","a":true}$j$, $q$Verdadeiro: intemperismo quebra as rochas e a matéria orgânica completa o solo — um processo de milhares de anos.$q$, 2);
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:1', 4, 'bank', $q$Complete a frase sobre as camadas$q$, $j${"parts":["A camada mais externa e fina da Terra é a ","; no centro do planeta fica o ",", onde as temperaturas são altíssimas."],"a":["crosta","núcleo"],"extra":["atmosfera","polo"]}$j$, $q$Da crosta ao núcleo são cerca de 6.370 km — e só conseguimos perfurar alguns quilômetros.$q$, 1);
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:1', 5, 'match', $q$Associe o tipo de rocha (e um extra) à sua origem$q$, $j${"pairs":[["Magmática","Formada do magma resfriado"],["Sedimentar","Formada por camadas de sedimentos"],["Metamórfica","Transformada por calor e pressão"],["Fóssil","Resto de ser vivo antigo preservado na rocha"]]}$j$, $q$As rochas sedimentares são as que guardam fósseis.$q$, 3);

-- cie:terra:2 · Água e atmosfera
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:2', 0, 'mc', $q$A maior parte da água do planeta é:$q$, $j${"opts":["Salgada, nos mares e oceanos","Doce, nos rios","Potável, nas torneiras","Congelada nos desertos"],"a":0}$j$, $q$Cerca de 97% da água da Terra é salgada; da doce, a maior parte está congelada ou no subsolo.$q$, 1);
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:2', 1, 'mc', $q$No ciclo da água, a chuva se forma quando o vapor:$q$, $j${"opts":["Se condensa nas nuvens e cai","Evapora dos oceanos","Infiltra no solo","Escorre pelos rios"],"a":0}$j$, $q$O vapor sobe, esfria, condensa em gotículas (nuvens) e cai como precipitação.$q$, 2);
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:2', 2, 'mc', $q$O gás da atmosfera essencial para a nossa respiração é:$q$, $j${"opts":["O oxigênio","O hélio","O gás carbônico","O neônio"],"a":0}$j$, $q$O oxigênio (cerca de 21% do ar) é usado pelas células para liberar energia dos alimentos.$q$, 1);
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:2', 3, 'tf', $q$Julgue a afirmação sobre o ar$q$, $j${"stmt":"O nitrogênio é o gás mais abundante do ar, representando cerca de 78% da atmosfera.","a":true}$j$, $q$Verdadeiro: o ar é principalmente nitrogênio (78%) e oxigênio (21%), mais outros gases.$q$, 3);
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:2', 4, 'bank', $q$Complete a frase sobre o ciclo da água$q$, $j${"parts":["No ciclo da água, a "," transforma a água líquida em vapor; a "," é a queda da água das nuvens em forma de chuva, granizo ou neve."],"a":["evaporação","precipitação"],"extra":["fusão","fotossíntese"]}$j$, $q$Evaporação sobe, condensação forma nuvens, precipitação desce: o ciclo não para.$q$, 2);
select public.fj_seed_q('cie', 'cie:terra', 'cie:terra:2', 5, 'order', $q$Ordene as etapas do ciclo da água$q$, $j${"items":["Evaporação da água dos mares e rios","Condensação do vapor nas nuvens","Precipitação, a chuva","Infiltração e retorno aos rios e mares"]}$j$, $q$O Sol move o ciclo: evapora, condensa, chove e a água volta a correr.$q$, 2);

-- ---------------------------------------------------------------
-- cie:universo:1 · Sol, planetas e Lua
-- ---------------------------------------------------------------
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:1', 0, 'mc', $q$O Sol é:$q$, $j${"opts":["Uma estrela","Um planeta","Um cometa","Um satélite"],"a":0}$j$, $q$O Sol é a estrela do nosso sistema: produz luz e calor por fusão nuclear.$q$, 1);
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:1', 1, 'mc', $q$A Lua é o satélite natural da Terra e o seu brilho vem:$q$, $j${"opts":["Da luz do Sol refletida","De luz própria","Das luzes das cidades","Dos relâmpagos"],"a":0}$j$, $q$A Lua não tem luz própria: vemos a parte iluminada pelo Sol — daí as fases.$q$, 1);
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:1', 2, 'mc', $q$Quantos planetas tem o Sistema Solar e qual é o mais próximo do Sol?$q$, $j${"opts":["Oito; Mercúrio","Nove; Plutão","Sete; Vênus","Dez; Marte"],"a":0}$j$, $q$Mercúrio, Vênus, Terra, Marte, Júpiter, Saturno, Urano e Netuno: oito planetas.$q$, 2);
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:1', 3, 'tf', $q$Julgue a afirmação sobre Plutão$q$, $j${"stmt":"Plutão deixou de ser classificado como planeta em 2006 e hoje é considerado um planeta-anão.","a":true}$j$, $q$Verdadeiro: pela definição da União Astronômica Internacional, Plutão virou planeta-anão.$q$, 2);
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:1', 4, 'bank', $q$Complete a frase sobre o movimento dos planetas$q$, $j${"parts":["Os planetas giram em torno do Sol em trajetórias chamadas ","; a força que os mantém nesse caminho é a ","."],"a":["órbitas","gravidade"],"extra":["marés","fotossíntese"]}$j$, $q$A gravidade do Sol segura os planetas em órbita; a da Terra segura a Lua (e nós).$q$, 2);
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:1', 5, 'match', $q$Associe o corpo celeste à sua definição$q$, $j${"pairs":[["Estrela","Tem luz própria, como o Sol"],["Planeta","Gira em torno de uma estrela"],["Satélite natural","Gira em torno de um planeta, como a Lua"],["Cometa","Corpo de gelo e poeira com cauda luminosa"]]}$j$, $q$Estrelas brilham, planetas refletem, satélites acompanham e cometas visitam.$q$, 2);

-- cie:universo:2 · Movimentos da Terra
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:2', 0, 'mc', $q$O movimento da Terra girando em torno do próprio eixo, que causa o dia e a noite, é a:$q$, $j${"opts":["Rotação","Translação","Gravitação","Levitação"],"a":0}$j$, $q$A rotação dura cerca de 24 horas: o lado voltado para o Sol tem dia; o oposto, noite.$q$, 1);
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:2', 1, 'mc', $q$A translação é o movimento da Terra em torno do Sol e dura aproximadamente:$q$, $j${"opts":["365 dias","24 horas","30 dias","7 dias"],"a":0}$j$, $q$Uma volta completa em torno do Sol leva um ano (365 dias e algumas horas — daí o ano bissexto).$q$, 1);
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:2', 2, 'mc', $q$As estações do ano existem principalmente por causa:$q$, $j${"opts":["Da inclinação do eixo da Terra combinada com a translação","Da distância fixa ao Sol","Do movimento da Lua","Dos ventos"],"a":0}$j$, $q$O eixo inclinado (23,5°) faz cada hemisfério receber mais ou menos luz ao longo do ano.$q$, 3);
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:2', 3, 'tf', $q$Julgue a afirmação sobre os hemisférios$q$, $j${"stmt":"Quando é verão no hemisfério sul, é inverno no hemisfério norte.","a":true}$j$, $q$Verdadeiro: as estações são opostas nos dois hemisférios, por causa da inclinação do eixo.$q$, 1);
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:2', 4, 'bank', $q$Complete a frase sobre os dois movimentos$q$, $j${"parts":["A "," dura cerca de 24 horas e causa o dia e a noite; a "," dura um ano e, com a inclinação do eixo, causa as estações."],"a":["rotação","translação"],"extra":["maré","chuva"]}$j$, $q$Rotação: gira em si. Translação: gira em torno do Sol.$q$, 2);
select public.fj_seed_q('cie', 'cie:universo', 'cie:universo:2', 5, 'match', $q$Associe o fenômeno à sua causa ou definição$q$, $j${"pairs":[["Rotação","Dia e noite"],["Translação","Ano e estações"],["Fases da Lua","Nova, crescente, cheia e minguante"],["Eclipse solar","A Lua fica entre o Sol e a Terra"]]}$j$, $q$Movimentos e alinhamentos explicam o dia, o ano, as fases e os eclipses.$q$, 2);

-- ---------------------------------------------------------------
-- cie:eco:1 · Cadeias alimentares
-- ---------------------------------------------------------------
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:1', 0, 'mc', $q$Numa cadeia alimentar, a energia começa:$q$, $j${"opts":["Nos produtores, que fazem fotossíntese","Nos carnívoros","Nos decompositores","No solo"],"a":0}$j$, $q$A energia entra pela fotossíntese dos produtores e passa de um nível para o outro.$q$, 2);
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:1', 1, 'mc', $q$Na cadeia capim → gafanhoto → sapo → cobra, o sapo é:$q$, $j${"opts":["Consumidor secundário","Produtor","Consumidor primário","Decompositor"],"a":0}$j$, $q$O gafanhoto come o capim (consumidor primário); o sapo come o gafanhoto (secundário); a cobra, o sapo (terciário).$q$, 3);
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:1', 2, 'mc', $q$Ecossistema é:$q$, $j${"opts":["O conjunto dos seres vivos de um lugar e o ambiente com que interagem","Só as plantas","Só os animais","Apenas o clima"],"a":0}$j$, $q$Ecossistema = comunidade de seres vivos + fatores do ambiente (água, luz, solo, clima) interagindo.$q$, 2);
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:1', 3, 'tf', $q$Julgue a afirmação sobre o equilíbrio$q$, $j${"stmt":"Se um elo da cadeia alimentar desaparece, as outras espécies podem ser afetadas, aumentando ou diminuindo de quantidade.","a":true}$j$, $q$Verdadeiro: sem o predador, a presa explode em número; sem a presa, o predador passa fome — tudo está ligado.$q$, 2);
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:1', 4, 'bank', $q$Complete a frase sobre quem come quem$q$, $j${"parts":["Os "," fabricam o próprio alimento; os "," se alimentam de outros seres vivos."],"a":["produtores","consumidores"],"extra":["minerais","fósseis"]}$j$, $q$Produtores produzem; consumidores consomem; decompositores reciclam.$q$, 1);
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:1', 5, 'order', $q$Ordene a cadeia alimentar, do produtor aos decompositores$q$, $j${"items":["Planta","Herbívoro que come a planta","Carnívoro que come o herbívoro","Decompositores que reciclam os restos"]}$j$, $q$Produtor → consumidor primário → consumidor secundário → decompositores.$q$, 2);

-- cie:eco:2 · Impactos ambientais
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:2', 0, 'mc', $q$O aumento do efeito estufa, ligado ao aquecimento global, é intensificado:$q$, $j${"opts":["Pela queima de combustíveis fósseis e pelo desmatamento","Pela fotossíntese","Pela chuva","Pelo vento"],"a":0}$j$, $q$Queimar petróleo, carvão e florestas lança gás carbônico, que retém mais calor na atmosfera.$q$, 2);
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:2', 1, 'mc', $q$O desmatamento pode causar:$q$, $j${"opts":["Perda de biodiversidade, erosão do solo e mudanças na chuva","Mais nascentes de água","Solo mais fértil para sempre","Aumento dos animais silvestres"],"a":0}$j$, $q$Sem a floresta, espécies perdem habitat, o solo fica exposto à erosão e o ciclo da chuva muda.$q$, 2);
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:2', 2, 'mc', $q$Jogar esgoto sem tratamento nos rios provoca:$q$, $j${"opts":["Poluição da água e morte dos peixes","Água mais limpa","Mais oxigênio na água","Nenhum efeito"],"a":0}$j$, $q$O esgoto consome o oxigênio da água e contamina quem depende dela — por isso o saneamento é vital.$q$, 1);
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:2', 3, 'tf', $q$Julgue a afirmação sobre o efeito estufa$q$, $j${"stmt":"O efeito estufa é totalmente ruim e deveria ser eliminado.","a":false}$j$, $q$Falso: o efeito estufa natural mantém a Terra aquecida e possibilita a vida; o problema é a sua intensificação pelas atividades humanas.$q$, 3);
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:2', 4, 'bank', $q$Complete a frase sobre a proteção da natureza$q$, $j${"parts":["Áreas protegidas, como os parques nacionais, são unidades de ","; replantar árvores nativas em áreas desmatadas é o ","."],"a":["conservação","reflorestamento"],"extra":["lazer","desmatamento"]}$j$, $q$Unidades de conservação protegem ecossistemas; o reflorestamento ajuda a recuperar o que foi perdido.$q$, 2);
select public.fj_seed_q('cie', 'cie:eco', 'cie:eco:2', 5, 'match', $q$Associe a ação ao seu efeito positivo$q$, $j${"pairs":[["Reciclagem","Transforma o lixo em novos produtos"],["Coleta seletiva","Separa o lixo por tipo"],["Reflorestamento","Replantio de árvores"],["Saneamento básico","Água tratada e esgoto coletado"]]}$j$, $q$Pequenas e grandes ações que reduzem o impacto humano no ambiente.$q$, 1);

-- ---------------------------------------------------------------
-- cie:saude:1 · Alimentação e hábitos saudáveis
-- ---------------------------------------------------------------
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:1', 0, 'mc', $q$Uma alimentação saudável deve priorizar:$q$, $j${"opts":["Alimentos naturais e variados, como frutas, legumes e grãos","Só ultraprocessados","Apenas doces","Somente refrigerante"],"a":0}$j$, $q$Comida de verdade e variada: quanto menos processado, melhor — regra do Guia Alimentar brasileiro.$q$, 1);
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:1', 1, 'mc', $q$Os carboidratos, como arroz, pão e massas, têm a função principal de:$q$, $j${"opts":["Fornecer energia","Construir músculos","Transportar oxigênio","Combater infecções"],"a":0}$j$, $q$Carboidrato é o combustível do corpo: vira glicose, a energia das células.$q$, 2);
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:1', 2, 'mc', $q$As proteínas, presentes em carnes, ovos e feijão, servem principalmente para:$q$, $j${"opts":["Construir e reparar os tecidos do corpo","Dar sabor doce","Hidratar","Iluminar"],"a":0}$j$, $q$Proteínas são os tijolos do corpo: músculos, pele, cabelos e defesas.$q$, 2);
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:1', 3, 'tf', $q$Julgue a afirmação sobre os hábitos$q$, $j${"stmt":"Beber água, dormir bem e praticar atividade física regularmente fazem parte de uma vida saudável.","a":true}$j$, $q$Verdadeiro: alimentação, sono, hidratação e movimento são os pilares da saúde.$q$, 1);
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:1', 4, 'bank', $q$Complete a frase sobre vitaminas e minerais$q$, $j${"parts":["As "," e os minerais, presentes em frutas e verduras, regulam o funcionamento do corpo; a falta de vitamina C, por exemplo, pode causar ","."],"a":["vitaminas","escorbuto"],"extra":["gorduras","cárie"]}$j$, $q$Vitaminas e minerais são reguladores; a carência de vitamina C causava escorbuto nos navegantes.$q$, 3);
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:1', 5, 'match', $q$Associe o nutriente à sua função principal$q$, $j${"pairs":[["Carboidratos","Energia"],["Proteínas","Construção do corpo"],["Vitaminas e minerais","Regulação do organismo"],["Água","Hidratação e transporte de substâncias"]]}$j$, $q$Cada grupo de nutrientes tem um papel; o equilíbrio entre eles é a dieta saudável.$q$, 2);

-- cie:saude:2 · Vacinas e prevenção
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:2', 0, 'mc', $q$As vacinas protegem porque:$q$, $j${"opts":["Ensinam o corpo a produzir defesas contra o causador da doença","Matam o mosquito da dengue","Substituem a alimentação","Curam qualquer doença na hora"],"a":0}$j$, $q$A vacina apresenta o inimigo (enfraquecido ou em pedaços) e o corpo cria anticorpos e memória de defesa.$q$, 2);
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:2', 1, 'mc', $q$Lavar as mãos com água e sabão é importante porque:$q$, $j${"opts":["Remove micro-organismos que causam doenças","Deixa as mãos perfumadas apenas","Não serve para nada","Substitui a vacina"],"a":0}$j$, $q$Mãos limpas evitam levar vírus e bactérias à boca, ao nariz e aos olhos.$q$, 1);
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:2', 2, 'mc', $q$A dengue é transmitida:$q$, $j${"opts":["Pela picada do mosquito Aedes aegypti","De pessoa para pessoa pelo ar","Por alimentos estragados","Pelo contato com animais domésticos"],"a":0}$j$, $q$O Aedes aegypti transmite dengue, zika e chikungunya; o combate é eliminar os criadouros.$q$, 1);
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:2', 3, 'tf', $q$Julgue a afirmação sobre a prevenção da dengue$q$, $j${"stmt":"Para evitar a dengue, é preciso eliminar a água parada, onde o mosquito se reproduz.","a":true}$j$, $q$Verdadeiro: pneus, vasos e calhas com água parada são berçários do mosquito.$q$, 1);
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:2', 4, 'bank', $q$Complete a frase sobre os micro-organismos$q$, $j${"parts":["Micro-organismos como vírus e "," podem causar doenças; os "," combatem infecções causadas por bactérias, mas não funcionam contra vírus."],"a":["bactérias","antibióticos"],"extra":["vitaminas","chás"]}$j$, $q$Antibiótico é remédio para bactéria; usar sem necessidade cria bactérias resistentes.$q$, 3);
select public.fj_seed_q('cie', 'cie:saude', 'cie:saude:2', 5, 'match', $q$Associe cada recurso de saúde à sua função$q$, $j${"pairs":[["Vacina","Previne doenças ensinando o corpo a se defender"],["Soro","Trata com anticorpos prontos, como em picadas de cobra"],["Antibiótico","Combate bactérias"],["Saneamento","Evita doenças transmitidas pela água"]]}$j$, $q$Prevenir (vacina, saneamento) é sempre melhor do que remediar (soro, antibiótico).$q$, 3);

-- Função auxiliar não é mais necessária
drop function if exists public.fj_seed_q(text, text, text, int, text, text, jsonb, text, int);

insert into public.schema_versao (versao) values (37) on conflict do nothing;
