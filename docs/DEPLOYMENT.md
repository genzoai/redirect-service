# Deployment Guide

Deployment options for Universal Redirect Service.

---

## Deployment Methods

### 1. Bare Metal (Ubuntu/Debian)

**Best for:** Single server, full control

```bash
# Complete installation
sudo bash scripts/install.sh
```

**Pros:**
- Simple, direct access
- Full control over system
- No containerization overhead

**Cons:**
- Manual dependency management
- Less portable

---

### 2. Docker Compose

**Best for:** Isolated environment, easy deployment

```bash
# Production
cd docker/
docker-compose up -d

# Development
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
```

**Pros:**
- Isolated environment
- Easy replication
- Consistent across environments

**Cons:**
- Requires Docker knowledge
- External WordPress DB needs network access

See [docker/README.md](../docker/README.md) for details.

---

### 3. Cloud VPS

**Recommended Providers:**
- DigitalOcean Droplet (Basic $6/mo)
- AWS Lightsail ($5-10/mo)
- Hetzner Cloud (€4-8/mo)
- Vultr ($5-10/mo)

**Minimum Specs:**
- 1 vCPU, 1GB RAM
- 25GB SSD
- Ubuntu 22.04 LTS

**Setup:**
```bash
# 1. Create VPS with Ubuntu 22.04
# 2. SSH into server
ssh root@your-server-ip

# 3. Clone and install
cd /opt
git clone https://github.com/genzoai/redirect-service.git
cd redirect-service
sudo bash scripts/install.sh
```

---

## Architecture Patterns

### Single Server (Simple)

```
Internet → Domain (A Record)
         → Nginx (:80, :443)
         → Node.js (:3077)
         → MySQL (localhost)
         → [Optional] WordPress DB (remote/local)
```

**Good for:**
- Small to medium traffic (<10k requests/day)
- Budget-friendly
- Easy to maintain

---

### High Availability (Advanced)

```
Internet → Load Balancer
         → Node.js Instance 1
         → Node.js Instance 2
         → Shared MySQL (RDS/managed)
         → [Optional] WordPress DB (remote)
```

**Good for:**
- High traffic (>100k requests/day)
- Zero downtime requirements
- Enterprise

**Tools:**
- Load Balancer: HAProxy, Nginx
- Database: AWS RDS, DigitalOcean Managed MySQL
- Orchestration: Docker Swarm, Kubernetes

---

## Environment-Specific Configuration

### Production

`.env`:
```bash
NODE_ENV=production
PORT=3077
DB_HOST=localhost  # or RDS endpoint
LOG_LEVEL=info
```

**Security:**
- Enable SSL (certbot)
- Use strong passwords
- Firewall: allow only 80, 443, 22
- Regular updates

---

### Staging

`.env`:
```bash
NODE_ENV=staging
PORT=3077
DB_HOST=staging-db
LOG_LEVEL=debug
```

**Purpose:**
- Test updates before production
- QA environment
- Integration testing

---

### Development

`.env`:
```bash
NODE_ENV=development
PORT=3077
DB_HOST=localhost
LOG_LEVEL=debug
DEBUG=*
```

Or use Docker:
```bash
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml up
```

---

## Reverse Proxy Configuration

### Nginx (Recommended)

Already configured by `setup-nginx.sh`:
```nginx
location / {
    proxy_pass http://localhost:3077;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

### Cloudflare (CDN + DDoS Protection)

1. Point domain to server IP
2. Enable Cloudflare proxy (orange cloud)
3. Set SSL mode: Full (strict)
4. Optional: Enable caching rules

---

## SSL/TLS

### Let's Encrypt (Free)

```bash
sudo bash scripts/setup-ssl.sh your-domain.com
```

Auto-renewal configured automatically.

### Custom Certificate

```nginx
ssl_certificate /path/to/cert.pem;
ssl_certificate_key /path/to/key.pem;
```

---

## Monitoring

### Service Health

```bash
# Systemd status
sudo systemctl status redirect-service

# Logs
sudo journalctl -u redirect-service -f

# Health endpoint
curl http://localhost:3077/health
```

If you used a custom service name, replace `redirect-service` with your `SERVICE_NAME`.

### Uptime Monitoring

**Free tools:**
- UptimeRobot
- StatusCake
- Healthchecks.io

**Monitor:** `https://your-domain.com/health`

---

## Backup Strategy

### Automated Backups

Backups created automatically during updates:
```
redirect-service-backups/
├── backup_20260112_210000/
├── backup_20260112_200000/
└── backup_20260112_190000/
```

### Manual Backup

```bash
# Application
tar -czf redirect-backup-$(date +%Y%m%d).tar.gz \
  --exclude='node_modules' \
  --exclude='logs' \
  /opt/redirect-service/

# Database
mysqldump -u redirect_user -p redirect_db > redirect-db-$(date +%Y%m%d).sql
```

### Restore

```bash
# Application
tar -xzf redirect-backup-YYYYMMDD.tar.gz -C /opt/

# Database
mysql -u redirect_user -p redirect_db < redirect-db-YYYYMMDD.sql
```

---

## Scaling Considerations

### Vertical Scaling (Easier)
- Upgrade VPS to more CPU/RAM
- Optimize MySQL queries
- Add Redis caching (future)

### Horizontal Scaling (Advanced)
- Multiple Node.js instances behind load balancer
- Shared database (managed MySQL)
- Session persistence (not needed for this stateless service)

---

## Security Checklist

- [ ] SSL/TLS enabled
- [ ] Firewall configured (ufw/iptables)
- [ ] Strong database passwords
- [ ] API Bearer tokens rotated regularly
- [ ] System updates applied
- [ ] Nginx security headers configured
- [ ] Fail2ban for SSH protection
- [ ] Regular backups scheduled
- [ ] Monitoring and alerts enabled

---

## Performance Tuning

### Node.js

```bash
# PM2 for clustering (alternative to systemd)
npm install -g pm2
pm2 start src/server.js -i max  # Use all CPU cores
```

### MySQL

```sql
-- Add indexes for frequently queried fields
CREATE INDEX idx_clicks_created ON clicks(created_at);
CREATE INDEX idx_clicks_country ON clicks(country);
```

### Nginx Caching

```nginx
# Cache static assets
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

---

## Additional Resources

- [Installation Guide](INSTALLATION.md)
- [Configuration Guide](CONFIGURATION.md)
- [Upgrade Guide](UPGRADE.md)
- [Docker Documentation](../docker/README.md)
