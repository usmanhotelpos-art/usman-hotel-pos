// Shared rider summary helper
export function isExtrasItemGeneric(item, getProductById) {
  if (!item) return false;
  const name = (item.name || item.itemName || '').toString().toLowerCase();
  const category = (item.category || item.categoryName || item.type || item.subcategory || item.group || '').toString().toLowerCase();
  if (name.includes('extra') || category.includes('extra')) return true;
  if (item.productId && typeof getProductById === 'function') {
    try {
      const prod = getProductById(item.productId) || {};
      const prodCat = (prod.category || prod.type || prod.group || '').toString().toLowerCase();
      if (prodCat.includes('extra')) return true;
    } catch (e) {
      // ignore
    }
  }
  return false;
}

export function getOrderDeliveryFeeGeneric(order) {
  const o = order || {};
  return Number(o.deliveryCharge || o.deliveryFee || o.serviceCharge || o.deliveryFeeAmount || 0) || 0;
}

export function calculateRiderSummary(orders = [], type = 'cash', opts = {}) {
  const { getProductById, getServiceCharge } = opts;
  const totals = {
    orderTotal: 0,
    productTotal: 0,
    extrasTotal: 0,
    deliveryFeeTotal: 0,
    riderAmount: 0,
    count: 0
  };

  orders.forEach((order) => {
    const original = order.originalOrder || order || {};
    const items = Array.isArray(original.items) ? original.items : Array.isArray(order.items) ? order.items : [];
    const deliveryFee = typeof getServiceCharge === 'function' ? Number(getServiceCharge(original) || 0) : getOrderDeliveryFeeGeneric(original);

    let itemTotal = 0;
    let extrasTotal = 0;
    items.forEach((item) => {
      const quantity = Number(item.quantity || 1);
      const price = Number(item.price || item.unitPrice || 0);
      const amount = quantity * price;
      itemTotal += amount;
      if (isExtrasItemGeneric(item, getProductById)) extrasTotal += amount;
    });

    const orderTotal = Math.max(0, itemTotal + deliveryFee);
    const productTotal = Math.max(0, itemTotal - extrasTotal);
    const riderAmount = type === 'cash' ? productTotal : Math.max(0, extrasTotal + deliveryFee);

    totals.orderTotal += orderTotal;
    totals.productTotal += productTotal;
    totals.extrasTotal += extrasTotal;
    totals.deliveryFeeTotal += deliveryFee;
    totals.riderAmount += riderAmount;
    totals.count += 1;
  });

  return totals;
}
