// Assa um MP4 da Rapozinha (era roxa, fundo chapado) numa folha de sprites WebP pronta
// para o app: quadros lado a lado, com o chroma key e a recoloração já aplicados.
//
// Antes, esse trabalho rodava no navegador: um <video> escondido, um canvas e o chroma key
// pixel a pixel a 60 fps, porque MP4 não tem canal alfa. Fazendo uma vez só, aqui, o app
// recebe alfa de verdade, perde o canvas e o requestAnimationFrame, e os arquivos caem de
// 1.778 KB para 532 KB nos três humores.
//
// A quantização não é capricho: o MP4 é comprimido com perda, então a arte chapada chega
// com ~104 mil cores de ruído (o sprite PNG equivalente tem ~7 mil). Sem colapsar isso, o
// WebP sem perda guarda o ruído fielmente e o arquivo sai maior que o vídeo. Corte mediano
// sem dithering — dither recria justamente o ruído que estamos tirando.
//
// Uso: node assar-sprite.js entrada.mp4 saida.webp [largura] [fps] [cores]
//      node assar-sprite.js ../app-orig/rapozinha-triste.mp4 ../app/rapozinha-triste.webp 240 12 1024
// Precisa do ffmpeg no PATH (winget install Gyan.FFmpeg).
// No fim ele imprime a linha pronta para colar em SPRITES, no app/index.html.

const fs = require('fs');
const { execFileSync } = require('child_process');

const [SRC, OUT, WSTR, FSTR, CSTR] = process.argv.slice(2);
if (!SRC || !OUT) { console.error('uso: node assar-sprite.js entrada.mp4 saida.webp [largura] [fps] [cores]'); process.exit(1); }
const LARGURA = +WSTR || 240;     // largura de UM quadro; o app desenha a mascote com 56–160 px
const FPS = +FSTR || 12;          // metade dos 24 do vídeo, como já foi feito no sprite feliz3
const CORES = +CSTR || 1024;      // 1024 é indistinguível de 4096 nesta arte, e 25% menor
const FF = process.env.FFMPEG || 'ffmpeg';

// ---- as mesmas regras de cor que o app usava em tempo real ----
// azuis/roxos médios (matiz 200–300) viram azul royal (227, mais saturado; os escuros viram a
// sombra), lavanda/cinza claro e rosa viram quase branco, bege/laranja (fones) vira o laranja
// da marca, e teal/ciano (140–205) vira laranja (27). Cache por cor: a arte tem poucas cores.
const RECOR = new Map();
function hsl2rgb(h, s, l) {
  h = ((h % 360) + 360) % 360 / 360;
  const q = l < .5 ? l * (1 + s) : l + s - l * s, p2 = 2 * l - q;
  const f = t => { if (t < 0) t += 1; if (t > 1) t -= 1; return t < 1 / 6 ? p2 + (q - p2) * 6 * t : t < 1 / 2 ? q : t < 2 / 3 ? p2 + (q - p2) * (2 / 3 - t) * 6 : p2; };
  return [Math.round(f(h + 1 / 3) * 255), Math.round(f(h) * 255), Math.round(f(h - 1 / 3) * 255)];
}
function recor(r, g, b) {
  const k = (r << 16) | (g << 8) | b;
  let v = RECOR.get(k);
  if (v !== undefined) return v;
  const r1 = r / 255, g1 = g / 255, b1 = b / 255;
  const max = Math.max(r1, g1, b1), min = Math.min(r1, g1, b1), d = max - min, l = (max + min) / 2;
  let h = 0, s = 0;
  if (d) {
    s = l > .5 ? d / (2 - max - min) : d / (max + min);
    h = (max === r1 ? (g1 - b1) / d + (g1 < b1 ? 6 : 0) : max === g1 ? (b1 - r1) / d + 2 : (r1 - g1) / d + 4) * 60;
  }
  let novo = null;
  if (h >= 200 && h <= 300 && s > .25 && l >= .15 && l < .65) novo = l < .36 ? hsl2rgb(227, .66, Math.min(.42, l * 1.22)) : hsl2rgb(227, .68, Math.max(.48, Math.min(.56, l * 1.2)));
  else if (l > .65 && (s < .35 || (h >= 290 && h <= 350) || (h >= 200 && h <= 290 && s < .6))) { if (l < .97) novo = hsl2rgb(227, .5, .95); }
  else if (h >= 10 && h <= 45 && s > .3 && l >= .3 && l <= .75) novo = hsl2rgb(31, .93, .54);
  else if (h >= 140 && h <= 205 && s > .08 && l > .3) novo = hsl2rgb(27, s, l);
  RECOR.set(k, novo);
  return novo;
}

// ---- corte mediano ----
function quantizar(folha, nCores) {
  const cont = new Map();
  for (let i = 0; i < folha.length; i += 4) {
    if (folha[i + 3] === 0) continue;
    const k = (folha[i] << 16) | (folha[i + 1] << 8) | folha[i + 2];
    cont.set(k, (cont.get(k) || 0) + 1);
  }
  const cores = [...cont].map(([k, n]) => ({r: k >> 16 & 255, g: k >> 8 & 255, b: k & 255, n}));
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

// ---- 1. decodifica os quadros já na escala final ----
const info = JSON.parse(execFileSync(FF.replace(/ffmpeg(\.exe)?$/i, (m) => m.replace('ffmpeg', 'ffprobe')),
  ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'json', SRC], {encoding: 'utf8'}));
const {width: vw, height: vh} = info.streams[0];
const ALTURA = Math.round(vh * LARGURA / vw);
const cru = execFileSync(FF, ['-v', 'error', '-i', SRC, '-vf', `fps=${FPS},scale=${LARGURA}:${ALTURA}:flags=lanczos`,
  '-f', 'rawvideo', '-pix_fmt', 'rgba', '-'], {maxBuffer: 1 << 30});
const porQuadro = LARGURA * ALTURA * 4;
const N = Math.floor(cru.length / porQuadro);
if (!N) { console.error('nenhum quadro saiu de ' + SRC); process.exit(1); }

// ---- 2. chroma key + recoloração, quadro a quadro, montando a folha ----
// a cor de fundo vem do primeiro pixel do primeiro quadro, como o app fazia
const bg = [cru[0], cru[1], cru[2]];
const LARG = LARGURA * N;
const folha = Buffer.alloc(LARG * ALTURA * 4);
for (let q = 0; q < N; q++) {
  const base = q * porQuadro;
  for (let y = 0; y < ALTURA; y++) for (let x = 0; x < LARGURA; x++) {
    const i = base + (y * LARGURA + x) * 4;
    let r = cru[i], g = cru[i + 1], b = cru[i + 2], a = 255;
    const dist = Math.abs(r - bg[0]) + Math.abs(g - bg[1]) + Math.abs(b - bg[2]);
    if (dist < 30) { a = 0; r = g = b = 0; }                       // fundo
    else {
      if (dist < 60) a = Math.round((dist - 30) / 30 * 255);       // borda: alfa em rampa
      const nc = recor(r, g, b);
      if (nc) { r = nc[0]; g = nc[1]; b = nc[2]; }
    }
    const o = (y * LARG + q * LARGURA + x) * 4;
    folha[o] = r; folha[o + 1] = g; folha[o + 2] = b; folha[o + 3] = a;
  }
}

// ---- 3. quantiza e grava em WebP sem perda ----
const mapa = quantizar(folha, CORES);
if (mapa) for (let i = 0; i < folha.length; i += 4) {
  if (folha[i + 3] === 0) continue;
  const p = mapa.get((folha[i] << 16) | (folha[i + 1] << 8) | folha[i + 2]);
  if (p) { folha[i] = p[0]; folha[i + 1] = p[1]; folha[i + 2] = p[2]; }
}
execFileSync(FF, ['-y', '-v', 'error', '-f', 'rawvideo', '-pixel_format', 'rgba', '-video_size', `${LARG}x${ALTURA}`,
  '-i', '-', '-c:v', 'libwebp', '-lossless', '1', '-compression_level', '6', OUT], {input: folha, maxBuffer: 1 << 30});

const dur = +(N / FPS).toFixed(2);
const humor = (OUT.split(/[\\/]/).pop() || '').replace(/^rapozinha-|\.webp$/g, '');
console.log(`${SRC} -> ${OUT}`);
console.log(`  ${N} quadros de ${LARGURA}x${ALTURA}, folha ${LARG}x${ALTURA}, ciclo de ${dur}s`);
console.log(`  ${Math.round(fs.statSync(SRC).size / 1024)} KB -> ${Math.round(fs.statSync(OUT).size / 1024)} KB`);
console.log(`\n  ${humor}: {src: '${OUT.split(/[\\/]/).pop()}', fw: ${LARGURA}, fh: ${ALTURA}, n: ${N}, dur: ${dur}},`);
