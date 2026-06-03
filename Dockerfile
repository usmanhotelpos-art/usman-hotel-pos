# Build stage
FROM node:24-alpine AS builder
WORKDIR /app

# Copy monorepo root
COPY package*.json ./

# Copy source folders
COPY client/ client/
COPY server/ server/

# Install all dependencies
RUN npm install

# Build frontend
RUN npm run build

# Runtime stage  
FROM node:24-alpine
WORKDIR /app

# Copy built frontend (will be served by Express)
COPY --from=builder /app/client/dist client/dist

# Copy server code and dependencies
COPY --from=builder /app/server server/
COPY --from=builder /app/node_modules node_modules/
COPY --from=builder /app/package*.json ./

# Expose port
EXPOSE 4000

# Start the backend server (serves frontend + API)
CMD ["node", "server/index.js"]
