# Universal Redirect Service - Production Dockerfile
# Node.js 18 LTS on Alpine Linux for minimal image size
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Install system dependencies for GeoIP and other native modules
RUN apk add --no-cache \
    dumb-init \
    && rm -rf /var/cache/apk/*

# Copy package files first for better layer caching
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && npm cache clean --force

# Copy application source code
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY sql/ ./sql/

# Create necessary directories
RUN mkdir -p logs config

# Health check to ensure service is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3002/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1) })" || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Run the application
CMD ["node", "src/server.js"]

# Expose the application port
EXPOSE 3002

# Labels for metadata
LABEL maintainer="Genzo AI LLP"
LABEL version="1.0.0"
LABEL description="Universal Redirect Service with OG preview and GeoIP tracking"
