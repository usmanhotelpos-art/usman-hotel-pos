# Build stage
FROM node:24-alpine AS builder
WORKDIR /app

# Copy monorepo files
COPY package*.json ./
COPY client/ client/
COPY server/ server/

# Install dependencies
RUN npm install

# Build frontend
WORKDIR /app/client
RUN npm run build

# Runtime stage
FROM node:24-alpine
WORKDIR /app

# Copy built frontend
COPY --from=builder /app/client/dist client/dist

# Copy server code
COPY server/ server/
COPY package*.json ./

# Install production dependencies only for server
WORKDIR /app/server
RUN npm install --production

# Set working directory
WORKDIR /app

# Expose port for Railway
EXPOSE 4000

# Start the server
CMD ["node", "server/index.js"]
