self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

const ICON =
  'data:image/svg+xml,' +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="#10b981"/><circle cx="32" cy="32" r="17" fill="#fff"/><text x="32" y="41" font-size="24" text-anchor="middle">🔔</text></svg>'
  );

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const c of list) {
        if (c.url.includes('/active-orders') && 'focus' in c) return c.focus();
      }
      for (const c of list) {
        if ('focus' in c) return c.focus();
      }
      return self.clients.openWindow('/active-orders');
    })
  );
});

self.addEventListener('message', (event) => {
  const d = event.data || {};
  if (d.type !== 'notify') return;
  const list = Array.isArray(d.orders) ? d.orders : [];
  const title = list.length > 1 ? `🆕 ${list.length} NEW Dine-In Orders!` : '🆕 NEW Dine-In Order!';
  let body = '';
  if (list.length) {
    body = list
      .slice(0, 3)
      .map((o) => `Table ${o.tableNumber || '-'} · #${o.orderNumber || o.id} · ${(o.items || []).length} items · ${Number(o.total || o.amount || 0)} Rs`)
      .join('\n');
    if (list.length > 3) body += `\n+${list.length - 3} more...`;
  } else if (d.body) {
    body = d.body;
  }
  self.registration.showNotification(title, {
    body,
    icon: ICON,
    badge: ICON,
    tag: d.tag || 'active-orders-' + Date.now(),
    renotify: true,
    vibrate: [800, 200, 800, 200, 800, 200, 800],
    requireInteraction: false,
    silent: false
  });
});
