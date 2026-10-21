// Converte um GIF da rapozinha (era roxa) para a identidade nova do app:
// aplica o MESMO remapeamento de cores do app/index.html (roxos 225–320
// giram −32° para o azul, claros dessaturam; teal vira laranja 27),
// reduz para 320px de largura e reencoda com transparência.
// Uso: npm install omggif gifenc && node recolorir-gif.js entrada.gif saida.gif [largura]
const fs = require('fs');
const { GifReader } = require('omggif');
const { GIFEncoder, quantize, applyPalette } = require('gifenc');

const [SRC, OUT, WSTR] = process.argv.slice(2);
const W = +WSTR || 320;

/* ---- recolorização portada de app/index.html (hsl2rgb + recor) ---- */
function hsl2rgb(h, s, l) {
  h = ((h % 360) + 360) % 360 / 360;
  const q = l < .5 ? l * (1 + s) : l + s - l * s, p2 = 2 * l - q;
  const f = t => { if (t < 0) t += 1; if (t > 1) t -= 1; return t < 1 / 6 ? p2 + (q - p2) * 6 * t : t < 1 / 2 ? q : t < 2 / 3 ? p2 + (q - p2) * (2 / 3 - t) * 6 : p2; };
  return [Math.round(f(h + 1 / 3) * 255), Math.round(f(h) * 255), Math.round(f(h - 1 / 3) * 255)];
}
const RECOR = new Map();
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
  if (h >= 225 && h <= 320 && s > .04) { h -= 32; if (l >= .72) s *= .55; novo = hsl2rgb(h, s, l); }
  else if (h >= 140 && h <= 205 && s > .08) novo = hsl2rgb(27, s, l);
  RECOR.set(k, novo);
  return novo;
}

/* ---- redução com média por área, ponderada pelo alfa (sem halo) ---- */
function reduzir(src, w0, h0, W, H) {
  const out = new Uint8ClampedArray(W * H * 4);
  const fx = w0 / W, fy = h0 / H;
  for (let y = 0; y < H; y++) {
    const y0 = Math.floor(y * fy), y1 = Math.min(h0, Math.ceil((y + 1) * fy));
    for (let x = 0; x < W; x++) {
      const x0 = Math.floor(x * fx), x1 = Math.min(w0, Math.ceil((x + 1) * fx));
      let sa = 0, sr = 0, sg = 0, sb = 0, n = 0;
      for (let yy = y0; yy < y1; yy++) for (let xx = x0; xx < x1; xx++) {
        const i = (yy * w0 + xx) * 4, a = src[i + 3];
        sa += a; sr += src[i] * a; sg += src[i + 1] * a; sb += src[i + 2] * a; n++;
      }
      const o = (y * W + x) * 4;
      if (sa > 0) { out[o] = sr / sa; out[o + 1] = sg / sa; out[o + 2] = sb / sa; out[o + 3] = sa / n; }
    }
  }
  return out;
}

const buf = fs.readFileSync(SRC);
const gr = new GifReader(buf);
const w0 = gr.width, h0 = gr.height, n = gr.numFrames();
const H = Math.round(h0 * W / w0);
console.log(`origem ${w0}x${h0}, ${n} quadros -> ${W}x${H}`);

const gif = GIFEncoder();
let tela = new Uint8Array(w0 * h0 * 4);   // "canvas" composto (compositing padrão de GIF)
for (let f = 0; f < n; f++) {
  const info = gr.frameInfo(f);
  const antes = info.disposal === 3 ? tela.slice() : null;
  gr.decodeAndBlitFrameRGBA(f, tela);     // pixels transparentes do patch não sobrescrevem
  const quadro = tela.slice();
  if (info.disposal === 2) {              // restaura a área do patch para transparente
    for (let yy = info.y; yy < info.y + info.height; yy++)
      tela.fill(0, (yy * w0 + info.x) * 4, (yy * w0 + info.x + info.width) * 4);
  } else if (info.disposal === 3 && antes) tela = antes;

  const peq = reduzir(quadro, w0, h0, W, H);
  for (let i = 0; i < peq.length; i += 4) {
    if (peq[i + 3] < 128) { peq[i] = peq[i + 1] = peq[i + 2] = peq[i + 3] = 0; continue; }
    peq[i + 3] = 255;
    const nc = recor(peq[i], peq[i + 1], peq[i + 2]);
    if (nc) { peq[i] = nc[0]; peq[i + 1] = nc[1]; peq[i + 2] = nc[2]; }
  }
  const palette = quantize(peq, 255, {format: 'rgba4444', oneBitAlpha: true});
  let ti = palette.findIndex(p => p[3] === 0);
  if (ti < 0) { palette.push([0, 0, 0, 0]); ti = palette.length - 1; }
  const index = applyPalette(peq, palette, 'rgba4444');
  for (let i = 0; i < W * H; i++) if (peq[i * 4 + 3] === 0) index[i] = ti;
  gif.writeFrame(index, W, H, {palette, transparent: true, transparentIndex: ti, delay: Math.max(20, (info.delay || 8) * 10), dispose: 2});
}
gif.finish();
fs.writeFileSync(OUT, Buffer.from(gif.bytes()));
console.log(`gravado ${OUT}: ${(fs.statSync(OUT).size / 1024).toFixed(0)} KB`);
