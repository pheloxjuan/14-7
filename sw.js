const CACHE_NAME = 'phelox-pwa-2026-08-19-v15';
const APP_SHELL = ['/index.html?v=cloud-v15', '/manifest.webmanifest', '/phelox-logo-192-v2.png', '/phelox-logo-512-v2.png', '/apple-touch-icon-v2.png'];
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
      const copy = response.clone(); caches.open(CACHE_NAME).then(cache => cache.put('/index.html?v=cloud-v15', copy)); return response;
    }).catch(() => caches.match('/index.html?v=cloud-v15')));
    return;
  }
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
    const copy = response.clone(); caches.open(CACHE_NAME).then(cache => cache.put(event.request, copy)); return response;
  })));
});
self.addEventListener('push', event => {
  let payload={title:'Phelox App',body:'Tenes una nueva notificacion',url:'https://pheloxapp.com/'};
  try{if(event.data)payload={...payload,...event.data.json()}}catch(error){if(event.data)payload.body=event.data.text()||payload.body}
  event.waitUntil(self.registration.showNotification(payload.title||'Phelox App',{
    body:payload.body||'',icon:'/phelox-logo-192-v2.png',badge:'/apple-touch-icon-v2.png',
    tag:payload.tag||'phelox-notification',renotify:true,data:{url:payload.url||'https://pheloxapp.com/'}
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  let target=event.notification.data?.url||'https://pheloxapp.com/';
  event.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(async windows=>{
    for(let client of windows){if('focus' in client){if('navigate' in client)await client.navigate(target);return client.focus()}}
    return self.clients.openWindow?self.clients.openWindow(target):null;
  }));
});
