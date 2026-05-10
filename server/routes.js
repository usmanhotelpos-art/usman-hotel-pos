import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import {
  createRecord,
  findUserByEmail,
  getCollection,
  readDb,
  removeRecord,
  updateRecord,
  writeDb
} from './db.js';

const JWT_SECRET = process.env.JWT_SECRET || 'usman-hotel-secret';
export const router = express.Router();

function createToken(user) {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role,
      name: user.name
    },
    JWT_SECRET,
    { expiresIn: '6h' }
  );
}

function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) {
    return res.status(401).send({ error: 'Unauthorized' });
  }

  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (error) {
    res.status(401).send({ error: 'Invalid token' });
  }
}

router.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  const user = findUserByEmail(email || '');
  if (!user) {
    return res.status(401).send({ error: 'Invalid credentials' });
  }

  const valid = await bcrypt.compare(password || '', user.passwordHash);
  if (!valid) {
    return res.status(401).send({ error: 'Invalid credentials' });
  }

  const token = createToken(user);
  res.send({ token, user: { id: user.id, name: user.name, email: user.email, role: user.role } });
});

router.get('/auth/me', authenticate, (req, res) => {
  const db = readDb();
  const user = db.users?.find((item) => item.id === req.user.id);
  if (!user) {
    return res.status(401).send({ error: 'User not found' });
  }
  res.send({ id: user.id, name: user.name, email: user.email, role: user.role });
});

router.use(authenticate);

const collections = ['rooms', 'reservations', 'inventory', 'staff', 'sales', 'invoices', 'pos_categories', 'pos_products', 'pos_tables', 'delivery_agents', 'pos_customers', 'pos_payments', 'pos_orders'];

router.get('/dashboard', (req, res) => {
  const db = readDb();
  const rooms = db.rooms || [];
  const reservations = db.reservations || [];
  const sales = db.sales || [];

  const revenue = sales.reduce((sum, item) => sum + Number(item.amount || 0), 0);
  const occupancy = rooms.filter((room) => room.status === 'occupied').length;
  const inventoryValue = (db.inventory || []).reduce((sum, item) => sum + Number(item.cost || 0) * Number(item.quantity || 0), 0);

  res.send({
    totalRooms: rooms.length,
    occupiedRooms: occupancy,
    totalReservations: reservations.length,
    totalSales: sales.length,
    revenue,
    inventoryValue,
    settings: db.settings
  });
});

router.get('/settings', (req, res) => {
  const db = readDb();
  res.send(db.settings || {});
});

router.put('/settings', (req, res) => {
  const settings = req.body;
  const db = readDb();
  db.settings = { ...db.settings, ...settings };
  writeDb(db);
  res.send(db.settings);
});

collections.forEach((collection) => {
  router.get(`/${collection}`, (req, res) => {
    res.send(getCollection(collection));
  });

  router.post(`/${collection}`, (req, res) => {
    const record = req.body;
    const created = createRecord(collection, record);
    res.status(201).send(created);
  });

  router.put(`/${collection}/:id`, (req, res) => {
    const updated = updateRecord(collection, req.params.id, req.body);
    if (!updated) {
      return res.status(404).send({ error: 'Record not found' });
    }
    res.send(updated);
  });

  router.delete(`/${collection}/:id`, (req, res) => {
    const removed = removeRecord(collection, req.params.id);
    if (!removed) {
      return res.status(404).send({ error: 'Record not found' });
    }
    res.send({ success: true });
  });
});

router.post('/reservations/:id/checkin', (req, res) => {
  const reservation = updateRecord('reservations', req.params.id, { status: 'checked-in' });
  if (!reservation) return res.status(404).send({ error: 'Reservation not found' });
  const room = updateRecord('rooms', reservation.roomId, { status: 'occupied' });
  res.send({ reservation, room });
});

router.post('/reservations/:id/checkout', (req, res) => {
  const reservation = readDb().reservations.find((item) => item.id === req.params.id);
  if (!reservation) return res.status(404).send({ error: 'Reservation not found' });

  const checkoutDate = req.body.checkOut || new Date().toISOString().slice(0, 10);
  const checkoutData = { ...reservation, status: 'checked-out', checkOut: checkoutDate };
  updateRecord('reservations', req.params.id, checkoutData);
  updateRecord('rooms', reservation.roomId, { status: 'available' });

  const sale = createRecord('sales', {
    description: `Reservation ${reservation.id} checkout`,
    amount: checkoutData.total || 0,
    date: checkoutDate
  });

  const invoice = createRecord('invoices', {
    reservationId: reservation.id,
    guestName: reservation.guestName,
    roomId: reservation.roomId,
    amount: checkoutData.total || 0,
    date: checkoutDate,
    status: 'paid',
    items: [
      {
        description: `Room ${reservation.roomId} stay`,
        amount: checkoutData.total || 0
      }
    ]
  });

  res.send({ reservation: checkoutData, sale, invoice });
});

router.post('/payments', (req, res) => {
  const payment = req.body;
  const sale = createRecord('sales', payment);
  const invoice = createRecord('invoices', {
    saleId: sale.id,
    description: payment.description,
    amount: payment.amount,
    date: sale.date,
    status: 'paid'
  });
  res.status(201).send({ sale, invoice });
});

router.get('/pos/categories', (req, res) => {
  res.send(getCollection('pos_categories'));
});

router.post('/pos/categories', (req, res) => {
  const category = req.body;
  const created = createRecord('pos_categories', category);
  res.status(201).send(created);
});

router.get('/pos/products', (req, res) => {
  res.send(getCollection('pos_products'));
});

router.post('/pos/products', (req, res) => {
  const product = req.body;
  const created = createRecord('pos_products', product);
  res.status(201).send(created);
});

router.get('/pos/tables', (req, res) => {
  res.send(getCollection('pos_tables'));
});

router.post('/pos/tables', (req, res) => {
  const table = req.body;
  const created = createRecord('pos_tables', table);
  res.status(201).send(created);
});

router.put('/pos/tables/:id', (req, res) => {
  const updated = updateRecord('pos_tables', req.params.id, req.body);
  if (!updated) {
    return res.status(404).send({ error: 'Table not found' });
  }
  res.send(updated);
});

router.delete('/pos/tables/:id', (req, res) => {
  const removed = removeRecord('pos_tables', req.params.id);
  if (!removed) {
    return res.status(404).send({ error: 'Table not found' });
  }
  res.send({ success: true });
});

router.get('/pos/delivery-agents', (req, res) => {
  res.send(getCollection('delivery_agents'));
});

router.get('/pos/customers', (req, res) => {
  res.send(getCollection('pos_customers'));
});

router.get('/pos/orders', (req, res) => {
  let orders = getCollection('pos_orders');
  const { status, orderType } = req.query;
  if (status) {
    orders = orders.filter((order) => order.status === status);
  }
  if (orderType) {
    orders = orders.filter((order) => order.orderType === orderType);
  }
  res.send(orders);
});

router.get('/pos/orders/:id', (req, res) => {
  const order = getCollection('pos_orders').find((item) => item.id === req.params.id);
  if (!order) return res.status(404).send({ error: 'Order not found' });
  res.send(order);
});

router.post('/pos/orders', (req, res) => {
  const {
    items,
    orderType,
    customerName,
    phone,
    address,
    tableNumber,
    deliveryAgent,
    deliveryFee = 0,
    discount = 0,
    taxPercent = 0,
    serviceCharge = 0,
    paymentMethod = 'Cash',
    notes = ''
  } = req.body;

  if (!items || !items.length) {
    return res.status(400).send({ error: 'Cart cannot be empty' });
  }

  if (!orderType) {
    return res.status(400).send({ error: 'Order type is required' });
  }

  if (orderType === 'Delivery' && (!customerName || !phone || !address)) {
    return res.status(400).send({ error: 'Delivery orders require customer name, phone, and address' });
  }

  if (orderType === 'Dine-In' && !tableNumber) {
    return res.status(400).send({ error: 'Dine-In orders require a table or room selection' });
  }

  const products = getCollection('pos_products');
  const orderItems = items.map((item) => {
    const product = products.find((product) => product.id === item.productId);
    if (!product) {
      throw new Error(`Product not found: ${item.productId}`);
    }
    const stock = product.availableStock ?? Number(product.stock) ?? 0;
    if (stock > 0 && stock < item.quantity) {
      return res.status(400).send({ error: `Insufficient stock for ${product.name}` });
    }
    return {
      productId: product.id,
      name: product.name,
      price: product.price,
      quantity: item.quantity,
      notes: item.notes || '',
      total: item.price * item.quantity
    };
  });

  const subtotal = orderItems.reduce((sum, item) => sum + item.total, 0);
  const discountValue = Number(discount) || 0;
  const taxValue = ((subtotal - discountValue) * (Number(taxPercent) || 0)) / 100;
  const deliveryValue = Number(deliveryFee) || 0;
  const serviceValue = Number(serviceCharge) || 0;
  const total = Math.max(0, subtotal - discountValue + taxValue + deliveryValue + serviceValue);

  const customers = getCollection('pos_customers');
  let customerId;
  if (customerName || phone) {
    const existingCustomer = customers.find(
      (customer) => customer.name === customerName && customer.phone === phone
    );
    if (existingCustomer) {
      customerId = existingCustomer.id;
    } else {
      customerId = createRecord('pos_customers', { name: customerName, phone, address }).id;
    }
  }

  const orderStatus = req.body.status || (orderType === 'Delivery' ? 'Pending' : 'New');
  const order = createRecord('pos_orders', {
    orderNumber: `ORD-${Date.now().toString().slice(-6)}`,
    orderType,
    customerName,
    phone,
    address,
    tableNumber,
    deliveryAgent,
    deliveryFee: deliveryValue,
    discount: discountValue,
    taxPercent: Number(taxPercent) || 0,
    serviceCharge: serviceValue,
    paymentMethod,
    notes,
    items: orderItems,
    subtotal,
    total,
    status: orderStatus,
    customerId,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  });

  products.forEach((product) => {
    const orderItem = orderItems.find((item) => item.productId === product.id);
    if (orderItem) {
      const updatedQty = Math.max(0, product.availableStock - orderItem.quantity);
      updateRecord('pos_products', product.id, { availableStock: updatedQty });
    }
  });

  res.status(201).send(order);
});

router.delete('/pos/orders/:id', (req, res) => {
  const removed = removeRecord('pos_orders', req.params.id);
  if (!removed) {
    return res.status(404).send({ error: 'Order not found' });
  }
  res.send({ success: true });
});

router.put('/pos/orders/:id/status', (req, res) => {
  const { status } = req.body;
  const updated = updateRecord('pos_orders', req.params.id, {
    status,
    updatedAt: new Date().toISOString()
  });
  if (!updated) {
    return res.status(404).send({ error: 'Order not found' });
  }
  res.send(updated);
});

router.put('/pos/orders/:id/assign-rider', (req, res) => {
  const { deliveryAgent, status } = req.body;
  const updated = updateRecord('pos_orders', req.params.id, {
    deliveryAgent,
    status: status || 'Riders Assigned',
    updatedAt: new Date().toISOString()
  });
  if (!updated) {
    return res.status(404).send({ error: 'Order not found' });
  }
  res.send(updated);
});

router.put('/pos/orders/:id', (req, res) => {
  const { items, customerName, phone, address, tableNumber, deliveryAgent, serviceType, deliveryFee, discount, taxPercent, serviceCharge, paymentMethod, notes, status, subtotal, total } = req.body;
  const updated = updateRecord('pos_orders', req.params.id, {
    items: items || [],
    customerName: customerName || '',
    phone: phone || '',
    address: address || '',
    tableNumber: tableNumber || '',
    deliveryAgent: deliveryAgent || '',
    serviceType: serviceType || '',
    deliveryFee: Number(deliveryFee) || 0,
    discount: Number(discount) || 0,
    taxPercent: Number(taxPercent) || 0,
    serviceCharge: Number(serviceCharge) || 0,
    paymentMethod: paymentMethod || 'Cash',
    notes: notes || '',
    status: status || 'New',
    subtotal: Number(subtotal) || 0,
    total: Number(total) || 0,
    updatedAt: new Date().toISOString()
  });
  if (!updated) {
    return res.status(404).send({ error: 'Order not found' });
  }
  res.send(updated);
});

router.post('/pos/payments', (req, res) => {
  const payment = req.body;
  const created = createRecord('pos_payments', {
    ...payment,
    date: payment.date || new Date().toISOString().slice(0, 10)
  });

  if (payment.orderId) {
    updateRecord('pos_orders', payment.orderId, {
      status: 'Completed',
      updatedAt: new Date().toISOString()
    });
  }

  res.status(201).send(created);
});

router.get('/search/:collection', (req, res) => {
  const results = getCollection(req.params.collection).filter((item) => {
    const term = (req.query.q || '').toString().toLowerCase();
    return Object.values(item).some((value) => value?.toString().toLowerCase().includes(term));
  });
  res.send(results);
});
