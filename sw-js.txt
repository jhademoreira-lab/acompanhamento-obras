const CACHE = 'fgr-obras-v1';
const CDN = [
  'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js',
  'https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js',
  'https://www.gstatic.com/firebasejs/10.12.0/firebase-database-compat.js',
  'https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js'
];

self.addEventListener('install', e => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE);
    await Promise.allSettled(['./'].map(u => c.add(u)));
    await Promise.allSettled(CDN.map(async u => {
      const r = await fetch(new Request(u, { mode: 'no-cors' }));
      await c.put(u, r);
    }));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (CDN.includes(req.url)) {
    e.respondWith(caches.match(req.url).then(hit => hit || fetch(new Request(req.url, { mode: 'no-cors' })).then(r => {
      const copy = r.clone();
      caches.open(CACHE).then(c => c.put(req.url, copy));
      return r;
    })));
    return;
  }

  if (url.origin !== location.origin) return;

  e.respondWith((async () => {
    try {
      const r = await Promise.race([
        fetch(req),
        new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 6000))
      ]);
      if (r && r.ok) {
        const copy = r.clone();
        caches.open(CACHE).then(c => c.put(req, copy));
      }
      return r;
    } catch (err) {
      const hit = await caches.match(req, { ignoreSearch: true });
      if (hit) return hit;
      if (req.mode === 'navigate') {
        return (await caches.match('./')) || (await caches.match('index.html')) || Response.error();
      }
      return Response.error();
    }
  })());
});
