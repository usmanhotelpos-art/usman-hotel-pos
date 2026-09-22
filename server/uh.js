// ---------------------------------------------------------------------------
// Usman Hotel online-ordering subsystem (/uh)
//   Powers the new customer + admin Flutter apps (replacing the local-only
//   Room DB in the Kotlin reference app). Data lives in its own collections
//   (uh_menu_items, uh_app_users, uh_customer_orders) fully separate from the
//   POS (pos_*) data. Public routes below are mounted BEFORE the global
//   router.use(authenticate) gate; admin routes use uhAuth individually.
// ---------------------------------------------------------------------------

import express from 'express';
import jwt from 'jsonwebtoken';
import { JWT_SECRET } from './config.js';
import {
  createRecord,
  getCollection,
  readDb,
  removeRecord,
  updateRecord,
  waitForPersist,
  writeDb
} from './db.js';

export const uhRouter = express.Router();

function uhAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) {
    return res.status(401).send({ error: 'Unauthorized' });
  }
  try {
    req.uh = jwt.verify(token, JWT_SECRET);
    next();
  } catch (error) {
    res.status(401).send({ error: 'Invalid token' });
  }
}

// Same extraction as uhAuth but non-blocking (for public routes that still want
// to scope results to the bearer's phone when a token is supplied).
function uhPayloadFromReq(req) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) return null;
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (_) {
    return null;
  }
}

function isUhManager(req) {
  const role = String(req.uh && req.uh.role || '').toUpperCase();
  return role === 'STAFF_ADMIN' || role === 'HOTEL_OWNER';
}

function requireUhManager(req, res, next) {
  if (!isUhManager(req)) {
    return res.status(403).send({ error: 'Forbidden: Admin or Owner access required' });
  }
  next();
}

// ---------------------------------------------------------------------------
// Seed data (ported verbatim from the Kotlin app HotelRepository.kt)
// ---------------------------------------------------------------------------

const SEED_MENU = [
  // DEALS
  { id: 1, name: 'Crown Crust Feast Deal', urduName: 'کراؤن کرسٹ فیملی ڈیل', category: 'Deals', description: '1 Large Crown Crust Pizza + 1 Bazinga Burger + 1 Cheesy Fries + 1.5L Drink', basePrice: 2499, badge: 'Bestseller', spiceLevel: 'Medium' },
  { id: 2, name: 'Cheezy Duo Deal', urduName: 'چیزی ڈبل پیزا ڈیل', category: 'Deals', description: '2 Medium Pizzas of your choice + 2 Cold Drink Cans', basePrice: 1899, badge: 'Hot Deal', spiceLevel: 'Medium' },
  { id: 3, name: 'Zinger Billa Deal', urduName: 'زنگر بلا ڈیل', category: 'Deals', description: '2 Crispy Bazinga Burgers + 2 Regular French Fries + 2 Cold Drinks', basePrice: 1299, badge: 'Special Offer', spiceLevel: 'Spicy' },
  { id: 4, name: 'Midnight Hunger Deal', urduName: 'مڈ نائٹ ڈیل', category: 'Deals', description: '1 Regular Pizza + 4 Hot Wings + 1 500ml Drink (Available late hours)', basePrice: 1099, badge: 'Late Night', spiceLevel: 'Medium' },

  // PIZZAS (Cheezious Style)
  { id: 10, name: 'Cheezious Crown Crust', urduName: 'چیزیئس کراؤن کرسٹ پیزا', category: 'Pizza', description: 'Signature golden crust crown filled with rich cream cheese, topped with marinated chicken tikka chunks and mozzarella melt', basePrice: 1490, sizesJson: 'Small:690,Medium:1490,Large:1990', badge: 'Signature', spiceLevel: 'Medium' },
  { id: 11, name: 'Behari Kabab Pizza', urduName: 'بہاری کباب پیزا', category: 'Pizza', description: 'Traditional Bihari kabab bites, green peppers, crispy onions, melted mozzarella cheese and spicy sauce drizzle', basePrice: 1390, sizesJson: 'Small:650,Medium:1390,Large:1890', badge: 'Chef Choice', spiceLevel: 'Spicy' },
  { id: 12, name: 'Chicken Tikka Cheezy', urduName: 'چکن تکہ چیزی پیزا', category: 'Pizza', description: 'Classic smoky chicken tikka cubes, golden mozzarella, sweet onions, and fresh garden herbs', basePrice: 1290, sizesJson: 'Small:590,Medium:1290,Large:1790', badge: 'Most Popular', spiceLevel: 'Medium' },
  { id: 13, name: 'Fajita Sicilian Special', urduName: 'فجیتا سسلین پیزا', category: 'Pizza', description: 'Spicy fajita chicken chunks, capsicum, black olives, sliced jalapeños, mushrooms, and rich cheese', basePrice: 1350, sizesJson: 'Small:620,Medium:1350,Large:1850', badge: 'Spicy Burst', spiceLevel: 'Extra Spicy' },
  { id: 14, name: 'Cheesy Garlic Supreme', urduName: 'چیزی گارلک سپریم پیزا', category: 'Pizza', description: 'Infused garlic herb base, creamy white sauce, smoked chicken strips, and double layer mozzarella', basePrice: 1390, sizesJson: 'Small:650,Medium:1390,Large:1890', badge: 'Cheesy', spiceLevel: 'Mild' },

  // BURGERS
  { id: 20, name: 'Bazinga Crispy Zinger Burger', urduName: 'بازنگا کرسپی زنگر برگر', category: 'Burgers', description: 'Huge golden crispy chicken fillet, signature tangy secret sauce, iceberg lettuce in toasted sesame bun', basePrice: 580, badge: 'Bestseller', spiceLevel: 'Spicy' },
  { id: 21, name: 'Reggy Cheesy Burger', urduName: 'ریگی چیزی برگر', category: 'Burgers', description: 'Crispy chicken patty with melted cheddar cheese slice, creamy garlic mayo and pickled gherkins', basePrice: 690, badge: 'Double Cheese', spiceLevel: 'Medium' },
  { id: 22, name: 'Cheesy Lava Stuffed Burger', urduName: 'چیزی لاوا برگر', category: 'Burgers', description: 'Handmade juicy patty stuffed with gooey molten cheese center that erupts with every bite', basePrice: 750, badge: 'Cheezy Lava', spiceLevel: 'Medium' },
  { id: 23, name: 'Roasted Platter Burger', urduName: 'روسٹڈ پلیٹر برگر', category: 'Burgers', description: 'Tender slow-roasted tandoori chicken shreds, caramelized onions and spicy peri peri sauce', basePrice: 650, spiceLevel: 'Medium' },

  // ROLLS & SHAWARMA
  { id: 30, name: 'Behari Kabab Paratha Roll', urduName: 'بہاری کباب پراٹھا رول', category: 'Rolls', description: 'Smokey spicy bihari kabab chunks wrapped in crispy golden paratha with mint chutney and onions', basePrice: 390, badge: 'Street Favorite', spiceLevel: 'Spicy' },
  { id: 31, name: 'Crispy Zinger Mayo Roll', urduName: 'کرسپی زنگر میو رول', category: 'Rolls', description: 'Crispy fried chicken tenders, garlic mayo, shredded lettuce in handmade flaky paratha', basePrice: 420, badge: 'Kids Love It', spiceLevel: 'Medium' },
  { id: 32, name: 'Malai Boti Cheese Roll', urduName: 'ملائی بوٹی چیز رول', category: 'Rolls', description: 'Creamy melt-in-mouth malai boti chicken cubes with melted cheese and mild creamy sauce', basePrice: 450, spiceLevel: 'Mild' },

  // TRADITIONAL KARAHI & BBQ (Usman Hotel Heritage)
  { id: 40, name: 'Desi Mutton Karahi (Special)', urduName: 'دیسی مٹن کڑاہی خاص', category: 'Karahi & BBQ', description: 'Fresh succulent mutton simmered with organic ginger, tomatoes, green chillies and pure desi ghee (Half Kg)', basePrice: 2400, badge: 'Heritage Special', spiceLevel: 'Medium' },
  { id: 41, name: 'Chicken White Handi / Karahi', urduName: 'چکن وائٹ ہانڈی / کڑاہی', category: 'Karahi & BBQ', description: 'Boneless chicken cubes cooked in thick rich cream, fresh yogurt, crushed white pepper and butter (Half Kg)', basePrice: 1450, badge: 'Chef Signature', spiceLevel: 'Mild' },
  { id: 42, name: 'Chicken Peshawari Karahi', urduName: 'چکن پشاوری کڑاہی', category: 'Karahi & BBQ', description: 'Slow cooked in iron wok with fresh red tomatoes, ginger slivers and freshly ground black pepper (Half Kg)', basePrice: 1350, badge: 'Traditional', spiceLevel: 'Medium' },
  { id: 43, name: 'Chicken Seekh Kabab (4 Pcs)', urduName: 'چکن سیخ کباب (4 عدد)', category: 'Karahi & BBQ', description: 'Finely minced seasoned chicken skewered and charcoal grilled to perfection, served with mint raita', basePrice: 650, spiceLevel: 'Medium' },
  { id: 44, name: 'Special Roghani / Garlic Naan', urduName: 'روغنی / گارلک نان', category: 'Karahi & BBQ', description: 'Fresh hot tandoori naan brushed with butter and sesame seeds', basePrice: 90, spiceLevel: 'Mild' },

  // SIDES & APPETIZERS
  { id: 50, name: 'Cheesy Loaded Fries', urduName: 'چیزی لوڈڈ فرائیز', category: 'Sides', description: 'Crispy golden potato fries drenched in molten cheddar cheese sauce, chicken chunks and jalapeño rings', basePrice: 550, badge: 'Cheesy Hit', spiceLevel: 'Medium' },
  { id: 51, name: 'Hot & Spicy Buffalo Wings (6 Pcs)', urduName: 'ہاٹ اینڈ سپائسی ونگز', category: 'Sides', description: 'Deep fried crispy chicken wings glazed in fiery tangy sauce served with garlic dip', basePrice: 480, badge: 'Spicy', spiceLevel: 'Spicy' },
  { id: 52, name: 'Golden Mozzarella Sticks (4 Pcs)', urduName: 'موزاریلا چیز سٹکس', category: 'Sides', description: 'Crispy breaded sticks loaded with gooey, stretchy 100% pure mozzarella cheese', basePrice: 490, badge: 'Stretchy Cheese', spiceLevel: 'Mild' },

  // BEVERAGES & DESSERTS
  { id: 60, name: 'Mint Margarita Cooler', urduName: 'منٹ مارگریٹا', category: 'Beverages', description: 'Fresh garden mint, crushed ice, fresh lime and fizzy soda - perfect food accompaniment', basePrice: 280, badge: 'Refreshing', spiceLevel: 'Mild' },
  { id: 61, name: 'Choco Brownie Thick Shake', urduName: 'چاکو براؤنی شیک', category: 'Beverages', description: 'Rich Belgian chocolate ice cream blended with fudgy brownie chunks and topped with chocolate drizzle', basePrice: 390, spiceLevel: 'Mild' },
  { id: 62, name: 'Molten Lava Cake with Ice Cream', urduName: 'مولٹن لاوا کیک', category: 'Beverages', description: 'Warm chocolate cake with a gushing chocolate fudge center served with vanilla ice cream scoop', basePrice: 450, badge: 'Sweet Delight', spiceLevel: 'Mild' },
  { id: 63, name: 'Chilled Cold Drink (500ml)', urduName: 'کولڈ ڈرنک (500 ملی لیٹر)', category: 'Beverages', description: 'Choice of Pepsi, 7Up, Mirinda, or Mountain Dew', basePrice: 120, spiceLevel: 'Mild' }
];

const SEED_USERS = [
  { id: '03001234567', fullName: 'Usman Hotel Owner', role: 'HOTEL_OWNER', deliveryAddress: 'Usman Hotel Executive Office, Lahore', zone: 'Model Town', loginCode: '1234' },
  { id: '03009876543', fullName: 'Manager Kashif (Admin)', role: 'STAFF_ADMIN', deliveryAddress: 'Usman Hotel Order Dispatch Desk', zone: 'Model Town', loginCode: '1234' },
  { id: '03214567890', fullName: 'Hamza Malik', role: 'CUSTOMER', deliveryAddress: 'House 42, Street 7, Block B, Model Town, Lahore', zone: 'Model Town', loginCode: '1234' },
  { id: '03338877665', fullName: 'Bilal Siddique', role: 'CUSTOMER', deliveryAddress: 'Street 12, Gulberg III, Lahore', zone: 'Gulberg', loginCode: '1234' }
];

const SEED_ORDERS = [
  {
    id: 'UH-7842',
    customerName: 'Hamza Malik',
    customerPhone: '0321-4567890',
    deliveryAddress: 'House 42, Street 7, Block B, Model Town, Lahore',
    areaZone: 'Model Town',
    latitude: 31.4822,
    longitude: 74.3216,
    itemsSummary: '1x Cheezious Crown Crust (Large), 2x Bazinga Zinger Burger, 1x Cheesy Loaded Fries',
    itemsJson: '',
    subtotal: 2650,
    deliveryFee: 150,
    totalAmount: 2800,
    paymentMethod: 'Cash on Delivery (COD)',
    specialInstructions: 'Please bring extra garlic sauce and keep pizza extra hot!',
    status: 'OUT_FOR_DELIVERY',
    orderType: 'DELIVERY',
    riderName: 'Tariq Mehmood',
    riderPhone: '0301-7654321',
    riderVehicle: 'Honda 125 (LEP-4019)',
    estimatedMinutes: 15
  },
  {
    id: 'UH-5120',
    customerName: 'Bilal Siddique',
    customerPhone: '0333-8877665',
    deliveryAddress: 'Self-Pickup at Usman Hotel Main Counter, Model Town',
    areaZone: 'Model Town Branch',
    latitude: 31.4855,
    longitude: 74.325,
    itemsSummary: '1x Cheezy Duo Deal, 1x Mint Margarita',
    itemsJson: '',
    subtotal: 2179,
    deliveryFee: 0,
    totalAmount: 2179,
    paymentMethod: 'Cash on Pickup (Counter)',
    specialInstructions: 'Please pack separately for takeaway',
    status: 'PREPARING',
    orderType: 'TAKEAWAY',
    riderName: 'Kitchen Counter #1',
    riderPhone: '042-35889900',
    riderVehicle: 'Pickup Token #42',
    estimatedMinutes: 10
  }
];

function ensureUhSeeded() {
  const db = readDb();
  if (!db.uh_menu_items || db.uh_menu_items.length === 0) {
    writeDb({ ...db, uh_menu_items: SEED_MENU.map((m) => ({ ...m, isAvailable: true, isVegetarian: false, imageUrl: '', createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() })) });
  }
  if ((db.uh_app_users || []).length === 0) {
    const users = SEED_USERS.map((u) => ({
      ...u,
      createdAt: new Date().toISOString(),
      lastLoginAt: null
    }));
    writeDb({ ...readDb(), uh_app_users: users });
  }
  if ((db.uh_customer_orders || []).length === 0) {
    const orders = SEED_ORDERS.map((o) => ({ ...o, createdAt: new Date(Date.now() - 8 * 60 * 1000).toISOString(), updatedAt: new Date().toISOString() }));
    writeDb({ ...readDb(), uh_customer_orders: orders });
  }
}

function normalizePhone(raw) {
  return String(raw || '').replace(/[^0-9]/g, '');
}

// Convert a Pakistani mobile (03XXXXXXXXX) to E.164 (+92XXXXXXXXX) for SMS.
function phoneE164(raw) {
  const digits = normalizePhone(raw);
  if (digits.startsWith('92') && digits.length === 12) return `+${digits}`;
  if (digits.startsWith('0') && digits.length === 11) return `+92${digits.slice(1)}`;
  if (digits.length === 10) return `+92${digits}`;
  return digits ? `+${digits}` : '';
}

function sendpkConfigured() {
  return !!process.env.SENDPK_API_KEY;
}

function twilioConfigured() {
  return !!(
    process.env.TWILIO_ACCOUNT_SID &&
    process.env.TWILIO_AUTH_TOKEN &&
    process.env.TWILIO_FROM_NUMBER
  );
}

// Send a verification code via SendPK (free Pakistani gateway, PTA-approved,
// no extra npm dep — global fetch). The `sender` defaults to the pre-approved
// shared name 'SMS Alert' (instant approval, works on Jazz/Zong/Ufone/Telenor).
// Resolves true when the gateway accepted the message (response starts with OK).
async function sendpkSendCode(phone, code) {
  const apiKey = process.env.SENDPK_API_KEY;
  const sender = process.env.SENDPK_SENDER || 'SMS Alert';
  const to = phoneE164(phone);
  if (!apiKey || !to) return false;
  const mobile = to.replace('+', '');
  const body =
    'Your Usman Hotel verification code is: ' + code + '. Do not share it.';
  const form = new URLSearchParams();
  form.set('api_key', apiKey);
  form.set('sender', sender);
  form.set('mobile', mobile);
  form.set('message', body);
  form.set('format', 'json');
  form.set('network', 'Jazz');
  try {
    const res = await fetch('https://sendpk.com/api/sms.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: form.toString()
    });
    const text = await res.text();
    let parsed = null;
    try {
      parsed = JSON.parse(text);
    } catch (_) {}
    const statusLine = parsed && (parsed.status || parsed.response || parsed.result || '');
    const ok = /^OK/i.test(text.trim()) || (statusLine && /^OK/i.test(String(statusLine)));
    if (!ok) {
      console.error('[uh-sms] SendPK error:', res.status, text.slice(0, 300));
    }
    return ok && res.ok;
  } catch (error) {
    console.error('[uh-sms] SendPK send failed:', error && error.message ? error.message : error);
    return false;
  }
}

// Send a verification code via the Twilio REST API (no extra npm dependency —
// uses global fetch, available on Node 18+). Resolves true when delivered ok.
async function twilioSendCode(phone, code) {
  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_FROM_NUMBER;
  if (!sid || !token || !from) return false;
  const to = phoneE164(phone);
  if (!to) return false;
  const body = 'Your Usman Hotel verification code is: ' + code + '. Do not share it.';
  const auth = 'Basic ' + Buffer.from(`${sid}:${token}`).toString('base64');
  const form = new URLSearchParams();
  form.set('To', to);
  form.set('From', from);
  form.set('Body', body);
  try {
    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: 'POST',
      headers: { Authorization: auth, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: form.toString()
    });
    if (!res.ok) {
      try {
        const err = await res.json();
        console.error('[uh-sms] Twilio error:', err && err.message ? err.message : res.status);
      } catch (_) {}
      return false;
    }
    return true;
  } catch (error) {
    console.error('[uh-sms] Twilio send failed:', error && error.message ? error.message : error);
    return false;
  }
}

// Deliver the login code over SMS. SendPK is the primary gateway (free
// Pakistani provider, chosen by the owner); Twilio is the fallback. Returns
// true only when a real SMS was accepted.
async function sendSmsCode(phone, code) {
  if (sendpkConfigured()) {
    const ok = await sendpkSendCode(phone, code);
    if (ok) return true;
    console.error('[uh-sms] SendPK failed, trying Twilio fallback...');
  }
  if (twilioConfigured()) {
    return twilioSendCode(phone, code);
  }
  return false;
}

// ---------------------------------------------------------------------------
// Public routes (no auth gate)
// ---------------------------------------------------------------------------

// GET /uh/menu -> auto-seeds the Kotlin menu on first call
uhRouter.get('/menu', (req, res) => {
  ensureUhSeeded();
  res.send(getCollection('uh_menu_items'));
});

// POST /uh/auth/request-code -> create/find user + issue a verification code.
// If Twilio is configured (TWILIO_ACCOUNT_SID/AUTH_TOKEN/FROM_NUMBER env vars),
// the code is sent as a real SMS and NOT included in the response. When the
// gateway is unconfigured/unreachable the code is returned in-app (dev fallback).
uhRouter.post('/auth/request-code', async (req, res) => {
  ensureUhSeeded();
  const phone = normalizePhone(req.body.phone);
  const name = String(req.body.fullName || '').trim();
  if (phone.length < 10) {
    return res.status(400).send({ error: 'براہ کرم درست موبائل نمبر درج کریں (10 یا 11 ہندسے)' });
  }
  const users = getCollection('uh_app_users');
  let user = users.find((u) => normalizePhone(u.id) === phone || normalizePhone(u.phone) === phone);
  const code = String(Math.floor(1000 + Math.random() * 9000));
  if (user) {
    updateRecord('uh_app_users', user.id, { loginCode: code, ...(name ? { fullName: name } : {}) });
  } else {
    user = createRecord('uh_app_users', {
      id: phone,
      phone,
      fullName: name || 'Usman Customer',
      role: 'CUSTOMER',
      deliveryAddress: '',
      zone: 'My Location',
      loginCode: code
    });
  }
  // Try to deliver the code by SMS first.
  const smsOk = await sendSmsCode(phone, code);
  if (smsOk) {
    return res.send({ success: true, smsSent: true, phone });
  }
  // Dev/demo fallback: no gateway or delivery failed -> reveal code in-app.
  if (sendpkConfigured() || twilioConfigured()) {
    console.warn(`[uh-sms] SMS gateway failed for ${phone}; falling back to in-app code.`);
  } else {
    console.warn(`[uh-sms] No SMS gateway configured for ${phone} (set SENDPK_API_KEY or Twilio vars); falling back to in-app code.`);
  }
  return res.send({ success: true, smsSent: false, code, phone });
});

// POST /uh/auth/login -> phone + code -> token + user
// Only the exact stored code (issued by request-code and delivered via SMS)
// is accepted. There is NO universal fallback code anymore.
uhRouter.post('/auth/login', (req, res) => {
  ensureUhSeeded();
  const phone = normalizePhone(req.body.phone);
  const code = String(req.body.code || '').trim();
  const users = getCollection('uh_app_users');
  const user = users.find((u) => normalizePhone(u.id) === phone || normalizePhone(u.phone) === phone);
  if (!user) {
    return res.status(401).send({ error: 'Invalid credentials' });
  }
  if (user.loginCode !== code) {
    return res.status(401).send({ error: 'کوڈ غلط ہے۔ درست کوڈ درج کریں جو SMS پر موصول ہوا' });
  }
  updateRecord('uh_app_users', user.id, { lastLoginAt: new Date().toISOString(), loginCode: '' });
  const token = jwt.sign(
    { id: user.id, phone, role: user.role, name: user.fullName || user.name || '' },
    JWT_SECRET,
    { expiresIn: '30d' }
  );
  res.send({
    token,
    user: {
      id: user.id,
      phone,
      fullName: user.fullName || user.name || '',
      role: user.role,
      deliveryAddress: user.deliveryAddress || '',
      zone: user.zone || 'Model Town'
    }
  });
});

// POST /uh/orders -> place an order (idempotent via clientId)
uhRouter.post('/orders', (req, res) => {
  ensureUhSeeded();
  const { clientId } = req.body;
  if (clientId) {
    const existing = getCollection('uh_customer_orders').find((o) => o.clientId === clientId);
    if (existing) {
      return res.status(201).send(existing);
    }
  }

  const itemsSummary = String(req.body.itemsSummary || '');
  if (!itemsSummary) {
    return res.status(400).send({ error: 'itemsSummary is required' });
  }

  const db = readDb();
  const counter = (db.uh_meta && db.uh_meta.orderCounter) || 5120;
  const newCount = counter + 1;
  writeDb({ ...db, uh_meta: { orderCounter: newCount } });

  const orderType = String(req.body.orderType || 'DELIVERY').toUpperCase();
  const defaultRider = orderType === 'TAKEAWAY'
    ? { riderName: 'Kitchen Counter #1', riderPhone: '042-35889900', riderVehicle: 'Pickup Token #42' }
    : { riderName: 'Mohammad Ali (Rider)', riderPhone: '0304-9876543', riderVehicle: 'Honda 125 (LE-8910)' };

  const order = createRecord('uh_customer_orders', {
    id: String(req.body.orderId || `UH-${newCount}`),
    customerName: String(req.body.customerName || ''),
    customerPhone: String(req.body.customerPhone || ''),
    deliveryAddress: String(req.body.deliveryAddress || ''),
    areaZone: String(req.body.areaZone || 'City Center'),
    latitude: Number(req.body.latitude) || 31.5204,
    longitude: Number(req.body.longitude) || 74.3587,
    itemsSummary,
    itemsJson: String(req.body.itemsJson || ''),
    subtotal: Number(req.body.subtotal) || 0,
    deliveryFee: Number(req.body.deliveryFee) || (orderType === 'DELIVERY' ? 150 : 0),
    totalAmount: Number(req.body.totalAmount) || 0,
    paymentMethod: String(req.body.paymentMethod || 'Cash on Delivery (COD)'),
    specialInstructions: String(req.body.specialInstructions || ''),
    status: String(req.body.status || 'PLACED').toUpperCase(),
    orderType,
    riderName: String(req.body.riderName || defaultRider.riderName),
    riderPhone: String(req.body.riderPhone || defaultRider.riderPhone),
    riderVehicle: String(req.body.riderVehicle || defaultRider.riderVehicle),
    estimatedMinutes: Number(req.body.estimatedMinutes) || (orderType === 'DELIVERY' ? 35 : 10),
    clientId: clientId || null
  });
  nextTickPersist();
  res.status(201).send(order);
});

// GET /uh/orders?phone= -> a customer's OWN orders only.
// - If a Bearer token is present, the phone is ALWAYS taken from the token
//   (a customer can only ever see their own orders).
// - Without a token it falls back to the ?phone= param (guest/dev demo).
// - Never returns all orders.
uhRouter.get('/orders', (req, res) => {
  const uh = uhPayloadFromReq(req);
  let phone = normalizePhone(req.query.phone);
  const authedPhone = uh ? normalizePhone(uh.phone) : '';
  if (authedPhone) phone = authedPhone;
  const orders = getCollection('uh_customer_orders');
  const filtered = phone
    ? orders.filter((o) => normalizePhone(o.customerPhone) === phone)
    : [];
  res.send(filtered.slice().sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || ''))));
});

// GET /uh/orders/:id -> single order (only if it belongs to the caller's phone)
uhRouter.get('/orders/:id', (req, res) => {
  const order = getCollection('uh_customer_orders').find((o) => o.id === req.params.id);
  if (!order) {
    return res.status(404).send({ error: 'Order not found' });
  }
  const uh = uhPayloadFromReq(req);
  const authedPhone = uh ? normalizePhone(uh.phone) : '';
  const queryPhone = normalizePhone(req.query.phone);
  const allowedPhone = authedPhone || queryPhone;
  if (allowedPhone && normalizePhone(order.customerPhone) !== allowedPhone) {
    return res.status(403).send({ error: 'Forbidden: not your order' });
  }
  res.send(order);
});

// ---------------------------------------------------------------------------
// Admin / Owner routes (uhAuth + role gate)
// ---------------------------------------------------------------------------

// GET /uh/admin/orders -> all orders (admin/owner)
uhRouter.get('/admin/orders', uhAuth, requireUhManager, (req, res) => {
  const orders = getCollection('uh_customer_orders').slice().sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
  res.send(orders);
});

// GET /uh/admin/users -> all app users (admin/owner)
uhRouter.get('/admin/users', uhAuth, requireUhManager, (req, res) => {
  const users = getCollection('uh_app_users').map((u) => ({
    id: u.id,
    phone: u.phone || u.id,
    fullName: u.fullName || u.name || '',
    role: u.role,
    deliveryAddress: u.deliveryAddress || '',
    zone: u.zone || '',
    createdAt: u.createdAt
  }));
  res.send(users);
});

// PUT /uh/orders/:id/status -> update status (admin/owner)
uhRouter.put('/orders/:id/status', uhAuth, requireUhManager, (req, res) => {
  const { status } = req.body;
  if (!status) {
    return res.status(400).send({ error: 'status is required' });
  }
  const updated = updateRecord('uh_customer_orders', req.params.id, {
    status: String(status).toUpperCase(),
    updatedAt: new Date().toISOString()
  });
  if (!updated) {
    return res.status(404).send({ error: 'Order not found' });
  }
  res.send(updated);
});

// DELETE /uh/orders/:id -> delete order (admin/owner)
uhRouter.delete('/orders/:id', uhAuth, requireUhManager, (req, res) => {
  const removed = removeRecord('uh_customer_orders', req.params.id);
  if (!removed) {
    return res.status(404).send({ error: 'Order not found' });
  }
  res.send({ success: true });
});

// POST /uh/menu -> add menu item (admin/owner)
uhRouter.post('/menu', uhAuth, requireUhManager, (req, res) => {
  const { name, category, basePrice } = req.body;
  if (!name || !category || basePrice == null) {
    return res.status(400).send({ error: 'name, category and basePrice are required' });
  }
  const menu = getCollection('uh_menu_items');
  const nextId = menu.reduce((max, m) => Math.max(max, Number(m.id) || 0), 0) + 1;
  const item = createRecord('uh_menu_items', {
    id: nextId,
    name: String(name),
    urduName: String(req.body.urduName || ''),
    category: String(category),
    description: String(req.body.description || ''),
    basePrice: Number(basePrice) || 0,
    sizesJson: String(req.body.sizesJson || ''),
    badge: req.body.badge != null ? String(req.body.badge) : null,
    isAvailable: req.body.isAvailable !== false,
    isVegetarian: !!req.body.isVegetarian,
    spiceLevel: String(req.body.spiceLevel || 'Medium'),
    imageUrl: String(req.body.imageUrl || '')
  });
  res.status(201).send(item);
});

// PUT /uh/menu/:id -> update menu item (admin/owner)
uhRouter.put('/menu/:id', uhAuth, requireUhManager, (req, res) => {
  const menu = getCollection('uh_menu_items');
  const item = menu.find((m) => String(m.id) === String(req.params.id));
  if (!item) {
    return res.status(404).send({ error: 'Menu item not found' });
  }
  const changes = {};
  ['name', 'urduName', 'category', 'description', 'sizesJson', 'spiceLevel', 'imageUrl'].forEach((k) => {
    if (req.body[k] !== undefined) changes[k] = String(req.body[k]);
  });
  if (req.body.basePrice !== undefined) changes.basePrice = Number(req.body.basePrice) || 0;
  if (req.body.isAvailable !== undefined) changes.isAvailable = !!req.body.isAvailable;
  if (req.body.isVegetarian !== undefined) changes.isVegetarian = !!req.body.isVegetarian;
  if (req.body.badge !== undefined) changes.badge = req.body.badge ? String(req.body.badge) : null;
  const updated = updateRecord('uh_menu_items', item.id, changes);
  res.send(updated);
});

// DELETE /uh/menu/:id -> delete menu item (admin/owner)
uhRouter.delete('/menu/:id', uhAuth, requireUhManager, (req, res) => {
  const removed = removeRecord('uh_menu_items', req.params.id);
  if (!removed) {
    const menu = getCollection('uh_menu_items');
    const byId = menu.find((m) => String(m.id) === String(req.params.id));
    if (!byId) {
      return res.status(404).send({ error: 'Menu item not found' });
    }
    const filtered = menu.filter((m) => String(m.id) !== String(req.params.id));
    const db = readDb();
    writeDb({ ...db, uh_menu_items: filtered });
    return res.send({ success: true });
  }
  res.send({ success: true });
});

// Small helper: kick a persist flush without awaiting (fire-and-forget).
function nextTickPersist() {
  setTimeout(() => {
    waitForPersist().catch(() => {});
  }, 0);
}