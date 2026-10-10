-- =====================================================================
-- Findout Jornada · Migration 0006 · Mais matérias (108 questões)
-- Geografia, Física, Química, Redação, Inglês e Filosofia/Sociologia,
-- em estilo ENEM, com resposta e explicação. Rodar no SQL Editor depois
-- da 0005. Idempotente. Depois de rodar, abra o painel: ele publica.
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
('geo', 'Geografia', 'GE', '#8FB569', true, 4),
('fis', 'Física', 'FI', '#4A7BD9', true, 5),
('qui', 'Química', 'QU', '#E0475B', true, 6),
('red', 'Redação', 'RE', '#F08A24', true, 7),
('ing', 'Inglês', 'EN', '#010F2E', true, 8),
('fil', 'Filosofia e Sociologia', 'FS', '#8E7FCF', true, 9)
on conflict (id) do nothing;

insert into public.secoes (id, materia_id, titulo, ordem) values
(md5('sec:geo:brasil')::uuid, 'geo', 'Brasil: natureza e sociedade', 0),
(md5('sec:fis:mecanica')::uuid, 'fis', 'Mecânica', 0),
(md5('sec:fis:eletricidade')::uuid, 'fis', 'Eletricidade', 1),
(md5('sec:qui:fundamentos')::uuid, 'qui', 'Fundamentos', 0),
(md5('sec:red:enem')::uuid, 'red', 'A redação do ENEM', 0),
(md5('sec:ing:leitura')::uuid, 'ing', 'Leitura', 0),
(md5('sec:fil:pensadores')::uuid, 'fil', 'Pensadores e conceitos', 0)
on conflict (id) do nothing;

insert into public.unidades (id, secao_id, titulo, ordem) values
(md5('uni:geo:biomas')::uuid, md5('sec:geo:brasil')::uuid, 'Biomas brasileiros', 0),
(md5('uni:geo:populacao')::uuid, md5('sec:geo:brasil')::uuid, 'População e urbanização', 1),
(md5('uni:geo:cartografia')::uuid, md5('sec:geo:brasil')::uuid, 'Cartografia e clima', 2),
(md5('uni:fis:cinematica')::uuid, md5('sec:fis:mecanica')::uuid, 'Cinemática', 0),
(md5('uni:fis:dinamica')::uuid, md5('sec:fis:mecanica')::uuid, 'Dinâmica', 1),
(md5('uni:fis:circuitos')::uuid, md5('sec:fis:eletricidade')::uuid, 'Circuitos elétricos', 0),
(md5('uni:qui:atomo')::uuid, md5('sec:qui:fundamentos')::uuid, 'Matéria e átomo', 0),
(md5('uni:qui:solucoes')::uuid, md5('sec:qui:fundamentos')::uuid, 'Soluções e reações', 1),
(md5('uni:red:estrutura')::uuid, md5('sec:red:enem')::uuid, 'Estrutura e competências', 0),
(md5('uni:ing:gramatica')::uuid, md5('sec:ing:leitura')::uuid, 'Gramática essencial', 0),
(md5('uni:ing:vocabulario')::uuid, md5('sec:ing:leitura')::uuid, 'Vocabulário e leitura', 1),
(md5('uni:fil:filosofia')::uuid, md5('sec:fil:pensadores')::uuid, 'Filosofia', 0),
(md5('uni:fil:sociologia')::uuid, md5('sec:fil:pensadores')::uuid, 'Sociologia', 1)
on conflict (id) do nothing;

insert into public.licoes (id, unidade_id, titulo, descricao, ordem) values
(md5('lic:geo:biomas:1')::uuid, md5('uni:geo:biomas')::uuid, 'Amazônia e Cerrado', 'Os dois maiores biomas do país.', 0),
(md5('lic:geo:biomas:2')::uuid, md5('uni:geo:biomas')::uuid, 'Caatinga, Pampa e Mata Atlântica', 'Semiárido, campos do Sul e litoral.', 1),
(md5('lic:geo:populacao:1')::uuid, md5('uni:geo:populacao')::uuid, 'Demografia', 'Transição demográfica e envelhecimento.', 0),
(md5('lic:geo:populacao:2')::uuid, md5('uni:geo:populacao')::uuid, 'Cidades e problemas urbanos', 'Urbanização, migrações e segregação.', 1),
(md5('lic:geo:cartografia:1')::uuid, md5('uni:geo:cartografia')::uuid, 'Mapas e coordenadas', 'Escala, paralelos e meridianos.', 0),
(md5('lic:geo:cartografia:2')::uuid, md5('uni:geo:cartografia')::uuid, 'Clima do Brasil', 'Os tipos de clima e onde ocorrem.', 1),
(md5('lic:fis:cinematica:1')::uuid, md5('uni:fis:cinematica')::uuid, 'Velocidade média', 'Distância, tempo e conversão de unidades.', 0),
(md5('lic:fis:cinematica:2')::uuid, md5('uni:fis:cinematica')::uuid, 'Movimento uniforme e acelerado', 'Aceleração e queda livre.', 1),
(md5('lic:fis:dinamica:1')::uuid, md5('uni:fis:dinamica')::uuid, 'Leis de Newton', 'Inércia, F = m·a e ação e reação.', 0),
(md5('lic:fis:dinamica:2')::uuid, md5('uni:fis:dinamica')::uuid, 'Trabalho e energia', 'Energia cinética, potencial e potência.', 1),
(md5('lic:fis:circuitos:1')::uuid, md5('uni:fis:circuitos')::uuid, 'Corrente e tensão', 'Lei de Ohm e unidades.', 0),
(md5('lic:fis:circuitos:2')::uuid, md5('uni:fis:circuitos')::uuid, 'Potência e consumo', 'kWh e a conta de luz.', 1),
(md5('lic:qui:atomo:1')::uuid, md5('uni:qui:atomo')::uuid, 'Tabela periódica', 'Símbolos, grupos e número atômico.', 0),
(md5('lic:qui:atomo:2')::uuid, md5('uni:qui:atomo')::uuid, 'Ligações químicas', 'Iônica, covalente e metálica.', 1),
(md5('lic:qui:solucoes:1')::uuid, md5('uni:qui:solucoes')::uuid, 'Ácidos, bases e pH', 'A escala de pH no dia a dia.', 0),
(md5('lic:qui:solucoes:2')::uuid, md5('uni:qui:solucoes')::uuid, 'Reações e balanceamento', 'Tipos de reação e conservação da massa.', 1),
(md5('lic:red:estrutura:1')::uuid, md5('uni:red:estrutura')::uuid, 'As 5 competências', 'O que a banca avalia.', 0),
(md5('lic:red:estrutura:2')::uuid, md5('uni:red:estrutura')::uuid, 'Introdução e tese', 'Contextualizar, apresentar a tese e os argumentos.', 1),
(md5('lic:red:estrutura:3')::uuid, md5('uni:red:estrutura')::uuid, 'Proposta de intervenção', 'Agente, ação, meio, finalidade e detalhamento.', 2),
(md5('lic:ing:gramatica:1')::uuid, md5('uni:ing:gramatica')::uuid, 'Verbos e tempos', 'Simple present, simple past e present perfect.', 0),
(md5('lic:ing:gramatica:2')::uuid, md5('uni:ing:gramatica')::uuid, 'Conectivos', 'Although, however, therefore e outros.', 1),
(md5('lic:ing:vocabulario:1')::uuid, md5('uni:ing:vocabulario')::uuid, 'Falsos cognatos', 'Palavras que enganam.', 0),
(md5('lic:ing:vocabulario:2')::uuid, md5('uni:ing:vocabulario')::uuid, 'Interpretação', 'Skimming, scanning e cognatos.', 1),
(md5('lic:fil:filosofia:1')::uuid, md5('uni:fil:filosofia')::uuid, 'Antiguidade', 'Sócrates, Platão e Aristóteles.', 0),
(md5('lic:fil:filosofia:2')::uuid, md5('uni:fil:filosofia')::uuid, 'Modernos e contemporâneos', 'Descartes, Kant, Nietzsche e Sartre.', 1),
(md5('lic:fil:sociologia:1')::uuid, md5('uni:fil:sociologia')::uuid, 'Clássicos', 'Durkheim, Marx e Weber.', 0),
(md5('lic:fil:sociologia:2')::uuid, md5('uni:fil:sociologia')::uuid, 'Cultura e sociedade', 'Cultura, etnocentrismo e cidadania.', 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- GEOGRAFIA
-- ---------------------------------------------------------------
select public.fj_seed_q('geo', 'geo:biomas', 'geo:biomas:1', 0, 'mc', $q$Qual é o maior bioma do Brasil em área?$q$, $j${"opts":["Amazônia","Cerrado","Caatinga","Mata Atlântica"],"a":0}$j$, $q$A Amazônia cobre quase metade do território brasileiro.$q$, 1);
select public.fj_seed_q('geo', 'geo:biomas', 'geo:biomas:1', 1, 'mc', $q$O Cerrado é chamado de "berço das águas" porque:$q$, $j${"opts":["Nele nascem rios de várias bacias hidrográficas","Chove o ano inteiro","Tem o maior rio do mundo","É coberto por lagos"],"a":0}$j$, $q$No planalto central nascem rios das bacias do São Francisco, Paraná, Tocantins e outras.$q$, 2);
select public.fj_seed_q('geo', 'geo:biomas', 'geo:biomas:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A Amazônia é uma floresta tropical úmida com grande biodiversidade.","a":true}$j$, $q$Verdadeiro: clima equatorial, chuvas abundantes e a maior biodiversidade do planeta.$q$, 1);
select public.fj_seed_q('geo', 'geo:biomas', 'geo:biomas:1', 3, 'match', $q$Associe o bioma à sua característica$q$, $j${"pairs":[["Amazônia","Floresta tropical úmida"],["Cerrado","Savana com árvores retorcidas"],["Caatinga","Semiárido com plantas espinhosas"],["Pampa","Campos do Sul"]]}$j$, $q$Cada bioma tem vegetação e clima próprios.$q$, 1);
select public.fj_seed_q('geo', 'geo:biomas', 'geo:biomas:2', 0, 'mc', $q$Qual bioma é exclusivamente brasileiro e ocupa o semiárido nordestino?$q$, $j${"opts":["Caatinga","Cerrado","Pampa","Pantanal"],"a":0}$j$, $q$A Caatinga só existe no Brasil, com vegetação adaptada à seca.$q$, 1);
select public.fj_seed_q('geo', 'geo:biomas', 'geo:biomas:2', 1, 'mc', $q$O bioma mais devastado do Brasil, que ocupava a faixa litorânea, é:$q$, $j${"opts":["Mata Atlântica","Amazônia","Pantanal","Cerrado"],"a":0}$j$, $q$Restam cerca de 12% da Mata Atlântica original, por causa da ocupação do litoral.$q$, 2);
select public.fj_seed_q('geo', 'geo:biomas', 'geo:biomas:2', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"O Pantanal é a maior planície alagável do mundo.","a":true}$j$, $q$Verdadeiro: fica em Mato Grosso e Mato Grosso do Sul.$q$, 1);
select public.fj_seed_q('geo', 'geo:biomas', 'geo:biomas:2', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["O "," é o bioma dos campos do Rio Grande do Sul, e o "," é a planície alagável de Mato Grosso."],"a":["Pampa","Pantanal"],"extra":["Cerrado","Caatinga"]}$j$, $q$Pampa: campos do Sul. Pantanal: planície alagável do Centro-Oeste.$q$, 1);
select public.fj_seed_q('geo', 'geo:populacao', 'geo:populacao:1', 0, 'mc', $q$A transição demográfica brasileira se caracteriza por:$q$, $j${"opts":["Queda da natalidade e da mortalidade","Aumento da natalidade","Crescimento acelerado da população jovem","Redução da expectativa de vida"],"a":0}$j$, $q$Menos nascimentos e mais longevidade: a população cresce devagar e envelhece.$q$, 2);
select public.fj_seed_q('geo', 'geo:populacao', 'geo:populacao:1', 1, 'mc', $q$O envelhecimento da população brasileira exige, principalmente:$q$, $j${"opts":["Mais investimento em previdência e saúde","Mais escolas de ensino fundamental","Redução de hospitais","Mais creches"],"a":0}$j$, $q$Mais idosos significam mais aposentadorias e mais demanda por saúde.$q$, 2);
select public.fj_seed_q('geo', 'geo:populacao', 'geo:populacao:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A região mais populosa do Brasil é o Sudeste.","a":true}$j$, $q$Verdadeiro: São Paulo, Minas, Rio e Espírito Santo concentram mais de 40% dos brasileiros.$q$, 1);
select public.fj_seed_q('geo', 'geo:populacao', 'geo:populacao:1', 3, 'order', $q$Ordene as regiões da mais populosa para a menos populosa$q$, $j${"items":["Sudeste","Nordeste","Sul","Centro-Oeste"]}$j$, $q$Sudeste, Nordeste, Sul, Norte e Centro-Oeste, nessa ordem.$q$, 2);
select public.fj_seed_q('geo', 'geo:populacao', 'geo:populacao:2', 0, 'mc', $q$O crescimento desordenado das cidades, sem planejamento, gera:$q$, $j${"opts":["Favelização e falta de saneamento","Redução do trânsito","Menos poluição","Mais áreas verdes"],"a":0}$j$, $q$Sem planejamento, a cidade cresce sem infraestrutura para todos.$q$, 1);
select public.fj_seed_q('geo', 'geo:populacao', 'geo:populacao:2', 1, 'mc', $q$O deslocamento diário de pessoas entre cidades vizinhas para trabalhar ou estudar chama-se:$q$, $j${"opts":["Movimento pendular","Êxodo rural","Migração sazonal","Transumância"],"a":0}$j$, $q$Pendular: vai e volta todo dia, como um pêndulo.$q$, 2);
select public.fj_seed_q('geo', 'geo:populacao', 'geo:populacao:2', 2, 'tf', $q$Esta definição está certa?$q$, $j${"stmt":"Êxodo rural é a migração do campo para a cidade.","a":true}$j$, $q$Verdadeiro: foi intenso no Brasil entre as décadas de 1950 e 1980.$q$, 1);
select public.fj_seed_q('geo', 'geo:populacao', 'geo:populacao:2', 3, 'match', $q$Associe o conceito à definição$q$, $j${"pairs":[["Conurbação","Cidades que crescem até se unir"],["Metrópole","Cidade que comanda uma região"],["Segregação urbana","Separação de classes no espaço"],["Verticalização","Construção de prédios altos"]]}$j$, $q$Conceitos básicos da geografia urbana.$q$, 2);
select public.fj_seed_q('geo', 'geo:cartografia', 'geo:cartografia:1', 0, 'mc', $q$Em um mapa, a escala 1:1.000.000 significa que 1 cm equivale a:$q$, $j${"opts":["10 km","1 km","100 km","100 m"],"a":0}$j$, $q$1.000.000 cm = 10.000 m = 10 km.$q$, 2);
select public.fj_seed_q('geo', 'geo:cartografia', 'geo:cartografia:1', 1, 'mc', $q$As linhas imaginárias horizontais que medem a latitude são os:$q$, $j${"opts":["Paralelos","Meridianos","Fusos","Trópicos"],"a":0}$j$, $q$Paralelos medem latitude (Norte-Sul); meridianos medem longitude (Leste-Oeste).$q$, 1);
select public.fj_seed_q('geo', 'geo:cartografia', 'geo:cartografia:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"O Meridiano de Greenwich divide a Terra em hemisférios Norte e Sul.","a":false}$j$, $q$Falso: Greenwich divide em Leste e Oeste. Quem divide Norte e Sul é a linha do Equador.$q$, 2);
select public.fj_seed_q('geo', 'geo:cartografia', 'geo:cartografia:1', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["A linha do "," divide a Terra em hemisférios Norte e Sul; o meridiano de "," divide em Leste e Oeste."],"a":["Equador","Greenwich"],"extra":["Capricórnio","Câncer"]}$j$, $q$Equador: Norte/Sul. Greenwich: Leste/Oeste.$q$, 1);
select public.fj_seed_q('geo', 'geo:cartografia', 'geo:cartografia:2', 0, 'mc', $q$O clima predominante na maior parte do território brasileiro é:$q$, $j${"opts":["Tropical","Temperado","Polar","Desértico"],"a":0}$j$, $q$O Brasil fica quase todo na zona tropical.$q$, 1);
select public.fj_seed_q('geo', 'geo:cartografia', 'geo:cartografia:2', 1, 'mc', $q$O clima da região Sul do Brasil, com as quatro estações bem definidas, é:$q$, $j${"opts":["Subtropical","Equatorial","Semiárido","Tropical de altitude"],"a":0}$j$, $q$Subtropical: verões quentes, invernos frios e chuvas bem distribuídas.$q$, 1);
select public.fj_seed_q('geo', 'geo:cartografia', 'geo:cartografia:2', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"O clima semiárido do Nordeste tem chuvas escassas e irregulares.","a":true}$j$, $q$Verdadeiro: é o clima do sertão, onde ocorrem as secas.$q$, 1);
select public.fj_seed_q('geo', 'geo:cartografia', 'geo:cartografia:2', 3, 'match', $q$Associe o clima à sua característica$q$, $j${"pairs":[["Equatorial","Quente e úmido o ano todo"],["Semiárido","Chuvas escassas"],["Subtropical","Estações bem definidas"],["Tropical","Verão chuvoso e inverno seco"]]}$j$, $q$Os quatro principais climas do Brasil.$q$, 2);

-- ---------------------------------------------------------------
-- FÍSICA
-- ---------------------------------------------------------------
select public.fj_seed_q('fis', 'fis:cinematica', 'fis:cinematica:1', 0, 'mc', $q$Um ônibus percorre 180 km em 3 horas. Qual é a sua velocidade média?$q$, $j${"opts":["60 km/h","540 km/h","90 km/h","30 km/h"],"a":0}$j$, $q$180 ÷ 3 = 60 km/h.$q$, 1);
select public.fj_seed_q('fis', 'fis:cinematica', 'fis:cinematica:1', 1, 'mc', $q$Um atleta corre 100 m em 10 s. Sua velocidade média é:$q$, $j${"opts":["10 m/s","100 m/s","1 m/s","0,1 m/s"],"a":0}$j$, $q$100 ÷ 10 = 10 m/s (36 km/h).$q$, 1);
select public.fj_seed_q('fis', 'fis:cinematica', 'fis:cinematica:1', 2, 'tf', $q$Esta definição está certa?$q$, $j${"stmt":"Velocidade média é a distância percorrida dividida pelo tempo gasto.","a":true}$j$, $q$Verdadeiro: v = Δs / Δt.$q$, 1);
select public.fj_seed_q('fis', 'fis:cinematica', 'fis:cinematica:1', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["Para converter km/h em m/s, "," por 3,6; para converter m/s em km/h, "," por 3,6."],"a":["dividimos","multiplicamos"],"extra":["somamos","subtraímos"]}$j$, $q$72 km/h ÷ 3,6 = 20 m/s.$q$, 2);
select public.fj_seed_q('fis', 'fis:cinematica', 'fis:cinematica:2', 0, 'mc', $q$Um carro parte do repouso e atinge 20 m/s em 5 s. Sua aceleração média é:$q$, $j${"opts":["4 m/s²","100 m/s²","25 m/s²","0,25 m/s²"],"a":0}$j$, $q$a = Δv / Δt = 20 ÷ 5 = 4 m/s².$q$, 2);
select public.fj_seed_q('fis', 'fis:cinematica', 'fis:cinematica:2', 1, 'mc', $q$No movimento uniforme, a velocidade:$q$, $j${"opts":["É constante","Aumenta sempre","Diminui sempre","É zero"],"a":0}$j$, $q$Uniforme = sem aceleração: a velocidade não muda.$q$, 1);
select public.fj_seed_q('fis', 'fis:cinematica', 'fis:cinematica:2', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A aceleração da gravidade na Terra é aproximadamente 10 m/s².","a":true}$j$, $q$Verdadeiro: o valor mais preciso é 9,8 m/s², arredondado para 10 nas provas.$q$, 1);
select public.fj_seed_q('fis', 'fis:cinematica', 'fis:cinematica:2', 3, 'order', $q$Ordene as velocidades da menor para a maior$q$, $j${"items":["5 m/s","36 km/h","15 m/s","72 km/h"]}$j$, $q$36 km/h = 10 m/s e 72 km/h = 20 m/s. Então: 5, 10, 15 e 20 m/s.$q$, 3);
select public.fj_seed_q('fis', 'fis:dinamica', 'fis:dinamica:1', 0, 'mc', $q$Pela 2ª Lei de Newton, uma força de 20 N aplicada em um corpo de 4 kg produz aceleração de:$q$, $j${"opts":["5 m/s²","80 m/s²","16 m/s²","0,2 m/s²"],"a":0}$j$, $q$F = m · a → a = 20 ÷ 4 = 5 m/s².$q$, 2);
select public.fj_seed_q('fis', 'fis:dinamica', 'fis:dinamica:1', 1, 'mc', $q$A 1ª Lei de Newton (inércia) afirma que um corpo:$q$, $j${"opts":["Mantém seu estado de repouso ou movimento se a força resultante for nula","Sempre para quando ninguém empurra","Acelera sozinho","Tem massa variável"],"a":0}$j$, $q$Sem força resultante, nada muda: parado continua parado, em movimento continua em movimento retilíneo uniforme.$q$, 2);
select public.fj_seed_q('fis', 'fis:dinamica', 'fis:dinamica:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Pela 3ª Lei de Newton, toda ação tem uma reação de mesma intensidade e sentido contrário.","a":true}$j$, $q$Verdadeiro: as forças de ação e reação atuam em corpos diferentes.$q$, 1);
select public.fj_seed_q('fis', 'fis:dinamica', 'fis:dinamica:1', 3, 'match', $q$Associe a lei ao seu conteúdo$q$, $j${"pairs":[["1ª Lei de Newton","Inércia"],["2ª Lei de Newton","F = m · a"],["3ª Lei de Newton","Ação e reação"],["Lei da gravitação","Atração entre massas"]]}$j$, $q$As três leis do movimento e a gravitação universal.$q$, 1);
select public.fj_seed_q('fis', 'fis:dinamica', 'fis:dinamica:2', 0, 'mc', $q$A unidade de energia e de trabalho no Sistema Internacional é o:$q$, $j${"opts":["Joule (J)","Newton (N)","Watt (W)","Pascal (Pa)"],"a":0}$j$, $q$Joule. Newton é força, watt é potência, pascal é pressão.$q$, 1);
select public.fj_seed_q('fis', 'fis:dinamica', 'fis:dinamica:2', 1, 'mc', $q$Uma bola parada no alto de um prédio tem, principalmente, energia:$q$, $j${"opts":["Potencial gravitacional","Cinética","Térmica","Elétrica"],"a":0}$j$, $q$Energia potencial gravitacional depende da altura: E = m · g · h.$q$, 1);
select public.fj_seed_q('fis', 'fis:dinamica', 'fis:dinamica:2', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A energia cinética depende da massa e da velocidade do corpo.","a":true}$j$, $q$Verdadeiro: E = m · v² / 2.$q$, 1);
select public.fj_seed_q('fis', 'fis:dinamica', 'fis:dinamica:2', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["Trabalho é força vezes ","; potência é trabalho dividido pelo ","."],"a":["deslocamento","tempo"],"extra":["massa","volume"]}$j$, $q$W = F · d e P = W / t.$q$, 2);
select public.fj_seed_q('fis', 'fis:circuitos', 'fis:circuitos:1', 0, 'mc', $q$A grandeza que mede o fluxo de cargas elétricas em um circuito é a:$q$, $j${"opts":["Corrente elétrica (A)","Tensão (V)","Resistência (Ω)","Potência (W)"],"a":0}$j$, $q$Corrente, medida em ampères.$q$, 1);
select public.fj_seed_q('fis', 'fis:circuitos', 'fis:circuitos:1', 1, 'mc', $q$Pela Lei de Ohm, um resistor de 10 Ω ligado a 20 V é percorrido por uma corrente de:$q$, $j${"opts":["2 A","200 A","0,5 A","10 A"],"a":0}$j$, $q$U = R · i → i = 20 ÷ 10 = 2 A.$q$, 2);
select public.fj_seed_q('fis', 'fis:circuitos', 'fis:circuitos:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A unidade de resistência elétrica é o ohm (Ω).","a":true}$j$, $q$Verdadeiro.$q$, 1);
select public.fj_seed_q('fis', 'fis:circuitos', 'fis:circuitos:1', 3, 'match', $q$Associe a unidade à grandeza$q$, $j${"pairs":[["Volt","Tensão"],["Ampère","Corrente"],["Ohm","Resistência"],["Watt","Potência"]]}$j$, $q$V, A, Ω e W.$q$, 1);
select public.fj_seed_q('fis', 'fis:circuitos', 'fis:circuitos:2', 0, 'mc', $q$Um chuveiro de 5.000 W ligado por 30 minutos consome:$q$, $j${"opts":["2,5 kWh","5 kWh","150 kWh","0,5 kWh"],"a":0}$j$, $q$5 kW × 0,5 h = 2,5 kWh.$q$, 2);
select public.fj_seed_q('fis', 'fis:circuitos', 'fis:circuitos:2', 1, 'mc', $q$Uma lâmpada de 100 W ligada em 220 V tem corrente de aproximadamente:$q$, $j${"opts":["0,45 A","2,2 A","22 A","4,5 A"],"a":0}$j$, $q$P = U · i → i = 100 ÷ 220 ≈ 0,45 A.$q$, 3);
select public.fj_seed_q('fis', 'fis:circuitos', 'fis:circuitos:2', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A conta de luz cobra pela energia consumida, medida em quilowatt-hora (kWh).","a":true}$j$, $q$Verdadeiro: potência (kW) × tempo (h).$q$, 1);
select public.fj_seed_q('fis', 'fis:circuitos', 'fis:circuitos:2', 3, 'order', $q$Ordene os aparelhos do menor para o maior consumo em 1 hora$q$, $j${"items":["Lâmpada LED (10 W)","Ventilador (100 W)","Micro-ondas (1.000 W)","Chuveiro (5.000 W)"]}$j$, $q$Quanto maior a potência, maior o consumo no mesmo tempo.$q$, 1);

-- ---------------------------------------------------------------
-- QUÍMICA
-- ---------------------------------------------------------------
select public.fj_seed_q('qui', 'qui:atomo', 'qui:atomo:1', 0, 'mc', $q$Qual é o símbolo do sódio na tabela periódica?$q$, $j${"opts":["Na","So","S","Sd"],"a":0}$j$, $q$Na, do latim natrium.$q$, 1);
select public.fj_seed_q('qui', 'qui:atomo', 'qui:atomo:1', 1, 'mc', $q$Os elementos de uma mesma coluna (grupo) da tabela periódica têm:$q$, $j${"opts":["Propriedades químicas semelhantes","A mesma massa","O mesmo número de prótons","A mesma cor"],"a":0}$j$, $q$Mesmo grupo = mesmo número de elétrons na camada de valência.$q$, 2);
select public.fj_seed_q('qui', 'qui:atomo', 'qui:atomo:1', 2, 'tf', $q$Esta definição está certa?$q$, $j${"stmt":"O número atômico de um elemento é o número de prótons no núcleo.","a":true}$j$, $q$Verdadeiro: Z = número de prótons.$q$, 1);
select public.fj_seed_q('qui', 'qui:atomo', 'qui:atomo:1', 3, 'match', $q$Associe o símbolo ao elemento$q$, $j${"pairs":[["H","Hidrogênio"],["O","Oxigênio"],["C","Carbono"],["Fe","Ferro"]]}$j$, $q$Fe vem do latim ferrum.$q$, 1);
select public.fj_seed_q('qui', 'qui:atomo', 'qui:atomo:2', 0, 'mc', $q$A ligação em que um metal transfere elétrons para um ametal, formando íons, é a:$q$, $j${"opts":["Iônica","Covalente","Metálica","De hidrogênio"],"a":0}$j$, $q$Iônica: cátion (metal) e ânion (ametal) se atraem.$q$, 2);
select public.fj_seed_q('qui', 'qui:atomo', 'qui:atomo:2', 1, 'mc', $q$A molécula de água (H₂O) é formada por ligações:$q$, $j${"opts":["Covalentes","Iônicas","Metálicas","Nucleares"],"a":0}$j$, $q$Hidrogênio e oxigênio compartilham elétrons.$q$, 1);
select public.fj_seed_q('qui', 'qui:atomo', 'qui:atomo:2', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"O sal de cozinha (NaCl) é um composto iônico.","a":true}$j$, $q$Verdadeiro: Na⁺ e Cl⁻.$q$, 1);
select public.fj_seed_q('qui', 'qui:atomo', 'qui:atomo:2', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["Na ligação "," os átomos compartilham elétrons; na ligação "," há transferência de elétrons."],"a":["covalente","iônica"],"extra":["metálica","nuclear"]}$j$, $q$Covalente compartilha; iônica transfere.$q$, 2);
select public.fj_seed_q('qui', 'qui:solucoes', 'qui:solucoes:1', 0, 'mc', $q$Uma solução com pH 3 é:$q$, $j${"opts":["Ácida","Básica","Neutra","Salina"],"a":0}$j$, $q$pH abaixo de 7 é ácido; acima de 7, básico.$q$, 1);
select public.fj_seed_q('qui', 'qui:solucoes', 'qui:solucoes:1', 1, 'mc', $q$Qual destas substâncias é uma base?$q$, $j${"opts":["Hidróxido de sódio (NaOH)","Ácido clorídrico (HCl)","Água pura","Vinagre"],"a":0}$j$, $q$Hidróxidos são bases; a soda cáustica é NaOH.$q$, 2);
select public.fj_seed_q('qui', 'qui:solucoes', 'qui:solucoes:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A água pura tem pH 7, ou seja, é neutra.","a":true}$j$, $q$Verdadeiro.$q$, 1);
select public.fj_seed_q('qui', 'qui:solucoes', 'qui:solucoes:1', 3, 'order', $q$Ordene do pH mais baixo para o mais alto$q$, $j${"items":["Suco de limão","Café","Água pura","Sabão"]}$j$, $q$Limão ≈ 2, café ≈ 5, água 7, sabão ≈ 10.$q$, 2);
select public.fj_seed_q('qui', 'qui:solucoes', 'qui:solucoes:2', 0, 'mc', $q$Na equação 2H₂ + O₂ → 2H₂O, o número de moléculas de água formadas é:$q$, $j${"opts":["2","1","3","4"],"a":0}$j$, $q$O coeficiente 2 antes de H₂O indica duas moléculas.$q$, 2);
select public.fj_seed_q('qui', 'qui:solucoes', 'qui:solucoes:2', 1, 'mc', $q$A reação entre um ácido e uma base, formando sal e água, chama-se:$q$, $j${"opts":["Neutralização","Combustão","Oxidação","Fermentação"],"a":0}$j$, $q$Exemplo: HCl + NaOH → NaCl + H₂O.$q$, 1);
select public.fj_seed_q('qui', 'qui:solucoes', 'qui:solucoes:2', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Em uma reação química, a massa total se conserva (Lei de Lavoisier).","a":true}$j$, $q$Verdadeiro: "na natureza nada se cria, nada se perde, tudo se transforma".$q$, 1);
select public.fj_seed_q('qui', 'qui:solucoes', 'qui:solucoes:2', 3, 'match', $q$Associe o tipo de reação à descrição$q$, $j${"pairs":[["Combustão","Reage com oxigênio liberando calor"],["Neutralização","Ácido + base → sal + água"],["Síntese","Duas substâncias formam uma"],["Decomposição","Uma substância forma duas ou mais"]]}$j$, $q$Os principais tipos de reação.$q$, 2);

-- ---------------------------------------------------------------
-- REDAÇÃO
-- ---------------------------------------------------------------
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:1', 0, 'mc', $q$Quantas competências a redação do ENEM avalia?$q$, $j${"opts":["5","3","4","6"],"a":0}$j$, $q$São 5 competências, de 0 a 200 pontos cada, totalizando 1.000.$q$, 1);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:1', 1, 'mc', $q$A competência 5 da redação do ENEM avalia:$q$, $j${"opts":["A proposta de intervenção","A norma-padrão","O tema","A coesão"],"a":0}$j$, $q$A competência 5 é a proposta de solução para o problema discutido.$q$, 1);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:1', 2, 'match', $q$Associe a competência ao que ela avalia$q$, $j${"pairs":[["Competência 1","Norma-padrão da língua"],["Competência 2","Compreender o tema e o tipo textual"],["Competência 4","Coesão e articulação"],["Competência 5","Proposta de intervenção"]]}$j$, $q$A competência 3 avalia a seleção e organização dos argumentos.$q$, 2);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:1', 3, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Fugir do tema zera a redação.","a":true}$j$, $q$Verdadeiro: fuga ao tema é um dos motivos de nota zero.$q$, 1);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:2', 0, 'mc', $q$A tese de uma redação dissertativa é:$q$, $j${"opts":["O ponto de vista que será defendido","Um resumo do texto motivador","A proposta de solução","Uma citação obrigatória"],"a":0}$j$, $q$Tese é a opinião do autor sobre o tema, apresentada na introdução.$q$, 1);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:2', 1, 'mc', $q$O uso de uma citação, dado ou fato histórico para sustentar o texto é chamado de:$q$, $j${"opts":["Repertório sociocultural","Proposta de intervenção","Tese","Conectivo"],"a":0}$j$, $q$Repertório legitimado e pertinente ao tema vale pontos na competência 2.$q$, 2);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:2', 2, 'bank', $q$Complete a frase$q$, $j${"parts":["Um bom parágrafo de desenvolvimento apresenta um "," e o sustenta com ","."],"a":["argumento","exemplos"],"extra":["título","rimas"]}$j$, $q$Argumento + exemplos, dados ou citações.$q$, 1);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:2', 3, 'order', $q$Ordene a estrutura da introdução$q$, $j${"items":["Contextualização do tema","Apresentação da tese","Indicação dos argumentos"]}$j$, $q$Contextualiza, posiciona-se e anuncia o que vai defender.$q$, 2);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:3', 0, 'mc', $q$Uma proposta de intervenção completa precisa ter agente, ação, meio, finalidade e:$q$, $j${"opts":["Detalhamento","Rima","Título","Citação"],"a":0}$j$, $q$Os 5 elementos: agente, ação, meio/modo, finalidade e detalhamento.$q$, 2);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:3', 1, 'mc', $q$"O Ministério da Educação deve criar campanhas nas escolas." Nessa proposta, o agente é:$q$, $j${"opts":["O Ministério da Educação","As campanhas","As escolas","Os alunos"],"a":0}$j$, $q$Agente é quem executa a ação.$q$, 1);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:3', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A proposta de intervenção deve respeitar os direitos humanos.","a":true}$j$, $q$Verdadeiro: desrespeito aos direitos humanos zera a competência 5.$q$, 1);
select public.fj_seed_q('red', 'red:estrutura', 'red:estrutura:3', 3, 'match', $q$Associe o elemento da proposta à sua pergunta$q$, $j${"pairs":[["Agente","Quem vai agir"],["Ação","O que será feito"],["Meio","Como será feito"],["Finalidade","Para que será feito"]]}$j$, $q$Quem, o quê, como e para quê.$q$, 1);

-- ---------------------------------------------------------------
-- INGLÊS
-- ---------------------------------------------------------------
select public.fj_seed_q('ing', 'ing:gramatica', 'ing:gramatica:1', 0, 'mc', $q$"She ___ to school every day."$q$, $j${"opts":["goes","go","going","gone"],"a":0}$j$, $q$Terceira pessoa do singular no simple present recebe -s: goes.$q$, 1);
select public.fj_seed_q('ing', 'ing:gramatica', 'ing:gramatica:1', 1, 'mc', $q$"They ___ a movie last night."$q$, $j${"opts":["watched","watch","watching","watches"],"a":0}$j$, $q$"Last night" indica passado: simple past, watched.$q$, 1);
select public.fj_seed_q('ing', 'ing:gramatica', 'ing:gramatica:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"'I have lived here for five years' está no present perfect.","a":true}$j$, $q$Verdadeiro: have + particípio (lived).$q$, 2);
select public.fj_seed_q('ing', 'ing:gramatica', 'ing:gramatica:1', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["No simple past, os verbos regulares recebem a terminação ","; o passado do verbo 'go' é ","."],"a":["-ed","went"],"extra":["-ing","goed"]}$j$, $q$Regulares: -ed. Go é irregular: went.$q$, 1);
select public.fj_seed_q('ing', 'ing:gramatica', 'ing:gramatica:2', 0, 'mc', $q$O que significa "although"?$q$, $j${"opts":["embora","além disso","portanto","sempre"],"a":0}$j$, $q$Although = embora, apesar de.$q$, 1);
select public.fj_seed_q('ing', 'ing:gramatica', 'ing:gramatica:2', 1, 'mc', $q$"I was tired, ___ I kept studying." A palavra que indica contraste é:$q$, $j${"opts":["but","and","so","because"],"a":0}$j$, $q$But = mas.$q$, 1);
select public.fj_seed_q('ing', 'ing:gramatica', 'ing:gramatica:2', 2, 'match', $q$Associe o conectivo à tradução$q$, $j${"pairs":[["However","Entretanto"],["Therefore","Portanto"],["Because","Porque"],["Moreover","Além disso"]]}$j$, $q$Conectivos aparecem muito nas provas de leitura.$q$, 2);
select public.fj_seed_q('ing', 'ing:gramatica', 'ing:gramatica:2', 3, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"'So' indica consequência, como em 'It was late, so we left'.","a":true}$j$, $q$Verdadeiro: so = então, por isso.$q$, 1);
select public.fj_seed_q('ing', 'ing:vocabulario', 'ing:vocabulario:1', 0, 'mc', $q$O que significa "actually"?$q$, $j${"opts":["na verdade","atualmente","rapidamente","finalmente"],"a":0}$j$, $q$Falso cognato: actually = na verdade. Atualmente = currently.$q$, 2);
select public.fj_seed_q('ing', 'ing:vocabulario', 'ing:vocabulario:1', 1, 'mc', $q$"Library" significa:$q$, $j${"opts":["biblioteca","livraria","liberdade","leitura"],"a":0}$j$, $q$Library = biblioteca. Livraria = bookstore.$q$, 1);
select public.fj_seed_q('ing', 'ing:vocabulario', 'ing:vocabulario:1', 2, 'match', $q$Associe os falsos cognatos à tradução correta$q$, $j${"pairs":[["Pretend","Fingir"],["Push","Empurrar"],["College","Faculdade"],["Parents","Pais"]]}$j$, $q$Nenhum deles significa o que parece.$q$, 2);
select public.fj_seed_q('ing', 'ing:vocabulario', 'ing:vocabulario:1', 3, 'tf', $q$Esta tradução está certa?$q$, $j${"stmt":"'Fabric' significa fábrica.","a":false}$j$, $q$Falso: fabric = tecido. Fábrica = factory.$q$, 2);
select public.fj_seed_q('ing', 'ing:vocabulario', 'ing:vocabulario:2', 0, 'mc', $q$Ao ler um texto em inglês, a melhor estratégia para entender a ideia geral é:$q$, $j${"opts":["Skimming: ler rapidamente buscando o sentido geral","Traduzir palavra por palavra","Ler só o título","Decorar o vocabulário antes"],"a":0}$j$, $q$Skimming dá a visão geral; scanning procura um dado específico.$q$, 2);
select public.fj_seed_q('ing', 'ing:vocabulario', 'ing:vocabulario:2', 1, 'mc', $q$Palavras parecidas com o português e com o mesmo sentido, como "information", são:$q$, $j${"opts":["Cognatos","Falsos cognatos","Phrasal verbs","Sinônimos"],"a":0}$j$, $q$Cognatos ajudam muito na leitura.$q$, 1);
select public.fj_seed_q('ing', 'ing:vocabulario', 'ing:vocabulario:2', 2, 'tf', $q$Esta definição está certa?$q$, $j${"stmt":"'Scanning' é a leitura rápida em busca de uma informação específica.","a":true}$j$, $q$Verdadeiro: como procurar um número em uma tabela.$q$, 1);
select public.fj_seed_q('ing', 'ing:vocabulario', 'ing:vocabulario:2', 3, 'order', $q$Ordene as palavras para formar a frase$q$, $j${"items":["She","is","my","best","friend"]}$j$, $q$She is my best friend.$q$, 1);

-- ---------------------------------------------------------------
-- FILOSOFIA E SOCIOLOGIA
-- ---------------------------------------------------------------
select public.fj_seed_q('fil', 'fil:filosofia', 'fil:filosofia:1', 0, 'mc', $q$"Só sei que nada sei" é uma frase atribuída a:$q$, $j${"opts":["Sócrates","Platão","Aristóteles","Descartes"],"a":0}$j$, $q$Sócrates: reconhecer a própria ignorância é o começo do saber.$q$, 1);
select public.fj_seed_q('fil', 'fil:filosofia', 'fil:filosofia:1', 1, 'mc', $q$O Mito da Caverna, que trata da diferença entre aparência e verdade, é de:$q$, $j${"opts":["Platão","Sócrates","Nietzsche","Kant"],"a":0}$j$, $q$Platão, no livro "A República".$q$, 1);
select public.fj_seed_q('fil', 'fil:filosofia', 'fil:filosofia:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Aristóteles foi discípulo de Platão.","a":true}$j$, $q$Verdadeiro: Sócrates → Platão → Aristóteles.$q$, 1);
select public.fj_seed_q('fil', 'fil:filosofia', 'fil:filosofia:1', 3, 'match', $q$Associe o filósofo à sua ideia$q$, $j${"pairs":[["Sócrates","Método do diálogo (maiêutica)"],["Platão","Mundo das ideias"],["Aristóteles","Lógica e ética das virtudes"],["Epicuro","Busca do prazer moderado"]]}$j$, $q$Quatro pensadores da Antiguidade grega.$q$, 2);
select public.fj_seed_q('fil', 'fil:filosofia', 'fil:filosofia:2', 0, 'mc', $q$"Penso, logo existo" é de:$q$, $j${"opts":["Descartes","Kant","Nietzsche","Sartre"],"a":0}$j$, $q$René Descartes, pai do racionalismo moderno.$q$, 1);
select public.fj_seed_q('fil', 'fil:filosofia', 'fil:filosofia:2', 1, 'mc', $q$Para Kant, agir moralmente é agir por:$q$, $j${"opts":["Dever, seguindo o imperativo categórico","Interesse próprio","Medo de punição","Tradição"],"a":0}$j$, $q$Imperativo categórico: aja de modo que sua conduta possa virar lei universal.$q$, 3);
select public.fj_seed_q('fil', 'fil:filosofia', 'fil:filosofia:2', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Para Sartre, 'a existência precede a essência': o ser humano se constrói pelas próprias escolhas.","a":true}$j$, $q$Verdadeiro: é a base do existencialismo.$q$, 2);
select public.fj_seed_q('fil', 'fil:filosofia', 'fil:filosofia:2', 3, 'order', $q$Ordene os filósofos do mais antigo para o mais recente$q$, $j${"items":["Sócrates","Descartes","Kant","Nietzsche"]}$j$, $q$Século V a.C., XVII, XVIII e XIX.$q$, 2);
select public.fj_seed_q('fil', 'fil:sociologia', 'fil:sociologia:1', 0, 'mc', $q$O conceito de "fato social", regras externas que se impõem ao indivíduo, é de:$q$, $j${"opts":["Durkheim","Marx","Weber","Comte"],"a":0}$j$, $q$Émile Durkheim, um dos fundadores da Sociologia.$q$, 2);
select public.fj_seed_q('fil', 'fil:sociologia', 'fil:sociologia:1', 1, 'mc', $q$Para Marx, a história das sociedades é movida pela:$q$, $j${"opts":["Luta de classes","Vontade de Deus","Ação dos grandes líderes","Evolução natural"],"a":0}$j$, $q$Conflito entre quem detém os meios de produção e quem vende a força de trabalho.$q$, 1);
select public.fj_seed_q('fil', 'fil:sociologia', 'fil:sociologia:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Weber estudou a 'ação social', o sentido que as pessoas dão às suas ações.","a":true}$j$, $q$Verdadeiro: Max Weber e a sociologia compreensiva.$q$, 2);
select public.fj_seed_q('fil', 'fil:sociologia', 'fil:sociologia:1', 3, 'match', $q$Associe o sociólogo ao conceito$q$, $j${"pairs":[["Durkheim","Fato social"],["Marx","Luta de classes"],["Weber","Ação social"],["Comte","Positivismo"]]}$j$, $q$Os clássicos da Sociologia.$q$, 2);
select public.fj_seed_q('fil', 'fil:sociologia', 'fil:sociologia:2', 0, 'mc', $q$Cultura, em Sociologia, é:$q$, $j${"opts":["O conjunto de costumes, valores e saberes de um grupo","Apenas as artes eruditas","Só o que é ensinado na escola","Algo inato ao ser humano"],"a":0}$j$, $q$Cultura é tudo que é aprendido e compartilhado em sociedade.$q$, 1);
select public.fj_seed_q('fil', 'fil:sociologia', 'fil:sociologia:2', 1, 'mc', $q$Julgar outra cultura com base nos valores da própria cultura chama-se:$q$, $j${"opts":["Etnocentrismo","Relativismo cultural","Alteridade","Aculturação"],"a":0}$j$, $q$Etnocentrismo: achar que o próprio modo de vida é o certo.$q$, 2);
select public.fj_seed_q('fil', 'fil:sociologia', 'fil:sociologia:2', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Cidadania envolve direitos e deveres na vida em sociedade.","a":true}$j$, $q$Verdadeiro: direitos civis, políticos e sociais, e também deveres.$q$, 1);
select public.fj_seed_q('fil', 'fil:sociologia', 'fil:sociologia:2', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["O "," julga outras culturas pelos próprios padrões; o relativismo cultural procura entender cada cultura a partir de seus "," valores."],"a":["etnocentrismo","próprios"],"extra":["relativismo","piores"]}$j$, $q$Etnocentrismo julga; relativismo compreende.$q$, 2);

drop function public.fj_seed_q(text, text, text, int, text, text, jsonb, text, int);
