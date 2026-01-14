# Installation Guide

Complete installation guide for Universal Redirect Service.

---

## Quick Install (Recommended)

### Prerequisites
- Ubuntu/Debian server (20.04+) or similar Linux distribution
- Root access (sudo)
- Domain pointing to your server

### One-Command Install

```bash
sudo bash scripts/install.sh
```

This will:
1. ✅ Check system requirements
2. ✅ Run interactive setup wizard
3. ✅ Install Node.js dependencies
4. ✅ Setup MySQL/MariaDB database
5. ✅ Configure Nginx reverse proxy
6. ✅ Setup SSL certificate (Let's Encrypt)
7. ✅ Create systemd service
8. ✅ Start the service

**Installation time:** ~10-15 minutes

---

## Step-by-Step Installation

### 1. System Requirements

#### Minimum Requirements
- **OS:** Ubuntu 20.04+, Debian 11+, RHEL 8+
- **Node.js:** >= 24.0.0
- **npm:** >= 11.0.0
- **MySQL/MariaDB:** >= 8.4.0
- **RAM:** 512MB minimum, 1GB recommended
- **Disk:** 1GB free space

#### Optional (but recommended)
- **Nginx:** >= 1.18 (for reverse proxy)
- **Certbot:** for SSL certificates

#### Check Requirements

```bash
node scripts/check-requirements.js
```

### 2. Clone Repository

```bash
cd /opt
git clone https://github.com/genzoai/redirect-service.git
cd redirect-service
```

### 3. Run Setup Wizard

```bash
node scripts/setup-wizard.js
```

The wizard will ask you:

#### Server Configuration
- **Domain:** Your domain/subdomain (e.g., go.example.com)
- **Port:** Service port (default: 3077)

#### Database Configuration
- **Host:** Database host (default: localhost)
- **Port:** Database port (default: 3306)
- **Name:** Database name (default: redirect_db)
- **User:** Database user
- **Password:** Database password
- **Root Password:** For initial setup

#### Sites Configuration
For each site you want to redirect:
- **Site ID:** Unique slug (e.g., "mysite")
- **Domain:** Site domain (e.g., "example.com")
- **OG Method:**
  - `wordpress_db` - Direct WordPress database access
  - `html_fetch` - Parse OG tags from HTML
- **WordPress DB:** Database name (if wordpress_db method)
- **Description:** Optional description

#### UTM Sources
- **Default sources:** fb, ig, tiktok, tg, email (recommended: yes)
- **Custom sources:** Add additional traffic sources if needed

#### Additional Settings
- **GeoIP:** Enable country tracking (recommended: yes)
- **SSL:** Setup Let's Encrypt certificate (recommended: yes)
- **API Token:** Generate automatically or provide your own

**Output:** Creates `.env`, `config/sites.json`, `config/utm-sources.json`

### 4. Install Dependencies

```bash
npm install
```

### 5. Setup Database

```bash
sudo bash scripts/setup-database.sh
```

This will:
- Create database
- Create user with permissions
- Run all SQL migrations

### 6. Setup Nginx (Optional)

```bash
sudo bash scripts/setup-nginx.sh
```

Or specify domain directly:
```bash
sudo bash scripts/setup-nginx.sh go.example.com
```

### 7. Setup SSL (Optional)

```bash
sudo bash scripts/setup-ssl.sh
```

Or specify domain directly:
```bash
sudo bash scripts/setup-ssl.sh go.example.com
```

### 8. Setup Systemd Service

```bash
sudo SERVICE_NAME=redirect-goexample bash scripts/setup-systemd.sh
```

Creates and starts systemd service for automatic startup. Use a unique `SERVICE_NAME` if multiple installs run on the same server.

### 9. Verify Installation

```bash
# Check service status
sudo systemctl status redirect-service

# Test health endpoint
curl http://localhost:3077/health

# Test full URL
curl -I http://your-domain.com/test/123
```

If you used a custom service name, replace `redirect-service` with your `SERVICE_NAME`.

---

## Docker Installation

### Quick Start with Docker Compose

```bash
# 1. Create config files
cp config/.env.example .env
cp config/sites.example.json config/sites.json
cp config/utm-sources.example.json config/utm-sources.json

# 2. Edit configuration
nano .env

# 3. Start services (use a unique project name per install)
cd docker/
docker compose -p redirect-goexample up -d

# 4. Check logs
docker compose -p redirect-goexample logs -f redirect

# 5. Verify
curl http://localhost:3077/health
```

See [docker/README.md](../docker/README.md) for detailed Docker documentation.

---

## Manual Installation (Advanced)

### 1. Install Node.js

```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify
node --version  # Should be >= 24.0.0 (update to 24.13.0 LTS if lower)
npm --version   # Should be >= 11.0.0
```

### 2. Install MySQL/MariaDB

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y mariadb-server

# Start and enable
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Secure installation
sudo mysql_secure_installation
```

### 3. Create Database Manually

```bash
mysql -u root -p
```

```sql
CREATE DATABASE redirect_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'redirect_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON redirect_db.* TO 'redirect_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 4. Run Migrations

```bash
# Run all migrations
npm run migrate

# Check migration status
npm run migrate:status
```

### 5. Create Configuration Files

Copy examples and edit:
```bash
cp config/.env.example .env
cp config/sites.example.json config/sites.json
cp config/utm-sources.example.json config/utm-sources.json

# Edit files
nano .env
nano config/sites.json
```

### 6. Install Nginx (Optional)

```bash
sudo apt-get install -y nginx

# Copy config
sudo cp config/nginx.example.conf /etc/nginx/sites-available/redirect
sudo ln -s /etc/nginx/sites-available/redirect /etc/nginx/sites-enabled/

# Edit config
sudo nano /etc/nginx/sites-available/redirect

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### 7. Create Systemd Service

```bash
# Copy service file
sudo cp config/systemd.example.service /etc/systemd/system/redirect-service.service

# Edit paths and user
sudo nano /etc/systemd/system/redirect-service.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable redirect-service
sudo systemctl start redirect-service
```

---

## Post-Installation

### 1. Verify Service

```bash
# Service status
sudo systemctl status redirect-service

# View logs
sudo journalctl -u redirect-service -f

# Test endpoints
curl http://localhost:3077/health
curl -I http://your-domain.com/yoursite/123
```

### 2. Setup n8n Integration

Get your API Token from `.env`:
```bash
grep API_TOKEN .env
```

Use this token in n8n HTTP Request node:
- **URL:** `https://your-domain.com/api/stats`
- **Authentication:** Bearer Token
- **Token:** [your token from .env]

See [API.md](API.md) for full API documentation.

### 3. Configure GeoIP Auto-Update

GeoIP database updates automatically if using systemd:
```bash
# Check GeoIP update timer
sudo systemctl status geoip-update.timer

# Manual update
sudo bash scripts/update-geoip.sh
```

### 4. Backfill Country Data (Optional)

If you have existing clicks without country data:
```bash
node scripts/backfill-countries.js
```

---

## Troubleshooting

### Service won't start
```bash
# Check logs
sudo journalctl -u redirect-service -n 50

# Common issues:
# - Port 3077 already in use → Change PORT in .env
# - Cannot connect to database → Check DB credentials in .env
# - Missing dependencies → Run npm install
```

### Database connection errors
```bash
# Test MySQL connection
mysql -h localhost -u redirect_user -p redirect_db

# If fails, check:
# - MySQL is running: sudo systemctl status mysql
# - User exists: SELECT user FROM mysql.user;
# - Permissions: SHOW GRANTS FOR 'redirect_user'@'localhost';
```

### Nginx configuration errors
```bash
# Test nginx config
sudo nginx -t

# Check nginx logs
sudo tail -f /var/log/nginx/error.log
```

### SSL certificate issues
```bash
# Test certificate renewal
sudo certbot renew --dry-run

# Manual renewal
sudo certbot renew

# Check certificate status
sudo certbot certificates
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more solutions.

---

## Next Steps

1. **Configure sites:** Edit `config/sites.json` to add your sites
2. **Test redirects:** Visit `http://your-domain.com/site-id/article-id`
3. **Setup n8n:** Use API token to connect n8n
4. **Monitor:** Check logs and stats regularly

---

## Additional Resources

- [Configuration Guide](CONFIGURATION.md)
- [API Documentation](API.md)
- [Deployment Options](DEPLOYMENT.md)
- [Upgrade Guide](UPGRADE.md)
- [Troubleshooting](TROUBLESHOOTING.md)

---

## Support

For issues and questions:
- GitHub Issues: https://github.com/genzoai/redirect-service/issues
- Documentation: [/docs](.)
