Deployment to Railway

1. Connect your GitHub repository to Railway.
2. In Railway, create a new project and select "Deploy from GitHub".
3. Choose the `main` branch of this repository.
4. Set environment variables:
   - `PORT` (optional, default 4000)
   - `JWT_SECRET` (production secret)
5. For build and start commands, Railway will run `npm run serve` or `npm start` from the root which builds the client and starts the server.
6. Alternatively, set up two services:
   - `server` service: Root directory `server`, build: `npm install`, start: `npm run start` (or `node start.js`).
   - `client` service: Root directory `client`, build: `npm install`, start: `npm run preview` after `vite build`.

Notes:
- The server exposes an SSE endpoint at `/api/events` for realtime order updates. If you use Railway, ensure the client can reach the server via the provided Railway URL and the `VITE_API_BASE` env var is set to the server URL.
- After deploying, open the app URL and verify Rider flows: assign → rider marks delivered → main app shows delivered under Cash/Online.
