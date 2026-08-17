// Central config loader: loads .env, resolves the JWT signing secret.
// NEVER commit server/.env or server/.jwt-secret to git (see .gitignore).

import dotenv from 'dotenv';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

dotenv.config({ path: path.join(__dirname, '.env') });
const dataDir = path.join(__dirname, 'data');
const jwtSecretFile = path.join(dataDir, '.jwt-secret');

let jwtSecret = process.env.JWT_SECRET || '';

if (!jwtSecret) {
  try {
    fs.mkdirSync(dataDir, { recursive: true });
    if (fs.existsSync(jwtSecretFile)) {
      jwtSecret = fs.readFileSync(jwtSecretFile, 'utf8').trim();
    }
    if (!jwtSecret) {
      jwtSecret = crypto.randomBytes(48).toString('hex');
      fs.writeFileSync(jwtSecretFile, jwtSecret, { mode: 0o600 });
      console.warn('[security] No JWT_SECRET env var found. Generated a new random secret stored in server/data/.jwt-secret (gitignored).');
    }
  } catch (error) {
    jwtSecret = crypto.randomBytes(48).toString('hex');
    console.warn('[security] Could not persist JWT secret file; using ephemeral random secret. Tokens will be invalidated on restart.');
  }
}

export const JWT_SECRET = jwtSecret;
export const POSTGRES_URL = process.env.DATABASE_URL || process.env.PG_CONNECTION_STRING || '';
