#!/bin/bash

###############################################################################
# Universal Redirect Service - Nginx Setup Script
# Version: 2.0.0
#
# Creates nginx configuration for the redirect service with safety features:
# - Automatic backup of existing nginx configuration
# - Detection and handling of existing configurations
# - Interactive prompts for potentially destructive operations
# - Automatic rollback on errors
# - Support for --skip-backup flag
#
# Usage: sudo bash setup-nginx.sh [OPTIONS] [DOMAIN]
###############################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
DOMAIN=""
PORT="3077"
BACKUP_DIR=""
SKIP_BACKUP=false

###############################################################################
# Functions
###############################################################################

print_header() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║   Universal Redirect Service - Nginx Setup            ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${CYAN}${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Backup nginx configuration
backup_nginx() {
    if [ "$SKIP_BACKUP" = true ]; then
        print_warning "Skipping backup (--skip-backup flag)"
        return 0
    fi

    print_step "Step 0: Creating Backup"

    BACKUP_DIR="/etc/nginx/backup-$(date +%Y%m%d-%H%M%S)"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Backup nginx.conf
    if [ -f /etc/nginx/nginx.conf ]; then
        cp /etc/nginx/nginx.conf "$BACKUP_DIR/"
        print_success "Backed up nginx.conf"
    fi

    # Backup sites-available if exists
    if [ -d /etc/nginx/sites-available ]; then
        cp -r /etc/nginx/sites-available "$BACKUP_DIR/"
        print_success "Backed up sites-available/"
    fi

    # Backup sites-enabled if exists
    if [ -d /etc/nginx/sites-enabled ]; then
        cp -r /etc/nginx/sites-enabled "$BACKUP_DIR/"
        print_success "Backed up sites-enabled/"
    fi

    # Backup conf.d if exists
    if [ -d /etc/nginx/conf.d ]; then
        cp -r /etc/nginx/conf.d "$BACKUP_DIR/"
        print_success "Backed up conf.d/"
    fi

    echo -e "${GREEN}✓ Backup created: ${BACKUP_DIR}${NC}"
    echo ""
}

# Rollback function
rollback_nginx() {
    if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
        print_error "No backup directory found, cannot rollback"
        return 1
    fi

    print_warning "Rolling back nginx configuration..."

    # Restore nginx.conf
    if [ -f "$BACKUP_DIR/nginx.conf" ]; then
        cp "$BACKUP_DIR/nginx.conf" /etc/nginx/nginx.conf
        print_success "Restored nginx.conf"
    fi

    # Restore sites-available
    if [ -d "$BACKUP_DIR/sites-available" ]; then
        rm -rf /etc/nginx/sites-available
        cp -r "$BACKUP_DIR/sites-available" /etc/nginx/
        print_success "Restored sites-available/"
    fi

    # Restore sites-enabled
    if [ -d "$BACKUP_DIR/sites-enabled" ]; then
        rm -rf /etc/nginx/sites-enabled
        cp -r "$BACKUP_DIR/sites-enabled" /etc/nginx/
        print_success "Restored sites-enabled/"
    fi

    # Restore conf.d
    if [ -d "$BACKUP_DIR/conf.d" ]; then
        rm -rf /etc/nginx/conf.d
        cp -r "$BACKUP_DIR/conf.d" /etc/nginx/
        print_success "Restored conf.d/"
    fi

    # Test and reload
    if nginx -t; then
        systemctl reload nginx
        print_success "Rollback complete, nginx reloaded"
    else
        print_error "Nginx configuration test failed after rollback"
        return 1
    fi
}

# Check for existing configuration
check_existing_config() {
    print_step "Checking for Existing Configuration"

    NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
    NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

    local has_conflict=false

    # Check if config file exists
    if [ -f "$NGINX_CONF" ]; then
        print_warning "Configuration file already exists: $NGINX_CONF"
        has_conflict=true
    fi

    # Check if enabled symlink exists
    if [ -L "$NGINX_ENABLED" ]; then
        print_warning "Site is already enabled: $NGINX_ENABLED"
        has_conflict=true
    fi

    # If conflict found, ask user
    if [ "$has_conflict" = true ]; then
        echo ""
        echo -e "${YELLOW}${BOLD}WARNING:${NC} An nginx configuration for ${BOLD}$DOMAIN${NC} already exists."
        echo ""
        echo "Options:"
        echo "  1) Overwrite existing configuration (backup will be created)"
        echo "  2) Keep existing configuration and exit"
        echo "  3) Show existing configuration"
        echo ""

        while true; do
            read -p "Choose option [1-3]: " choice
            case $choice in
                1)
                    print_warning "Will overwrite existing configuration"
                    return 0
                    ;;
                2)
                    print_info "Keeping existing configuration, exiting..."
                    exit 0
                    ;;
                3)
                    echo ""
                    echo -e "${BOLD}=== Current configuration for $DOMAIN ===${NC}"
                    cat "$NGINX_CONF" 2>/dev/null || echo "File not found"
                    echo -e "${BOLD}========================================${NC}"
                    echo ""
                    ;;
                *)
                    echo "Invalid option, please choose 1-3"
                    ;;
            esac
        done
    else
        print_success "No existing configuration found"
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Load environment variables
load_env() {
    if [ -f "$ROOT_DIR/.env" ]; then
        # Source .env file to get PORT variable
        source <(grep -v '^#' "$ROOT_DIR/.env" | sed 's/^/export /')

        # Validate port from .env
        if [ -n "$PORT" ]; then
            # Check if it's a valid port number
            if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
                print_success "Using port from .env: $PORT"
            else
                print_warning "Invalid PORT in .env ($PORT), using default 3077"
                PORT="3077"
            fi
        else
            print_warning "PORT not found in .env, using default 3077"
            PORT="3077"
        fi
    else
        print_warning ".env file not found, using default port 3077"
    fi
}

# Get domain
get_domain() {
    if [ -n "$1" ]; then
        DOMAIN="$1"
    elif [ -f "$ROOT_DIR/.env" ]; then
        # Try to extract from .env (not standard but may exist)
        DOMAIN=$(grep -E "^DOMAIN=" "$ROOT_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "")
    fi

    if [ -z "$DOMAIN" ]; then
        echo -e "${YELLOW}Enter your domain (e.g., go.example.com):${NC}"
        read -r DOMAIN
    fi

    # Validate domain
    if [[ ! "$DOMAIN" =~ ^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}$ ]]; then
        print_error "Invalid domain format: $DOMAIN"
        exit 1
    fi

    print_success "Domain: $DOMAIN"
}

# Check web ports availability
check_web_ports() {
    print_step "Checking Web Ports (80/443)"

    local ports_in_use=false

    # Check port 80
    if sudo lsof -i :80 2>/dev/null | grep -v "^COMMAND" | grep -q .; then
        print_warning "Port 80 (HTTP) is already in use:"
        sudo lsof -i :80 2>/dev/null | grep -v "^COMMAND" | head -5
        echo ""
        ports_in_use=true
    else
        print_success "Port 80 is available"
    fi

    # Check port 443
    if sudo lsof -i :443 2>/dev/null | grep -v "^COMMAND" | grep -q .; then
        print_warning "Port 443 (HTTPS) is already in use:"
        sudo lsof -i :443 2>/dev/null | grep -v "^COMMAND" | head -5
        echo ""
        ports_in_use=true
    else
        print_success "Port 443 is available"
    fi

    if [ "$ports_in_use" = true ]; then
        echo -e "${YELLOW}${BOLD}WARNING:${NC} Web ports are already in use!"
        echo ""
        echo "This may be:"
        echo "  - Another web server (Apache, existing Nginx, etc.)"
        echo "  - Another application using these ports"
        echo ""
        echo "Options:"
        echo "  1) Continue anyway (may cause Nginx to fail)"
        echo "  2) Stop conflicting services and retry"
        echo "  3) Exit installation"
        echo ""

        while true; do
            read -p "Choose option [1-3]: " choice
            case $choice in
                1)
                    print_warning "Continuing with port conflicts..."
                    print_info "Nginx may fail to start. You'll need to resolve conflicts manually."
                    return 0
                    ;;
                2)
                    echo ""
                    echo "To stop Apache:"
                    echo "  ${YELLOW}sudo systemctl stop apache2${NC}"
                    echo ""
                    echo "To stop existing Nginx:"
                    echo "  ${YELLOW}sudo systemctl stop nginx${NC}"
                    echo ""
                    read -p "Press Enter after stopping services to retry..."
                    # Retry check
                    check_web_ports
                    return 0
                    ;;
                3)
                    print_info "Installation cancelled"
                    exit 0
                    ;;
                *)
                    echo "Invalid option, please choose 1-3"
                    ;;
            esac
        done
    fi
}

# Check firewall rules
check_firewall() {
    print_step "Checking Firewall Rules"

    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        print_info "UFW not installed, skipping firewall check"
        return 0
    fi

    # Check UFW status
    UFW_STATUS=$(sudo ufw status 2>/dev/null | grep "Status:" | awk '{print $2}')

    if [ "$UFW_STATUS" != "active" ]; then
        print_info "UFW firewall is not active"
        return 0
    fi

    print_warning "UFW firewall is active"

    local ports_blocked=false

    # Check port 80
    if ! sudo ufw status | grep -q "80"; then
        print_warning "Port 80 (HTTP) is not allowed in UFW"
        ports_blocked=true
    else
        print_success "Port 80 is allowed"
    fi

    # Check port 443
    if ! sudo ufw status | grep -q "443"; then
        print_warning "Port 443 (HTTPS) is not allowed in UFW"
        ports_blocked=true
    else
        print_success "Port 443 is allowed"
    fi

    if [ "$ports_blocked" = true ]; then
        echo ""
        echo -e "${YELLOW}${BOLD}WARNING:${NC} Required ports are blocked by UFW!"
        echo ""
        echo "Options:"
        echo "  1) Allow ports 80 and 443 in UFW (recommended)"
        echo "  2) Continue without changing firewall (service may not be accessible)"
        echo "  3) Exit installation"
        echo ""

        while true; do
            read -p "Choose option [1-3]: " choice
            case $choice in
                1)
                    if ! sudo ufw status | grep -q "80"; then
                        sudo ufw allow 80/tcp
                        print_success "Allowed port 80 (HTTP)"
                    fi
                    if ! sudo ufw status | grep -q "443"; then
                        sudo ufw allow 443/tcp
                        print_success "Allowed port 443 (HTTPS)"
                    fi
                    echo ""
                    print_success "Firewall configured successfully"
                    return 0
                    ;;
                2)
                    print_warning "Continuing without firewall changes"
                    print_info "Your service may not be accessible from outside"
                    return 0
                    ;;
                3)
                    print_info "Installation cancelled"
                    exit 0
                    ;;
                *)
                    echo "Invalid option, please choose 1-3"
                    ;;
            esac
        done
    else
        print_success "Firewall is properly configured"
    fi
}

# Check if nginx is installed
check_nginx() {
    print_step "Step 1: Checking Nginx"

    if command -v nginx &> /dev/null; then
        NGINX_VERSION=$(nginx -v 2>&1)
        print_success "Nginx is installed: $NGINX_VERSION"
    else
        print_warning "Nginx is not installed"
        echo ""
        read -p "Install nginx now? [Y/n]: " install_choice
        install_choice=${install_choice:-Y}

        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            install_nginx
        else
            print_error "Nginx is required. Exiting."
            exit 1
        fi
    fi
}

# Install nginx
install_nginx() {
    print_step "Installing Nginx"

    # Detect OS
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y nginx
        print_success "Nginx installed (Debian/Ubuntu)"
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora
        yum install -y nginx || dnf install -y nginx
        print_success "Nginx installed (RHEL/CentOS)"
    else
        print_error "Unsupported OS. Please install nginx manually."
        exit 1
    fi

    # Start and enable nginx
    systemctl start nginx
    systemctl enable nginx
}

# Create nginx configuration
create_nginx_config() {
    print_step "Step 2: Creating Nginx Configuration"

    NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
    NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

    # Check if sites-available directory exists (Debian/Ubuntu)
    if [ ! -d "/etc/nginx/sites-available" ]; then
        mkdir -p /etc/nginx/sites-available
        mkdir -p /etc/nginx/sites-enabled

        # Add include to nginx.conf if not present
        if ! grep -q "include /etc/nginx/sites-enabled/\*" /etc/nginx/nginx.conf; then
            sed -i '/include \/etc\/nginx\/conf.d\/\*.conf;/a\    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
        fi
    fi

    # Generate configuration from template
    cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # Redirect HTTP to HTTPS (will be configured by certbot)
    # return 301 https://\$server_name\$request_uri;

    # Initially proxy to Node.js app (before SSL setup)
    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;

        # Headers for correct proxying
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_cache_bypass \$http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Logs
    access_log /var/log/nginx/$DOMAIN-access.log;
    error_log /var/log/nginx/$DOMAIN-error.log;
}

# HTTPS configuration (will be added by certbot)
# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     server_name $DOMAIN;
#
#     # SSL certificates (will be configured by certbot)
#     # ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
#     # ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
#     # include /etc/letsencrypt/options-ssl-nginx.conf;
#     # ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
#
#     # Proxy to Node.js application
#     location / {
#         proxy_pass http://localhost:$PORT;
#         proxy_http_version 1.1;
#
#         # Headers
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection 'upgrade';
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto \$scheme;
#
#         proxy_cache_bypass \$http_upgrade;
#
#         # Timeouts
#         proxy_connect_timeout 60s;
#         proxy_send_timeout 60s;
#         proxy_read_timeout 60s;
#     }
#
#     # Logs
#     access_log /var/log/nginx/$DOMAIN-access.log;
#     error_log /var/log/nginx/$DOMAIN-error.log;
#
#     # Client upload limit
#     client_max_body_size 10M;
# }
EOF

    print_success "Nginx configuration created: $NGINX_CONF"
}

# Enable site
enable_site() {
    print_step "Step 3: Enabling Site"

    NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
    NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

    # Create symlink if doesn't exist
    if [ ! -L "$NGINX_ENABLED" ]; then
        ln -s "$NGINX_CONF" "$NGINX_ENABLED"
        print_success "Site enabled"
    else
        print_warning "Site already enabled"
    fi

    # Ask about default site if exists
    if [ -L "/etc/nginx/sites-enabled/default" ]; then
        echo ""
        echo -e "${YELLOW}Default nginx site is currently enabled.${NC}"
        read -p "Disable default site? [Y/n]: " disable_default
        disable_default=${disable_default:-Y}

        if [[ "$disable_default" =~ ^[Yy]$ ]]; then
            rm -f /etc/nginx/sites-enabled/default
            print_success "Disabled default nginx site"
        else
            print_info "Keeping default site enabled"
        fi
    fi
}

# Test nginx configuration
test_nginx_config() {
    print_step "Step 4: Testing Nginx Configuration"

    if nginx -t; then
        print_success "Nginx configuration is valid"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi
}

# Reload nginx
reload_nginx() {
    print_step "Step 5: Reloading Nginx"

    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
        print_success "Nginx reloaded"
    else
        systemctl start nginx
        systemctl enable nginx
        print_success "Nginx started and enabled"
    fi
}

# Verify setup
verify_setup() {
    print_step "Step 6: Verifying Setup"

    # Check if nginx is running
    if systemctl is-active --quiet nginx; then
        print_success "Nginx is running"
    else
        print_error "Nginx is not running"
        exit 1
    fi

    # Test HTTP connection
    echo "Testing HTTP connection to $DOMAIN..."

    # Add domain to /etc/hosts for local testing if needed
    if ! grep -q "$DOMAIN" /etc/hosts; then
        echo "127.0.0.1 $DOMAIN" >> /etc/hosts
        print_warning "Added $DOMAIN to /etc/hosts for local testing"
    fi

    # Test connection
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" -H "Host: $DOMAIN" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "502" ]; then
        if [ "$HTTP_CODE" = "502" ]; then
            print_warning "Nginx is configured but backend (Node.js) is not running"
            echo "  Start the service: ${YELLOW}npm start${NC} or ${YELLOW}systemctl start redirect-service${NC}"
        else
            print_success "HTTP connection successful"
        fi
    else
        print_warning "Could not verify HTTP connection (HTTP $HTTP_CODE)"
    fi

    # Show listening ports
    echo ""
    echo "Nginx is listening on:"
    ss -tlnp | grep nginx | awk '{print "  "$4}' || netstat -tlnp 2>/dev/null | grep nginx | awk '{print "  "$4}'
}

# Print summary
print_summary() {
    echo -e "\n${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║              ✓ Nginx Setup Complete!                  ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${BOLD}Nginx Configuration:${NC}"
    echo "  Domain:       $DOMAIN"
    echo "  Config:       /etc/nginx/sites-available/$DOMAIN"
    echo "  Backend:      http://localhost:$PORT"
    echo "  Logs:         /var/log/nginx/$DOMAIN-*.log"
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        echo "  Backup:       $BACKUP_DIR"
    fi
    echo ""

    echo -e "${BOLD}Your service will be accessible at:${NC}"
    echo "  ${GREEN}http://$DOMAIN${NC}"
    echo ""

    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Start redirect service: ${YELLOW}npm start${NC} or ${YELLOW}sudo systemctl start redirect-service${NC}"
    echo "  2. Test: ${YELLOW}curl -I http://$DOMAIN/test/123${NC}"
    echo "  3. Setup SSL: ${YELLOW}sudo bash scripts/setup-ssl.sh $DOMAIN${NC}"
    echo ""

    echo -e "${BOLD}Useful commands:${NC}"
    echo "  Check nginx status: ${YELLOW}sudo systemctl status nginx${NC}"
    echo "  View access logs: ${YELLOW}sudo tail -f /var/log/nginx/$DOMAIN-access.log${NC}"
    echo "  View error logs: ${YELLOW}sudo tail -f /var/log/nginx/$DOMAIN-error.log${NC}"
    echo "  Reload nginx: ${YELLOW}sudo systemctl reload nginx${NC}"
    echo "  Test config: ${YELLOW}sudo nginx -t${NC}"
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        echo "  Rollback: ${YELLOW}sudo bash -c 'cp -r $BACKUP_DIR/* /etc/nginx/ && nginx -t && systemctl reload nginx'${NC}"
    fi
    echo ""
}

###############################################################################
# Main
###############################################################################

# Error handler
error_handler() {
    local exit_code=$?
    echo ""
    print_error "Setup failed with exit code $exit_code"

    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        echo ""
        read -p "Rollback to previous configuration? [Y/n]: " do_rollback
        do_rollback=${do_rollback:-Y}

        if [[ "$do_rollback" =~ ^[Yy]$ ]]; then
            rollback_nginx
        else
            print_warning "Backup preserved at: $BACKUP_DIR"
            echo "To manually rollback, run: sudo bash -c 'cp -r $BACKUP_DIR/* /etc/nginx/ && nginx -t && systemctl reload nginx'"
        fi
    fi

    exit $exit_code
}

# Show usage
show_usage() {
    echo "Usage: sudo bash $0 [OPTIONS] [DOMAIN]"
    echo ""
    echo "Options:"
    echo "  --skip-backup    Skip automatic backup of nginx configuration"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo bash $0 go.example.com"
    echo "  sudo bash $0 --skip-backup go.example.com"
    echo ""
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$DOMAIN" ]; then
                    DOMAIN="$1"
                fi
                shift
                ;;
        esac
    done

    print_header

    # Check root
    check_root

    # Load environment
    load_env

    # Get domain (pass empty if already set from args)
    if [ -z "$DOMAIN" ]; then
        get_domain
    else
        # Validate domain from args
        if [[ ! "$DOMAIN" =~ ^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}$ ]]; then
            print_error "Invalid domain format: $DOMAIN"
            exit 1
        fi
        print_success "Domain: $DOMAIN"
    fi

    # Set error trap
    trap error_handler ERR

    # Setup steps
    backup_nginx
    check_existing_config
    check_nginx
    check_web_ports
    check_firewall
    create_nginx_config
    enable_site
    test_nginx_config
    reload_nginx
    verify_setup

    # Remove error trap
    trap - ERR

    # Print summary
    print_summary

    # Cleanup old backups (keep last 5)
    if [ -n "$BACKUP_DIR" ]; then
        echo ""
        print_info "Backup directory: $BACKUP_DIR"
        echo "To remove backup: sudo rm -rf $BACKUP_DIR"

        # Count backups
        backup_count=$(ls -1d /etc/nginx/backup-* 2>/dev/null | wc -l)
        if [ "$backup_count" -gt 5 ]; then
            print_warning "Found $backup_count backup directories. Consider cleaning old backups."
            echo "List backups: ls -lad /etc/nginx/backup-*"
        fi
    fi
}

# Run main function
main "$@"
