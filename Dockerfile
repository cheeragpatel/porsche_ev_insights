# Porsche EV Insights - Container Build Configuration
# This creates an optimized container for running both the React frontend and Express API

# === BUILD PHASE ===
FROM node:20-alpine AS frontend_builder

# Set working directory for build operations
WORKDIR /build_workspace

# Dependency installation (cached layer)
COPY package.json package-lock.json ./
RUN npm ci

# Application source (eslint not needed for production build)
COPY index.html vite.config.js ./
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

# API server with dependencies (copy entire server directory for future-proofing)
COPY --from=api_deps /api_workspace/node_modules ./api/node_modules
COPY server/ ./api/

# Nginx site configuration
RUN mkdir -p /run/nginx
COPY docker/nginx-site.conf /etc/nginx/http.d/default.conf

# Supervisor configuration for process management
COPY docker/supervisord.conf /etc/supervisord.conf

# Only expose nginx port (API is accessed internally via reverse proxy)
EXPOSE 8080

# Health check to verify nginx is responding (API health available at /api/health)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Launch via supervisor (manages nginx + node processes)
CMD ["supervisord", "-c", "/etc/supervisord.conf"]
