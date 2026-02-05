# Porsche EV Insights - Container Build Configuration
# This creates an optimized container for running both the React frontend and Express API

# === BUILD PHASE ===
FROM node:20-alpine AS frontend_builder

# Set working directory for build operations
WORKDIR /build_workspace

# Dependency installation (cached layer)
COPY package.json package-lock.json ./
RUN npm ci

# Application source
COPY index.html vite.config.js eslint.config.js ./
COPY src/ ./src/
COPY public/ ./public/

# Generate production bundle
RUN npm run build

# === API SERVER SETUP ===
FROM node:20-alpine AS api_deps

WORKDIR /api_workspace

COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev

# === FINAL RUNTIME IMAGE ===
FROM node:20-alpine

# Add nginx for serving static assets
RUN apk add --no-cache nginx supervisor

WORKDIR /porsche_ev_insights

# Frontend static files
COPY --from=frontend_builder /build_workspace/dist ./frontend_dist

# API server with dependencies
COPY --from=api_deps /api_workspace/node_modules ./api/node_modules
COPY server/index.js ./api/
COPY server/package.json ./api/

# Nginx site configuration
RUN mkdir -p /run/nginx
COPY docker/nginx-site.conf /etc/nginx/http.d/default.conf

# Supervisor configuration for process management
COPY docker/supervisord.conf /etc/supervisord.conf

# Application ports
EXPOSE 8080 3001

# Launch via supervisor (manages nginx + node processes)
CMD ["supervisord", "-c", "/etc/supervisord.conf"]
