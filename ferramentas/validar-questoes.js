// Visão GLOBAL: reconstrói o estado final do banco aplicando as migrations de
// conteúdo em ordem (inserts com on-conflict-do-nothing + deletes de correção)
// e valida o conjunto resultante, como ele existe no Supabase.
const fs = require('fs');
const base = 'C:/Users/Artur Morais/Documents/GitHub/findout-jornada/supabase/migrations/';
const ordem = ['0005_conteudo.sql', '0006_conteudo_mais_materias.sql', '0007_conteudo_5_secoes.sql',
  '0013_conteudo_mais_secoes.sql', '0015_espanhol.sql', '0029_literatura.sql', '0030_conhecimentos_gerais.sql',
  '0035_etica_cidadania.sql', '0036_arte.sql', '0037_ciencias.sql', '0041_curso_dev.sql',
  '0042_logica_programacao.sql', '0043_analise_ciencia_dados.sql', '0044_geometria.sql', '0045_raciocinio_logico.sql'];
const t = s => String(s == null ? '' : s).trim();
const banco = new Map();   // id(lic|enun) -> {arq, lic, mat, tipo, enun, dados}
let erros = [], avisos = [];

for (const f of ordem) {
  const sql = fs.readFileSync(base + f, 'utf8');
  // deletes de correção: md5('q:<lic>|<enun>') dentro de delete from questoes
  for (const del of sql.matchAll(/delete from public\.questoes where id in \(([\s\S]*?)\);/g)) {
    for (const m of del[1].matchAll(/md5\('q:([^|]+)\|([^']+)'\)::uuid/g)) {
      const chave = m[1] + '|' + m[2];
      if (!banco.has(chave)) avisos.push(`${f}: delete de questão que não existia: ${chave.slice(0, 70)}`);
      banco.delete(chave);
    }
  }
  for (const m of sql.matchAll(/fj_seed_q\(\s*'(\w+)',\s*'([^']+)',\s*'([^']+)',\s*(\d+),\s*'(\w+)',\s*\$q\$([\s\S]*?)\$q\$,\s*\$j\$([\s\S]*?)\$j\$,\s*\$q\$([\s\S]*?)\$q\$(?:,\s*(\d))?\s*\)/g)) {
    const [, mat, uni, lic, ord, tipo, enun, json] = m;
    const chave = lic + '|' + enun;
    let d; try { d = JSON.parse(json); } catch (e) { erros.push(`${f} · ${lic}: JSON inválido`); continue; }
    if (banco.has(chave)) {
      const antes = banco.get(chave);
      if (JSON.stringify(antes.dados) !== JSON.stringify(d) || antes.tipo !== tipo)
        erros.push(`${f} · ${lic}: reinsere "${t(enun).slice(0, 50)}" com CONTEÚDO DIFERENTE de ${antes.arq} — o on conflict ignora e a versão nova NÃO entra`);
      continue;   // mesma questão re-afirmada: sem efeito
    }
    banco.set(chave, {arq: f, lic, mat, tipo, enun: t(enun), dados: d});
  }
}

// contagem final por lição e por matéria + distribuição do gabarito mc por matéria
const porLic = {}, porMat = {}, posMat = {};
for (const q of banco.values()) {
  (porLic[q.lic] = porLic[q.lic] || []).push(q);
  porMat[q.mat] = (porMat[q.mat] || 0) + 1;
  if (q.tipo === 'mc') { (posMat[q.mat] = posMat[q.mat] || [0, 0, 0, 0, 0])[q.dados.a]++; posMat[q.mat][4]++; }
}
console.log('=== Estado final reconstruído: ' + banco.size + ' questões em ' + Object.keys(porLic).length + ' lições\n');
console.log('Por matéria (questões · gabarito mc em A/B/C/D %):');
Object.keys(porMat).sort().forEach(m2 => {
  const p = posMat[m2] || [0, 0, 0, 0, 0];
  console.log(`  ${m2}: ${porMat[m2]} · ${p[4] ? p.slice(0, 4).map(n => Math.round(100 * n / p[4])).join('/') : '—'} (${p[4]} mc)`);
});
const magras = Object.entries(porLic).filter(([, qs]) => qs.length < 4);
console.log('\nLições com menos de 4 questões próprias: ' + (magras.length ? '' : 'nenhuma'));
magras.forEach(([l, qs]) => console.log(`  • ${l}: ${qs.length} (${qs.map(q => q.tipo).join(', ')})`));
console.log('\n--- ERROS (' + erros.length + ') ---'); erros.forEach(e => console.log('  ✗ ' + e));
console.log('--- AVISOS (' + avisos.length + ') ---'); avisos.forEach(a => console.log('  • ' + a));
process.exitCode = erros.length ? 1 : 0;
