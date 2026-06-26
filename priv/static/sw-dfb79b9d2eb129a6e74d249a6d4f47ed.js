// Service Worker mínimo — Phase 0b
// Proposito: ativar install prompt do navegador. Sem cache strategy (fica pra futuro).

self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

// fetch handler precisa existir (mesmo vazio) para que beforeinstallprompt
// dispare confiavelmente em todos os browsers.
self.addEventListener("fetch", () => {});
