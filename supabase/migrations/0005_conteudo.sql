-- =====================================================================
-- Findout Jornada · Migration 0005 · Conteúdo inicial (112 questões)
-- Matemática, Português, Biologia e História em estilo ENEM, com
-- resposta e explicação. Rodar no SQL Editor. Idempotente: pode rodar
-- de novo sem duplicar (os ids são derivados dos títulos).
-- Depois de rodar, abra o painel: ele publica a nova versão sozinho.
-- =====================================================================

-- Função auxiliar (apagada no fim do arquivo)
create or replace function public.fj_seed_q(p_mat text, p_uni text, p_lic text, p_ordem int, p_tipo text, p_enun text, p_dados jsonb, p_expl text, p_dif int default 2)
returns void language plpgsql as $$
declare uni uuid := md5('uni:' || p_uni)::uuid; lic uuid := md5('lic:' || p_lic)::uuid; qid uuid := md5('q:' || p_lic || '|' || p_enun)::uuid;
begin
  insert into public.questoes (id, materia_id, unidade_id, tipo, enunciado, dados, explicacao, status)
  values (qid, p_mat, uni, p_tipo, p_enun, p_dados || jsonb_build_object('dificuldade', p_dif), p_expl, 'publicada')
  on conflict (id) do nothing;
  insert into public.licao_questoes (licao_id, questao_id, ordem) values (lic, qid, p_ordem) on conflict do nothing;
end $$;

-- ---------------------------------------------------------------
-- Matérias (não mexe nas que já existem)
-- ---------------------------------------------------------------
insert into public.materias (id, nome, sigla, cor, ativa, ordem) values
('mat', 'Matemática', 'MA', '#503C9D', true, 0),
('por', 'Português', 'PT', '#4CC3C1', true, 1),
('bio', 'Biologia', 'BI', '#2F7D4F', true, 2),
('his', 'História', 'HS', '#B9773B', true, 3)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- Seções, unidades e lições
-- ---------------------------------------------------------------
insert into public.secoes (id, materia_id, titulo, ordem) values
(md5('sec:mat:numeros')::uuid, 'mat', 'Números e proporção', 0),
(md5('sec:mat:algebra')::uuid, 'mat', 'Álgebra e funções', 1),
(md5('sec:por:norma')::uuid, 'por', 'Norma-padrão', 0),
(md5('sec:por:leitura')::uuid, 'por', 'Leitura e interpretação', 1),
(md5('sec:bio:citologia')::uuid, 'bio', 'Citologia', 0),
(md5('sec:bio:ecologia')::uuid, 'bio', 'Ecologia', 1),
(md5('sec:his:brasil')::uuid, 'his', 'Brasil: Império e República', 1)
on conflict (id) do nothing;

insert into public.unidades (id, secao_id, titulo, ordem) values
(md5('uni:mat:fracoes')::uuid, md5('sec:mat:numeros')::uuid, 'Frações e decimais', 0),
(md5('uni:mat:porcentagem')::uuid, md5('sec:mat:numeros')::uuid, 'Porcentagem', 1),
(md5('uni:mat:proporcao')::uuid, md5('sec:mat:numeros')::uuid, 'Razão e proporção', 2),
(md5('uni:mat:equacoes')::uuid, md5('sec:mat:algebra')::uuid, 'Equações do 1º grau', 0),
(md5('uni:por:crase')::uuid, md5('sec:por:norma')::uuid, 'Crase e acentuação', 0),
(md5('uni:por:concordancia')::uuid, md5('sec:por:norma')::uuid, 'Concordância e regência', 1),
(md5('uni:por:linguagem')::uuid, md5('sec:por:leitura')::uuid, 'Figuras e funções da linguagem', 0),
(md5('uni:bio:celula')::uuid, md5('sec:bio:citologia')::uuid, 'A célula', 0),
(md5('uni:bio:ecologia')::uuid, md5('sec:bio:ecologia')::uuid, 'Ecossistemas', 0),
(md5('uni:his:imperio')::uuid, md5('sec:his:brasil')::uuid, 'Do Império à República', 0),
(md5('uni:his:vargas')::uuid, md5('sec:his:brasil')::uuid, 'Era Vargas e ditadura', 1)
on conflict (id) do nothing;

insert into public.licoes (id, unidade_id, titulo, descricao, ordem) values
(md5('lic:mat:fracoes:1')::uuid, md5('uni:mat:fracoes')::uuid, 'Frações no dia a dia', 'Partes de um inteiro, frações equivalentes e comparação.', 0),
(md5('lic:mat:fracoes:2')::uuid, md5('uni:mat:fracoes')::uuid, 'Operações com frações', 'Somar, multiplicar e dividir frações.', 1),
(md5('lic:mat:fracoes:3')::uuid, md5('uni:mat:fracoes')::uuid, 'Frações e decimais', 'Converter frações em decimais e ordenar.', 2),
(md5('lic:mat:porcentagem:1')::uuid, md5('uni:mat:porcentagem')::uuid, 'Porcentagem de um valor', 'Calcular x% de um número.', 0),
(md5('lic:mat:porcentagem:2')::uuid, md5('uni:mat:porcentagem')::uuid, 'Desconto e acréscimo', 'Preço final depois de descontos e aumentos.', 1),
(md5('lic:mat:porcentagem:3')::uuid, md5('uni:mat:porcentagem')::uuid, 'Aumentos sucessivos', 'Por que +10% e −10% não se anulam.', 2),
(md5('lic:mat:proporcao:1')::uuid, md5('uni:mat:proporcao')::uuid, 'Razão e escala', 'Comparar grandezas e ler escalas de mapas.', 0),
(md5('lic:mat:proporcao:2')::uuid, md5('uni:mat:proporcao')::uuid, 'Regra de três', 'Grandezas direta e inversamente proporcionais.', 1),
(md5('lic:mat:proporcao:3')::uuid, md5('uni:mat:proporcao')::uuid, 'Proporcionalidade', 'Divisão proporcional e problemas do ENEM.', 2),
(md5('lic:mat:equacoes:1')::uuid, md5('uni:mat:equacoes')::uuid, 'Resolver equações', 'Isolar a incógnita passo a passo.', 0),
(md5('lic:mat:equacoes:2')::uuid, md5('uni:mat:equacoes')::uuid, 'Problemas com equações', 'Transformar o problema em equação.', 1),
(md5('lic:por:crase:1')::uuid, md5('uni:por:crase')::uuid, 'Quando usar crase', 'Preposição a + artigo a.', 0),
(md5('lic:por:crase:2')::uuid, md5('uni:por:crase')::uuid, 'Acentuação gráfica', 'Oxítonas, paroxítonas, proparoxítonas e hiatos.', 1),
(md5('lic:por:concordancia:1')::uuid, md5('uni:por:concordancia')::uuid, 'Concordância verbal', 'O verbo concorda com o sujeito.', 0),
(md5('lic:por:concordancia:2')::uuid, md5('uni:por:concordancia')::uuid, 'Regência', 'Verbos e as preposições que pedem.', 1),
(md5('lic:por:linguagem:1')::uuid, md5('uni:por:linguagem')::uuid, 'Figuras de linguagem', 'Metáfora, hipérbole, eufemismo e outras.', 0),
(md5('lic:por:linguagem:2')::uuid, md5('uni:por:linguagem')::uuid, 'Funções da linguagem', 'Emotiva, conativa, referencial, fática, poética e metalinguística.', 1),
(md5('lic:por:linguagem:3')::uuid, md5('uni:por:linguagem')::uuid, 'Gêneros textuais', 'Tipos de texto e a redação do ENEM.', 2),
(md5('lic:bio:celula:1')::uuid, md5('uni:bio:celula')::uuid, 'Organelas', 'Quem faz o quê dentro da célula.', 0),
(md5('lic:bio:celula:2')::uuid, md5('uni:bio:celula')::uuid, 'Membrana e transporte', 'Osmose, difusão e transporte ativo.', 1),
(md5('lic:bio:celula:3')::uuid, md5('uni:bio:celula')::uuid, 'Divisão celular', 'Mitose e meiose.', 2),
(md5('lic:bio:ecologia:1')::uuid, md5('uni:bio:ecologia')::uuid, 'Cadeias alimentares', 'Produtores, consumidores e decompositores.', 0),
(md5('lic:bio:ecologia:2')::uuid, md5('uni:bio:ecologia')::uuid, 'Ciclos biogeoquímicos', 'Água, carbono e nitrogênio.', 1),
(md5('lic:bio:ecologia:3')::uuid, md5('uni:bio:ecologia')::uuid, 'Impactos ambientais', 'Efeito estufa, eutrofização e camada de ozônio.', 2),
(md5('lic:his:imperio:1')::uuid, md5('uni:his:imperio')::uuid, 'Independência e Primeiro Reinado', 'De 1822 à abdicação de Dom Pedro I.', 0),
(md5('lic:his:imperio:2')::uuid, md5('uni:his:imperio')::uuid, 'Abolição e República', 'As leis abolicionistas e 1889.', 1),
(md5('lic:his:vargas:1')::uuid, md5('uni:his:vargas')::uuid, 'Era Vargas', 'De 1930 ao Estado Novo.', 0),
(md5('lic:his:vargas:2')::uuid, md5('uni:his:vargas')::uuid, 'Ditadura militar', 'De 1964 à redemocratização.', 1)
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- MATEMÁTICA · Frações e decimais
-- ---------------------------------------------------------------
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:1', 0, 'mc', $q$Uma pizza foi dividida em 8 fatias iguais. Ana comeu 3 fatias. Que fração da pizza ela comeu?$q$, $j${"opts":["3/8","3/5","5/8","1/3"],"a":0}$j$, $q$3 fatias de um total de 8: 3/8.$q$, 1);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:1', 1, 'mc', $q$Qual fração é equivalente a 2/3?$q$, $j${"opts":["4/6","3/4","2/6","6/4"],"a":0}$j$, $q$Multiplique numerador e denominador por 2: 2/3 = 4/6.$q$, 1);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:1', 2, 'tf', $q$Esta comparação está certa?$q$, $j${"stmt":"1/2 é maior que 2/5","a":true}$j$, $q$Verdadeiro: 1/2 = 0,5 e 2/5 = 0,4.$q$, 1);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:1', 3, 'match', $q$Associe cada fração à sua forma simplificada$q$, $j${"pairs":[["4/8","1/2"],["6/9","2/3"],["5/20","1/4"],["9/12","3/4"]]}$j$, $q$Divida numerador e denominador pelo mesmo número até não dar mais.$q$, 2);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:2', 0, 'mc', $q$Quanto é 1/4 + 1/2?$q$, $j${"opts":["3/4","2/6","1/6","2/4"],"a":0}$j$, $q$1/2 = 2/4. Então 1/4 + 2/4 = 3/4.$q$, 1);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:2', 1, 'mc', $q$Quanto é 2/3 × 3/5?$q$, $j${"opts":["2/5","6/8","5/8","1/5"],"a":0}$j$, $q$Multiplique em linha: 6/15, que simplificado dá 2/5.$q$, 2);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:2', 2, 'mc', $q$Quanto é 3/4 ÷ 1/2?$q$, $j${"opts":["3/2","3/8","1/2","6/8"],"a":0}$j$, $q$Inverta a segunda fração e multiplique: 3/4 × 2/1 = 6/4 = 3/2.$q$, 2);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:2', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["Para somar frações com denominadores diferentes, primeiro encontramos o "," dos denominadores e só então somamos os ","."],"a":["MMC","numeradores"],"extra":["MDC","denominadores"]}$j$, $q$Usamos o MMC para igualar os denominadores e depois somamos os numeradores.$q$, 2);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:3', 0, 'mc', $q$Qual decimal corresponde a 3/5?$q$, $j${"opts":["0,6","0,35","0,53","1,67"],"a":0}$j$, $q$3 ÷ 5 = 0,6.$q$, 1);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:3', 1, 'order', $q$Ordene do menor para o maior$q$, $j${"items":["1/5","0,3","1/2","0,75"]}$j$, $q$1/5 = 0,2 < 0,3 < 1/2 = 0,5 < 0,75.$q$, 2);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:3', 2, 'mc', $q$Qual fração corresponde a 0,25?$q$, $j${"opts":["1/4","1/25","2/5","25/10"],"a":0}$j$, $q$0,25 = 25/100 = 1/4.$q$, 1);
select public.fj_seed_q('mat', 'mat:fracoes', 'mat:fracoes:3', 3, 'tf', $q$Esta igualdade está certa?$q$, $j${"stmt":"0,8 = 4/5","a":true}$j$, $q$Verdadeiro: 4 ÷ 5 = 0,8.$q$, 1);

-- MATEMÁTICA · Porcentagem
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:1', 0, 'mc', $q$Quanto é 20% de 150?$q$, $j${"opts":["30","20","15","45"],"a":0}$j$, $q$20% = 0,2. Então 0,2 × 150 = 30.$q$, 1);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:1', 1, 'mc', $q$Em uma turma de 40 alunos, 25% usam óculos. Quantos alunos usam óculos?$q$, $j${"opts":["10","4","15","25"],"a":0}$j$, $q$25% é 1/4. 40 ÷ 4 = 10.$q$, 1);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:1', 2, 'match', $q$Associe a porcentagem à fração$q$, $j${"pairs":[["50%","1/2"],["25%","1/4"],["20%","1/5"],["10%","1/10"]]}$j$, $q$50% = 1/2 · 25% = 1/4 · 20% = 1/5 · 10% = 1/10.$q$, 1);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:1', 3, 'tf', $q$Esta conta está certa?$q$, $j${"stmt":"15% de 200 é 30","a":true}$j$, $q$Verdadeiro: 0,15 × 200 = 30.$q$, 1);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:2', 0, 'mc', $q$Um tênis custa R$ 250 e está com 30% de desconto. Qual é o preço final?$q$, $j${"opts":["R$ 175","R$ 220","R$ 75","R$ 185"],"a":0}$j$, $q$30% de 250 = 75. Então 250 − 75 = 175.$q$, 2);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:2', 1, 'mc', $q$Um salário de R$ 2.000 teve aumento de 8%. Qual é o novo salário?$q$, $j${"opts":["R$ 2.160","R$ 2.080","R$ 2.800","R$ 2.016"],"a":0}$j$, $q$8% de 2.000 = 160. Então 2.000 + 160 = 2.160.$q$, 2);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:2', 2, 'bank', $q$Complete a frase$q$, $j${"parts":["Para aplicar um desconto de 30%, multiplicamos o preço por ","; para um aumento de 30%, multiplicamos por ","."],"a":["0,7","1,3"],"extra":["0,3","3"]}$j$, $q$Desconto de 30% deixa 70% (×0,7); aumento de 30% vira 130% (×1,3).$q$, 2);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:2', 3, 'mc', $q$Uma loja vende um produto por R$ 120 com lucro de 20% sobre o custo. Qual foi o custo?$q$, $j${"opts":["R$ 100","R$ 96","R$ 144","R$ 110"],"a":0}$j$, $q$Preço = custo × 1,2. Então custo = 120 ÷ 1,2 = 100.$q$, 3);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:3', 0, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Aumentar 10% e depois reduzir 10% volta ao valor inicial","a":false}$j$, $q$Falso: 100 → 110 → 99. A redução incide sobre um valor maior.$q$, 2);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:3', 1, 'mc', $q$Um produto teve dois aumentos sucessivos de 10%. O aumento total foi de:$q$, $j${"opts":["21%","20%","19%","11%"],"a":0}$j$, $q$1,1 × 1,1 = 1,21, ou seja, 21% de aumento.$q$, 3);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:3', 2, 'mc', $q$Um preço caiu 50% e depois subiu 50%. Em relação ao valor original, ele ficou:$q$, $j${"opts":["25% menor","igual","25% maior","50% menor"],"a":0}$j$, $q$100 → 50 → 75. Ficou 25% menor que o original.$q$, 3);
select public.fj_seed_q('mat', 'mat:porcentagem', 'mat:porcentagem:3', 3, 'order', $q$Partindo de R$ 100, ordene do menor para o maior valor final$q$, $j${"items":["−20% e depois −20%","−20% e depois +20%","+20% e depois +20%"]}$j$, $q$Os valores finais são R$ 64, R$ 96 e R$ 144.$q$, 3);

-- MATEMÁTICA · Razão e proporção
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:1', 0, 'mc', $q$Em um mapa na escala 1:100.000, 3 cm correspondem a quantos quilômetros reais?$q$, $j${"opts":["3 km","30 km","300 m","0,3 km"],"a":0}$j$, $q$3 cm × 100.000 = 300.000 cm = 3 km.$q$, 2);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:1', 1, 'mc', $q$A razão entre 12 meninas e 18 meninos em uma turma é:$q$, $j${"opts":["2:3","3:2","12:30","1:2"],"a":0}$j$, $q$12/18 simplificado por 6 dá 2/3, ou 2:3.$q$, 1);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Se a razão entre dois números é 1:4, o segundo é quatro vezes o primeiro.","a":true}$j$, $q$Verdadeiro: 1 para 4 significa que o segundo é 4 vezes maior.$q$, 1);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:1', 3, 'mc', $q$Uma receita usa 2 xícaras de farinha para 3 ovos. Para 9 ovos, quantas xícaras de farinha?$q$, $j${"opts":["6","4","5","9"],"a":0}$j$, $q$9 ovos são 3 vezes 3 ovos; então 3 × 2 = 6 xícaras.$q$, 1);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:2', 0, 'mc', $q$Se 5 cadernos custam R$ 40, quanto custam 8 cadernos?$q$, $j${"opts":["R$ 64","R$ 56","R$ 72","R$ 48"],"a":0}$j$, $q$Cada caderno custa 8 reais; 8 × 8 = 64.$q$, 1);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:2', 1, 'mc', $q$Um carro percorre 300 km com 25 litros. Quantos litros são necessários para 480 km?$q$, $j${"opts":["40 L","35 L","48 L","32 L"],"a":0}$j$, $q$300 ÷ 25 = 12 km por litro; 480 ÷ 12 = 40 litros.$q$, 2);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:2', 2, 'mc', $q$6 operários constroem um muro em 10 dias. Em quantos dias 15 operários constroem o mesmo muro?$q$, $j${"opts":["4 dias","25 dias","6 dias","9 dias"],"a":0}$j$, $q$Grandezas inversas: 6 × 10 = 60 "operários-dia"; 60 ÷ 15 = 4 dias.$q$, 3);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:2', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["Quando uma grandeza aumenta e a outra também aumenta, elas são "," proporcionais; quando uma aumenta e a outra diminui, são "," proporcionais."],"a":["diretamente","inversamente"],"extra":["igualmente","nunca"]}$j$, $q$Direta: crescem juntas. Inversa: uma cresce e a outra diminui.$q$, 1);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:3', 0, 'mc', $q$Dois sócios dividem um lucro de R$ 9.000 na proporção 2:1. Quanto recebe o que tem a maior parte?$q$, $j${"opts":["R$ 6.000","R$ 4.500","R$ 3.000","R$ 7.000"],"a":0}$j$, $q$São 3 partes de R$ 3.000; o maior fica com 2 partes: R$ 6.000.$q$, 2);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:3', 1, 'match', $q$Associe a razão ao seu valor decimal$q$, $j${"pairs":[["1:2","0,5"],["3:4","0,75"],["1:5","0,2"],["2:5","0,4"]]}$j$, $q$Divida o primeiro pelo segundo número.$q$, 1);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:3', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Se 3 kg de maçã custam R$ 15, então 1 kg custa R$ 5.","a":true}$j$, $q$Verdadeiro: 15 ÷ 3 = 5.$q$, 1);
select public.fj_seed_q('mat', 'mat:proporcao', 'mat:proporcao:3', 3, 'mc', $q$Um mapa tem escala 1:50.000. Uma distância real de 10 km aparece no mapa com:$q$, $j${"opts":["20 cm","5 cm","2 cm","50 cm"],"a":0}$j$, $q$10 km = 1.000.000 cm; 1.000.000 ÷ 50.000 = 20 cm.$q$, 3);

-- MATEMÁTICA · Equações do 1º grau
select public.fj_seed_q('mat', 'mat:equacoes', 'mat:equacoes:1', 0, 'mc', $q$Qual é a solução de 2x + 6 = 14?$q$, $j${"opts":["x = 4","x = 10","x = 8","x = 3"],"a":0}$j$, $q$2x = 14 − 6 = 8; x = 4.$q$, 1);
select public.fj_seed_q('mat', 'mat:equacoes', 'mat:equacoes:1', 1, 'mc', $q$Qual é a solução de 3x − 5 = x + 7?$q$, $j${"opts":["x = 6","x = 1","x = 12","x = 2"],"a":0}$j$, $q$3x − x = 7 + 5 → 2x = 12 → x = 6.$q$, 2);
select public.fj_seed_q('mat', 'mat:equacoes', 'mat:equacoes:1', 2, 'bank', $q$Complete a frase$q$, $j${"parts":["Para resolver 5x = 20, dividimos os dois lados por "," e encontramos x = ","."],"a":["5","4"],"extra":["20","15"]}$j$, $q$20 ÷ 5 = 4.$q$, 1);
select public.fj_seed_q('mat', 'mat:equacoes', 'mat:equacoes:1', 3, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"x = 3 é solução de 4x − 2 = 10","a":true}$j$, $q$Verdadeiro: 4 × 3 − 2 = 10.$q$, 1);
select public.fj_seed_q('mat', 'mat:equacoes', 'mat:equacoes:2', 0, 'mc', $q$A soma de um número com o seu dobro é 27. Qual é o número?$q$, $j${"opts":["9","13,5","18","27"],"a":0}$j$, $q$x + 2x = 27 → 3x = 27 → x = 9.$q$, 2);
select public.fj_seed_q('mat', 'mat:equacoes', 'mat:equacoes:2', 1, 'mc', $q$Pedro tem 5 anos a mais que Lucas. Juntos, eles têm 31 anos. Quantos anos tem Lucas?$q$, $j${"opts":["13","18","16","15"],"a":0}$j$, $q$L + (L + 5) = 31 → 2L = 26 → L = 13.$q$, 2);
select public.fj_seed_q('mat', 'mat:equacoes', 'mat:equacoes:2', 2, 'mc', $q$Um retângulo tem perímetro de 30 cm e o comprimento é o dobro da largura. Qual é a largura?$q$, $j${"opts":["5 cm","10 cm","15 cm","7,5 cm"],"a":0}$j$, $q$2(2L + L) = 30 → 6L = 30 → L = 5 cm.$q$, 3);
select public.fj_seed_q('mat', 'mat:equacoes', 'mat:equacoes:2', 3, 'order', $q$Ordene os passos para resolver 3x + 4 = 19$q$, $j${"items":["Subtrair 4 dos dois lados","Obter 3x = 15","Dividir os dois lados por 3","Obter x = 5"]}$j$, $q$Primeiro isolamos o termo com x, depois dividimos pelo coeficiente.$q$, 2);

-- ---------------------------------------------------------------
-- PORTUGUÊS · Crase e acentuação
-- ---------------------------------------------------------------
select public.fj_seed_q('por', 'por:crase', 'por:crase:1', 0, 'mc', $q$Em qual frase a crase está correta?$q$, $j${"opts":["Fui à feira pela manhã.","Começou à chover cedo.","Entreguei o livro à ele.","Vou à pé para a escola."],"a":0}$j$, $q$Crase só antes de palavra feminina que aceita artigo: fui a + a feira.$q$, 2);
select public.fj_seed_q('por', 'por:crase', 'por:crase:1', 1, 'tf', $q$Esta regra está certa?$q$, $j${"stmt":"Usa-se crase antes de palavras masculinas.","a":false}$j$, $q$Falso: a crase é a + a (artigo feminino), então nunca antes de palavra masculina.$q$, 1);
select public.fj_seed_q('por', 'por:crase', 'por:crase:1', 2, 'mc', $q$Complete: "Refiro-me ___ pessoas que chegaram atrasadas."$q$, $j${"opts":["às","as","à","a"],"a":0}$j$, $q$Referir-se a + as pessoas = às pessoas.$q$, 2);
select public.fj_seed_q('por', 'por:crase', 'por:crase:1', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["A crase é a junção de uma "," com um ","."],"a":["preposição","artigo"],"extra":["conjunção","verbo"]}$j$, $q$Preposição "a" + artigo feminino "a".$q$, 1);
select public.fj_seed_q('por', 'por:crase', 'por:crase:2', 0, 'mc', $q$Qual palavra é proparoxítona?$q$, $j${"opts":["Lâmpada","Café","Também","Papel"],"a":0}$j$, $q$Lâm-pa-da: a sílaba tônica é a antepenúltima.$q$, 1);
select public.fj_seed_q('por', 'por:crase', 'por:crase:2', 1, 'mc', $q$Assinale a palavra escrita corretamente pela ortografia atual:$q$, $j${"opts":["Herói","Ideía","Heróico","Assembléia"],"a":0}$j$, $q$Herói mantém o acento (oxítona com ditongo aberto). Ideia, heroico e assembleia perderam o acento.$q$, 3);
select public.fj_seed_q('por', 'por:crase', 'por:crase:2', 2, 'match', $q$Associe a palavra à regra de acentuação$q$, $j${"pairs":[["Café","Oxítona terminada em -e"],["Fácil","Paroxítona terminada em -l"],["Médico","Proparoxítona"],["Saúde","Hiato com u tônico"]]}$j$, $q$Cada regra depende da sílaba tônica e da terminação.$q$, 2);
select public.fj_seed_q('por', 'por:crase', 'por:crase:2', 3, 'tf', $q$Esta regra está certa?$q$, $j${"stmt":"Todas as proparoxítonas são acentuadas.","a":true}$j$, $q$Verdadeiro: é a regra mais simples da acentuação.$q$, 1);

-- PORTUGUÊS · Concordância e regência
select public.fj_seed_q('por', 'por:concordancia', 'por:concordancia:1', 0, 'mc', $q$Assinale a frase correta:$q$, $j${"opts":["Havia muitas pessoas na fila.","Haviam muitas pessoas na fila.","Houveram muitos problemas.","Fazem dois anos que saí."],"a":0}$j$, $q$"Haver" no sentido de existir e "fazer" indicando tempo são impessoais: ficam no singular.$q$, 2);
select public.fj_seed_q('por', 'por:concordancia', 'por:concordancia:1', 1, 'mc', $q$"Faz dois anos que ele viajou." O verbo fica no singular porque:$q$, $j${"opts":["indica tempo decorrido e é impessoal","concorda com a palavra anos","está no passado","é um verbo irregular"],"a":0}$j$, $q$"Fazer" indicando tempo não tem sujeito, por isso não vai ao plural.$q$, 2);
select public.fj_seed_q('por', 'por:concordancia', 'por:concordancia:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Em 'Vendem-se casas', o verbo deve ficar no plural.","a":true}$j$, $q$Verdadeiro: "casas" é o sujeito (voz passiva sintética), então o verbo vai ao plural.$q$, 3);
select public.fj_seed_q('por', 'por:concordancia', 'por:concordancia:1', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["O verbo concorda com o "," da oração em número e ","."],"a":["sujeito","pessoa"],"extra":["objeto","gênero"]}$j$, $q$Concordância verbal: verbo e sujeito combinam em número e pessoa.$q$, 1);
select public.fj_seed_q('por', 'por:concordancia', 'por:concordancia:2', 0, 'mc', $q$Assinale a frase com regência correta:$q$, $j${"opts":["Assisti ao filme ontem.","Assisti o filme ontem.","Prefiro mais cinema do que teatro.","Obedeça seus pais."],"a":0}$j$, $q$Assistir (ver) pede "a"; preferir pede "a" sem "mais"; obedecer pede "a".$q$, 2);
select public.fj_seed_q('por', 'por:concordancia', 'por:concordancia:2', 1, 'mc', $q$Complete: "Ela chegou ___ escola atrasada."$q$, $j${"opts":["à","na","a","em"],"a":0}$j$, $q$Na norma-padrão, chegar pede "a": chegou a + a escola = à escola.$q$, 2);
select public.fj_seed_q('por', 'por:concordancia', 'por:concordancia:2', 2, 'order', $q$Monte a frase na ordem correta$q$, $j${"items":["Nós","preferimos","cinema","a","teatro"]}$j$, $q$Preferir uma coisa a outra: "Nós preferimos cinema a teatro".$q$, 2);
select public.fj_seed_q('por', 'por:concordancia', 'por:concordancia:2', 3, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"O verbo 'visar', no sentido de 'ter como objetivo', pede a preposição 'a'.","a":true}$j$, $q$Verdadeiro: "O projeto visa ao bem-estar da comunidade."$q$, 3);

-- PORTUGUÊS · Figuras e funções da linguagem
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:1', 0, 'mc', $q$"Seus olhos são duas estrelas." Que figura de linguagem aparece na frase?$q$, $j${"opts":["Metáfora","Comparação","Hipérbole","Eufemismo"],"a":0}$j$, $q$Metáfora: comparação sem conectivo ("como").$q$, 1);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:1', 1, 'mc', $q$"Estou morrendo de fome." Que figura é essa?$q$, $j${"opts":["Hipérbole","Metonímia","Ironia","Antítese"],"a":0}$j$, $q$Hipérbole: exagero intencional.$q$, 1);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:1', 2, 'match', $q$Associe a frase à figura de linguagem$q$, $j${"pairs":[["Ele partiu desta para melhor","Eufemismo"],["Li Machado de Assis nas férias","Metonímia"],["O silêncio gritava no quarto","Personificação"],["Ela é forte como um touro","Comparação"]]}$j$, $q$Eufemismo suaviza; metonímia troca autor pela obra; personificação dá vida a coisas; comparação usa "como".$q$, 2);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:1', 3, 'tf', $q$Esta definição está certa?$q$, $j${"stmt":"Na ironia, dizemos o contrário do que pensamos para criticar ou brincar.","a":true}$j$, $q$Verdadeiro: "Que ótimo, choveu no dia do passeio!"$q$, 1);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:2', 0, 'mc', $q$Um anúncio que diz "Compre já!" usa predominantemente a função:$q$, $j${"opts":["Conativa (apelativa)","Referencial","Emotiva","Metalinguística"],"a":0}$j$, $q$Conativa: centrada no receptor, tenta convencê-lo.$q$, 1);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:2', 1, 'mc', $q$Um dicionário que explica o significado das palavras usa a função:$q$, $j${"opts":["Metalinguística","Fática","Poética","Emotiva"],"a":0}$j$, $q$Metalinguística: a língua explicando a própria língua.$q$, 2);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:2', 2, 'match', $q$Associe a frase à função da linguagem$q$, $j${"pairs":[["Alô, está me ouvindo?","Fática"],["Que dia lindo, estou feliz!","Emotiva"],["O Brasil tem 26 estados.","Referencial"],["A lua é um lago de prata","Poética"]]}$j$, $q$Fática testa o canal; emotiva é o emissor; referencial informa; poética trabalha a forma.$q$, 2);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:2', 3, 'tf', $q$Esta definição está certa?$q$, $j${"stmt":"A função referencial é centrada no emissor e em seus sentimentos.","a":false}$j$, $q$Falso: essa é a função emotiva. A referencial é centrada na informação.$q$, 2);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:3', 0, 'mc', $q$Um texto que apresenta tese, argumentos e conclusão é do tipo:$q$, $j${"opts":["Dissertativo-argumentativo","Narrativo","Descritivo","Injuntivo"],"a":0}$j$, $q$É a estrutura da redação do ENEM.$q$, 1);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:3', 1, 'mc', $q$Uma receita de bolo, com instruções passo a passo, é um texto:$q$, $j${"opts":["Injuntivo","Narrativo","Dissertativo","Lírico"],"a":0}$j$, $q$Injuntivo: dá ordens ou instruções.$q$, 1);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:3', 2, 'order', $q$Ordene a estrutura da redação do ENEM$q$, $j${"items":["Introdução com tese","Desenvolvimento 1","Desenvolvimento 2","Conclusão com proposta de intervenção"]}$j$, $q$Introdução, dois parágrafos de desenvolvimento e conclusão com proposta.$q$, 1);
select public.fj_seed_q('por', 'por:linguagem', 'por:linguagem:3', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["A redação do ENEM avalia "," competências, e cada uma vale até "," pontos."],"a":["5","200"],"extra":["4","100"]}$j$, $q$5 competências × 200 pontos = nota máxima 1.000.$q$, 1);

-- ---------------------------------------------------------------
-- BIOLOGIA · A célula
-- ---------------------------------------------------------------
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:1', 0, 'mc', $q$Em qual organela ocorre a respiração celular?$q$, $j${"opts":["Mitocôndria","Cloroplasto","Ribossomo","Lisossomo"],"a":0}$j$, $q$A mitocôndria produz energia (ATP) a partir da glicose e do oxigênio.$q$, 1);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:1', 1, 'mc', $q$A síntese de proteínas acontece nos:$q$, $j${"opts":["Ribossomos","Lisossomos","Vacúolos","Centríolos"],"a":0}$j$, $q$Os ribossomos "leem" o RNA mensageiro e montam as proteínas.$q$, 1);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:1', 2, 'match', $q$Associe a organela à sua função$q$, $j${"pairs":[["Mitocôndria","Produção de energia (ATP)"],["Cloroplasto","Fotossíntese"],["Lisossomo","Digestão intracelular"],["Complexo golgiense","Secreção e empacotamento"]]}$j$, $q$Cada organela tem um papel específico no funcionamento da célula.$q$, 2);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:1', 3, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Células vegetais possuem parede celular e cloroplastos; células animais, não.","a":true}$j$, $q$Verdadeiro: parede celular e cloroplastos são exclusivos das células vegetais.$q$, 1);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:2', 0, 'mc', $q$A passagem de água pela membrana, do meio menos concentrado para o mais concentrado, chama-se:$q$, $j${"opts":["Osmose","Difusão facilitada","Transporte ativo","Fagocitose"],"a":0}$j$, $q$Osmose é a difusão da água através de uma membrana semipermeável.$q$, 2);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:2', 1, 'mc', $q$O transporte que gasta energia (ATP) para mover substâncias contra o gradiente de concentração é o:$q$, $j${"opts":["Transporte ativo","Difusão simples","Osmose","Difusão facilitada"],"a":0}$j$, $q$Só o transporte ativo gasta energia; os outros são passivos.$q$, 2);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:2', 2, 'bank', $q$Complete a frase$q$, $j${"parts":["A membrana plasmática é formada por uma dupla camada de "," e tem permeabilidade ","."],"a":["fosfolipídios","seletiva"],"extra":["celulose","total"]}$j$, $q$Bicamada de fosfolipídios com proteínas, que deixa passar só algumas substâncias.$q$, 2);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:2', 3, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"Na difusão simples, as substâncias passam do meio mais concentrado para o menos concentrado, sem gasto de energia.","a":true}$j$, $q$Verdadeiro: a difusão segue o gradiente de concentração.$q$, 1);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:3', 0, 'mc', $q$A mitose produz:$q$, $j${"opts":["2 células idênticas à célula-mãe","4 células com metade dos cromossomos","2 células com metade dos cromossomos","1 célula maior"],"a":0}$j$, $q$A mitose gera duas células-filhas iguais à célula original.$q$, 1);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:3', 1, 'mc', $q$A meiose é importante porque:$q$, $j${"opts":["Forma gametas com metade dos cromossomos","Repara tecidos lesionados","Permite o crescimento do corpo","Produz células idênticas"],"a":0}$j$, $q$Com metade dos cromossomos, o gameta restaura o número normal na fecundação.$q$, 2);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:3', 2, 'order', $q$Ordene as fases da mitose$q$, $j${"items":["Prófase","Metáfase","Anáfase","Telófase"]}$j$, $q$Dica: PRÓ-ME-A-TE.$q$, 2);
select public.fj_seed_q('bio', 'bio:celula', 'bio:celula:3', 3, 'match', $q$Associe o processo à sua função$q$, $j${"pairs":[["Mitose","Crescimento e regeneração"],["Meiose","Formação de gametas"],["Interfase","Duplicação do DNA"],["Citocinese","Divisão do citoplasma"]]}$j$, $q$Cada etapa do ciclo celular tem um objetivo.$q$, 2);

-- BIOLOGIA · Ecossistemas
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:1', 0, 'mc', $q$Em uma cadeia alimentar, os produtores são:$q$, $j${"opts":["Organismos que fazem fotossíntese","Animais herbívoros","Animais carnívoros","Fungos e bactérias"],"a":0}$j$, $q$Plantas e algas produzem o próprio alimento pela fotossíntese.$q$, 1);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:1', 1, 'mc', $q$Os decompositores são importantes porque:$q$, $j${"opts":["Devolvem nutrientes ao solo","Produzem oxigênio","Caçam os herbívoros","Armazenam energia"],"a":0}$j$, $q$Fungos e bactérias reciclam a matéria orgânica morta.$q$, 1);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:1', 2, 'order', $q$Ordene a cadeia alimentar, do produtor ao consumidor final$q$, $j${"items":["Capim","Gafanhoto","Sapo","Cobra"]}$j$, $q$Produtor → consumidor primário → secundário → terciário.$q$, 1);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:1', 3, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A energia disponível diminui a cada nível trófico da cadeia alimentar.","a":true}$j$, $q$Verdadeiro: só cerca de 10% da energia passa de um nível para o seguinte.$q$, 2);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:2', 0, 'mc', $q$No ciclo do carbono, o principal processo que retira CO₂ da atmosfera é:$q$, $j${"opts":["Fotossíntese","Respiração","Combustão","Decomposição"],"a":0}$j$, $q$A fotossíntese transforma CO₂ em matéria orgânica.$q$, 1);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:2', 1, 'mc', $q$As bactérias fixadoras de nitrogênio vivem associadas às raízes de:$q$, $j${"opts":["Leguminosas","Gramíneas","Pinheiros","Algas"],"a":0}$j$, $q$Feijão, soja e outras leguminosas abrigam bactérias do gênero Rhizobium.$q$, 3);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:2', 2, 'match', $q$Associe o processo ao ciclo$q$, $j${"pairs":[["Evaporação","Ciclo da água"],["Fixação por bactérias","Ciclo do nitrogênio"],["Fotossíntese","Ciclo do carbono"],["Queima de combustíveis fósseis","Aumento do CO₂"]]}$j$, $q$Cada ciclo tem processos característicos.$q$, 2);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:2', 3, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A queima de combustíveis fósseis libera carbono que estava armazenado há milhões de anos.","a":true}$j$, $q$Verdadeiro: petróleo e carvão guardam carbono de organismos antigos.$q$, 1);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:3', 0, 'mc', $q$O excesso de nutrientes em lagos, que causa proliferação de algas e falta de oxigênio, chama-se:$q$, $j${"opts":["Eutrofização","Lixiviação","Salinização","Assoreamento"],"a":0}$j$, $q$Esgoto e fertilizantes alimentam algas, que consomem o oxigênio da água.$q$, 2);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:3', 1, 'mc', $q$O principal gás responsável pela intensificação do efeito estufa é o:$q$, $j${"opts":["Gás carbônico (CO₂)","Oxigênio (O₂)","Nitrogênio (N₂)","Hélio (He)"],"a":0}$j$, $q$O CO₂ retém calor na atmosfera.$q$, 1);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:3', 2, 'bank', $q$Complete a frase$q$, $j${"parts":["A "," protege a Terra dos raios ultravioleta, e os gases "," foram os principais responsáveis por sua destruição."],"a":["camada de ozônio","CFC"],"extra":["atmosfera","CO₂"]}$j$, $q$Os CFCs, usados em sprays e geladeiras, destroem o ozônio.$q$, 2);
select public.fj_seed_q('bio', 'bio:ecologia', 'bio:ecologia:3', 3, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"O desmatamento contribui para o aquecimento global porque reduz a captura de CO₂.","a":true}$j$, $q$Verdadeiro: menos árvores, menos fotossíntese, mais CO₂ no ar.$q$, 1);

-- ---------------------------------------------------------------
-- HISTÓRIA · Do Império à República
-- ---------------------------------------------------------------
select public.fj_seed_q('his', 'his:imperio', 'his:imperio:1', 0, 'mc', $q$A Independência do Brasil foi proclamada em:$q$, $j${"opts":["7 de setembro de 1822","15 de novembro de 1889","13 de maio de 1888","21 de abril de 1792"],"a":0}$j$, $q$7 de setembro de 1822, às margens do Ipiranga.$q$, 1);
select public.fj_seed_q('his', 'his:imperio', 'his:imperio:1', 1, 'mc', $q$Quem proclamou a Independência do Brasil?$q$, $j${"opts":["Dom Pedro I","Dom Pedro II","Dom João VI","Deodoro da Fonseca"],"a":0}$j$, $q$Dom Pedro I, filho de Dom João VI.$q$, 1);
select public.fj_seed_q('his', 'his:imperio', 'his:imperio:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A primeira Constituição do Brasil, de 1824, foi outorgada por Dom Pedro I.","a":true}$j$, $q$Verdadeiro: outorgada, ou seja, imposta pelo imperador após fechar a Assembleia.$q$, 2);
select public.fj_seed_q('his', 'his:imperio', 'his:imperio:1', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["Após a Independência, o Brasil adotou a "," como forma de governo, e Dom Pedro I abdicou em "," em favor do filho."],"a":["monarquia","1831"],"extra":["república","1840"]}$j$, $q$Monarquia constitucional; a abdicação foi em 7 de abril de 1831.$q$, 2);
select public.fj_seed_q('his', 'his:imperio', 'his:imperio:2', 0, 'mc', $q$A Lei Áurea, que aboliu a escravidão no Brasil, foi assinada em:$q$, $j${"opts":["1888","1822","1889","1850"],"a":0}$j$, $q$13 de maio de 1888, pela princesa Isabel.$q$, 1);
select public.fj_seed_q('his', 'his:imperio', 'his:imperio:2', 1, 'match', $q$Associe a lei ao que ela determinou$q$, $j${"pairs":[["Lei Eusébio de Queirós (1850)","Fim do tráfico de escravizados"],["Lei do Ventre Livre (1871)","Liberdade aos filhos de escravizadas"],["Lei dos Sexagenários (1885)","Liberdade aos maiores de 60 anos"],["Lei Áurea (1888)","Abolição da escravidão"]]}$j$, $q$A abolição foi gradual, ao longo de quase 40 anos.$q$, 2);
select public.fj_seed_q('his', 'his:imperio', 'his:imperio:2', 2, 'mc', $q$A Proclamação da República, em 1889, foi liderada por:$q$, $j${"opts":["Marechal Deodoro da Fonseca","Dom Pedro II","Getúlio Vargas","Tiradentes"],"a":0}$j$, $q$Deodoro da Fonseca, em 15 de novembro de 1889.$q$, 1);
select public.fj_seed_q('his', 'his:imperio', 'his:imperio:2', 3, 'order', $q$Ordene os acontecimentos, do mais antigo para o mais recente$q$, $j${"items":["Independência","Lei Eusébio de Queirós","Lei Áurea","Proclamação da República"]}$j$, $q$1822, 1850, 1888 e 1889.$q$, 2);

-- HISTÓRIA · Era Vargas e ditadura
select public.fj_seed_q('his', 'his:vargas', 'his:vargas:1', 0, 'mc', $q$Getúlio Vargas chegou ao poder em 1930 por meio de:$q$, $j${"opts":["Uma revolução que derrubou a República Velha","Eleição direta","Golpe militar apoiado pelos EUA","Herança do pai"],"a":0}$j$, $q$A Revolução de 1930 encerrou a República Velha e a política do café com leite.$q$, 2);
select public.fj_seed_q('his', 'his:vargas', 'his:vargas:1', 1, 'mc', $q$O período de 1937 a 1945, marcado pela ditadura de Vargas, é chamado de:$q$, $j${"opts":["Estado Novo","República Velha","Regime Militar","Nova República"],"a":0}$j$, $q$Estado Novo: Congresso fechado, censura e centralização do poder.$q$, 1);
select public.fj_seed_q('his', 'his:vargas', 'his:vargas:1', 2, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A CLT (Consolidação das Leis do Trabalho) foi criada no governo Vargas, em 1943.","a":true}$j$, $q$Verdadeiro: a CLT reuniu os direitos trabalhistas em uma só lei.$q$, 1);
select public.fj_seed_q('his', 'his:vargas', 'his:vargas:1', 3, 'bank', $q$Complete a frase$q$, $j${"parts":["O revezamento de presidentes entre São Paulo e Minas Gerais na República Velha era conhecido como política do "," com ","."],"a":["café","leite"],"extra":["açúcar","ouro"]}$j$, $q$Café (São Paulo) com leite (Minas Gerais).$q$, 1);
select public.fj_seed_q('his', 'his:vargas', 'his:vargas:2', 0, 'mc', $q$O golpe que iniciou a ditadura militar no Brasil ocorreu em:$q$, $j${"opts":["1964","1930","1985","1954"],"a":0}$j$, $q$31 de março / 1º de abril de 1964, derrubando João Goulart.$q$, 1);
select public.fj_seed_q('his', 'his:vargas', 'his:vargas:2', 1, 'mc', $q$O AI-5, de 1968, ficou conhecido por:$q$, $j${"opts":["Endurecer a repressão e suspender direitos","Convocar eleições diretas","Anistiar presos políticos","Criar a nova Constituição"],"a":0}$j$, $q$O Ato Institucional nº 5 fechou o Congresso e suspendeu o habeas corpus.$q$, 2);
select public.fj_seed_q('his', 'his:vargas', 'his:vargas:2', 2, 'match', $q$Associe o acontecimento ao seu significado$q$, $j${"pairs":[["Diretas Já (1984)","Campanha por eleições diretas"],["Lei da Anistia (1979)","Retorno de exilados políticos"],["Constituição de 1988","Fim da transição democrática"],["AI-5 (1968)","Auge da repressão"]]}$j$, $q$Marcos da ditadura e da redemocratização.$q$, 2);
select public.fj_seed_q('his', 'his:vargas', 'his:vargas:2', 3, 'tf', $q$Esta afirmação está certa?$q$, $j${"stmt":"A ditadura militar brasileira terminou em 1985, com a eleição indireta de Tancredo Neves.","a":true}$j$, $q$Verdadeiro: Tancredo foi eleito pelo Colégio Eleitoral, mas morreu antes de tomar posse; José Sarney assumiu.$q$, 2);

-- Limpeza
drop function public.fj_seed_q(text, text, text, int, text, text, jsonb, text, int);
