const fs = require('fs');
const path = 'server/data/db.json';
const backupPath = 'server/data/db.json.backup-extraCharge-before.json';
if (!fs.existsSync(path)) {
  console.error('Input file not found:', path);
  process.exit(1);
}
fs.copyFileSync(path, backupPath);
const raw = fs.readFileSync(path, 'utf8');
const data = JSON.parse(raw);
if (Array.isArray(data.pos_orders)) {
  data.pos_orders = data.pos_orders.map((order) => {
    if (Object.prototype.hasOwnProperty.call(order,'extraCharge')) {
      const extraCharge = Number(order.extraCharge || 0);
      if (!Number.isNaN(extraCharge) && extraCharge !== 0) {
        order.total = Math.max(0, Number(order.total || 0) - extraCharge);
      }
      delete order.extraCharge;
    }
    return order;
  });
}
fs.writeFileSync(path, JSON.stringify(data, null, 2), 'utf8');
console.log('Updated', data.pos_orders.length, 'orders and created backup at', backupPath);