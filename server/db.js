// IMPORTANT: This file contains the core DB initialization and persistence logic.
// Do not modify this file unless you understand the upgrade path and the server
// stability requirements. Changes here can cause future internal server errors.

import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { Client } from 'pg';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbFile = path.join(__dirname, 'data', 'db.json');
const postgresUrl = process.env.DATABASE_URL || process.env.PG_CONNECTION_STRING || '';

// Railway and most hosted Postgres providers expose a connection string through
// DATABASE_URL or PG_CONNECTION_STRING. If provided, the app will use Postgres
// for persistence; otherwise it falls back to local JSON storage for development.
const pgClient = postgresUrl
  ? new Client({
      connectionString: postgresUrl,
      ssl: {
        rejectUnauthorized: false
      }
    })
  : null;

let dbCache = null;
let pgConnected = false;

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
    { id: 's2', name: 'Usman', role: 'Manager', phone: '+923009876543', status: 'active' },
    { id: 's3', name: 'Admin Rider', role: 'Biker', phone: '+923001222333', status: 'active', otherName: '', username: 'adminrider@rider.com', password: 'adminriderpass', facePhoto: '', idCardNumber: '', idCardFront: '', idCardBack: '', description: '', address: '', loginEnabled: true, riderId: 'adminrider1' }
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
    { id: 'cat5', name: 'Desserts' },
    { id: 'cat6', name: 'ناشتے کی آئٹمز' },
    { id: 'cat7', name: 'چکن کڑاہی مینیو' },
    { id: 'cat8', name: 'سیخ کباب' },
    { id: 'cat9', name: 'بوٹی آئٹمز' },
    { id: 'cat10', name: 'چکن پیسز' },
    { id: 'cat11', name: 'نان اور روٹی' },
    { id: 'cat12', name: 'اسپیشل نان' }
  ],
  pos_products: [
    { id: 'p1', name: 'Chicken Karahi', category: 'Karahi', price: 1200, availableStock: 18, image: '', description: 'Spicy chicken karahi with fresh spices.' },
    { id: 'p2', name: 'Mutton Karahi', category: 'Karahi', price: 1500, availableStock: 12, image: '', description: 'Rich mutton karahi with traditional taste.' },
    { id: 'p3', name: 'Beef Biryani', category: 'Biryani', price: 980, availableStock: 22, image: '', description: 'Fragrant beef biryani with raita.' },
    { id: 'p4', name: 'Chicken Biryani', category: 'Biryani', price: 900, availableStock: 25, image: '', description: 'Aromatic chicken biryani with spices.' },
    { id: 'p5', name: 'French Fries', category: 'Fast Food', price: 300, availableStock: 45, image: '', description: 'Crispy golden french fries.' },
    { id: 'p6', name: 'Cold Drink', category: 'Drinks', price: 120, availableStock: 60, image: '', description: 'Chilled soft drink.' },
    { id: 'p7', name: 'Gulab Jamun', category: 'Desserts', price: 220, availableStock: 30, image: '', description: 'Sweet syrup-soaked gulab jamun.' },
    { id: 'p8', name: 'سادہ چنے — ہاف', category: 'ناشتے کی آئٹمز', price: 150, availableStock: 20, image: '', description: 'سادہ چنے ہاف سروس۔' },
    { id: 'p9', name: 'سادہ چنے — فل', category: 'ناشتے کی آئٹمز', price: 250, availableStock: 15, image: '', description: 'سادہ چنے فل سروس۔' },
    { id: 'p10', name: 'انڈہ چنے — ہاف', category: 'ناشتے کی آئٹمز', price: 180, availableStock: 18, image: '', description: 'انڈہ چنے ہاف سروس۔' },
    { id: 'p11', name: 'انڈہ چنے — فل', category: 'ناشتے کی آئٹمز', price: 300, availableStock: 12, image: '', description: 'انڈہ چنے فل سروس۔' },
    { id: 'p12', name: 'کوفتہ چنے — ہاف', category: 'ناشتے کی آئٹمز', price: 200, availableStock: 18, image: '', description: 'کوفتہ چنے ہاف سروس۔' },
    { id: 'p13', name: 'کوفتہ چنے — فل', category: 'ناشتے کی آئٹمز', price: 320, availableStock: 12, image: '', description: 'کوفتہ چنے فل سروس۔' },
    { id: 'p14', name: 'اسپیشل حلیم — ہاف', category: 'ناشتے کی آئٹمز', price: 150, availableStock: 10, image: '', description: 'بہترین اسپیشل حلیم ہاف۔' },
    { id: 'p15', name: 'اسپیشل حلیم — فل', category: 'ناشتے کی آئٹمز', price: 250, availableStock: 8, image: '', description: 'بہترین اسپیشل حلیم فل۔' },
    { id: 'p16', name: 'اسپیشل پائے — ہاف', category: 'ناشتے کی آئٹمز', price: 400, availableStock: 6, image: '', description: 'اسپیشل پائے ہاف سروس۔' },
    { id: 'p17', name: 'اسپیشل پائے — فل', category: 'ناشتے کی آئٹمز', price: 600, availableStock: 4, image: '', description: 'اسپیشل پائے فل سروس۔' },
    { id: 'p18', name: 'رائتہ', category: 'ناشتے کی آئٹمز', price: 50, availableStock: 30, image: '', description: 'تازہ رائتہ۔' },
    { id: 'p19', name: 'توہ پراٹھا', category: 'ناشتے کی آئٹمز', price: 60, availableStock: 40, image: '', description: 'گرم توہ پراٹھا۔' },
    { id: 'p20', name: 'ریڈ چکن کڑاہی — ہاف', category: 'چکن کڑاہی مینیو', price: 800, availableStock: 8, image: '', description: 'ریڈ چکن کڑاہی ہاف۔' },
    { id: 'p21', name: 'ریڈ چکن کڑاہی — فل', category: 'چکن کڑاہی مینیو', price: 1600, availableStock: 5, image: '', description: 'ریڈ چکن کڑاہی فل۔' },
    { id: 'p22', name: 'وائٹ چکن کڑاہی — ہاف', category: 'چکن کڑاہی مینیو', price: 1000, availableStock: 8, image: '', description: 'وائٹ چکن کڑاہی ہاف۔' },
    { id: 'p23', name: 'وائٹ چکن کڑاہی — فل', category: 'چکن کڑاہی مینیو', price: 2000, availableStock: 5, image: '', description: 'وائٹ چکن کڑاہی فل۔' },
    { id: 'p24', name: 'گرین چکن کڑاہی — ہاف', category: 'چکن کڑاہی مینیو', price: 900, availableStock: 8, image: '', description: 'گرین چکن کڑاہی ہاف۔' },
    { id: 'p25', name: 'گرین چکن کڑاہی — فل', category: 'چکن کڑاہی مینیو', price: 1800, availableStock: 5, image: '', description: 'گرین چکن کڑاہی فل۔' },
    { id: 'p26', name: 'اچاری چکن کڑاہی — ہاف', category: 'چکن کڑاہی مینیو', price: 900, availableStock: 8, image: '', description: 'اچاری چکن کڑاہی ہاف۔' },
    { id: 'p27', name: 'اچاری چکن کڑاہی — فل', category: 'چکن کڑاہی مینیو', price: 1800, availableStock: 5, image: '', description: 'اچاری چکن کڑاہی فل۔' },
    { id: 'p28', name: 'مکھنی چکن کڑاہی — ہاف', category: 'چکن کڑاہی مینیو', price: 1000, availableStock: 8, image: '', description: 'مکھنی چکن کڑاہی ہاف۔' },
    { id: 'p29', name: 'مکھنی چکن کڑاہی — فل', category: 'چکن کڑاہی مینیو', price: 2000, availableStock: 5, image: '', description: 'مکھنی چکن کڑاہی فل۔' },
    { id: 'p30', name: 'چکن کباب', category: 'سیخ کباب', price: 170, availableStock: 20, image: '', description: 'چیپسی چکن کباب۔' },
    { id: 'p31', name: 'بیف کباب', category: 'سیخ کباب', price: 250, availableStock: 15, image: '', description: 'گرما گرم بیف کباب۔' },
    { id: 'p32', name: 'چکن ریشمی کباب', category: 'سیخ کباب', price: 300, availableStock: 12, image: '', description: 'نرم چکن ریشمی کباب۔' },
    { id: 'p33', name: 'چکن چیز کباب', category: 'سیخ کباب', price: 300, availableStock: 10, image: '', description: 'مزیدار چکن چیز کباب۔' },
    { id: 'p34', name: 'تکہ بوٹی', category: 'بوٹی آئٹمز', price: 220, availableStock: 18, image: '', description: 'رسیلا تکہ بوٹی۔' },
    { id: 'p35', name: 'ملائی بوٹی', category: 'بوٹی آئٹمز', price: 350, availableStock: 14, image: '', description: 'ملائی بوٹی خاص۔' },
    { id: 'p36', name: 'گرین بوٹی', category: 'بوٹی آئٹمز', price: 400, availableStock: 12, image: '', description: 'گرین بوٹی مصالحہ دار۔' },
    { id: 'p37', name: 'ساسمی بوٹی', category: 'بوٹی آئٹمز', price: 450, availableStock: 12, image: '', description: 'خَوشبودار ساسمی بوٹی۔' },
    { id: 'p38', name: 'پاشا بوٹی', category: 'بوٹی آئٹمز', price: 450, availableStock: 10, image: '', description: 'خاص پاشا بوٹی۔' },
    { id: 'p39', name: 'چیز ملائی بوٹی', category: 'بوٹی آئٹمز', price: 450, availableStock: 10, image: '', description: 'چیز ملائی بوٹی۔' },
    { id: 'p40', name: 'لیگ پیس', category: 'چکن پیسز', price: 370, availableStock: 12, image: '', description: 'گرم لیگ پیس۔' },
    { id: 'p41', name: 'چیسٹ پیس', category: 'چکن پیسز', price: 400, availableStock: 12, image: '', description: 'رسیلا چیسٹ پیس۔' },
    { id: 'p42', name: 'نان سادہ', category: 'نان اور روٹی', price: 30, availableStock: 80, image: '', description: 'گرم نان سادہ۔' },
    { id: 'p43', name: 'سادہ روٹی', category: 'نان اور روٹی', price: 14, availableStock: 90, image: '', description: 'تازہ سادہ روٹی۔' },
    { id: 'p44', name: 'خمیری روٹی', category: 'نان اور روٹی', price: 30, availableStock: 60, image: '', description: 'خمیری روٹی۔' },
    { id: 'p45', name: 'دھنیا نان', category: 'نان اور روٹی', price: 35, availableStock: 50, image: '', description: 'دھنیا نان۔' },
    { id: 'p46', name: 'کلچہ نان', category: 'نان اور روٹی', price: 35, availableStock: 50, image: '', description: 'کلچہ نان۔' },
    { id: 'p47', name: 'کلونجی نان', category: 'نان اور روٹی', price: 35, availableStock: 50, image: '', description: 'کلونجی نان۔' },
    { id: 'p48', name: 'روغنی نان', category: 'اسپیشل نان', price: 90, availableStock: 40, image: '', description: 'روغنی نان۔' },
    { id: 'p49', name: 'ہاف روغنی', category: 'اسپیشل نان', price: 60, availableStock: 45, image: '', description: 'ہاف روغنی نان۔' },
    { id: 'p50', name: 'گارلک نان', category: 'اسپیشل نان', price: 120, availableStock: 35, image: '', description: 'خوشبودار گارلک نان۔' },
    { id: 'p51', name: 'اسپیشل کلچہ', category: 'اسپیشل نان', price: 50, availableStock: 48, image: '', description: 'اسپیشل کلچہ نان۔' },
    { id: 'p52', name: 'تندوری پراٹھا', category: 'اسپیشل نان', price: 70, availableStock: 40, image: '', description: 'گرم تندوری پراٹھا۔' },
    { id: 'p53', name: 'آلو نان', category: 'اسپیشل نان', price: 150, availableStock: 32, image: '', description: 'آلو نان۔' },
    { id: 'p54', name: 'چکن قیمہ نان', category: 'اسپیشل نان', price: 350, availableStock: 28, image: '', description: 'چکن قیمہ نان۔' },
    { id: 'p55', name: 'بیف قیمہ نان', category: 'اسپیشل نان', price: 450, availableStock: 22, image: '', description: 'بیف قیمہ نان۔' },
    { id: 'p56', name: 'چیز نان', category: 'اسپیشل نان', price: 350, availableStock: 26, image: '', description: 'چیز نان۔' },
    { id: 'p57', name: 'چکن چیز نان', category: 'اسپیشل نان', price: 450, availableStock: 20, image: '', description: 'چکن چیز نان۔' },
    { id: 'p58', name: 'چاکلیٹ نان', category: 'اسپیشل نان', price: 400, availableStock: 18, image: '', description: 'مٹھاس دار چاکلیٹ نان۔' },
    { id: 'p59', name: 'نٹیلا نان', category: 'اسپیشل نان', price: 400, availableStock: 18, image: '', description: 'نٹیلا نان۔' },
    { id: 'p60', name: 'اچاری نان', category: 'اسپیشل نان', price: 120, availableStock: 30, image: '', description: 'مسالہ دار اچاری نان۔' }
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
  delivery_service_types: [
    { id: 'standard', name: 'Standard Delivery', charge: 50, location: 'City', active: true },
    { id: 'express', name: 'Express Delivery', charge: 120, location: '', active: true }
  ],
  delivery_locations: [
    { id: 'city', name: 'City Area', description: 'Standard city delivery zone' },
    { id: 'suburbs', name: 'Suburbs', description: 'Extended suburb delivery zone' }
  ],
  pos_orders: [],
  pos_customers: [],
  pos_payments: [],
  riders: [
    { id: 'rider1', name: 'Ahmed Rider', phone: '+923001234567', email: 'ahmed@rider.com', role: 'Rider', status: 'active', passwordHash: null },
    { id: 'rider2', name: 'Hassan Biker', phone: '+923009876543', email: 'hassan@rider.com', role: 'Rider', status: 'active', passwordHash: null },
    { id: 'adminrider1', name: 'Admin Rider', phone: '+923001222333', email: 'adminrider@rider.com', role: 'Admin Rider', status: 'active', passwordHash: '$2a$10$zHAic7WcWCv8LTu2P9BPgeN38oHUgH47lznluzm8OZtG6ljdnoJJ6', rawPassword: 'adminriderpass' }
  ],
  rider_orders: [],
  rider_order_requests: []
};

function ensureLocalDataDir() {
  const dir = path.dirname(dbFile);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function mergeDefaultData(existingData) {
  const merged = { ...defaultData, ...existingData };
  Object.keys(defaultData).forEach((key) => {
    if (existingData[key] === undefined) {
      merged[key] = defaultData[key];
    }
  });
  return merged;
}

function writeDbFile(data) {
  ensureLocalDataDir();
  const tempFile = `${dbFile}.tmp`;
  fs.writeFileSync(tempFile, JSON.stringify(data, null, 2), 'utf-8');
  fs.renameSync(tempFile, dbFile);
}

function loadDbFile() {
  ensureLocalDataDir();

  if (!fs.existsSync(dbFile)) {
    writeDbFile(defaultData);
    return defaultData;
  }

  const raw = fs.readFileSync(dbFile, 'utf-8');
  if (!raw.trim()) {
    writeDbFile(defaultData);
    return defaultData;
  }

  try {
    const existingData = JSON.parse(raw);
    const merged = mergeDefaultData(existingData);
    writeDbFile(merged);
    return merged;
  } catch (error) {
    const backupPath = `${dbFile}.corrupt-${Date.now()}.bak`;
    fs.writeFileSync(backupPath, raw, 'utf-8');
    console.error(`Database file corrupted. Backed up invalid JSON to ${backupPath}. Resetting database.`);
    writeDbFile(defaultData);
    return defaultData;
  }
}

function loadDbFileIfExists() {
  ensureLocalDataDir();
  if (!fs.existsSync(dbFile)) {
    return null;
  }

  const raw = fs.readFileSync(dbFile, 'utf-8');
  if (!raw.trim()) {
    return null;
  }

  try {
    const existingData = JSON.parse(raw);
    return mergeDefaultData(existingData);
  } catch (error) {
    const backupPath = `${dbFile}.corrupt-${Date.now()}.bak`;
    fs.writeFileSync(backupPath, raw, 'utf-8');
    console.error(`Local JSON database file corrupted. Backed up invalid data to ${backupPath}.`);
    return null;
  }
}

async function ensurePostgresSchema() {
  if (!pgClient) return;
  await pgClient.query(`
    CREATE TABLE IF NOT EXISTS pos_data (
      id TEXT PRIMARY KEY,
      payload JSONB NOT NULL
    )
  `);
}

async function loadDbFromPostgres() {
  if (!pgClient) return null;

  const result = await pgClient.query('SELECT payload FROM pos_data WHERE id = $1', ['db']);
  if (result.rowCount === 0) {
    return null;
  }
  return result.rows[0].payload;
}

async function saveDbToPostgres(data) {
  if (!pgClient || !pgConnected) return;
  try {
    await pgClient.query(
      `INSERT INTO pos_data(id, payload) VALUES ($1, $2)
       ON CONFLICT (id) DO UPDATE SET payload = EXCLUDED.payload`,
      ['db', data]
    );
  } catch (error) {
    console.error('Failed to save DB to Postgres:', error);
  }
}

export async function initDatabase() {
  if (pgClient) {
    try {
      await pgClient.connect();
      pgConnected = true;
      await ensurePostgresSchema();
      const postgresData = await loadDbFromPostgres();

      if (postgresData) {
        dbCache = mergeDefaultData(postgresData);
      } else {
        const localData = loadDbFileIfExists();
        if (localData) {
          dbCache = localData;
          await saveDbToPostgres(dbCache);
        } else {
          dbCache = defaultData;
          await saveDbToPostgres(dbCache);
        }
      }

      console.log('Connected to Postgres. Data persistence is now using Postgres.');
      return;
    } catch (error) {
      console.error('Postgres initialization failed:', error);
      console.warn('Falling back to local JSON file storage.');
      pgConnected = false;
    }
  }

  dbCache = loadDbFile();
}

export function readDb() {
  if (dbCache === null) {
    throw new Error('Database has not been initialized. Call initDatabase() first.');
  }
  return dbCache;
}

export function writeDb(data) {
  if (dbCache === null) {
    throw new Error('Database has not been initialized. Call initDatabase() first.');
  }

  dbCache = data;
  if (pgConnected) {
    return saveDbToPostgres(data).catch((error) => {
      console.error('Failed to persist DB to Postgres:', error);
    });
  }

  writeDbFile(data);
  return Promise.resolve();
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
  const timestamp = new Date().toISOString();
  const newRecord = {
    id: crypto.randomUUID(),
    createdAt: record.createdAt || timestamp,
    updatedAt: record.updatedAt || timestamp,
    ...record
  };
  items.push(newRecord);
  saveCollection(collectionName, items);
  return newRecord;
}

export function updateRecord(collectionName, id, changes) {
  const items = getCollection(collectionName);
  const index = items.findIndex((item) => item.id === id);
  if (index === -1) return null;
  const timestamp = new Date().toISOString();
  items[index] = { ...items[index], ...changes, updatedAt: changes.updatedAt || timestamp };
  saveCollection(collectionName, items);
  return items[index];
}

export function removeRecord(collectionName, id) {
  const items = getCollection(collectionName);
  const filtered = items.filter((item) => item.id !== id);
  saveCollection(collectionName, filtered);
  return filtered.length !== items.length;
}
