# Usman Hotel POS System

A full-stack web-based hotel point-of-sale (POS) and management system with a React + Vite + Tailwind CSS frontend and Express.js backend.

## Features

- **Dashboard**: Real-time analytics and business metrics
- **POS System**: Fast and efficient point-of-sale operations
- **Order Management**: Track and manage customer orders
- **Table Management**: Restaurant table reservation and management
- **Inventory Management**: Stock control and tracking
- **Staff Management**: Employee and staff administration
- **Sales Reports**: Comprehensive sales analytics
- **Customer Management**: Customer database and profiles
- **Settings**: Customizable hotel configurations

## Project Structure

- `server/` - Express.js API backend with JSON data storage
- `client/` - React + Vite + Tailwind CSS frontend
- `package.json` - Monorepo workspace configuration

## Requirements

- Node.js (v16 or higher)
- npm or yarn

## Quick Start

### 1. Install Dependencies
```bash
npm run install:all
```

### 2. Start Development Servers

**Terminal 1 - Backend:**
```bash
npm run dev:server
```
Backend runs on: `http://localhost:4000`

**Terminal 2 - Frontend:**
```bash
npm run dev:client
```
Frontend runs on: `http://localhost:5173`

### 3. Access the Application
Open your browser and navigate to `http://localhost:5173`

## Build for Production

```bash
npm run build:client
npm run start:server
```

## Technology Stack

- **Frontend**: React 18, Vite, Tailwind CSS
- **Backend**: Express.js, Node.js
- **Database**: JSON file storage
- **Authentication**: JWT, bcryptjs

## Configuration

- Backend API base URL: `http://localhost:4000/api`
- Frontend development URL: `http://localhost:5173`
- Backend will serve built frontend files from `/client/dist`

## Troubleshooting

- **Port 4000 already in use**: Change `PORT` environment variable
- **Port 5173 already in use**: Vite will use next available port
- **Database issues**: Check `server/data/db.json` file permissions

## License

Proprietary - Usman Hotel

## Author

Usman Hotel Team
                                                                                                                  