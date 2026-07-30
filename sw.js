const CACHE_NAME = 'phelox-pwa-2026-07-30-v8';
const APP_SHELL = ['/index.html?v=cloud-v8', '/manifest.webmanifest', '/phelox-logo-192-v2.png', '/phelox-logo-512-v2.png', '/apple-touch-icon-v2.png'];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET' || new URL(event.request.url).origin !== self.location.origin) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request, {cache: 'no-store'}).then(response => {
      const copy = response.clone(); caches.open(CACHE_NAME).then(cache => cache.put('/index.html?v=cloud-v8', copy)); return response;
    }).catch(() => caches.match('/index.html?v=cloud-v8')));
    return;
  }
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
    const copy = response.clone(); caches.open(CACHE_NAME).then(cache => cache.put(event.request, copy)); return response;
  })));
});
