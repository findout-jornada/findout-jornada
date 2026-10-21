// Validação completa das questões de TODAS as fontes do repositório:
// migrations de conteúdo (fj_seed_q) + painel/seed.js.
// Checa: JSON, formato por tipo, resposta dentro do intervalo, alternativas
// repetidas, banco de palavras conflitante, pares ambíguos, itens repetidos,
// enunciado duplicado na mesma lição (perderia questão no ON CONFLICT),
// campos vazios e distribuição da posição do gabarito (mc) por arquivo.
const fs = require('fs');
const base = 'C:/Users/Artur Morais/Documents/GitHub/findout-jornada/';
const arquivos = ['0005_conteudo.sql', '0006_conteudo_mais_materias.sql', '0007_conteudo_5_secoes.sql',
  '0013_conteudo_mais_secoes.sql', '0015_espanhol.sql', '0029_literatura.sql', '0030_conhecimentos_gerais.sql',
  '0035_etica_cidadania.sql', '0036_arte.sql', '0037_ciencias.sql', '0041_curso_dev.sql',
  '0042_logica_programacao.sql', '0043_analise_ciencia_dados.sql'];
let erros = [], avisos = [], totalQ = 0;
const err = m => erros.push(m);
const avi = m => avisos.push(m);
const t = s => String(s == null ? '' : s).trim();

function checaQuestao(fonte, lic, tipo, enun, d, expl) {
  const onde = `${fonte} · ${lic} · "${t(enun).slice(0, 48)}"`;
  if (!t(enun)) err(`${onde}: enunciado vazio`);
  if (!t(expl)) avi(`${onde}: sem explicação`);
  if (tipo === 'mc') {
    if (!Array.isArray(d.opts) || d.opts.length !== 4) return err(`${onde}: mc sem 4 alternativas`);
    if (d.opts.some(o => !t(o))) err(`${onde}: alternativa vazia`);
    const setO = new Set(d.opts.map(o => t(o).toLowerCase()));
    if (setO.size !== 4) err(`${onde}: alternativas repetidas`);
    if (typeof d.a !== 'number' || d.a < 0 || d.a > 3 || !Number.isInteger(d.a)) err(`${onde}: resposta (a=${d.a}) fora de 0..3`);
  } else if (tipo === 'tf') {
    if (!t(d.stmt)) err(`${onde}: tf sem afirmação`);
    if (typeof d.a !== 'boolean') err(`${onde}: tf com resposta não booleana (${JSON.stringify(d.a)})`);
  } else if (tipo === 'bank') {
    if (!Array.isArray(d.parts) || d.parts.length < 2 || d.parts.length > 3) err(`${onde}: bank com parts inválido`);
    if (!Array.isArray(d.a) || d.a.length !== 2 || d.a.some(w => !t(w))) err(`${onde}: bank precisa de 2 respostas`);
    if (!Array.isArray(d.extra) || !d.extra.length || d.extra.some(w => !t(w))) err(`${onde}: bank sem palavras extras`);
    if (Array.isArray(d.a) && Array.isArray(d.extra)) {
      const aSet = new Set(d.a.map(w => t(w).toLowerCase()));
      d.extra.forEach(w => { if (aSet.has(t(w).toLowerCase())) avi(`${onde}: palavra extra "${w}" igual a uma resposta`); });
      if (t(d.a[0]).toLowerCase() === t(d.a[1]).toLowerCase()) avi(`${onde}: as duas lacunas têm a mesma palavra`);
    }
  } else if (tipo === 'order') {
    if (!Array.isArray(d.items) || d.items.length < 3) err(`${onde}: order com menos de 3 itens`);
    else if (new Set(d.items.map(w => t(w).toLowerCase())).size !== d.items.length) err(`${onde}: itens repetidos no order (correção ambígua)`);
  } else if (tipo === 'match') {
    if (!Array.isArray(d.pairs) || d.pairs.length !== 4 || d.pairs.some(p => !Array.isArray(p) || p.length !== 2 || !t(p[0]) || !t(p[1]))) return err(`${onde}: match sem 4 pares completos`);
    if (new Set(d.pairs.map(p => t(p[0]).toLowerCase())).size !== 4) err(`${onde}: lados esquerdos repetidos no match (impossível acertar)`);
    if (new Set(d.pairs.map(p => t(p[1]).toLowerCase())).size !== 4) avi(`${onde}: lados direitos repetidos no match`);
  } else err(`${onde}: tipo desconhecido "${tipo}"`);
}

for (const f of arquivos) {
  const sql = fs.readFileSync(base + 'supabase/migrations/' + f, 'utf8');
  const chamadas = [...sql.matchAll(/fj_seed_q\(\s*'(\w+)',\s*'([^']+)',\s*'([^']+)',\s*(\d+),\s*'(\w+)',\s*\$q\$([\s\S]*?)\$q\$,\s*\$j\$([\s\S]*?)\$j\$,\s*\$q\$([\s\S]*?)\$q\$(?:,\s*(\d))?\s*\)/g)];
  // confere se alguma chamada escapou do regex
  const brutas = (sql.match(/select public\.fj_seed_q\(/g) || []).length;
  if (brutas !== chamadas.length) err(`${f}: ${brutas} chamadas no arquivo, ${chamadas.length} interpretadas — formato fora do padrão em alguma linha`);
  const porLicao = {}, posMc = [0, 0, 0, 0];
  let mc = 0;
  chamadas.forEach(m => {
    const [, mat, uni, lic, ordem, tipo, enun, json, expl, dif] = m;
    totalQ++;
    let d; try { d = JSON.parse(json); } catch (e) { return err(`${f} · ${lic}: JSON inválido (${e.message}) em "${t(enun).slice(0, 40)}"`); }
    porLicao[lic] = porLicao[lic] || [];
    if (porLicao[lic].includes(t(enun))) err(`${f} · ${lic}: enunciado DUPLICADO (a 2ª questão se perde): "${t(enun).slice(0, 60)}"`);
    porLicao[lic].push(t(enun));
    if (tipo === 'mc' && typeof d.a === 'number' && d.a >= 0 && d.a <= 3) { posMc[d.a]++; mc++; }
    checaQuestao(f, lic, tipo, enun, d, expl);
  });
  const nLic = Object.keys(porLicao).length;
  const dist = mc ? posMc.map(n => Math.round(100 * n / mc)).join('/') : '—';
  console.log(`${f}: ${chamadas.length} questões · ${nLic} lições · gabarito mc em A/B/C/D: ${dist}% (${mc} mc)`);
  Object.entries(porLicao).forEach(([l, qs]) => { if (qs.length < 4) avi(`${f}: lição ${l} com só ${qs.length} questões`); });
}

// painel/seed.js
const js = fs.readFileSync(base + 'painel/seed.js', 'utf8');
const window = {}; eval(js.replace(/^window\./m, 'window.'));
const S = window.FJ_SEED;
const porUni = {};
S.questoes.forEach(q => {
  totalQ++;
  porUni[q.unidade] = porUni[q.unidade] || [];
  if (porUni[q.unidade].includes(t(q.enunciado))) avi(`seed.js · ${q.unidade}: enunciado repetido "${t(q.enunciado).slice(0, 50)}"`);
  porUni[q.unidade].push(t(q.enunciado));
  checaQuestao('seed.js', q.unidade, q.tipo, q.enunciado, q.dados || {}, q.explicacao);
});
const posSeed = [0, 0, 0, 0]; let mcSeed = 0;
S.questoes.forEach(q => { if (q.tipo === 'mc') { posSeed[q.dados.a]++; mcSeed++; } });
console.log(`seed.js: ${S.questoes.length} questões · gabarito mc em A/B/C/D: ${posSeed.map(n => Math.round(100 * n / Math.max(1, mcSeed))).join('/')}% (${mcSeed} mc)`);

console.log('\n=== TOTAL: ' + totalQ + ' questões validadas');
console.log('\n--- ERROS (' + erros.length + ') ---'); erros.forEach(e => console.log('  ✗ ' + e));
console.log('\n--- AVISOS (' + avisos.length + ') ---'); avisos.forEach(a => console.log('  • ' + a));
process.exitCode = erros.length ? 1 : 0;
