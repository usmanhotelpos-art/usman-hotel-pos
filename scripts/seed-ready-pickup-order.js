import fetch from 'node-fetch';

const api = 'http://localhost:4000/api';

async function main() {
  const loginRes = await fetch(`${api}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@usmanhotel.com', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  if (!loginRes.ok) {
    console.error('Login failed', loginData);
    process.exit(1);
  }

  const token = loginData.token;
  const newOrder = {
    orderId: 'pickup-ready-1',
    riderId: 'rider1',
    status: 'approved',
    originalOrder: {
      id: 'pickup-ready-1',
      customerName: 'Pickup Customer',
      phone: '+923001234567',
      address: '123 Test Street',
      deliveryAddress: '123 Test Street',
      serviceType: 'Delivery',
      orderType: 'Delivery',
      deliveryAgent: 'Ahmed Rider',
      items: [
        { name: 'Chicken Karahi', quantity: 1, price: 1200 },
        { name: 'Cold Drink', quantity: 2, price: 120 }
      ],
      subtotal: 1440,
      deliveryCharge: 0,
      total: 1440
    }
  };

  const createRes = await fetch(`${api}/rider_orders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(newOrder)
  });

  const createData = await createRes.json();
  console.log('create status', createRes.status, createData);
  if (!createRes.ok) process.exit(1);

  const approvedRes = await fetch(`${api}/rider/approved-orders/rider1`, {
    headers: { Authorization: `Bearer ${token}` }
  });

  const approvedData = await approvedRes.json();
  console.log('approvedOrders count', Array.isArray(approvedData) ? approvedData.length : approvedData);
  console.log(JSON.stringify(approvedData, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
