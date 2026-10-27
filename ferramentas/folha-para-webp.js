// Converte a folha de sprites PNG que o assar-gif-fundo-preto.ps1 grava no WebP que o app
// carrega, quantizando as cores antes.
//
// A quantização não é capricho — é o que decide o tamanho do arquivo. A folha sai do
// PowerShell redimensionada com interpolação bicúbica, e isso transforma a arte chapada
// (algumas dezenas de cores) em mais de 100 mil tons ligeiramente diferentes: só a
// eletricidade tinha 121 mil. O WebP sem perda guarda esse ruído fielmente, e a folha
// da eletricidade saía com 1,8 MB em vez dos 350 KB das outras mascotes.
//
// Corte mediano sem dithering, o mesmo de assar-sprite.js: dither recriaria justamente o
// ruído que estamos tirando. 384 cores é o que as mascotes vêm usando; abaixo disso o
// degradê dos raios e do brilho começa a formar faixas visíveis.
//
// Uso: node folha-para-webp.js folha.png ../app/rapozinha-xxx.webp [cores]
// Precisa do ffmpeg no PATH (winget install Gyan.FFmpeg).

const fs = require('fs');
const { execFileSync } = require('child_process');

const [SRC, OUT, CSTR] = process.argv.slice(2);
if (!SRC || !OUT) { console.error('uso: node folha-para-webp.js folha.png saida.webp [cores]'); process.exit(1); }
const CORES = +CSTR || 384;
const FF = process.env.FFMPEG || 'ffmpeg';
const FP = FF.replace(/ffmpeg(\.exe)?$/i, m => m.replace('ffmpeg', 'ffprobe'));

const info = JSON.parse(execFileSync(FP, ['-v', 'error', '-select_streams', 'v:0',
  '-show_entries', 'stream=width,height', '-of', 'json', SRC], {encoding: 'utf8'}));
const {width: W, height: H} = info.streams[0];
const px = execFileSync(FF, ['-v', 'error', '-i', SRC, '-f', 'rawvideo', '-pix_fmt', 'rgba', '-'], {maxBuffer: 1 << 30});

// ---- corte mediano (portado de assar-sprite.js) ----
function quantizar(folha, nCores) {
  const cont = new Map();
  for (let i = 0; i < folha.length; i += 4) {
    if (folha[i + 3] === 0) continue;
    const k = (folha[i] << 16) | (folha[i + 1] << 8) | folha[i + 2];
    cont.set(k, (cont.get(k) || 0) + 1);
  }
  const cores = [...cont].map(([k, n]) => ({r: k >> 16 & 255, g: k >> 8 & 255, b: k & 255, n}));
  console.log(`  ${cores.length} cores distintas`);
  if (cores.length <= nCores) return null;
  const faixa = c => {
    let lo = [255, 255, 255], hi = [0, 0, 0];
    for (const p of c) { const v = [p.r, p.g, p.b]; for (let j = 0; j < 3; j++) { if (v[j] < lo[j]) lo[j] = v[j]; if (v[j] > hi[j]) hi[j] = v[j]; } }
    return [hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]];
  };
  let caixas = [cores];
  while (caixas.length < nCores) {
    let alvo = -1, maior = 0;
    caixas.forEach((c, i) => { if (c.length < 2) return; const m = Math.max(...faixa(c)); if (m > maior) { maior = m; alvo = i; } });
    if (alvo < 0) break;
    const c = caixas[alvo], eixo = faixa(c).indexOf(maior), ch = ['r', 'g', 'b'][eixo];
    c.sort((a, b) => a[ch] - b[ch]);
    const meio = Math.max(1, Math.min(c.length - 1, c.length >> 1));
    caixas.splice(alvo, 1, c.slice(0, meio), c.slice(meio));
  }
  const mapa = new Map();
  for (const c of caixas) {
    let r = 0, g = 0, b = 0, t = 0;
    for (const p of c) { r += p.r * p.n; g += p.g * p.n; b += p.b * p.n; t += p.n; }
    const cor = [Math.round(r / t), Math.round(g / t), Math.round(b / t)];
    for (const p of c) mapa.set((p.r << 16) | (p.g << 8) | p.b, cor);
  }
  return mapa;
}

const mapa = quantizar(px, CORES);
if (mapa) for (let i = 0; i < px.length; i += 4) {
  if (px[i + 3] === 0) continue;
  const p = mapa.get((px[i] << 16) | (px[i + 1] << 8) | px[i + 2]);
  if (p) { px[i] = p[0]; px[i + 1] = p[1]; px[i + 2] = p[2]; }
}
execFileSync(FF, ['-y', '-v', 'error', '-f', 'rawvideo', '-pixel_format', 'rgba', '-video_size', `${W}x${H}`,
  '-i', '-', '-c:v', 'libwebp', '-lossless', '1', '-compression_level', '6', OUT], {input: px, maxBuffer: 1 << 30});
console.log(`  ${SRC} -> ${OUT}: ${Math.round(fs.statSync(OUT).size / 1024)} KB`);
