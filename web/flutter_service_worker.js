// Service worker de limpieza: borra la versión antigua guardada,
// se desinstala y recarga la app para que cargue la versión nueva.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const claves = await caches.keys();
    await Promise.all(claves.map((c) => caches.delete(c)));
    await self.registration.unregister();
    const ventanas = await self.clients.matchAll({ type: 'window' });
    ventanas.forEach((v) => v.navigate(v.url));
  })());
});
