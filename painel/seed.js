// Conteúdo inicial importado do protótipo (só as 3 matérias do lançamento).
// O painel usa isto uma única vez, quando o banco está vazio ("Importar conteúdo inicial").
window.FJ_SEED = {
  materias: [
    {id: 'mat', nome: 'Matemática', sigla: 'MA', cor: '#503C9D', ativa: true, ordem: 0, secoes: [
      {titulo: 'Fundamentos', unidades: [
        {titulo: 'Múltiplos e divisores', licoes: []},
        {titulo: 'MMC e MDC', licoes: []}]},
      {titulo: 'Frações e proporção', unidades: [
        {chave: 'fra', titulo: 'Frações e decimais', licoes: ['O que é uma fração', 'Frações equivalentes', 'Somar e subtrair frações', 'Multiplicar frações', 'Dividir frações', 'Frações e decimais']},
        {chave: 'pct', titulo: 'Porcentagem', licoes: ['Porcentagem de um valor', 'Desconto e acréscimo', 'Porcentagem e frações', 'Aumentos sucessivos', 'Problemas do ENEM']},
        {titulo: 'Razão e proporção', licoes: []}]},
      {titulo: 'Álgebra básica', unidades: []},
      {titulo: 'Geometria plana', unidades: []}]},
    {id: 'por', nome: 'Português', sigla: 'PT', cor: '#4CC3C1', ativa: true, ordem: 1, secoes: [
      {titulo: 'Norma-padrão', unidades: [
        {chave: 'por', titulo: 'Crase, acentuação e concordância', licoes: ['Quando usar crase', 'Acentuação gráfica', 'Concordância verbal', 'Sinônimos e sentido']}]}]},
    {id: 'bio', nome: 'Biologia', sigla: 'BI', cor: '#2F7D4F', ativa: true, ordem: 2, secoes: [
      {titulo: 'Citologia', unidades: [
        {chave: 'bio', titulo: 'A célula', licoes: ['Organelas', 'Fotossíntese', 'Mitose e meiose', 'DNA']}]}]}
  ],
  questoes: [
    {materia: 'mat', unidade: 'fra', tipo: 'mc', enunciado: 'Qual fração é equivalente a 3/4?', dados: {opts: ['6/8', '4/6', '9/16', '3/8'], a: 0}, explicacao: '6/8: multiplique numerador e denominador por 2.'},
    {materia: 'mat', unidade: 'fra', tipo: 'mc', enunciado: 'Quanto é 1/4 + 2/4?', dados: {opts: ['3/4', '3/8', '2/4', '1/2'], a: 0}, explicacao: 'Mesmo denominador: some os numeradores.'},
    {materia: 'mat', unidade: 'fra', tipo: 'mc', enunciado: 'Quanto é 1/2 + 1/3?', dados: {opts: ['5/6', '2/5', '2/6', '1/6'], a: 0}, explicacao: 'O MMC de 2 e 3 é 6: 3/6 + 2/6 = 5/6.'},
    {materia: 'mat', unidade: 'fra', tipo: 'mc', enunciado: 'Qual é o resultado de 2/3 × 3/4?', dados: {opts: ['1/2', '5/7', '8/9', '3/2'], a: 0}, explicacao: 'Multiplique em linha: 6/12 = 1/2.'},
    {materia: 'mat', unidade: 'fra', tipo: 'mc', enunciado: 'Simplifique 12/18.', dados: {opts: ['2/3', '3/4', '6/8', '4/9'], a: 0}, explicacao: 'Divida os dois por 6.'},
    {materia: 'mat', unidade: 'fra', tipo: 'mc', enunciado: 'Quanto é 3/5 ÷ 1/2?', dados: {opts: ['6/5', '3/10', '5/6', '3/7'], a: 0}, explicacao: 'Inverta a segunda e multiplique.', status: 'rascunho'},
    {materia: 'mat', unidade: 'fra', tipo: 'bank', enunciado: 'Complete a frase', dados: {parts: ['Para somar frações com o mesmo denominador, somamos os ', ' e mantemos o ', '.'], a: ['numeradores', 'denominador'], extra: ['inteiros', 'divisores']}, explicacao: 'Somamos os numeradores e mantemos o denominador.'},
    {materia: 'mat', unidade: 'fra', tipo: 'bank', enunciado: 'Complete a frase', dados: {parts: ['Na fração 3/5, o 3 é o ', ' e o 5 é o ', '.'], a: ['numerador', 'denominador'], extra: ['quociente', 'resto']}, explicacao: 'O de cima é o numerador; o de baixo, o denominador.'},
    {materia: 'mat', unidade: 'fra', tipo: 'order', enunciado: 'Ordene da menor para a maior', dados: {items: ['1/8', '1/4', '1/2', '3/4']}, explicacao: 'Ordem correta: 1/8, 1/4, 1/2, 3/4.'},
    {materia: 'mat', unidade: 'fra', tipo: 'order', enunciado: 'Ordene do menor para o maior', dados: {items: ['1/4', '0,5', '3/5', '0,8']}, explicacao: '0,25 < 0,5 < 0,6 < 0,8.'},
    {materia: 'mat', unidade: 'fra', tipo: 'match', enunciado: 'Associe cada fração ao seu decimal', dados: {pairs: [['1/2', '0,5'], ['1/4', '0,25'], ['3/4', '0,75'], ['1/5', '0,2']]}, explicacao: '1/2 = 0,5 · 1/4 = 0,25 · 3/4 = 0,75 · 1/5 = 0,2.'},
    {materia: 'mat', unidade: 'fra', tipo: 'tf', enunciado: 'Esta comparação está certa?', dados: {stmt: '0,8 > 4/5', a: false}, explicacao: 'Falso: 0,8 é igual a 4/5.'},
    {materia: 'mat', unidade: 'fra', tipo: 'tf', enunciado: 'Esta igualdade está certa?', dados: {stmt: '3/6 = 1/2', a: true}, explicacao: 'Verdadeiro: divida por 3.'},
    {materia: 'mat', unidade: 'pct', tipo: 'mc', enunciado: 'Quanto é 25% de 80?', dados: {opts: ['20', '25', '32', '40'], a: 0}, explicacao: '25% é 1/4. 80 ÷ 4 = 20.'},
    {materia: 'mat', unidade: 'pct', tipo: 'mc', enunciado: 'Um produto de R$ 200 teve 10% de desconto. Qual o novo preço?', dados: {opts: ['R$ 180', 'R$ 190', 'R$ 160', 'R$ 210'], a: 0}, explicacao: '10% de 200 = 20.'},
    {materia: 'mat', unidade: 'pct', tipo: 'tf', enunciado: 'Esta afirmação está certa?', dados: {stmt: 'Aumentar 10% e depois reduzir 10% volta ao valor inicial', a: false}, explicacao: 'Falso: 100 → 110 → 99.'},
    {materia: 'mat', unidade: 'pct', tipo: 'match', enunciado: 'Associe a porcentagem à fração', dados: {pairs: [['50%', '1/2'], ['25%', '1/4'], ['20%', '1/5'], ['10%', '1/10']]}, explicacao: 'Equivalências básicas.'},
    {materia: 'por', unidade: 'por', tipo: 'mc', enunciado: 'Em qual frase a crase está correta?', dados: {opts: ['Fui à escola cedo.', 'Fui à pé para casa.', 'Começou à chover.', 'Entreguei à ele o livro.'], a: 0}, explicacao: 'Crase só antes de palavra feminina que aceita artigo.'},
    {materia: 'por', unidade: 'por', tipo: 'tf', enunciado: 'Esta frase está correta?', dados: {stmt: 'Haviam muitas pessoas na fila.', a: false}, explicacao: '"Haver" no sentido de existir não vai ao plural.'},
    {materia: 'por', unidade: 'por', tipo: 'bank', enunciado: 'Complete a frase', dados: {parts: ['"Mal" é o oposto de ', ' e "mau" é o oposto de ', '.'], a: ['bem', 'bom'], extra: ['ruim', 'pior']}, explicacao: 'Mal × bem; mau × bom.'},
    {materia: 'por', unidade: 'por', tipo: 'order', enunciado: 'Monte a frase', dados: {items: ['Os', 'livros', 'estão', 'na', 'mesa']}, explicacao: 'Os livros estão na mesa.'},
    {materia: 'bio', unidade: 'bio', tipo: 'mc', enunciado: 'Em qual organela ocorre a fotossíntese?', dados: {opts: ['Cloroplasto', 'Mitocôndria', 'Ribossomo', 'Núcleo'], a: 0}, explicacao: 'No cloroplasto, que tem clorofila.'},
    {materia: 'bio', unidade: 'bio', tipo: 'match', enunciado: 'Associe a organela à função', dados: {pairs: [['Mitocôndria', 'Respiração celular'], ['Ribossomo', 'Síntese de proteínas'], ['Cloroplasto', 'Fotossíntese'], ['Lisossomo', 'Digestão celular']]}, explicacao: 'Cada organela tem uma função.'}
  ]
};
