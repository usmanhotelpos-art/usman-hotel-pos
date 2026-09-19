// IMPORTANT: This file initializes the backend server and must remain stable.
// Avoid changing this file unless you are fixing a server-level issue.

import express from 'express';
import cors from 'cors';
import compression from 'compression';
import helmet from 'helmet';
import bcrypt from 'bcryptjs';
import { router } from './routes.js';
import { initDatabase, readDb, getCollection, createRecord } from './db.js';
import { initUpdatesTable } from './updates.js';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const port = process.env.PORT || 4000;

app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors());
app.use(compression());

// Raw APK binary upload for the in-app updater. Placed BEFORE the JSON parser
// so multi-MB APK bodies bypass the 10mb JSON limit (and body-parser skips it
// because req._body is already set).
app.use('/api/pos/update/apk', express.raw({ type: () => true, limit: '250mb' }));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Lightweight request log so order flow can be diagnosed from server_out.txt
app.use((req, res, next) => {
  if (req.path.startsWith('/api')) {
    console.log(`${new Date().toISOString()} ${req.method} ${req.originalUrl} from ${req.ip}`);
  }
  next();
});

app.use('/api', router);

app.use('/api/*', (req, res) => {
  res.status(404).json({ error: 'API route not found' });
});

app.use((err, req, res, next) => {
  console.error('Express error handler caught:', err);
  res.status(500).json({ error: err.message || 'Internal Server Error' });
});

// Validate DB before serving requests. If the DB is invalid, it will be reset safely.
try {
  await initDatabase();
  await initUpdatesTable();
  readDb();

  // Seed default Order Taker staff members if none exists
  const staffMembers = getCollection('staff') || [];
  const orderTakerExists = staffMembers.some(
    (s) => (s.role || '').toString().trim() === 'Order Taker' && (s.username || '').toString() === 'usman'
  );
  if (!orderTakerExists) {
    createRecord('staff', {
      name: 'Usman',
      username: 'usman',
      passwordHash: bcrypt.hashSync('usman123', 10),
      role: 'Admin Order Taker',
      loginEnabled: true,
      permissions: { 'order-taker-app': true },
    });
    console.log('Default Admin Order Taker staff created: usman / usman123');
  }

  // Seed Manager account for Stock App (Manager / Cashier can login)
  const managerExists = staffMembers.some(
    (s) => (s.username || '').toString().trim().toLowerCase() === 'farhanadmin'
  );
  if (!managerExists) {
    createRecord('staff', {
      name: 'Farhan',
      username: 'farhanadmin',
      passwordHash: bcrypt.hashSync('Farhan123', 10),
      role: 'Manager',
      loginEnabled: true,
      permissions: {},
    });
    console.log('Stock App Manager staff created: farhanadmin / Farhan123');
  }

  
} catch (startupError) {
  console.error('Failed to initialize database on startup:', startupError);
  process.exit(1);
}

// Serve static frontend files
app.use(express.static(join(__dirname, '../client/dist')));

// Direct route for Order Taker App
app.get('/order-taker', (req, res) => {
  res.sendFile(join(__dirname, '../client/dist/index.html'));
});

// SPA fallback - serve index.html for all other routes
app.get('*', (req, res) => {
  res.sendFile(join(__dirname, '../client/dist/index.html'));
});

app.listen(port, () => {
  console.log(`Usman Hotel POS backend running at http://localhost:${port}`);
});

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});
