# Troubleshooting Guide

Common issues and solutions for Universal Redirect Service.

---

## Service Issues

### Service Won't Start

**Symptom:**
```bash
sudo systemctl status redirect-service
# Status: failed
```

If you used a custom service name, replace `redirect-service` with your `SERVICE_NAME` in all commands.

**Solutions:**

1. Check logs:
```bash
sudo journalctl -u redirect-service -n 50
```

2. Common causes:

**Port already in use:**
```bash
# Find process using port 3077
sudo lsof -i :3077
# Kill it
sudo kill -9 PID
# Or change PORT in .env
```

**Database connection error:**
```bash
# Test MySQL connection
mysql -h localhost -u redirect_user -p redirect_db

# Check credentials in .env
grep DB_ .env
```

**Missing dependencies:**
```bash
cd /opt/redirect-service
npm install --production
```

**Permissions error:**
```bash
# Fix ownership
sudo chown -R www-data:www-data /opt/redirect-service
# Or user specified in systemd service
```

---

### Service Crashes Frequently

**Check logs:**
```bash
sudo journalctl -u redirect-service -f
```

**Common issues:**

**Out of memory:**
```bash
# Check memory usage
free -h
htop

# Solution: Upgrade server or add swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

**Database connection pool exhausted:**
```sql
-- Check MySQL connections
SHOW PROCESSLIST;

-- Increase max connections
SET GLOBAL max_connections = 200;
```

**Uncaught exceptions:**
- Check logs for stack traces
- Update to latest version
- Report bug on GitHub

---

## Database Issues

### Cannot Connect to Database

**Symptoms:**
- `ECONNREFUSED`
- `Access denied for user`

**Solutions:**

1. **Check MySQL is running:**
```bash
sudo systemctl status mysql
sudo systemctl start mysql
```

2. **Test credentials:**
```bash
mysql -h localhost -u redirect_user -p redirect_db
```

3. **Verify user permissions:**
```sql
SHOW GRANTS FOR 'redirect_user'@'localhost';
```

4. **Recreate user if needed:**
```bash
sudo bash scripts/setup-database.sh
```

---

### Migrations Fail

**Symptom:**
```bash
npm run migrate
# Error: Migration failed
```

**Solutions:**

1. **Check migration status:**
```bash
npm run migrate:status
```

2. **Verify database access:**
```bash
mysql -u redirect_user -p redirect_db -e "SHOW TABLES;"
```

3. **Manual migration:**
```bash
# Run specific SQL file
mysql -u redirect_user -p redirect_db < sql/01-create-database.sql
```

4. **Reset migrations (DANGER - data loss):**
```sql
DROP TABLE IF EXISTS schema_migrations;
```
Then run migrations again.

---

## Nginx Issues

### 502 Bad Gateway

**Cause:** Nginx can't reach Node.js backend

**Solutions:**

1. **Check Node.js is running:**
```bash
curl http://localhost:3077/health
```

2. **Check Nginx config:**
```bash
sudo nginx -t
```

3. **Check Nginx error logs:**
```bash
sudo tail -f /var/log/nginx/error.log
```

4. **Verify proxy_pass target:**
```nginx
# Should be:
proxy_pass http://localhost:3077;
```

---

### 404 Not Found

**Cause:** Nginx config not enabled or wrong domain

**Solutions:**

1. **Check site is enabled:**
```bash
ls -l /etc/nginx/sites-enabled/
```

2. **Enable site:**
```bash
sudo ln -s /etc/nginx/sites-available/your-domain /etc/nginx/sites-enabled/
sudo systemctl reload nginx
```

3. **Check server_name:**
```nginx
server_name go.example.com;
```

---

## SSL/Certificate Issues

### Certificate Not Found

**Symptom:**
```
SSL_CTX_use_PrivateKey_file failed
```

**Solutions:**

1. **Run certbot:**
```bash
sudo bash scripts/setup-ssl.sh your-domain.com
```

2. **Check certificate exists:**
```bash
sudo ls /etc/letsencrypt/live/your-domain.com/
```

3. **Manual certificate request:**
```bash
sudo certbot --nginx -d your-domain.com
```

---

### Certificate Renewal Fails

**Symptoms:**
- Certificate expired
- Renewal cron job fails

**Solutions:**

1. **Test renewal:**
```bash
sudo certbot renew --dry-run
```

2. **Manual renewal:**
```bash
sudo certbot renew
sudo systemctl reload nginx
```

3. **Check renewal timer:**
```bash
sudo systemctl status certbot.timer
```

---

## OG Fetching Issues

### No OG Data Returned

**Symptoms:**
- Redirects work but no OG preview
- Empty title/description/image

**Solutions:**

**For `og_method: wordpress_db`:**

1. **Check WordPress DB connection:**
```bash
mysql -h WP_DB_HOST -u WP_DB_USER -p WP_DB_NAME -e "SHOW TABLES;"
```

2. **Verify table exists:**
```sql
SELECT * FROM wp_posts WHERE ID = 123;
```

3. **Check wp_db config:**
```json
{
  "mysite": {
    "og_method": "wordpress_db",
    "wp_db": "correct_database_name"
  }
}
```

**For `og_method: html_fetch`:**

1. **Test URL manually:**
```bash
curl -I https://example.com/article/123
```

2. **Check OG tags exist:**
```bash
curl https://example.com/article/123 | grep 'og:title'
```

3. **Increase timeout (if slow site):**
Edit `src/utils/og-fetcher-html.js`:
```javascript
timeout: 10000  // 10 seconds instead of 5
```

---

## GeoIP Issues

### Country Always NULL

**Symptoms:**
- Clicks logged but `country` field is NULL

**Solutions:**

1. **Check GeoIP database exists:**
```bash
ls -la node_modules/geoip-lite/data/
```

2. **Update GeoIP database:**
```bash
sudo bash scripts/update-geoip.sh
```

3. **Backfill existing data:**
```bash
node scripts/backfill-countries.js
```

4. **Verify GEOIP_ENABLED:**
```bash
grep GEOIP_ENABLED .env
# Should be: GEOIP_ENABLED=true
```

---

## n8n Integration Issues

### API Returns 401 Unauthorized

**Cause:** Invalid or missing Bearer token

**Solutions:**

1. **Check token in .env:**
```bash
grep API_TOKEN .env
```

2. **Update n8n workflow:**
- Authentication: Bearer Token
- Token: [value from .env]

3. **Test API manually:**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://localhost:3077/api/stats?site=test&period=week"
```

---

### API Returns Empty Data

**Cause:** No clicks in database or wrong site ID

**Solutions:**

1. **Check database has data:**
```sql
SELECT COUNT(*) FROM clicks WHERE site_id = 'yoursite';
```

2. **Verify site_id in request:**
```
/api/stats?site=yoursite  # Must match sites.json key
```

3. **Check date range:**
```sql
SELECT MIN(created_at), MAX(created_at) FROM clicks;
```

---

## Performance Issues

### Slow Response Times

**Symptoms:**
- Redirects take >1s
- High latency

**Solutions:**

1. **Check server load:**
```bash
htop
iostat
```

2. **Optimize MySQL:**
```sql
-- Add indexes
CREATE INDEX idx_clicks_created ON clicks(created_at);
CREATE INDEX idx_clicks_site ON clicks(site_id);

-- Analyze tables
ANALYZE TABLE clicks;
```

3. **Monitor queries:**
```sql
-- Enable slow query log
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
```

4. **Upgrade server:**
- More RAM
- Faster CPU
- SSD storage

---

### High Memory Usage

**Solutions:**

1. **Check Node.js memory:**
```bash
ps aux | grep node
```

2. **Restart service:**
```bash
sudo systemctl restart redirect-service
```

3. **Add memory limit (if needed):**
Edit systemd service:
```ini
Environment="NODE_OPTIONS=--max-old-space-size=512"
```

---

## Docker Issues

### Container Won't Start

**Check logs:**
```bash
docker-compose logs redirect
```

**Common issues:**

**Missing .env:**
```bash
cp config/.env.example .env
# Edit .env
docker-compose up -d
```

**Port conflict:**
```bash
# Change PORT in .env
# Or stop conflicting service
docker ps
docker stop conflicting_container
```

**Database not ready:**
```yaml
# Ensure depends_on with health check
depends_on:
  db:
    condition: service_healthy
```

---

### Can't Connect to Database from Container

**Solutions:**

1. **Use correct host:**
```env
# In Docker, use service name
DB_HOST=db  # NOT localhost
```

2. **Check network:**
```bash
docker network ls
docker network inspect redirect-network
```

3. **Test connection:**
```bash
docker-compose exec redirect ping db
```

---

## Common Error Messages

### "EADDRINUSE: address already in use"

**Fix:**
```bash
# Find process
sudo lsof -i :3077
# Kill it
sudo kill -9 PID
# Or change port in .env
```

---

### "ER_ACCESS_DENIED_ERROR"

**Fix:**
```bash
# Check credentials
mysql -h DB_HOST -u DB_USER -p

# Reset password
mysql -u root -p
ALTER USER 'redirect_user'@'localhost' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;

# Update .env
```

---

### "Cannot find module"

**Fix:**
```bash
npm install --production
```

---

### "ECONNREFUSED" (Database)

**Fix:**
```bash
# Start MySQL
sudo systemctl start mysql

# Check it's listening
sudo netstat -tlnp | grep 3306
```

---

## Getting Help

### Before Asking for Help

1. Check logs:
```bash
sudo journalctl -u redirect-service -n 100
```

2. Verify configuration:
```bash
grep -v '^#' .env | grep -v '^$'
cat config/sites.json
```

3. Test components individually:
```bash
# Database
mysql -u redirect_user -p redirect_db

# Node.js
node src/server.js

# Nginx
sudo nginx -t
```

### Report an Issue

Include:
1. Error message (full stack trace)
2. System info: `uname -a`, `node --version`
3. Service logs: `sudo journalctl -u redirect-service -n 50`
4. Configuration (with sensitive data removed)
5. Steps to reproduce

GitHub Issues: https://github.com/genzoai/redirect-service/issues

---

## Additional Resources

- [Installation Guide](INSTALLATION.md)
- [Configuration Guide](CONFIGURATION.md)
- [API Documentation](API.md)
- [Upgrade Guide](UPGRADE.md)
- [Deployment Guide](DEPLOYMENT.md)
