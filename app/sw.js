// Service worker: deixa o app instalável e abre offline a "casca" (telas).
// Dados do aluno e conteúdo vêm do Supabase e não passam por aqui.
const CACHE = 'fj-casca-v1';
const CASCA = ['./', './index.html', './config.js', './manifest.json', './rapozinha.png', './icone-192.png', './icone-512.png'];

self.addEventListener('install', ev => {
  ev.waitUntil(caches.open(CACHE).then(c => c.addAll(CASCA)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', ev => {
  ev.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', ev => {
  const url = new URL(ev.request.url);
  if (ev.request.method !== 'GET' || url.origin !== location.origin) return;
  // rede primeiro (para pegar versões novas), cache se estiver offline
  ev.respondWith(
    fetch(ev.request).then(r => { const copia = r.clone(); caches.open(CACHE).then(c => c.put(ev.request, copia)); return r; })
      .catch(() => caches.match(ev.request).then(r => r || (ev.request.mode === 'navigate' ? caches.match('./index.html') : undefined)))
  );
});
