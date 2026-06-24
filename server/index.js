// IMPORTANT: This file initializes the backend server and must remain stable.
// Avoid changing this file unless you are fixing a server-level issue.

import express from 'express';
import cors from 'cors';
import { router } from './routes.js';
import { initDatabase, readDb, getCollection, createRecord } from './db.js';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const port = process.env.PORT || 4000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
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
  readDb();

  // Seed default Order Taker staff member if none exists
  const staffMembers = getCollection('staff') || [];
  const orderTakerExists = staffMembers.some(
    (s) => (s.role || '').toString().trim() === 'Order Taker' && (s.username || '').toString() === 'usman'
  );
  if (!orderTakerExists) {
    createRecord('staff', {
      name: 'Usman',
      username: 'usman',
      password: 'usman123',
      role: 'Order Taker',
      loginEnabled: true,
      permissions: { 'order-taker-app': true },
    });
    console.log('Default Order Taker staff created: usman / usman123');
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
