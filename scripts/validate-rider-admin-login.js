import fetch from 'node-fetch';

const api = 'http://localhost:4000/api';

async function main() {
  const res = await fetch(`${api}/auth/rider-login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'ahmed@rider.com', password: 'riderpass1' })
  });
  const data = await res.json();
  console.log('status', res.status);
  console.log(JSON.stringify(data, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});