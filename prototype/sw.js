// Network-first with offline fallback, so updates show up immediately but the game still works offline.
const CACHE = 'snackbeats-v1';
const ASSETS = [
  './', 'index.html', 'css/style.css', 'manifest.webmanifest', 'icon.svg',
  'js/main.js', 'js/engine.js', 'js/board-view.js', 'js/board-game.js', 'js/audio.js',
  'js/speech.js', 'js/i18n.js', 'js/levels.js', 'js/songs.js', 'js/store.js',
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    fetch(e.request)
      .then(r => {
        const copy = r.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy));
        return r;
      })
      .catch(() => caches.match(e.request))
  );
});
