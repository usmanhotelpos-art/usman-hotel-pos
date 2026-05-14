import bcrypt from 'bcryptjs';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbFile = path.join(__dirname, 'data', 'db.json');

const defaultData = {
  settings: {
    hotelName: 'Usman Hotel',
    currency: 'PKR',
    location: 'Karachi',
    taxRate: 0.18
  },
  rooms: [
    { id: 'r1', number: '101', type: 'Single', status: 'available', rate: 3800 },
    { id: 'r2', number: '102', type: 'Double', status: 'occupied', rate: 5200 },
    { id: 'r3', number: '103', type: 'Suite', status: 'available', rate: 9800 }
  ],
  reservations: [
    {
      id: 'res1',
      guestName: 'Ali Khan',
      roomId: 'r2',
      status: 'checked-in',
      checkIn: '2026-05-05',
      checkOut: '2026-05-09',
      total: 20800
    }
  ],
  inventory: [
    { id: 'i1', name: 'Laundry Detergent', category: 'Housekeeping', quantity: 24, cost: 220 },
    { id: 'i2', name: 'Breakfast Bundle', category: 'Food', quantity: 12, cost: 560 }
  ],
  staff: [
    { id: 's1', name: 'Ayesha', role: 'Receptionist', phone: '+923001234567', status: 'active' },
    { id: 's2', name: 'Usman', role: 'Manager', phone: '+923009876543', status: 'active' }
  ],
  sales: [
    { id: 'sale1', description: 'Room 102 payment', amount: 20800, date: '2026-05-05' }
  ],
  invoices: [],
  users: [
    {
      id: 'u1',
      name: 'Admin',
      email: 'admin@usmanhotel.com',
      role: 'admin',
      passwordHash: bcrypt.hashSync('admin123', 10)
    }
  ],
  pos_categories: [
    { id: 'cat1', name: 'Karahi' },
    { id: 'cat2', name: 'Biryani' },
    { id: 'cat3', name: 'Fast Food' },
    { id: 'cat4', name: 'Drinks' },
    { id: 'cat5', name: 'Desserts' }
  ],
  pos_products: [
    { id: 'p1', name: 'Chicken Karahi', category: 'Karahi', price: 1200, availableStock: 18, image: '', description: 'Spicy chicken karahi with fresh spices.' },
    { id: 'p2', name: 'Mutton Karahi', category: 'Karahi', price: 1500, availableStock: 12, image: '', description: 'Rich mutton karahi with traditional taste.' },
    { id: 'p3', name: 'Beef Biryani', category: 'Biryani', price: 980, availableStock: 22, image: '', description: 'Fragrant beef biryani with raita.' },
    { id: 'p4', name: 'Chicken Biryani', category: 'Biryani', price: 900, availableStock: 25, image: '', description: 'Aromatic chicken biryani with spices.' },
    { id: 'p5', name: 'French Fries', category: 'Fast Food', price: 300, availableStock: 45, image: '', description: 'Crispy golden french fries.' },
    { id: 'p6', name: 'Cold Drink', category: 'Drinks', price: 120, availableStock: 60, image: '', description: 'Chilled soft drink.' },
    { id: 'p7', name: 'Gulab Jamun', category: 'Desserts', price: 220, availableStock: 30, image: '', description: 'Sweet syrup-soaked gulab jamun.' }
  ],
  pos_tables: [
    { id: 't1', label: 'Table 1', type: 'Table', status: 'available' },
    { id: 't2', label: 'Table 2', type: 'Table', status: 'available' },
    { id: 't3', label: 'Table 3', type: 'Table', status: 'occupied' },
    { id: 'r101', label: 'Room 101', type: 'Room', status: 'available' },
    { id: 'r102', label: 'Room 102', type: 'Room', status: 'available' }
  ],
  delivery_agents: [
    { id: 'd1', name: 'Taha Delivery', phone: '+923001234567', status: 'online' },
    { id: 'd2', name: 'Rashid Courier', phone: '+923011234567', status: 'online' }
  ],
  pos_orders: [],
  pos_customers: [],
  pos_payments: []
};

function ensureDb() {
  const dir = path.dirname(dbFile);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  if (!fs.existsSync(dbFile)) {
    fs.writeFileSync(dbFile, JSON.stringify(defaultData, null, 2), 'utf-8');
    return;
  }

  const raw = fs.readFileSync(dbFile, 'utf-8');
  let existingData = {};

  if (raw.trim()) {
    try {
      existingData = JSON.parse(raw);
    } catch (error) {
      const backupPath = `${dbFile}.corrupt-${Date.now()}.bak`;
      fs.writeFileSync(backupPath, raw, 'utf-8');
      console.error(`Database file corrupted. Backed up invalid JSON to ${backupPath}. Resetting database.`);
      existingData = {};
    }
  }

  const merged = { ...defaultData, ...existingData };
  Object.keys(defaultData).forEach((key) => {
    if (existingData[key] === undefined) {
      merged[key] = defaultData[key];
    }
  });
  fs.writeFileSync(dbFile, JSON.stringify(merged, null, 2), 'utf-8');
}

export function readDb() {
  ensureDb();
  const raw = fs.readFileSync(dbFile, 'utf-8');
  try {
    return JSON.parse(raw);
  } catch (error) {
    console.error('Failed to parse database JSON. Resetting database.', error);
    fs.writeFileSync(dbFile, JSON.stringify(defaultData, null, 2), 'utf-8');
    return defaultData;
  }
}

export function writeDb(data) {
  ensureDb();
  const tempFile = `${dbFile}.tmp`;
  fs.writeFileSync(tempFile, JSON.stringify(data, null, 2), 'utf-8');
  fs.renameSync(tempFile, dbFile);
}

export function getCollection(name) {
  const db = readDb();
  return db[name] || [];
}

export function saveCollection(name, items) {
  const db = readDb();
  db[name] = items;
  writeDb(db);
}

export function findUserByEmail(email) {
  const users = getCollection('users');
  return users.find((user) => user.email.toLowerCase() === email.toLowerCase());
}

export function findUserById(id) {
  const users = getCollection('users');
  return users.find((user) => user.id === id);
}

export function createRecord(collectionName, record) {
  const items = getCollection(collectionName);
  const newRecord = { id: crypto.randomUUID(), ...record };
  items.push(newRecord);
  saveCollection(collectionName, items);
  return newRecord;
}

export function updateRecord(collectionName, id, changes) {
  const items = getCollection(collectionName);
  const index = items.findIndex((item) => item.id === id);
  if (index === -1) return null;
  items[index] = { ...items[index], ...changes };
  saveCollection(collectionName, items);
  return items[index];
}

export function removeRecord(collectionName, id) {
  const items = getCollection(collectionName);
  const filtered = items.filter((item) => item.id !== id);
  saveCollection(collectionName, filtered);
  return filtered.length !== items.length;
}
