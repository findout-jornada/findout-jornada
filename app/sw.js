/* Cache "casca": o app abre offline com a última versão que funcionou.
   Rede primeiro (com limite de tempo) para o que é nosso; o supabase-js tem
   versão fixa e fica em cache (sem ele o app nem abre). Só respostas 200
   entram no cache — erro e resposta parcial (206 dos vídeos) ficam fora. */
const CACHE = 'fj-casca-v2';
const CASCA = ['./', 'index.html', 'config.js', 'manifest.json', 'rapozinha.png', 'icone-192.png', 'icone-512.png'];
const CDN = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.4/dist/umd/supabase.min.js';

self.addEventListener('install', ev => {
  ev.waitUntil(caches.open(CACHE)
    .then(c => Promise.all([c.addAll(CASCA), fetch(CDN, {mode: 'cors'}).then(r => { if (r.ok) return c.put(CDN, r); }).catch(() => {})]))
    .then(() => self.skipWaiting()));
});
self.addEventListener('activate', ev => {
  ev.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', ev => {
  const req = ev.request;
  if (req.method !== 'GET') return;
  if (req.url === CDN) {
    // versão fixa: cache primeiro (o navegador ainda confere o integrity da tag)
    ev.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => {
      if (r.ok) { const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); }
      return r;
    })));
    return;
  }
  if (new URL(req.url).origin !== location.origin) return;
  ev.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const rede = fetch(req);
    try {
      // rede primeiro, mas sem esperar demais em conexão ruim
      const r = await Promise.race([rede, new Promise((_, rej) => setTimeout(() => rej(new Error('demorou')), 4000))]);
      if (r && r.status === 200) cache.put(req, r.clone()).catch(() => {});
      return r;
    } catch (e) {
      const hit = await cache.match(req, {ignoreSearch: req.mode === 'navigate'});
      if (hit) return hit;
      try { // sem cache: espera a rede lenta terminar (primeiro acesso)
        const r = await rede;
        if (r && r.status === 200) cache.put(req, r.clone()).catch(() => {});
        return r;
      } catch (e2) {
        if (req.mode === 'navigate') { const idx = await cache.match('index.html'); if (idx) return idx; }
        throw e2;
      }
    }
  })());
});
