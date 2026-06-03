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
  saveCollection,
  writeDb
} from './db.js';
import { createBackup, listBackups, restoreBackup, deleteBackup } from './backup-restore.js';

const JWT_SECRET = process.env.JWT_SECRET || 'usman-hotel-secret';
export const router = express.Router();

// Basic API root for health check
router.get('/', (req, res) => {
  res.send({ ok: true, message: 'Usman POS API' });
});

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

function safe(handler) {
  return (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
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

router.post('/auth/login', safe(async (req, res) => {
  const { email, password } = req.body;
  const user = findUserByEmail(email || '');
  if (!user) {
    // Attempt staff fallback: allow staff members (helpers, cashiers, etc.) to login
    const staffMembers = getCollection('staff') || [];
    const loginValue = (email || '').toString().trim().toLowerCase();
    const staff = staffMembers.find((s) => {
      const username = (s.username || '').toString().trim().toLowerCase();
      const staffEmail = (s.email || '').toString().trim().toLowerCase();
      const loginEnabled = s.loginEnabled !== false;
      if (!loginEnabled) return false;
      return username === loginValue || staffEmail === loginValue;
    });

    if (!staff) return res.status(401).send({ error: 'Invalid credentials' });

    // staff passwords are stored as plain `password` field in many setups
    let validStaff = false;
    if (typeof staff.password === 'string') {
      validStaff = password === staff.password;
    }
    if (!validStaff && staff.passwordHash) {
      validStaff = await bcrypt.compare(password || '', staff.passwordHash);
    }
    if (!validStaff) return res.status(401).send({ error: 'Invalid credentials' });

    const token = createToken({ id: staff.id, email: staff.username || staff.email, role: staff.role, name: staff.name });
    return res.send({ token, user: { id: staff.id, name: staff.name, email: staff.username || staff.email, role: staff.role } });
  }

  const valid = await bcrypt.compare(password || '', user.passwordHash);
  if (!valid) {
    return res.status(401).send({ error: 'Invalid credentials' });
  }

  const token = createToken(user);
  res.send({ token, user: { id: user.id, name: user.name, email: user.email, role: user.role } });
}));

router.get('/auth/me', authenticate, (req, res) => {
  const db = readDb();
  let user = db.users?.find((item) => item.id === req.user.id);
  if (!user) {
    // Try staff collection
    user = (db.staff || []).find((s) => s.id === req.user.id);
    if (user) {
      return res.send({ id: user.id, name: user.name, email: user.username || user.email, role: user.role });
    }
    // Try riders
    user = (db.riders || []).find((r) => r.id === req.user.id);
    if (user) {
      return res.send({ id: user.id, name: user.name, email: user.email, role: user.role });
    }
    return res.status(401).send({ error: 'User not found' });
  }
  res.send({ id: user.id, name: user.name, email: user.email, role: user.role });
});

// Rider Authentication Routes
router.post('/auth/rider-login', safe(async (req, res) => {
  const { email, password } = req.body;
  const loginValue = (email || '').toString().trim().toLowerCase();
  const riders = getCollection('riders');
  const staffMembers = getCollection('staff') || [];

  const candidates = riders.filter((r) => {
    const riderEmail = (r.email || '').toString().trim().toLowerCase();
    const riderUsername = (r.username || '').toString().trim().toLowerCase();
    return riderEmail === loginValue || riderUsername === loginValue;
  });

  // Prefer a rider entry that has a passwordHash (created/updated), otherwise fallback to first match
  let rider = candidates.find((r) => r.passwordHash) || candidates[0];
  let valid = false;

  const attemptStaffFallback = async () => {
    const staff = staffMembers.find((s) => {
      const username = (s.username || '').toString().trim().toLowerCase();
      const staffEmail = (s.email || '').toString().trim().toLowerCase();
      const normalizedRole = (s.role || '').toString().trim().toLowerCase();
      const loginEnabled = s.loginEnabled !== false;
      if (!loginEnabled) return false;
      if (normalizedRole !== 'rider' && normalizedRole !== 'admin rider') return false;
      return username === loginValue || staffEmail === loginValue;
    });

    if (!staff) return null;

    if (typeof staff.password !== 'string' || password !== staff.password) {
      return null;
    }

    let targetRider = rider;
    if (staff.riderId) {
      targetRider = riders.find((r) => r.id === staff.riderId) || rider;
    }

    if (!targetRider) {
      const passwordHash = await bcrypt.hash(password || '', 10);
      targetRider = createRecord('riders', {
        name: staff.name || staff.username,
        phone: staff.phone || '',
        email: staff.username,
        username: staff.username,
        passwordHash,
        rawPassword: staff.password,
        role: staff.role,
        status: 'active'
      });
      updateRecord('staff', staff.id, { ...staff, riderId: targetRider.id });
    }

    return targetRider;
  };

  if (rider) {
    if (rider.passwordHash) {
      valid = await bcrypt.compare(password || '', rider.passwordHash);
    } else if (typeof rider.password === 'string') {
      valid = password === rider.password;
    } else if (typeof rider.rawPassword === 'string') {
      valid = password === rider.rawPassword;
    }
  }

  if (!valid) {
    const staffRider = await attemptStaffFallback();
    if (staffRider) {
      rider = staffRider;
      valid = true;
    }
  }

  if (!valid || !rider) {
    console.warn(`Rider login failed for '${loginValue}' riderId=${rider?.id || 'none'}`);
    return res.status(401).send({ error: 'Invalid rider credentials' });
  }

  const normalizedRole = (rider.role || '').toString().trim().toLowerCase();
  const isAdminRider = normalizedRole === 'admin' || normalizedRole === 'admin rider' || normalizedRole.includes('admin');
  const tokenRole = isAdminRider ? 'admin rider' : 'rider';
  const token = jwt.sign(
    {
      id: rider.id,
      email: rider.email,
      role: tokenRole,
      name: rider.name
    },
    JWT_SECRET,
    { expiresIn: '6h' }
  );

  res.send({ token, rider: { id: rider.id, name: rider.name, email: rider.email, phone: rider.phone, role: rider.role } });
}));

router.get('/auth/rider-debug', authenticate, safe(async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).send({ error: 'Forbidden' });
  }

  const email = (req.query.email || '').toString().trim().toLowerCase();
  if (!email) {
    return res.status(400).send({ error: 'email query parameter is required' });
  }

  const riders = getCollection('riders');
  const candidates = riders.filter((r) => {
    const riderEmail = (r.email || '').toString().trim().toLowerCase();
    const riderUsername = (r.username || '').toString().trim().toLowerCase();
    return riderEmail === email || riderUsername === email;
  });

  const debugData = candidates.map((r) => ({
    id: r.id,
    email: r.email,
    username: r.username,
    role: r.role,
    status: r.status,
    hasPasswordHash: Boolean(r.passwordHash),
    hasRawPassword: Boolean(r.rawPassword),
    loginEnabled: r.loginEnabled !== false
  }));

  res.send({ email, matches: debugData });
}));

router.get('/auth/rider-me', authenticate, (req, res) => {
  const riders = getCollection('riders');
  const rider = riders.find((r) => r.id === req.user.id);
  if (!rider) {
    return res.status(401).send({ error: 'Rider not found' });
  }
  res.send({ id: rider.id, name: rider.name, email: rider.email, phone: rider.phone, role: rider.role });
});

router.get('/pos/categories', (req, res) => {
  res.send(getCollection('pos_categories'));
});

router.get('/pos/products', (req, res) => {
  res.send(getCollection('pos_products'));
});

// Public: return basic rider/hotel settings without requiring auth
router.get('/settings', (req, res) => {
  const db = readDb();
  res.send(db.settings || {});
});

router.use(authenticate);

const collections = ['rooms', 'reservations', 'inventory', 'staff', 'sales', 'invoices', 'pos_categories', 'pos_products', 'pos_tables', 'delivery_agents', 'delivery_service_types', 'delivery_locations', 'pos_customers', 'pos_payments', 'pos_orders', 'riders', 'rider_orders', 'rider_order_requests'];

router.get('/dashboard', (req, res) => {
  const db = readDb();
  const products = db.pos_products || [];

  // Allow optional date range filtering via query params: start, end (ISO or date-only YYYY-MM-DD)
  // If date-only provided, interpret start as 00:00:00Z and end as 23:59:59.999Z to include the full day
  const parseDateParam = (v, isEnd = false) => {
    if (!v) return null;
    // recognize YYYY-MM-DD (10 chars) and treat specially
    if (/^\d{4}-\d{2}-\d{2}$/.test(v)) {
      return new Date(v + (isEnd ? 'T23:59:59.999Z' : 'T00:00:00.000Z'));
    }
    return new Date(v);
  };

  const start = parseDateParam(req.query.start, false);
  const end = parseDateParam(req.query.end, true);

  const productCategoryById = (id) => {
    const normalizedId = String(id || '').trim().toLowerCase();
    const product = products.find((p) => {
      const productId = String(p.id || p.productId || p._id || '').trim().toLowerCase();
      const name = String(p.name || '').trim().toLowerCase();
      return productId === normalizedId || name === normalizedId;
    });
    return (product && String(product.category || '')).toLowerCase();
  };

  const isPaidOrder = (order) => {
    const status = String(order.status || '').toLowerCase();
    const paymentStatus = String(order.paymentStatus || '').toLowerCase();
    if (paymentStatus === 'paid') return true;
    if (['payment collected', 'completed', 'delivered'].includes(status)) return true;
    return false;
  };

  const orderRevenue = (order) => {
    const baseTotal = Number(order.total || order.amount || 0) || 0;
    const extrasAmount = (order.items || []).reduce((sum, item) => {
      const category = productCategoryById(item.productId || item.id || item.name);
      if (category.includes('extras') || category.includes('extra')) {
        return sum + (Number(item.total || (item.price || 0) * (item.quantity || 0)) || 0);
      }
      return sum;
    }, 0);
    const deliveryFee = String(order.orderType || '').toLowerCase() === 'delivery' ? Number(order.deliveryFee || 0) || 0 : 0;
    return Math.max(0, baseTotal - extrasAmount - deliveryFee);
  };

  const matchesDateRange = (order) => {
    if (!start && !end) return true;
    const t = new Date(order.createdAt);
    if (start && t < start) return false;
    if (end && t > end) return false;
    return true;
  };

  const paidOrders = (db.pos_orders || []).filter((order) => isPaidOrder(order) && matchesDateRange(order));

  // Normalize order types (handle variants like 'Dine-In', 'Dine In', etc.)
  const getOrderTypeKey = (order) => {
    const t = String(order.orderType || '').toLowerCase();
    if (!t) return null;
    if (t.includes('dine')) return 'Dine';
    if (t.includes('take')) return 'Takeaway';
    if (t.includes('deliver') || t.includes('deliv')) return 'Delivery';
    return null;
  };

  // Order type summary
  const types = ['Delivery', 'Takeaway', 'Dine'];
  const orderTypeSummary = {};
  types.forEach((type) => {
    const list = paidOrders.filter((o) => getOrderTypeKey(o) === type);
    orderTypeSummary[type] = {
      count: list.length,
      revenue: list.reduce((s, it) => s + orderRevenue(it), 0)
    };
  });

  // Time series (daily) for the range or last 7 days if none provided
  const MS_IN_DAY = 24 * 60 * 60 * 1000;
  let seriesStart = start;
  let seriesEnd = end;
  if (!seriesEnd || !seriesStart) {
    seriesEnd = new Date();
    seriesStart = new Date(seriesEnd.getTime() - 6 * MS_IN_DAY);
  }

  const dates = [];
  for (let t = new Date(seriesStart); t <= seriesEnd; t = new Date(t.getTime() + MS_IN_DAY)) {
    const key = new Date(t).toISOString().slice(0, 10);
    dates.push(key);
  }

  const salesSeries = { dates, Delivery: [], Takeaway: [], Dine: [] };
  dates.forEach((d) => {
    const dayStart = new Date(d + 'T00:00:00.000Z');
    const dayEnd = new Date(dayStart.getTime() + MS_IN_DAY - 1);
    ['Delivery', 'Takeaway', 'Dine'].forEach((type) => {
      const list = paidOrders.filter((o) => {
        const t = new Date(o.createdAt);
        return getOrderTypeKey(o) === type && t >= dayStart && t <= dayEnd;
      });
      const sum = list.reduce((s, it) => s + orderRevenue(it), 0);
      salesSeries[type].push(sum);
    });
  });

  // Top products across the filtered paid orders
  const productMap = {};
  paidOrders.forEach((o) => {
    (o.items || []).forEach((it) => {
      const category = productCategoryById(it.productId || it.id || it.name);
      if (category.includes('extras') || category.includes('extra')) return;
      const id = it.productId || it.id || it.name;
      if (!productMap[id]) productMap[id] = { productId: id, name: it.name || id, totalQuantity: 0, totalRevenue: 0 };
      productMap[id].totalQuantity += Number(it.quantity || 0);
      productMap[id].totalRevenue += Number(it.total || (it.price || 0) * (it.quantity || 0));
    });
  });
  const topProducts = Object.values(productMap).sort((a, b) => b.totalQuantity - a.totalQuantity).slice(0, 10);

  topProducts.forEach((p) => {
    p.series = dates.map((d) => 0);
  });
  paidOrders.forEach((o) => {
    const dayKey = new Date(o.createdAt).toISOString().slice(0, 10);
    const dateIndex = dates.indexOf(dayKey);
    if (dateIndex === -1) return;
    (o.items || []).forEach((it) => {
      const category = productCategoryById(it.productId || it.id || it.name);
      if (category.includes('extras') || category.includes('extra')) return;
      const id = it.productId || it.id || it.name;
      const tp = topProducts.find((x) => x.productId === id);
      if (tp) tp.series[dateIndex] += Number(it.quantity || 0);
    });
  });

  const totalOrders = paidOrders.length;
  const totalRevenue = paidOrders.reduce((s, it) => s + orderRevenue(it), 0);

  res.send({
    orderTypeSummary,
    salesSeries,
    topProducts,
    totalOrders,
    totalRevenue,
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
    // Admin-only delete for pos_orders
    if (collection === 'pos_orders') {
      const userRole = (req.user.role || '').toLowerCase();
      if (userRole !== 'admin' && userRole !== 'admin rider') {
        return res.status(403).send({ error: 'Forbidden: Only admin riders can delete orders' });
      }
    }

    const removed = removeRecord(collection, req.params.id);
    if (!removed) {
      return res.status(404).send({ error: 'Record not found' });
    }

    // Clean up related records when deleting orders
    if (collection === 'pos_orders') {
      const remainingRequests = getCollection('rider_order_requests').filter((r) => r.orderId !== req.params.id);
      saveCollection('rider_order_requests', remainingRequests);
      const remainingRiderOrders = getCollection('rider_orders').filter((r) => r.orderId !== req.params.id);
      saveCollection('rider_orders', remainingRiderOrders);
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

router.put('/pos/categories/:id', (req, res) => {
  const updated = updateRecord('pos_categories', req.params.id, req.body);
  if (!updated) {
    return res.status(404).send({ error: 'Category not found' });
  }
  res.send(updated);
});

router.delete('/pos/categories/:id', (req, res) => {
  const removed = removeRecord('pos_categories', req.params.id);
  if (!removed) {
    return res.status(404).send({ error: 'Category not found' });
  }
  res.send({ success: true });
});

router.get('/pos/products', (req, res) => {
  res.send(getCollection('pos_products'));
});

router.post('/pos/products', (req, res) => {
  const product = req.body;
  const created = createRecord('pos_products', product);
  res.status(201).send(created);
});

router.put('/pos/products/:id', (req, res) => {
  const updated = updateRecord('pos_products', req.params.id, req.body);
  if (!updated) {
    return res.status(404).send({ error: 'Product not found' });
  }
  res.send(updated);
});

router.delete('/pos/products/:id', (req, res) => {
  const removed = removeRecord('pos_products', req.params.id);
  if (!removed) {
    return res.status(404).send({ error: 'Product not found' });
  }
  res.send({ success: true });
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

router.get('/pos/mashallah-slots', (req, res) => {
  res.send(getCollection('pos_mashallah_slots'));
});

router.put('/pos/mashallah-slots', (req, res) => {
  const slots = req.body;
  if (!Array.isArray(slots)) {
    return res.status(400).send({ error: 'Expected an array of slots' });
  }
  saveCollection('pos_mashallah_slots', slots);
  res.send(slots);
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
    serviceType = '',
    deliveryFee = 0,
    discount = 0,
    taxPercent = 0,
    serviceCharge = 0,
    paymentMethod = 'Cash',
    paymentStatus = '',
    notes = ''
  } = req.body;

  if (!items || !items.length) {
    return res.status(400).send({ error: 'Cart cannot be empty' });
  }

  if (!orderType) {
    return res.status(400).send({ error: 'Order type is required' });
  }

  if (orderType === 'Delivery' && !address) {
    return res.status(400).send({ error: 'Delivery orders require an address' });
  }

  if (orderType === 'Dine-In' && !tableNumber) {
    return res.status(400).send({ error: 'Dine-In orders require a table or room selection' });
  }

  const products = getCollection('pos_products');
  const orderItems = [];

  for (const item of items) {
    const product = products.find((product) => product.id === item.productId);
    if (!product) {
      return res.status(400).send({ error: `Product not found: ${item.productId}` });
    }

    const quantity = Number(item.quantity || 0);
    if (quantity <= 0) {
      return res.status(400).send({ error: `Invalid quantity for ${product.name}` });
    }

    const stock = Number(product.availableStock ?? product.stock ?? 0);
    if (stock > 0 && stock < quantity) {
      return res.status(400).send({ error: `Insufficient stock for ${product.name}` });
    }

    const price = Number(item.price || product.price) || 0;
    orderItems.push({
      productId: product.id,
      name: item.name || product.name,
      price,
      quantity,
      notes: item.notes || '',
      weight: item.weight || '',
      flavor: item.flavor || '',
      total: price * quantity
    });
  }

  const subtotal = orderItems.reduce((sum, item) => sum + item.total, 0);
  const discountValue = Number(discount) || 0;
  const taxValue = ((subtotal - discountValue) * (Number(taxPercent) || 0)) / 100;
  const deliveryValue = orderType === 'Delivery' ? (Number(deliveryFee) || 0) : 0;
  const serviceValue = Number(serviceCharge) || 0;
  const total = Math.max(0, subtotal - discountValue + taxValue + deliveryValue + serviceValue);

  const customers = getCollection('pos_customers');
  let customerId;
  if (phone || (orderType === 'Delivery' && address)) {
    let existingCustomer;
    if (orderType === 'Delivery' && address) {
      // For delivery orders, match by address first
      existingCustomer = customers.find(
        (customer) => customer.address === address
      );
    }
    if (!existingCustomer && customerName && phone) {
      // Fallback to name and phone matching
      existingCustomer = customers.find(
        (customer) => customer.name === customerName && customer.phone === phone
      );
    }
    if (existingCustomer) {
      customerId = existingCustomer.id;
    } else {
      customerId = createRecord('pos_customers', { name: customerName || '', phone: phone || '', address: address || '' }).id;
    }
  }

  const orderStatus = req.body.status || (orderType === 'Delivery' ? (deliveryAgent ? 'Riders Assigned' : 'Pending') : 'New');
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
    paymentStatus,
    notes,
    items: orderItems,
    serviceType,
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

  const riderOrders = getCollection('rider_orders') || [];
  const matchedOrder = riderOrders.find((order) => order.orderId === req.params.id);
  if (matchedOrder) {
    const riders = getCollection('riders') || [];
    const rider = riders.find((r) => (r.name || '').toLowerCase() === (deliveryAgent || '').toLowerCase());
    updateRecord('rider_orders', matchedOrder.id, {
      status: 'assigned',
      riderId: rider ? rider.id : matchedOrder.riderId || null,
      updatedAt: new Date().toISOString()
    });
  }

  res.send(updated);
});
router.delete('/pos/orders/:id', (req, res) => {
  const userRole = (req.user.role || '').toLowerCase();
  if (userRole !== 'admin' && userRole !== 'admin rider') {
    return res.status(403).send({ error: 'Forbidden: Only admin riders can delete orders' });
  }

  const orderId = req.params.id;
  let deleted = removeRecord('pos_orders', orderId);
  if (!deleted) {
    deleted = removeRecord('rider_orders', orderId);
  }

  if (!deleted) {
    const riderOrders = getCollection('rider_orders') || [];
    const filtered = riderOrders.filter((r) => r.orderId !== orderId);
    if (filtered.length !== riderOrders.length) {
      saveCollection('rider_orders', filtered);
      deleted = true;
    }
  }

  if (!deleted) {
    return res.status(404).send({ error: 'Order not found' });
  }

  const remainingRequests = getCollection('rider_order_requests').filter((r) => r.orderId !== orderId);
  saveCollection('rider_order_requests', remainingRequests);

  const remainingRiderOrders = getCollection('rider_orders').filter((r) => r.orderId !== orderId);
  saveCollection('rider_orders', remainingRiderOrders);

  res.send({ success: true, message: 'Order deleted successfully' });
});

router.post('/admin/clear-rider-app', authenticate, (req, res) => {
  if (req.user.role !== 'admin' && req.user.role !== 'admin rider') {
    return res.status(403).send({ error: 'Forbidden' });
  }

  saveCollection('rider_order_requests', []);
  saveCollection('rider_orders', []);

  res.send({ success: true, message: 'Rider app data cleared for a fresh start' });
});

router.put('/pos/orders/:id/assign-waiter', (req, res) => {
  const { waiter } = req.body;
  const updated = updateRecord('pos_orders', req.params.id, {
    waiter,
    updatedAt: new Date().toISOString()
  });
  if (!updated) {
    return res.status(404).send({ error: 'Order not found' });
  }
  res.send(updated);
});

router.put('/pos/orders/:id', (req, res) => {
  const { items, customerName, phone, address, tableNumber, deliveryAgent, serviceType, deliveryFee, discount, taxPercent, serviceCharge, paymentMethod, paymentStatus, notes, status } = req.body;

  const itemsList = items || [];
  const computedSubtotal = itemsList.reduce((sum, item) => sum + (Number(item.total) || (Number(item.price || 0) * Number(item.quantity || 0))), 0);
  const discountValue = Number(discount) || 0;
  const taxValue = ((computedSubtotal - discountValue) * (Number(taxPercent) || 0)) / 100;
  // Determine orderType: prefer provided, otherwise use existing order's type
  const existingOrder = getCollection('pos_orders').find((o) => o.id === req.params.id) || {};
  const effectiveOrderType = req.body.orderType || existingOrder.orderType || 'Dine-In';
  const deliveryValue = effectiveOrderType === 'Delivery' ? (Number(deliveryFee) || 0) : 0;
  const serviceValue = Number(serviceCharge) || 0;
  const computedTotal = Math.max(0, computedSubtotal - discountValue + taxValue + deliveryValue + serviceValue);

  const updated = updateRecord('pos_orders', req.params.id, {
    items: itemsList,
    customerName: customerName || '',
    phone: phone || '',
    address: address || '',
    tableNumber: tableNumber || '',
    deliveryAgent: deliveryAgent || '',
    serviceType: serviceType || '',
    deliveryFee: Number(deliveryValue) || 0,
    discount: discountValue,
    taxPercent: Number(taxPercent) || 0,
    serviceCharge: serviceValue,
    paymentMethod: paymentMethod || 'Cash',
    paymentStatus: paymentStatus || '',
    notes: notes || '',
    status: status || 'New',
    subtotal: computedSubtotal,
    total: computedTotal,
    updatedAt: new Date().toISOString()
  });
  if (!updated) {
    return res.status(404).send({ error: 'Order not found' });
  }

  if ((paymentStatus || '').toLowerCase().includes('payment') || (status || '').toLowerCase().includes('payment')) {
    const riderOrders = getCollection('rider_orders') || [];
    const matchedOrder = riderOrders.find((order) => order.orderId === req.params.id);
    if (matchedOrder) {
      updateRecord('rider_orders', matchedOrder.id, {
        status: 'completed',
        updatedAt: new Date().toISOString()
      });
    }
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

router.use((err, req, res, next) => {
  console.error('Unhandled server error:', err);
  res.status(500).send({ error: err.message || 'Internal Server Error' });
});

// Google Sheets endpoints removed

// Rider Order Management Routes
router.get('/rider/assigned-orders/:riderId', authenticate, (req, res) => {
  const userRole = (req.user.role || '').toLowerCase();
  const isAdminRider = userRole === 'admin' || userRole === 'admin rider';

  const riderOrders = getCollection('rider_orders') || [];
  const assignedFromRiderOrders = riderOrders.filter((o) => o.status === 'assigned' && (isAdminRider || o.riderId === req.params.riderId));

  const posOrders = getCollection('pos_orders') || [];
  const riders = getCollection('riders') || [];
  const rider = riders.find((r) => r.id === req.params.riderId);

  const assignedFromPosOrders = [];
  if (rider || isAdminRider) {
    const riderName = rider ? (rider.name || '').toLowerCase() : null;
    posOrders.forEach((po) => {
      if ((po.status || '').toLowerCase() === 'riders assigned') {
        if (isAdminRider || (riderName && (po.deliveryAgent || '').toLowerCase() === riderName)) {
          assignedFromPosOrders.push({
            id: po.id,
            riderId: req.params.riderId,
            originalOrder: po,
            status: po.status
          });
        }
      }
    });
  }

  res.send([...assignedFromRiderOrders, ...assignedFromPosOrders]);
});

router.get('/rider/kitchen-orders', authenticate, (req, res) => {
  const riderOrders = getCollection('rider_orders') || [];
  const posOrders = getCollection('pos_orders') || [];

  const kitchenRiderOrders = riderOrders.filter((o) => !o.riderId && o.status === 'kitchen');
  const kitchenPosOrders = posOrders
    .filter((o) => o.orderType === 'Delivery' && o.status === 'Kitchen')
    .filter((po) => !riderOrders.some((ro) => ro.orderId === po.id));

  const mappedPosOrders = kitchenPosOrders.map((order) => ({
    id: order.id,
    orderId: order.id,
    originalOrder: order,
    status: 'kitchen'
  }));

  res.send([...kitchenRiderOrders, ...mappedPosOrders]);
});

router.get('/rider/approved-orders/:riderId', authenticate, (req, res) => {
  const userRole = (req.user.role || '').toLowerCase();
  const isAdminRider = userRole === 'admin' || userRole === 'admin rider';
  const riderOrders = getCollection('rider_orders') || [];
  const orders = riderOrders.filter((o) => o.status === 'approved' && (isAdminRider || o.riderId === req.params.riderId));
  res.send(orders);
});

router.get('/rider/requested-orders/:riderId', authenticate, (req, res) => {
  const userRole = (req.user.role || '').toLowerCase();
  const isAdminRider = userRole === 'admin' || userRole === 'admin rider';
  const requests = getCollection('rider_order_requests') || [];
  const posOrders = getCollection('pos_orders') || [];
  const riderOrders = getCollection('rider_orders') || [];
  const riderRequests = isAdminRider ? requests : requests.filter((request) => request.riderId === req.params.riderId);

  const requestedWithOrders = riderRequests.map((request) => ({
    id: request.id,
    riderId: request.riderId,
    orderId: request.orderId,
    status: request.status,
    requestedAt: request.requestedAt,
    originalOrder:
      posOrders.find((order) => order.id === request.orderId) ||
      riderOrders.find((order) => order.id === request.orderId)
  }));

  res.send(requestedWithOrders);
});

router.get('/rider/delivered-orders/:riderId/:paymentMethod', authenticate, (req, res) => {
  const userRole = (req.user.role || '').toLowerCase();
  const isAdminRider = userRole === 'admin' || userRole === 'admin rider';
  const paymentMethod = req.params.paymentMethod; // 'cash' or 'online'
  
  const posOrders = getCollection('pos_orders') || [];
  const riders = getCollection('riders') || [];
  const rider = riders.find((r) => r.id === req.params.riderId);
  
  const deliveredOrders = [];
  if (rider || isAdminRider) {
    const riderName = rider ? (rider.name || '').toLowerCase() : null;
    posOrders.forEach((po) => {
      if ((po.status || '').toLowerCase() === 'payment collected') {
        const matchesPayment = paymentMethod.toLowerCase() === 'cash' 
          ? (po.paymentMethod || '').toLowerCase() === 'cash'
          : paymentMethod.toLowerCase() === 'online'
          ? (po.paymentMethod || '').toLowerCase() === 'online'
          : true;
        
        if (matchesPayment && (isAdminRider || (riderName && (po.deliveryAgent || '').toLowerCase() === riderName))) {
          deliveredOrders.push({
            id: po.id,
            riderId: req.params.riderId,
            originalOrder: po,
            status: po.status,
            paymentMethod: po.paymentMethod
          });
        }
      }
    });
  }
  
  res.send(deliveredOrders);
});

router.get('/rider/delivered-orders/:riderId', authenticate, (req, res) => {
  const userRole = (req.user.role || '').toLowerCase();
  const isAdminRider = userRole === 'admin' || userRole === 'admin rider';
  
  const posOrders = getCollection('pos_orders') || [];
  const riders = getCollection('riders') || [];
  const rider = riders.find((r) => r.id === req.params.riderId);
  
  const deliveredOrders = [];
  if (rider || isAdminRider) {
    const riderName = rider ? (rider.name || '').toLowerCase() : null;
    posOrders.forEach((po) => {
      if ((po.status || '').toLowerCase() === 'payment collected') {
        if (isAdminRider || (riderName && (po.deliveryAgent || '').toLowerCase() === riderName)) {
          deliveredOrders.push({
            id: po.id,
            riderId: req.params.riderId,
            originalOrder: po,
            status: po.status,
            paymentMethod: po.paymentMethod
          });
        }
      }
    });
  }
  
  res.send(deliveredOrders);
});

router.post('/rider/request-approval', authenticate, (req, res) => {
  const { riderId, orderId } = req.body;
  const posOrders = getCollection('pos_orders') || [];
  const riderOrders = getCollection('rider_orders') || [];
  const existingRiderOrder = riderOrders.find((order) => order.orderId === orderId);

  if (!existingRiderOrder) {
    const posOrder = posOrders.find((order) => order.id === orderId);
    if (posOrder) {
      createRecord('rider_orders', {
        orderId: posOrder.id,
        riderId: null,
        originalOrder: posOrder,
        status: 'kitchen',
        createdAt: new Date().toISOString()
      });
    }
  }

  const request = createRecord('rider_order_requests', {
    orderId,
    riderId,
    status: 'pending',
    requestedAt: new Date().toISOString()
  });
  res.status(201).send(request);
});

router.get('/rider/requests', authenticate, (req, res) => {
  const requests = getCollection('rider_order_requests') || [];
  res.send(requests);
});

router.get('/rider/pending-requests', authenticate, (req, res) => {
  const requests = getCollection('rider_order_requests') || [];
  const pending = requests.filter((r) => r.status === 'pending');
  res.send(pending);
});

// Admin: clear all rider order requests (useful for fresh start/testing)
router.post('/admin/clear-requested-orders', authenticate, (req, res) => {
  if (req.user.role !== 'admin') return res.status(403).send({ error: 'Forbidden' });
  saveCollection('rider_order_requests', []);
  res.send({ success: true, message: 'Cleared rider order requests' });
});

router.put('/rider/approve-request/:requestId', authenticate, (req, res) => {
  const request = updateRecord('rider_order_requests', req.params.requestId, { status: 'approved' });
  if (!request) return res.status(404).send({ error: 'Request not found' });
  
  const riderOrders = getCollection('rider_orders') || [];
  const posOrders = getCollection('pos_orders') || [];
  const riders = getCollection('riders') || [];
  const rider = riders.find((r) => r.id === request.riderId);
  const riderName = rider?.name || '';
  let order = riderOrders.find((o) => o.orderId === request.orderId);

  updateRecord('pos_orders', request.orderId, {
    deliveryAgent: riderName,
    status: 'Riders Assigned',
    updatedAt: new Date().toISOString()
  });

  if (order) {
    updateRecord('rider_orders', order.id, {
      status: 'assigned',
      riderId: request.riderId,
      updatedAt: new Date().toISOString()
    });
  } else {
    const posOrder = posOrders.find((o) => o.id === request.orderId);
    if (posOrder) {
      order = createRecord('rider_orders', {
        orderId: posOrder.id,
        riderId: request.riderId,
        originalOrder: posOrder,
        status: 'assigned',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      });
    }
  }
  
  res.send(request);
});

router.put('/rider/reject-request/:requestId', authenticate, (req, res) => {
  const request = updateRecord('rider_order_requests', req.params.requestId, { status: 'rejected' });
  if (!request) return res.status(404).send({ error: 'Request not found' });
  
  // Update the order status back to kitchen
  const riderOrders = getCollection('rider_orders') || [];
  const order = riderOrders.find((o) => o.orderId === request.orderId);
  if (order) {
    updateRecord('rider_orders', order.id, { status: 'kitchen', riderId: null });
  }
  
  res.send(request);
});

router.post('/pos/order-to-delivery', (req, res) => {
  const { orderId, riderId } = req.body;
  const order = req.body;
  
  const riderOrder = createRecord('rider_orders', {
    orderId,
    riderId: riderId || null,
    originalOrder: order,
    status: riderId ? 'assigned' : 'kitchen',
    createdAt: new Date().toISOString()
  });
  
  res.status(201).send(riderOrder);
});

router.post('/rider/set-password', authenticate, safe(async (req, res) => {
  const { riderId, password } = req.body;
  if (!password) return res.status(400).send({ error: 'Password is required' });
  
  const riders = getCollection('riders');
  const rider = riders.find((r) => r.id === riderId);
  if (!rider) return res.status(404).send({ error: 'Rider not found' });
  
  const passwordHash = await bcrypt.hash(password, 10);
  const updated = updateRecord('riders', riderId, { passwordHash, rawPassword: password });
  
  res.send({ success: true, rider: { id: updated.id, name: updated.name, email: updated.email } });
}));

// Create rider with password (admin only)
router.post('/riders/create', authenticate, safe(async (req, res) => {
  if (req.user.role !== 'admin') return res.status(403).send({ error: 'Forbidden' });
  const { name, phone, email, password, role } = req.body;
  if (!name || !email || !password) return res.status(400).send({ error: 'name, email and password are required' });
  const normalizedEmail = (email || '').toString().trim().toLowerCase();
  const assignedRole = normalizedEmail === 'ahmed@rider.com' ? 'Admin Rider' : (role && ['Admin Rider', 'Rider'].includes(role) ? role : 'Rider');
  const passwordHash = await bcrypt.hash(password, 10);
  const rider = createRecord('riders', {
    name,
    phone,
    email,
    username: email,
    passwordHash,
    rawPassword: password,
    role: assignedRole,
    status: 'active'
  });
  res.status(201).send(rider);
}));

router.post('/admin/rider-repair', authenticate, safe(async (req, res) => {
  if (req.user.role !== 'admin') return res.status(403).send({ error: 'Forbidden' });

  const staffMembers = getCollection('staff') || [];
  const riders = getCollection('riders') || [];
  const created = [];
  const linked = [];
  const skipped = [];

  for (const staff of staffMembers) {
    const normalizedRole = (staff.role || '').toString().trim().toLowerCase();
    const loginEnabled = staff.loginEnabled !== false;
    if (!loginEnabled) continue;
    if (normalizedRole !== 'rider' && normalizedRole !== 'admin rider') continue;
    if (!staff.username) {
      skipped.push({ staffId: staff.id, reason: 'missing username' });
      continue;
    }

    const loginValue = staff.username.toString().trim().toLowerCase();
    const existingRider = riders.find((r) => {
      const riderEmail = (r.email || '').toString().trim().toLowerCase();
      const riderUsername = (r.username || '').toString().trim().toLowerCase();
      return riderEmail === loginValue || riderUsername === loginValue;
    });

    if (existingRider) {
      if (!staff.riderId || staff.riderId !== existingRider.id) {
        updateRecord('staff', staff.id, { ...staff, riderId: existingRider.id });
      }
      linked.push({ staffId: staff.id, riderId: existingRider.id });
      continue;
    }

    if (!staff.password) {
      skipped.push({ staffId: staff.id, reason: 'missing password' });
      continue;
    }

    const normalizedStaffEmail = (staff.username || '').toString().trim().toLowerCase();
    // Preserve original role (Admin Rider or Rider) when creating rider record
    const riderRole = normalizedStaffEmail === 'ahmed@rider.com' ? 'Admin Rider' : 'Rider';
    const passwordHash = await bcrypt.hash(staff.password, 10);
    const rider = createRecord('riders', {
      name: staff.name || staff.username,
      phone: staff.phone || '',
      email: staff.username,
      passwordHash,
      rawPassword: staff.password,
      role: riderRole,
      status: 'active'
    });

    updateRecord('staff', staff.id, { ...staff, riderId: rider.id });
    created.push({ staffId: staff.id, riderId: rider.id });
  }

  res.send({ created, linked, skipped });
}));

// Return raw password for a rider (admin only)
router.get('/riders/raw/:id', authenticate, (req, res) => {
  if (req.user.role !== 'admin') return res.status(403).send({ error: 'Forbidden' });
  const riders = getCollection('riders');
  const rider = riders.find((r) => r.id === req.params.id);
  if (!rider) return res.status(404).send({ error: 'Rider not found' });
  res.send({ id: rider.id, email: rider.email, rawPassword: rider.rawPassword || null });
});
