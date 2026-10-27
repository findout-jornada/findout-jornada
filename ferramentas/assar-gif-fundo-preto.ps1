# Assa um GIF da Rapozinha com FUNDO PRETO OPACO (ex.: rapozinha-reverencia.gif) numa folha de
# sprites PNG pronta para virar WebP: quadros lado a lado, fundo removido e cores da identidade nova.
#
#  · Fundo: preenchimento a partir das bordas sobre pixels quase pretos (canal máximo < -Limiar);
#    a borda suave ganha alfa proporcional ao brilho e a cor é "despremultiplicada" (sem halo preto).
#    Áreas escuras DENTRO da Rapozinha (máscara, contorno) não são tocadas, porque o preenchimento
#    só anda a partir das bordas da imagem.
#    O limiar padrão (70) serve para arte cujo tom mais escuro é bem mais claro que o fundo.
#    Quando a Rapozinha veste preto (o terno da eletricidade), parte da roupa cai nessa faixa,
#    encosta na borda e o preenchimento come a roupa: aí baixe o limiar (-Limiar 24).
#    Para saber o valor, veja quantos pixels existem entre 18 e o limiar — se forem muitos
#    (a eletricidade tem 9%, contra 1% das outras), é roupa, não fundo.
#  · Cores: as mesmas regras de recor() de ferramentas/assar-sprite.js (roxo → azul royal,
#    lavanda/rosa → quase branco, bege/dourado → laranja da marca).
#  · Corte: a caixa que contém a Rapozinha em todos os quadros, com 4% de folga.
#
# Uso (PowerShell):
#   powershell -File ferramentas\assar-gif-fundo-preto.ps1 -Entrada C:\caminho\gif.gif -Saida folha.png -Largura 240 -Passo 2
#   ... -Limiar 24    # quando a Rapozinha veste preto e o fundo come a roupa
# Depois, para virar WebP (quantizando antes: a interpolação deixa mais de 100 mil cores
# distintas numa arte chapada, e sem colapsar isso o arquivo sai várias vezes maior):
#   node ferramentas\folha-para-webp.js folha.png app\rapozinha-xxx.webp 384
param([string]$Entrada, [string]$Saida, [int]$Largura = 240, [int]$Passo = 2, [int]$Limiar = 70)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class Assar {
  static double[] Hsl(double h, double s, double l) {
    h = ((h % 360) + 360) % 360 / 360.0;
    double q = l < .5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    Func<double,double> f = t => { if (t < 0) t += 1; if (t > 1) t -= 1; return t < 1/6.0 ? p + (q - p) * 6 * t : t < .5 ? q : t < 2/3.0 ? p + (q - p) * (2/3.0 - t) * 6 : p; };
    return new double[] { f(h + 1/3.0) * 255, f(h) * 255, f(h - 1/3.0) * 255 };
  }
  static Dictionary<int,int> cache = new Dictionary<int,int>();
  public static int Recor(int r, int g, int b) {
    int k = (r << 16) | (g << 8) | b; int v; if (cache.TryGetValue(k, out v)) return v;
    double r1 = r/255.0, g1 = g/255.0, b1 = b/255.0, max = Math.Max(r1, Math.Max(g1, b1)), min = Math.Min(r1, Math.Min(g1, b1)), d = max - min, l = (max + min)/2, h = 0, s = 0;
    if (d > 0) { s = l > .5 ? d / (2 - max - min) : d / (max + min); h = (max == r1 ? (g1 - b1)/d + (g1 < b1 ? 6 : 0) : max == g1 ? (b1 - r1)/d + 2 : (r1 - g1)/d + 4) * 60; }
    double[] n = null;
    if (h >= 200 && h <= 300 && s > .25 && l >= .15 && l < .65) n = l < .36 ? Hsl(227, .66, Math.Min(.42, l * 1.22)) : Hsl(227, .68, Math.Max(.48, Math.Min(.56, l * 1.2)));
    else if (l > .65 && (s < .35 || (h >= 290 && h <= 350) || (h >= 200 && h <= 290 && s < .6))) { if (l < .97) n = Hsl(227, .5, .95); }
    else if (h >= 10 && h <= 45 && s > .3 && l >= .3 && l <= .75) n = Hsl(31, .93, .54);
    else if (h >= 140 && h <= 205 && s > .08 && l > .3) n = Hsl(27, s, l);
    v = n == null ? k : (((int)Math.Round(n[0])) << 16) | (((int)Math.Round(n[1])) << 8) | (int)Math.Round(n[2]);
    cache[k] = v; return v;
  }
  // tira o fundo preto (a partir das bordas) e recolore; trabalha in-place em ARGB 32 bits
  public static void Processar(Bitmap bmp) { Processar(bmp, 70); }
  public static void Processar(Bitmap bmp, int limiar) {
    int W = bmp.Width, H = bmp.Height; var rc = new Rectangle(0, 0, W, H);
    int rampa = Math.Max(1, limiar - 18);   // 18 = preto puro; a rampa de alfa acompanha o limiar
    var data = bmp.LockBits(rc, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    int n = data.Stride * H; var px = new byte[n]; Marshal.Copy(data.Scan0, px, 0, n);
    Func<int,int> mx = i => Math.Max(px[i], Math.Max(px[i+1], px[i+2]));
    var fundo = new bool[W * H]; var fila = new Queue<int>();
    for (int x = 0; x < W; x++) { fila.Enqueue(x); fila.Enqueue((H-1)*W + x); }
    for (int y = 0; y < H; y++) { fila.Enqueue(y*W); fila.Enqueue(y*W + W-1); }
    while (fila.Count > 0) {
      int p = fila.Dequeue(); if (fundo[p]) continue; int i = (p / W) * data.Stride + (p % W) * 4;
      if (mx(i) >= limiar) continue; fundo[p] = true; int x = p % W, y = p / W;
      if (x > 0) fila.Enqueue(p-1); if (x < W-1) fila.Enqueue(p+1); if (y > 0) fila.Enqueue(p-W); if (y < H-1) fila.Enqueue(p+W);
    }
    for (int p = 0; p < W*H; p++) {
      int i = (p / W) * data.Stride + (p % W) * 4;
      if (fundo[p]) {
        int m = mx(i); int a = Math.Max(0, Math.Min(255, (m - 18) * 255 / rampa));
        if (a == 0) { px[i] = px[i+1] = px[i+2] = px[i+3] = 0; continue; }
        // despremultiplica: a borda escurecida pelo preto volta à cor cheia
        px[i] = (byte)Math.Min(255, px[i] * 255 / Math.Max(1, m)); px[i+1] = (byte)Math.Min(255, px[i+1] * 255 / Math.Max(1, m)); px[i+2] = (byte)Math.Min(255, px[i+2] * 255 / Math.Max(1, m));
        px[i+3] = (byte)a;
      }
      if (px[i+3] == 0) continue;
      int c = Recor(px[i+2], px[i+1], px[i]);
      px[i+2] = (byte)(c >> 16); px[i+1] = (byte)(c >> 8); px[i] = (byte)c;
    }
    Marshal.Copy(px, 0, data.Scan0, n); bmp.UnlockBits(data);
  }
  public static Rectangle Caixa(Bitmap bmp) {
    int W = bmp.Width, H = bmp.Height, x0 = W, y0 = H, x1 = -1, y1 = -1;
    var data = bmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    int n = data.Stride * H; var px = new byte[n]; Marshal.Copy(data.Scan0, px, 0, n); bmp.UnlockBits(data);
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) if (px[y * data.Stride + x * 4 + 3] > 24) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    return x1 < 0 ? Rectangle.Empty : Rectangle.FromLTRB(x0, y0, x1 + 1, y1 + 1);
  }
}
'@
$gif = [System.Drawing.Image]::FromFile($Entrada)
$fd = New-Object System.Drawing.Imaging.FrameDimension($gif.FrameDimensionsList[0])
$total = $gif.GetFrameCount($fd)
$pi = $gif.GetPropertyItem(0x5100); $durMs = 0; for ($i = 0; $i -lt $total; $i++) { $durMs += [BitConverter]::ToInt32($pi.Value, $i * 4) * 10 }
# 1) cada quadro escolhido em meia resolução, sem fundo e recolorido
$esc = 0.5; $mw = [int]($gif.Width * $esc); $mh = [int]($gif.Height * $esc)
$quadros = New-Object System.Collections.ArrayList; $uniao = [System.Drawing.Rectangle]::Empty
for ($i = 0; $i -lt $total; $i += $Passo) {
  $gif.SelectActiveFrame($fd, $i) | Out-Null
  $b = New-Object System.Drawing.Bitmap($mw, $mh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gr = [System.Drawing.Graphics]::FromImage($b); $gr.InterpolationMode = 'HighQualityBicubic'; $gr.PixelOffsetMode = 'HighQuality'; $gr.DrawImage($gif, 0, 0, $mw, $mh); $gr.Dispose()
  [Assar]::Processar($b, $Limiar)
  $c = [Assar]::Caixa($b); if (-not $c.IsEmpty) { $uniao = if ($uniao.IsEmpty) { $c } else { [System.Drawing.Rectangle]::Union($uniao, $c) } }
  [void]$quadros.Add($b)
}
$gif.Dispose()
# 2) corta todos pela mesma caixa (com folga) e reduz para a largura final
$f = [int]([Math]::Max($uniao.Width, $uniao.Height) * 0.04)
$uniao = [System.Drawing.Rectangle]::FromLTRB([Math]::Max(0, $uniao.Left - $f), [Math]::Max(0, $uniao.Top - $f), [Math]::Min($mw, $uniao.Right + $f), [Math]::Min($mh, $uniao.Bottom + $f))
$fw = $Largura; $fh = [int][Math]::Round($uniao.Height * $fw / $uniao.Width); $n = $quadros.Count
$folha = New-Object System.Drawing.Bitmap(($fw * $n), $fh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gs = [System.Drawing.Graphics]::FromImage($folha); $gs.InterpolationMode = 'HighQualityBicubic'; $gs.PixelOffsetMode = 'HighQuality'; $gs.CompositingMode = 'SourceCopy'
for ($k = 0; $k -lt $n; $k++) { $gs.DrawImage($quadros[$k], (New-Object System.Drawing.Rectangle(($k * $fw), 0, $fw, $fh)), $uniao, [System.Drawing.GraphicsUnit]::Pixel); $quadros[$k].Dispose() }
$gs.Dispose(); $folha.Save($Saida, [System.Drawing.Imaging.ImageFormat]::Png); $folha.Dispose()
$dur = [Math]::Round($durMs / 1000.0, 2)
"quadros=$n fw=$fw fh=$fh dur=$dur"
"SPRITES: {src: 'rapozinha-xxx.webp', fw: $fw, fh: $fh, n: $n, dur: $dur}"
