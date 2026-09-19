#!/usr/bin/env node
// Publish a new APK update to the Usman Hotel server.
//
// Usage:
//   node publish-update.mjs \
//     --host https://usman-hotel-pos-server-production.up.railway.app \
//     --user farhanadmin --pass Farhan123 \
//     --version 1.2.0 --build 11 \
//     --notes "Naya update: ..." \
//     --apk D:\pos\usman_hotel_app.apk
//
// Steps:
//   1) LOGIN   -> POST /auth/login          (Manager/Admin required)
//   2) METADATA-> POST /pos/update          (version/buildCode/notes)
//   3) BINARY  -> PUT /pos/update/apk/:id   (raw APK bytes)
//
// Requires Node >= 18 (global fetch).

import fs from 'fs';

function arg(name, fallback) {
  const index = process.argv.indexOf(`--${name}`);
  return index !== -1 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
}

function has(name) {
  return process.argv.includes(`--${name}`);
}

const HOST = String(arg('host', 'https://usman-hotel-pos-server-production.up.railway.app')).replace(/\/+$/, '');
const USER = arg('user', '');
const PASS = arg('pass', '');
const PLATFORM = arg('platform', 'usman_hotel');
const VERSION = arg('version', '');
const BUILD = Number(arg('build', 0)) || 0;
const NOTES = arg('notes', '');
const APK = arg('apk', '');

if (!USER || !PASS || !VERSION || !APK) {
  console.error(
    'Missing required args. Need: --user --pass --version --apk (optional: --build --notes --platform --host)'
  );
  process.exit(1);
}
if (!fs.existsSync(APK)) {
  console.error(`APK file not found: ${APK}`);
  process.exit(1);
}

async function main() {
  console.log(`Host:     ${HOST}`);
  console.log(`Platform: ${PLATFORM}`);
  console.log(`Version:  ${VERSION} (build ${BUILD})`);
  console.log(`APK file: ${APK} (${(fs.statSync(APK).size / 1048576).toFixed(1)} MB)`);

  // 1) Login
  const loginRes = await fetch(`${HOST}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: USER, password: PASS }),
  });
  const loginJson = await loginRes.json().catch(() => ({}));
  if (loginRes.status !== 200 || !loginJson.token) {
    console.error(`Login failed (${loginRes.status}): ${loginJson.error || 'unknown error'}`);
    process.exit(1);
  }
  const token = loginJson.token;
  console.log(`Login OK (${loginJson.user && loginJson.user.role})`);

  // 2) Metadata
  const metaBody = {
    platform: PLATFORM,
    version: VERSION,
    buildCode: BUILD,
    notes: NOTES,
    fileName: `${PLATFORM}_v${VERSION}_${BUILD}.apk`,
  };
  const metaRes = await fetch(`${HOST}/api/pos/update`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(metaBody),
  });
  const metaJson = await metaRes.json().catch(() => ({}));
  if (metaRes.status !== 201) {
    console.error(`Publish metadata failed (${metaRes.status}): ${metaJson.error || 'unknown error'}`);
    process.exit(1);
  }
  const updateId = metaJson.update.id;
  console.log(`Metadata OK -> id=${updateId}`);

  // 3) Raw APK binary
  const bin = fs.readFileSync(APK);
  const apkRes = await fetch(`${HOST}/api/pos/update/apk/${updateId}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/octet-stream',
      Authorization: `Bearer ${token}`,
    },
    body: bin,
  });
  const apkJson = await apkRes.json().catch(() => ({}));
  if (apkRes.status !== 200) {
    console.error(`APK upload failed (${apkRes.status}): ${apkJson.error || 'unknown error'}`);
    process.exit(1);
  }

  const up = apkJson.update || {};
  console.log(`APK uploaded OK: ${(up.sizeBytes / 1048576).toFixed(1)} MB @ ${up.apkUploadedAt || 'now'}`);
  console.log(`Download URL: ${HOST}${up.downloadUrl || `/api/pos/update/apk/${updateId}`}`);
  console.log('Done.');
}

main().catch((err) => {
  console.error('Error:', err.message || err);
  process.exit(1);
});