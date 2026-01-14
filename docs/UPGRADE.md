# Upgrade Guide

Updating Universal Redirect Service to newer versions.

---

## Quick Upgrade

### Automatic Update (Recommended)

```bash
sudo bash scripts/update.sh
```

This will:
1. Check current version
2. Download latest release from GitHub
3. Create backup
4. Stop service
5. Update files (preserving config)
6. Update dependencies
7. Run database migrations
8. Restart service
9. Health check (auto-rollback if fails)

---

## Update Options

### Update to Latest Version

```bash
sudo bash scripts/update.sh
```

### Update to Specific Version

```bash
sudo bash scripts/update.sh --version v1.2.0
```

### Force Update (Reinstall Current Version)

```bash
sudo bash scripts/update.sh --force
```

### Skip Backup (Not Recommended)

```bash
sudo bash scripts/update.sh --skip-backup
```

---

## Pre-Update Checklist

Before updating:

- [ ] Read CHANGELOG for breaking changes
- [ ] Backup database manually (optional)
- [ ] Check disk space (>1GB free)
- [ ] Note current version: `grep version package.json`
- [ ] Ensure service is running: `systemctl status redirect-service`
  If you used a custom service name, replace `redirect-service` with your `SERVICE_NAME`.

---

## Update Process (Manual)

### 1. Check Current Version

```bash
cd /opt/redirect-service
grep '"version"' package.json
```

### 2. Create Backup

```bash
# Application backup
sudo cp -r /opt/redirect-service /opt/redirect-service-backup-$(date +%Y%m%d)

# Database backup
mysqldump -u redirect_user -p redirect_db > redirect-db-backup-$(date +%Y%m%d).sql
```

### 3. Stop Service

```bash
sudo systemctl stop redirect-service
```

### 4. Pull Latest Code

```bash
cd /opt/redirect-service
git fetch origin
git checkout main
git pull origin main
```

### 5. Update Dependencies

```bash
npm install --production
```

### 6. Run Migrations

```bash
npm run migrate
```

### 7. Restart Service

```bash
sudo systemctl start redirect-service
```

### 8. Verify

```bash
# Check status
sudo systemctl status redirect-service

# Health check
curl http://localhost:3077/health

# Check logs
sudo journalctl -u redirect-service -n 50
```

---

## Database Migrations

### Run Migrations

```bash
npm run migrate
```

### Check Migration Status

```bash
npm run migrate:status
```

### Rollback Last Migration

```bash
npm run migrate:rollback
```

**Note:** Migrations are tracked in `schema_migrations` table.

---

## Rollback

### Automatic Rollback

If update fails health check, automatic rollback occurs.

### Manual Rollback

#### Option 1: Using Rollback Script

```bash
# Interactive selection
sudo bash scripts/rollback.sh

# Or specify backup path
sudo bash scripts/rollback.sh /path/to/backup_20260112_210000
```

#### Option 2: Manual Restore

```bash
# Stop service
sudo systemctl stop redirect-service

# Restore application
sudo rm -rf /opt/redirect-service
sudo cp -r /opt/redirect-service-backup-YYYYMMDD /opt/redirect-service

# Restore database (if needed)
mysql -u redirect_user -p redirect_db < redirect-db-backup-YYYYMMDD.sql

# Reinstall dependencies
cd /opt/redirect-service
npm install --production

# Restart service
sudo systemctl start redirect-service
```

---

## Docker Updates

### Update Docker Images

```bash
cd docker/
docker-compose pull
docker-compose up -d --build
```

### With Zero Downtime

```bash
# Build new image
docker-compose build redirect

# Rolling update
docker-compose up -d --no-deps --build redirect
```

---

## Upgrade Paths

### v1.0.x → v1.1.x

**Changes:**
- Minor feature additions
- No breaking changes
- No config changes required

**Steps:**
```bash
sudo bash scripts/update.sh
```

### v1.x.x → v2.0.0

**Breaking Changes:**
- Check CHANGELOG for details
- May require config updates
- May require manual migration steps

**Steps:**
1. Read CHANGELOG.md carefully
2. Update config files as needed
3. Run update script
4. Test thoroughly

---

## Post-Update Tasks

### 1. Verify Service

```bash
sudo systemctl status redirect-service
curl http://localhost:3077/health
```

### 2. Check Logs

```bash
sudo journalctl -u redirect-service -n 100
```

### 3. Test Redirects

```bash
curl -I http://your-domain.com/test/123
```

### 4. Test n8n API

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://localhost:3077/api/stats?site=yoursite&period=week"
```

### 5. Monitor for Issues

Watch logs for 5-10 minutes:
```bash
sudo journalctl -u redirect-service -f
```

---

## Backup Management

### List Available Backups

```bash
ls -lht ../redirect-service-backups/
```

### Cleanup Old Backups

Auto-cleanup keeps last 5 backups. Manual cleanup:
```bash
# Keep only last 3 backups
cd ../redirect-service-backups
ls -t | tail -n +4 | xargs rm -rf
```

---

## Troubleshooting Updates

### Update Fails to Download

```bash
# Check internet connection
ping github.com

# Check GitHub status
curl -I https://github.com

# Try manual download
wget https://github.com/genzoai/redirect-service/archive/refs/tags/v1.2.0.tar.gz
```

### Dependencies Installation Fails

```bash
# Clear npm cache
npm cache clean --force

# Remove node_modules and reinstall
rm -rf node_modules
npm install --production
```

### Service Won't Start After Update

```bash
# Check logs for errors
sudo journalctl -u redirect-service -n 100

# Common issues:
# - Port in use → killall node
# - DB connection → check .env
# - Missing deps → npm install

# If all else fails, rollback
sudo bash scripts/rollback.sh
```

### Health Check Fails

Auto-rollback should occur. If manual intervention needed:
```bash
# Check what's failing
curl -v http://localhost:3077/health

# Check database connection
mysql -h localhost -u redirect_user -p redirect_db

# Rollback if needed
sudo bash scripts/rollback.sh
```

---

## Version History

Check `CHANGELOG.md` for detailed version history and breaking changes.

---

## Additional Resources

- [Installation Guide](INSTALLATION.md)
- [Configuration Guide](CONFIGURATION.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Deployment Guide](DEPLOYMENT.md)
