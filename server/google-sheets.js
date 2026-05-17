import { google } from 'googleapis';
import fs from 'fs';
import { readDb, writeDb } from './db.js';

const KEYFILE = process.env.GOOGLE_SERVICE_ACCOUNT_KEYFILE || './config/google-service-account.json';
const SCOPES = ['https://www.googleapis.com/auth/spreadsheets'];

async function getAuthClient() {
  if (!fs.existsSync(KEYFILE)) {
    throw new Error(`Google service account key not found at ${KEYFILE}. Place your service account JSON there or set GOOGLE_SERVICE_ACCOUNT_KEYFILE env var.`);
  }
  const auth = new google.auth.GoogleAuth({ keyFile: KEYFILE, scopes: SCOPES });
  return auth.getClient();
}

export async function createSpreadsheet(title = 'Usman POS Backup') {
  const client = await getAuthClient();
  const sheets = google.sheets({ version: 'v4', auth: client });
  const res = await sheets.spreadsheets.create({
    requestBody: {
      properties: { title },
      sheets: [{ properties: { title: 'Sheet1' } }]
    }
  });
  return res.data;
}

export async function saveDbAsJson(spreadsheetId) {
  const client = await getAuthClient();
  const sheets = google.sheets({ version: 'v4', auth: client });
  const db = readDb();
  const json = JSON.stringify(db);
  await sheets.spreadsheets.values.update({
    spreadsheetId,
    range: 'Sheet1!A1',
    valueInputOption: 'RAW',
    requestBody: { values: [[json]] }
  });
}

export async function loadDbFromSheet(spreadsheetId) {
  const client = await getAuthClient();
  const sheets = google.sheets({ version: 'v4', auth: client });
  const res = await sheets.spreadsheets.values.get({ spreadsheetId, range: 'Sheet1!A1' });
  const raw = res.data.values?.[0]?.[0];
  if (!raw) throw new Error('No data found in Sheet1!A1');
  return JSON.parse(raw);
}

export async function restoreDbFromSheet(spreadsheetId) {
  const db = await loadDbFromSheet(spreadsheetId);
  writeDb(db);
  return db;
}

export default { createSpreadsheet, saveDbAsJson, loadDbFromSheet };
