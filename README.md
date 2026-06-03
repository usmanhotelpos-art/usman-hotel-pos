# Usman Hotel POS

A full-stack web-based hotel point-of-sale and management system with a Tailwind CSS frontend and Express backend.

## Structure

- `server/` - Express API backend with JSON data storage
- `client/` - React + Vite + Tailwind frontend

## Setup

1. Install dependencies:
   ```bash
   npm run install:all
   ```

2. Start the backend:
   ```bash
   npm run dev:server
   ```

3. Start the frontend in a second terminal:
   ```bash
   npm run dev:client
   ```

4. Open the client URL shown by Vite (typically `http://localhost:5173`).

## One-Port Production Serve

To run both the frontend and backend together on a single port (`4000`):

```bash
npm start
```

This builds the frontend and starts the backend server, which serves the built app from `client/dist` and exposes the API at `/api` on `http://localhost:4000`.

## Notes

- The backend listens on port `4000`.
- The frontend uses `http://localhost:4000/api` for data operations.

## Postgres on Railway

- In production, do not rely on `server/data/db.json`. That file is stored on disk and will be lost when the app is redeployed.
- Use Railway Postgres and set the `DATABASE_URL` environment variable for the `server` service.
- When `DATABASE_URL` is present, the backend stores all app data in Postgres instead of local JSON.
- If you already have local data in `server/data/db.json`, the next startup with `DATABASE_URL` will migrate that data into Postgres automatically.

### Example environment variables

```bash
DATABASE_URL=postgres://username:password@host:port/database
JWT_SECRET=your-jwt-secret
```
                                                                                                                  