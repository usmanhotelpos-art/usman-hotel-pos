import http from 'http';
import { request } from 'http';

const data = JSON.stringify({ email: 'admin@usmanhotel.com', password: 'admin123' });

const options = {
  hostname: 'localhost',
  port: 4000,
  path: '/api/auth/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(data)
  }
};

const req = request(options, (res) => {
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => {
    console.log('status', res.statusCode);
    console.log('body', body);
  });
});

req.on('error', (err) => console.error('error', err));
req.write(data);
req.end();
