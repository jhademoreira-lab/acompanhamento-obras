// App antigo desativado: este service worker apaga o cache, se desinstala
// e leva as abas abertas para o novo endereço no Hydra.
const NOVO = 'https://acompanhamento-obras.hydra.fgr.com.br/';
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    const ks = await caches.keys();
    await Promise.all(ks.map(k => caches.delete(k)));
    await self.registration.unregister();
    const abas = await self.clients.matchAll({ type: 'window' });
    abas.forEach(c => { try { c.navigate(NOVO); } catch (_) {} });
  })());
});
