const CACHE = 'ingetin-v28';
const SHELL = ['./', './index.html', './config.js', './manifest.json', './icon.svg', './icon-192.png', './apple-touch-icon.png', './holidays.json'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
// Utamakan jaringan (supaya update langsung terasa), pakai cache kalau offline.
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const sameOrigin = url.origin === location.origin;
  const isFont = url.host.includes('fonts.g') || url.host.includes('cdn.jsdelivr.net');
  if (!sameOrigin && !isFont) return;
  e.respondWith(
    fetch(sameOrigin ? new Request(req, { cache: 'no-cache' }) : req).then((res) => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
      return res;
    }).catch(() => caches.match(req).then((r) => r || caches.match('./index.html')))
  );
});
// Notifikasi dari server (Web Push): muncul walau aplikasi ditutup.
self.addEventListener('push', (e) => {
  let d = {}; try { d = e.data ? e.data.json() : {}; } catch { d = { body: e.data && e.data.text() }; }
  const title = d.title || 'Ingetin', tag = d.tag || 'ingetin-' + Date.now();
  e.waitUntil(self.registration.getNotifications({ tag }).then((l) => {
    if (l.length) return; // sudah tampil dari aplikasi
    return self.registration.showNotification(title, { body: d.body || '', tag, renotify: true, icon: 'icon-192.png', badge: 'favicon-32.png', vibrate: [120, 60, 120], data: { ev: d.ev || '', view: d.view || '' } });
  }));
});
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const ev = (e.notification.data && e.notification.data.ev) || '', view = (e.notification.data && e.notification.data.view) || '';
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((cs) => {
    const c = cs[0];
    if (c) { if (ev) c.postMessage({ openEv: ev }); else if (view) c.postMessage({ openView: view }); return c.focus(); }
    return self.clients.openWindow(ev ? './?ev=' + encodeURIComponent(ev) : view ? './?view=' + view : './');
  }));
});
