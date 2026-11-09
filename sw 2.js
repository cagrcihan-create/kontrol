// Bilerek önbellek tutmaz: her açılışta Netlify'daki güncel dosyalar gelir.
const CACHE='kontrol-v3';
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
