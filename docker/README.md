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

# 3. Build and start services
cd docker/
docker-compose up -d

# 4. Check logs
docker-compose logs -f redirect

# 5. Verify health
curl http://localhost:3002/health
```

### Development Environment

```bash
# Start with live reload (nodemon)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Or build and start
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build
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
- **Port**: `3002` (configurable via `PORT` env var)
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
PORT=3002

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
API_BEARER_TOKEN=CHANGE_ME_RANDOM_TOKEN_FOR_N8N

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
docker-compose up -d

# Stop services
docker-compose down

# Restart a service
docker-compose restart redirect

# View logs
docker-compose logs -f redirect
docker-compose logs -f db

# Execute commands in container
docker-compose exec redirect node --version
docker-compose exec db mysql -u root -p

# Update to latest version
docker-compose pull
docker-compose up -d --build
```

### Development

```bash
# Start with live reload
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Rebuild after package.json changes
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build

# Access container shell
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec redirect sh

# Run database migrations manually
docker-compose exec redirect node scripts/migrate.js
```

### Database

```bash
# Access MySQL shell
docker-compose exec db mysql -u root -p

# Backup database
docker-compose exec db mysqldump -u root -p redirect_db > backup.sql

# Restore database
docker-compose exec -T db mysql -u root -p redirect_db < backup.sql

# View database logs
docker-compose logs -f db
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
2. Restart service: `docker-compose restart redirect`

---

## Networking

### Production

- **Internal network**: `redirect-network` (bridge)
- **Exposed ports**: `3002` (redirect service)
- **Database**: Not exposed externally (accessible only to redirect service)

### Development

- **Exposed ports**: `3002` (app), `3306` (database), `9229` (Node.js debugger)
- **Database accessible** from host for development tools

---

## Health Checks

### Application Health

```bash
# Check if service is healthy
curl http://localhost:3002/health

# Expected response: 200 OK
```

### Docker Health Status

```bash
# View health status
docker-compose ps

# Detailed health check logs
docker inspect --format='{{json .State.Health}}' redirect-service | jq
```

---

## Troubleshooting

### Container won't start

```bash
# Check logs
docker-compose logs redirect

# Common issues:
# - Missing .env file → Create from .env.example
# - Missing config files → Create sites.json and utm-sources.json
# - Port 3002 in use → Change PORT in .env
```

### Database connection errors

```bash
# Verify database is healthy
docker-compose ps db

# Check database logs
docker-compose logs db

# Test connection from redirect container
docker-compose exec redirect ping db
```

### Permission errors

```bash
# Fix logs directory permissions
sudo chown -R $USER:$USER logs/

# Recreate volumes if needed
docker-compose down -v
docker-compose up -d
```

### Development hot reload not working

```bash
# Ensure you're using dev compose file
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Verify src/ is mounted
docker-compose exec redirect ls -la /app/src

# Check nodemon is running
docker-compose logs redirect | grep nodemon
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
        proxy_pass http://localhost:3002;
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
docker-compose down

# Pull latest code from GitHub
git pull origin main

# Rebuild and start
docker-compose up -d --build

# Run migrations if needed
docker-compose exec redirect node scripts/migrate.js
```

### Zero-Downtime Update

```bash
# Build new image
docker-compose build redirect

# Rolling restart
docker-compose up -d --no-deps --build redirect
```

---

## Security Recommendations

1. **Change default passwords** in `.env`
2. **Use strong API_BEARER_TOKEN** for n8n integration
3. **Limit database access** - create read-only users for WordPress DB
4. **Keep images updated**: `docker-compose pull && docker-compose up -d`
5. **Don't expose database port** in production
6. **Use secrets management** for production (Docker Secrets, Vault, etc.)

---

## Support

For issues, see:
- Main README: `../README.md`
- Configuration Guide: `../docs/CONFIGURATION.md`
- API Documentation: `../docs/API.md`
- Troubleshooting: `../docs/TROUBLESHOOTING.md`
