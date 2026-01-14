# Docker Deployment Guide

Docker configuration for Universal Redirect Service.

## Quick Start

### Production Deployment

```bash
# 1. Create configuration files
cp config/sites.example.json config/sites.json
cp config/utm-sources.example.json config/utm-sources.json
cp config/.env.example .env

# 2. Edit .env with your credentials
nano .env

# 3. Build and start services (use a unique project name per install)
cd docker/
docker compose -p redirect-goexample up -d

# 4. Check logs
docker compose -p redirect-goexample logs -f redirect

# 5. Verify health
curl http://localhost:3077/health
```

**Note:** `-p redirect-goexample` sets the Docker Compose project name, which keeps container names unique across multiple installs.

### Development Environment

```bash
# Start with live reload (nodemon)
docker compose -p redirect-goexample -f docker-compose.yml -f docker-compose.dev.yml up

# Or build and start
docker compose -p redirect-goexample -f docker-compose.yml -f docker-compose.dev.yml up --build
```

---

## File Structure

```
docker/
├── Dockerfile              # Production image
├── Dockerfile.dev          # Development image (with nodemon)
├── docker-compose.yml      # Production configuration
├── docker-compose.dev.yml  # Development overrides
└── README.md               # This file
```

---

## Services

### `redirect` - Node.js Application

- **Image**: Built from `Dockerfile`
- **Port**: `3077` (configurable via `PORT` env var)
- **Health check**: `GET /health`
- **Depends on**: `db` (MariaDB)

**Volumes**:
- `config/sites.json` → `/app/config/sites.json` (read-only)
- `config/utm-sources.json` → `/app/config/utm-sources.json` (read-only)
- `logs/` → `/app/logs/` (optional)

### `db` - MariaDB 10.11

- **Image**: `mariadb:10.11`
- **Port**: `3306` (not exposed in production, exposed in dev)
- **Persistent storage**: `db-data` volume
- **Auto-initialization**: Runs SQL migrations from `sql/` on first start

---

## Environment Variables

Create a `.env` file in the project root:

```env
# Server
PORT=3077

# Main Database (for clicks logging)
DB_HOST=db
DB_PORT=3306
DB_USER=redirect_user
DB_PASSWORD=CHANGE_ME_STRONG_PASSWORD
DB_NAME=redirect_db
DB_ROOT_PASSWORD=CHANGE_ME_ROOT_PASSWORD

# WordPress Database (optional - only if using og_method: wordpress_db)
WP_DB_HOST=your-wordpress-db-host
WP_DB_PORT=3306
WP_DB_USER=wp_readonly_user
WP_DB_PASSWORD=wp_password

# API Authentication
API_TOKEN=CHANGE_ME_RANDOM_TOKEN_FOR_N8N

# GeoIP
GEOIP_ENABLED=true
```

---

## Configuration Files

### `config/sites.json`

Define your sites and OG fetching methods:

```json
{
  "mysite": {
    "domain": "example.com",
    "og_method": "wordpress_db",
    "wp_db": "wordpress_db",
    "description": "WordPress site with direct DB access"
  },
  "othersite": {
    "domain": "another.com",
    "og_method": "html_fetch",
    "description": "Non-WordPress site - fetch OG from HTML"
  }
}
```

### `config/utm-sources.json`

Define your traffic sources:

```json
{
  "fb": { "utm_medium": "social", "utm_source": "facebook" },
  "ig": { "utm_medium": "social", "utm_source": "instagram" },
  "tg": { "utm_medium": "messenger", "utm_source": "telegram" }
}
```

---

## Commands

### Production

```bash
# Start services
docker compose -p redirect-goexample up -d

# Stop services
docker compose -p redirect-goexample down

# Restart a service
docker compose -p redirect-goexample restart redirect

# View logs
docker compose -p redirect-goexample logs -f redirect
docker compose -p redirect-goexample logs -f db

# Execute commands in container
docker compose -p redirect-goexample exec redirect node --version
docker compose -p redirect-goexample exec db mysql -u root -p

# Update to latest version
docker compose -p redirect-goexample pull
docker compose -p redirect-goexample up -d --build
```

### Development

```bash
# Start with live reload
docker compose -p redirect-goexample -f docker-compose.yml -f docker-compose.dev.yml up

# Rebuild after package.json changes
docker compose -p redirect-goexample -f docker-compose.yml -f docker-compose.dev.yml up --build

# Access container shell
docker compose -p redirect-goexample -f docker-compose.yml -f docker-compose.dev.yml exec redirect sh

# Run database migrations manually
docker compose -p redirect-goexample exec redirect node scripts/migrate.js
```

### Database

```bash
# Access MySQL shell
docker compose -p redirect-goexample exec db mysql -u root -p

# Backup database
docker compose -p redirect-goexample exec db mysqldump -u root -p redirect_db > backup.sql

# Restore database
docker compose -p redirect-goexample exec -T db mysql -u root -p redirect_db < backup.sql

# View database logs
docker compose -p redirect-goexample logs -f db
```

---

## Volumes

### Persistent Data

- **`db-data`**: MariaDB database files (auto-created)
- **`logs/`**: Application logs (optional, mapped from host)

### Configuration Mounts

Configuration files are mounted as **read-only** from the host:
- `config/sites.json`
- `config/utm-sources.json`

To update configuration:
1. Edit files on host
2. Restart service: `docker compose -p redirect-goexample restart redirect`

---

## Networking

### Production

- **Internal network**: `redirect-network` (bridge)
- **Exposed ports**: `3077` (redirect service)
- **Database**: Not exposed externally (accessible only to redirect service)

### Development

- **Exposed ports**: `3077` (app), `3306` (database), `9229` (Node.js debugger)
- **Database accessible** from host for development tools

---

## Health Checks

### Application Health

```bash
# Check if service is healthy
curl http://localhost:3077/health

# Expected response: 200 OK
```

### Docker Health Status

```bash
# View health status
docker compose -p redirect-goexample ps

# Detailed health check logs
docker inspect --format='{{json .State.Health}}' "$(docker compose -p redirect-goexample ps -q redirect)" | jq
```

---

## Troubleshooting

### Container won't start

```bash
# Check logs
docker compose -p redirect-goexample logs redirect

# Common issues:
# - Missing .env file → Create from config/.env.example
# - Missing config files → Create sites.json and utm-sources.json
# - Port 3077 in use → Change PORT in .env
```

### Database connection errors

```bash
# Verify database is healthy
docker compose -p redirect-goexample ps db

# Check database logs
docker compose -p redirect-goexample logs db

# Test connection from redirect container
docker compose -p redirect-goexample exec redirect ping db
```

### Permission errors

```bash
# Fix logs directory permissions
sudo chown -R $USER:$USER logs/

# Recreate volumes if needed
docker compose -p redirect-goexample down -v
docker compose -p redirect-goexample up -d
```

### Development hot reload not working

```bash
# Ensure you're using dev compose file
docker compose -p redirect-goexample -f docker-compose.yml -f docker-compose.dev.yml up

# Verify src/ is mounted
docker compose -p redirect-goexample exec redirect ls -la /app/src

# Check nodemon is running
docker compose -p redirect-goexample logs redirect | grep nodemon
```

---

## Production Deployment Notes

### Behind Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/redirect.conf
server {
    listen 80;
    server_name go.example.com;

    location / {
        proxy_pass http://localhost:3077;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### SSL with Let's Encrypt

```bash
# Install certbot
sudo apt-get install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d go.example.com

# Auto-renewal is configured automatically
```

### WordPress Database Connection

If using `og_method: wordpress_db`, ensure:

1. WordPress DB is accessible from Docker network
2. Read-only user is created (security best practice)
3. WP_DB_HOST points to correct host (may be `host.docker.internal` on macOS/Windows)

```sql
-- Create read-only WordPress user
CREATE USER 'wp_readonly'@'%' IDENTIFIED BY 'password';
GRANT SELECT ON wordpress_db.* TO 'wp_readonly'@'%';
FLUSH PRIVILEGES;
```

---

## Updating

### Pull Latest Version

```bash
# Stop services
docker compose -p redirect-goexample down

# Pull latest code from GitHub
git pull origin main

# Rebuild and start
docker compose -p redirect-goexample up -d --build

# Run migrations if needed
docker compose -p redirect-goexample exec redirect node scripts/migrate.js
```

### Zero-Downtime Update

```bash
# Build new image
docker compose -p redirect-goexample build redirect

# Rolling restart
docker compose -p redirect-goexample up -d --no-deps --build redirect
```

---

## Security Recommendations

1. **Change default passwords** in `.env`
2. **Use strong API_TOKEN** for n8n integration
3. **Limit database access** - create read-only users for WordPress DB
4. **Keep images updated**: `docker compose -p redirect-goexample pull && docker compose -p redirect-goexample up -d`
5. **Don't expose database port** in production
6. **Use secrets management** for production (Docker Secrets, Vault, etc.)

---

## Support

For issues, see:
- Main README: `../README.md`
- Configuration Guide: `../docs/CONFIGURATION.md`
- API Documentation: `../docs/API.md`
- Troubleshooting: `../docs/TROUBLESHOOTING.md`
