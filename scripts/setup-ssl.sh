#!/bin/bash

###############################################################################
# Universal Redirect Service - SSL Setup Script
# Installs Let's Encrypt SSL certificate using certbot
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

###############################################################################
# Functions
###############################################################################

print_header() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║   Universal Redirect Service - SSL Setup              ║"
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

# Check for existing SSL certificate
check_existing_cert() {
    print_step "Checking for Existing SSL Certificate"

    if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        print_warning "SSL certificate for '$DOMAIN' already exists!"
        echo ""

        # Show certificate info
        echo "Certificate information:"
        if command -v certbot &> /dev/null; then
            certbot certificates -d "$DOMAIN" 2>/dev/null | grep -A 10 "Certificate Name: $DOMAIN" || true
        else
            echo "  Location: /etc/letsencrypt/live/$DOMAIN/"
            if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
                local expiry=$(openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" -noout -enddate | cut -d= -f2)
                echo "  Expires: $expiry"
            fi
        fi
        echo ""

        echo "Options:"
        echo "  1) Keep existing certificate (recommended if valid)"
        echo "  2) Renew certificate"
        echo "  3) Delete and create new certificate"
        echo "  4) Exit setup"
        echo ""

        while true; do
            read -p "Choose option [1-4]: " choice
            case $choice in
                1)
                    print_success "Using existing certificate"
                    return 1  # Skip certificate creation
                    ;;
                2)
                    print_info "Will renew certificate..."
                    return 0  # Continue with renewal
                    ;;
                3)
                    echo ""
                    echo -e "${RED}${BOLD}WARNING:${NC} This will delete the existing certificate!"
                    read -p "Type domain name to confirm: " confirm_domain

                    if [ "$confirm_domain" = "$DOMAIN" ]; then
                        certbot delete --cert-name "$DOMAIN" 2>/dev/null || rm -rf "/etc/letsencrypt/live/$DOMAIN" "/etc/letsencrypt/archive/$DOMAIN" "/etc/letsencrypt/renewal/$DOMAIN.conf"
                        print_success "Deleted existing certificate"
                        return 0  # Continue with new cert
                    else
                        print_error "Domain name doesn't match"
                        print_info "Keeping existing certificate"
                        return 1
                    fi
                    ;;
                4)
                    print_info "SSL setup cancelled"
                    exit 0
                    ;;
                *)
                    echo "Invalid option, please choose 1-4"
                    ;;
            esac
        done
    else
        print_success "No existing certificate found"
        return 0  # Continue with cert creation
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Get domain from argument or env
get_domain() {
    if [ -n "$1" ]; then
        DOMAIN="$1"
    elif [ -f "$ROOT_DIR/.env" ]; then
        # Try to extract domain from .env
        DOMAIN=$(grep -E "^DOMAIN=" "$ROOT_DIR/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
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

# Get email for Let's Encrypt
get_email() {
    echo -e "${YELLOW}Enter email for Let's Encrypt notifications:${NC}"
    read -r EMAIL

    if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_error "Invalid email format"
        exit 1
    fi

    print_success "Email: $EMAIL"
}

# Check if certbot is installed
check_certbot() {
    print_step "Step 1: Checking Certbot"

    if command -v certbot &> /dev/null; then
        CERTBOT_VERSION=$(certbot --version 2>&1 | head -n1)
        print_success "Certbot is installed: $CERTBOT_VERSION"
        return 0
    else
        print_warning "Certbot is not installed"
        return 1
    fi
}

# Install certbot
install_certbot() {
    print_step "Step 2: Installing Certbot"

    # Detect OS
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
        print_success "Certbot installed (Debian/Ubuntu)"
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora
        yum install -y certbot python3-certbot-nginx || dnf install -y certbot python3-certbot-nginx
        print_success "Certbot installed (RHEL/CentOS)"
    else
        print_error "Unsupported OS. Please install certbot manually."
        exit 1
    fi
}

# Check if nginx is installed
check_nginx() {
    print_step "Step 3: Checking Nginx"

    if command -v nginx &> /dev/null; then
        NGINX_VERSION=$(nginx -v 2>&1)
        print_success "Nginx is installed: $NGINX_VERSION"
    else
        print_error "Nginx is not installed"
        echo -e "${YELLOW}Please install nginx first or run: sudo bash scripts/setup-nginx.sh${NC}"
        exit 1
    fi

    # Check if nginx is running
    if systemctl is-active --quiet nginx; then
        print_success "Nginx is running"
    else
        print_warning "Nginx is not running, attempting to start..."
        systemctl start nginx
        print_success "Nginx started"
    fi
}

# Check DNS records
check_dns() {
    print_step "Step 4: Checking DNS Records"

    echo "Checking if $DOMAIN resolves to this server..."

    # Get server's public IP
    SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "unknown")

    if [ "$SERVER_IP" = "unknown" ]; then
        print_warning "Could not determine server's public IP"
        echo -e "${YELLOW}Make sure your DNS A record points to this server${NC}"
    else
        # Check DNS resolution
        DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1 || echo "")

        if [ -z "$DOMAIN_IP" ]; then
            print_error "Domain does not resolve"
            echo -e "${YELLOW}Please create an A record for $DOMAIN pointing to $SERVER_IP${NC}"
            read -p "$(echo -e ${YELLOW}Continue anyway? [y/N]: ${NC})" -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        elif [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
            print_success "DNS correctly points to this server ($SERVER_IP)"
        else
            print_warning "DNS points to $DOMAIN_IP, but server IP is $SERVER_IP"
            echo -e "${YELLOW}SSL certificate may fail. Please update DNS record.${NC}"
            read -p "$(echo -e ${YELLOW}Continue anyway? [y/N]: ${NC})" -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# Obtain SSL certificate
obtain_certificate() {
    print_step "Step 5: Obtaining SSL Certificate"

    # Obtain new certificate (or renew if check_existing_cert returned 0)
    echo "Obtaining certificate from Let's Encrypt..."

    if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect; then
        print_success "SSL certificate obtained successfully"
    else
        print_error "Failed to obtain SSL certificate"
        echo -e "${YELLOW}Common issues:"
        echo "  - Domain does not point to this server"
        echo "  - Port 80 and 443 are not accessible"
        echo "  - Nginx configuration is incorrect${NC}"
        exit 1
    fi
}

# Setup auto-renewal
setup_auto_renewal() {
    print_step "Step 6: Setting Up Auto-Renewal"

    # Certbot automatically creates a systemd timer for renewal
    if systemctl list-timers | grep -q certbot; then
        print_success "Auto-renewal timer is active"
    else
        # Create cron job as fallback
        CRON_CMD="0 3 * * * /usr/bin/certbot renew --quiet"

        if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
            (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
            print_success "Auto-renewal cron job created"
        else
            print_success "Auto-renewal cron job already exists"
        fi
    fi

    # Test renewal
    echo "Testing renewal process..."
    if certbot renew --dry-run; then
        print_success "Renewal test passed"
    else
        print_warning "Renewal test failed (but certificate is installed)"
    fi
}

# Verify installation
verify_installation() {
    print_step "Step 7: Verifying Installation"

    # Check certificate files
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && \
       [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
        print_success "Certificate files found"

        # Show expiration date
        EXPIRY=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" | cut -d= -f2)
        echo "  Certificate expires: $EXPIRY"
    else
        print_error "Certificate files not found"
        exit 1
    fi

    # Test HTTPS connection
    echo "Testing HTTPS connection..."
    if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" | grep -q "200\|301\|302"; then
        print_success "HTTPS is working"
    else
        print_warning "Could not verify HTTPS connection (may need nginx restart)"
    fi
}

# Print summary
print_summary() {
    echo -e "\n${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║              ✓ SSL Setup Complete!                    ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${BOLD}SSL Configuration:${NC}"
    echo "  Domain:      $DOMAIN"
    echo "  Certificate: /etc/letsencrypt/live/$DOMAIN/"
    echo "  Auto-renewal: Enabled"
    echo ""

    echo -e "${BOLD}Your service is now accessible via HTTPS:${NC}"
    echo "  ${GREEN}https://$DOMAIN${NC}"
    echo ""

    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Verify HTTPS: ${YELLOW}curl -I https://$DOMAIN${NC}"
    echo "  2. Test redirect: ${YELLOW}curl -I https://$DOMAIN/test/123${NC}"
    echo ""

    echo -e "${BOLD}Certificate Renewal:${NC}"
    echo "  Certificates auto-renew every 60 days"
    echo "  Manual renewal: ${YELLOW}sudo certbot renew${NC}"
    echo "  Test renewal: ${YELLOW}sudo certbot renew --dry-run${NC}"
    echo ""
}

###############################################################################
# Main
###############################################################################

main() {
    print_header

    # Check root
    check_root

    # Get domain
    get_domain "$1"

    # Check for existing certificate
    if ! check_existing_cert; then
        # Certificate exists and user chose to keep it
        print_success "SSL setup complete (using existing certificate)"
        exit 0
    fi

    # Get email (only needed if creating/renewing cert)
    get_email

    # Install certbot if needed
    if ! check_certbot; then
        install_certbot
    fi

    # Check nginx
    check_nginx

    # Check DNS
    check_dns

    # Obtain certificate
    obtain_certificate

    # Setup auto-renewal
    setup_auto_renewal

    # Verify
    verify_installation

    # Print summary
    print_summary
}

# Run main function
main "$@"
