// In-app auto-update support for the Usman Hotel app (and future apps).
//
// DESIGN:
//  - Small update METADATA (version, buildCode, notes, date, size) is stored in
//    the main DB collection `app_updates` (a handful of tiny records).
//  - The APK BINARY is stored OUTSIDE the main `db` blob so it never bloats the
//    debounced Postgres flush:
//      * Postgres mode  -> separate `app_updates` table with a BYTEA column.
//      * Local JSON mode-> `server/data/updates/<id>.apk` file on disk.
//
// This keeps every day-to-day order write small on Railway while updates (rare)
// have plenty of room for multi-MB APK files.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { getCollection, getPg, isPgConnected, saveCollection } from './db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const updatesDir = path.join(__dirname, 'data', 'updates');

export async function initUpdatesTable() {
  const pg = getPg();
  if (pg && isPgConnected()) {
    await pg.query(`
      CREATE TABLE IF NOT EXISTS app_updates (
        id TEXT PRIMARY KEY,
        platform TEXT NOT NULL,
        version TEXT NOT NULL,
        build_code INT NOT NULL DEFAULT 0,
        apk BYTEA NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
  }
}

function metaId(platform, version) {
  return `${String(platform || 'usman_hotel')}_${String(version || '').replace(/[^A-Za-z0-9._-]/g, '_')}`;
}

export function getAllUpdateMeta() {
  return getCollection('app_updates') || [];
}

export function getUpdateMeta(id) {
  return getAllUpdateMeta().find((m) => m.id === id) || null;
}

// Creates (or replaces) the metadata record for a published update. The binary
// is attached later via attachApk() so the metadata POST stays small.
export async function publishUpdateMeta({ platform, version, buildCode, notes, fileName }) {
  if (!version) throw new Error('version is required');
  const id = metaId(platform, version);
  const meta = {
    id,
    platform: String(platform || 'usman_hotel'),
    version: String(version),
    buildCode: Number(buildCode) || 0,
    notes: String(notes || ''),
    fileName: String(fileName || `usman_hotel_app_v${version}_${Number(buildCode) || 0}.apk`),
    sizeBytes: 0,
    apkUploadedAt: null,
    publishedAt: new Date().toISOString(),
  };
  const existing = getUpdateMeta(id);
  if (existing) meta.publishedAt = existing.publishedAt || meta.publishedAt;
  const all = getAllUpdateMeta().filter((m) => m.id !== id);
  all.push(meta);
  saveCollection('app_updates', all);
  return meta;
}

// Attaches the raw APK bytes to an existing update record.
export async function attachApk(id, buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length === 0) {
    throw new Error('APK bytes are empty');
  }
  const meta = getUpdateMeta(id);
  if (!meta) throw new Error(`Update record not found: ${id}`);
  const pg = getPg();
  if (pg && isPgConnected()) {
    await pg.query(
      `INSERT INTO app_updates(id, platform, version, build_code, apk)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (id) DO UPDATE SET apk = EXCLUDED.apk`,
      [meta.id, meta.platform, meta.version, meta.buildCode, buffer]
    );
  } else {
    fs.mkdirSync(updatesDir, { recursive: true });
    fs.writeFileSync(path.join(updatesDir, `${id}.apk`), buffer);
  }
  const updated = {
    ...meta,
    sizeBytes: buffer.length,
    apkUploadedAt: new Date().toISOString(),
  };
  const all = getAllUpdateMeta().map((m) => (m.id === id ? updated : m));
  saveCollection('app_updates', all);
  return updated;
}

// Returns a Buffer with the APK bytes, or null when not found.
export async function getApkBuffer(id) {
  const pg = getPg();
  if (pg && isPgConnected()) {
    const result = await pg.query('SELECT apk FROM app_updates WHERE id = $1', [id]);
    if (result.rowCount === 0) return null;
    return result.rows[0].apk;
  }
  const file = path.join(updatesDir, `${id}.apk`);
  if (!fs.existsSync(file)) return null;
  return fs.readFileSync(file);
}

export { metaId, updatesDir };