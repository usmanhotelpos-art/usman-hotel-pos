export function isNotificationSupported() {
  return 'Notification' in window;
}

export function getNotificationPermission() {
  if (!isNotificationSupported()) return 'unsupported';
  return Notification.permission;
}

export async function requestNotificationPermission() {
  if (!isNotificationSupported()) return 'unsupported';
  if (Notification.permission === 'granted') return 'granted';
  if (Notification.permission === 'denied') return 'denied';
  const result = await Notification.requestPermission();
  return result;
}

let lastNotificationCount = 0;

export function showOrderNotification(order) {
  if (!isNotificationSupported()) return;
  if (Notification.permission !== 'granted') return;

  const orderType = order.orderType === 'Takeaway' ? 'Pickup' : order.orderType || 'Order';
  const customerName = order.customerName || 'Walk-in';
  const total = order.total || order.grandTotal || 0;
  const orderNumber = order.orderNumber || order.id || '';

  try {
    const notif = new Notification(`New ${orderType} Order #${orderNumber}`, {
      body: `${customerName} — Rs ${total}`,
      icon: `${window.location.origin}/favicon.ico`,
      tag: `order-${order.id}`,
      requireInteraction: true,
      silent: false,
    });
    notif.onclick = () => {
      window.focus();
      notif.close();
    };
  } catch (err) {
    console.warn('Notification error:', err.message);
  }
}

export function checkAndNotifyNewOrders(orders) {
  if (!Array.isArray(orders)) return;
  if (Notification.permission !== 'granted') return;

  const currentCount = orders.length;
  if (lastNotificationCount > 0 && currentCount > lastNotificationCount) {
    const newOrders = orders.slice(0, currentCount - lastNotificationCount);
    for (const order of newOrders) {
      showOrderNotification(order);
    }
  }
  lastNotificationCount = currentCount;
}

export function resetNotificationCount() {
  lastNotificationCount = 0;
}
