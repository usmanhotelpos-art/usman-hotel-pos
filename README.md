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

## Notes

- The backend listens on port `4000`.
- The frontend uses `http://localhost:4000/api` for data operations.
