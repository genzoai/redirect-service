#!/bin/bash

###############################################################################
# Universal Redirect Service - Complete Installation Script
# Runs all setup steps in sequence
###############################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_NAME="${SERVICE_NAME:-redirect-service}"

# Installation state
INSTALL_STATE_FILE="$ROOT_DIR/.install-state"

###############################################################################
# Functions
###############################################################################

print_header() {
    clear
    echo -e "${BOLD}${MAGENTA}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║      Universal Redirect Service - Complete Installation       ║"
    echo "║                                                                ║"
    echo "║           Production-ready UTM tracking & OG preview           ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

print_step() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        echo -e "${YELLOW}Usage: sudo bash scripts/install.sh${NC}"
        exit 1
    fi
}

# Check installation directory for existing files
check_installation_directory() {
    print_step "Checking Installation Directory"

    cd "$ROOT_DIR"

    # List of critical files to check
    local conflicts=()

    [ -f ".env" ] && conflicts+=(".env")
    [ -f "config/sites.json" ] && conflicts+=("config/sites.json")
    [ -d "node_modules" ] && conflicts+=("node_modules/")
    [ -f ".install-state" ] && conflicts+=(".install-state")

    if [ ${#conflicts[@]} -gt 0 ]; then
        print_warning "Found existing installation files:"
        for file in "${conflicts[@]}"; do
            echo "  - ${YELLOW}$file${NC}"
        done
        echo ""

        # Check if this looks like a previous installation
        if [ -f ".install-state" ]; then
            print_info "This appears to be a previous installation or incomplete setup."
            echo ""
            echo "Options:"
            echo "  1) Continue installation (may update existing configuration)"
            echo "  2) Clean installation (remove all existing files)"
            echo "  3) Exit and backup manually"
            echo ""

            while true; do
                read -p "Choose option [1-3]: " choice
                case $choice in
                    1)
                        print_warning "Continuing with existing files..."
                        return 0
                        ;;
                    2)
                        print_warning "This will remove:"
                        echo "  - .env"
                        echo "  - config/"
                        echo "  - node_modules/"
                        echo "  - .install-state"
                        echo ""
                        read -p "Are you sure? Type 'yes' to confirm: " confirm
                        if [ "$confirm" = "yes" ]; then
                            rm -f .env .install-state
                            rm -rf config/ node_modules/
                            print_success "Cleaned installation directory"
                            return 0
                        else
                            print_info "Clean installation cancelled"
                            ;;
                        fi
                        ;;
                    3)
                        print_info "Installation cancelled"
                        echo ""
                        echo "To backup your current installation:"
                        echo "  ${YELLOW}tar -czf redirect-backup-\$(date +%Y%m%d-%H%M%S).tar.gz .env config/ node_modules/${NC}"
                        echo ""
                        exit 0
                        ;;
                    *)
                        echo "Invalid option, please choose 1-3"
                        ;;
                esac
            done
        else
            # Just existing files, not a full installation
            echo -e "${YELLOW}This may be a re-installation. Continue? [Y/n]:${NC}"
            read -r -n 1 REPLY
            echo
            REPLY=${REPLY:-Y}
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Installation cancelled"
                exit 1
            fi
        fi
    else
        print_success "Installation directory is clean"
    fi
}

# Save installation state
save_state() {
    echo "$1" >> "$INSTALL_STATE_FILE"
}

# Check if step was completed
is_completed() {
    if [ -f "$INSTALL_STATE_FILE" ]; then
        grep -q "^$1$" "$INSTALL_STATE_FILE"
        return $?
    fi
    return 1
}

# Step 1: Check Requirements
step_check_requirements() {
    if is_completed "requirements"; then
        print_warning "Requirements already checked, skipping..."
        return 0
    fi

    print_step "Step 1/8: Checking System Requirements"

    cd "$ROOT_DIR"

    if node scripts/check-requirements.js; then
        save_state "requirements"
        print_success "All requirements met"
    else
        print_error "Requirements check failed"
        echo -e "${YELLOW}Please install missing dependencies and run again${NC}"
        exit 1
    fi
}

# Step 2: Setup Wizard
step_setup_wizard() {
    if is_completed "wizard"; then
        print_warning "Configuration already exists, skipping wizard..."
        return 0
    fi

    print_step "Step 2/8: Interactive Configuration"

    cd "$ROOT_DIR"

    if [ -f ".env" ]; then
        print_warning "Configuration files already exist"
        echo -e "${YELLOW}Overwrite existing configuration? [y/N]:${NC}"
        read -r -n 1 REPLY
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            save_state "wizard"
            return 0
        fi
    fi

    if node scripts/setup-wizard.js; then
        save_state "wizard"
        print_success "Configuration completed"
    else
        print_error "Setup wizard failed"
        exit 1
    fi
}

# Step 3: Install Dependencies
step_install_dependencies() {
    if is_completed "dependencies"; then
        print_warning "Dependencies already installed, skipping..."
        return 0
    fi

    print_step "Step 3/8: Installing Node.js Dependencies"

    cd "$ROOT_DIR"

    print_info "Running npm install (this may take a few minutes)..."

    if npm install --production; then
        save_state "dependencies"
        print_success "Dependencies installed"
    else
        print_error "npm install failed"
        exit 1
    fi
}

# Step 4: Setup Database
step_setup_database() {
    if is_completed "database"; then
        print_warning "Database already configured, skipping..."
        return 0
    fi

    print_step "Step 4/8: Setting Up Database"

    if bash "$SCRIPT_DIR/setup-database.sh"; then
        save_state "database"
        print_success "Database configured"
    else
        print_error "Database setup failed"
        exit 1
    fi
}

# Step 5: Setup Nginx
step_setup_nginx() {
    if is_completed "nginx"; then
        print_warning "Nginx already configured, skipping..."
        return 0
    fi

    print_step "Step 5/8: Setting Up Nginx"

    # Get domain from .env
    DOMAIN=""
    if [ -f "$ROOT_DIR/.env" ]; then
        DOMAIN=$(grep -E "^DOMAIN=" "$ROOT_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "")
    fi

    if bash "$SCRIPT_DIR/setup-nginx.sh" "$DOMAIN"; then
        save_state "nginx"
        print_success "Nginx configured"
    else
        print_error "Nginx setup failed"
        exit 1
    fi
}

# Step 6: Setup SSL (optional)
step_setup_ssl() {
    if is_completed "ssl"; then
        print_warning "SSL already configured, skipping..."
        return 0
    fi

    print_step "Step 6/8: Setting Up SSL Certificate"

    echo -e "${YELLOW}Do you want to setup SSL certificate now? [Y/n]:${NC}"
    read -r -n 1 REPLY
    echo

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        # Get domain from .env
        DOMAIN=""
        if [ -f "$ROOT_DIR/.env" ]; then
            DOMAIN=$(grep -E "^DOMAIN=" "$ROOT_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "")
        fi

        if bash "$SCRIPT_DIR/setup-ssl.sh" "$DOMAIN"; then
            save_state "ssl"
            print_success "SSL certificate configured"
        else
            print_error "SSL setup failed"
            echo -e "${YELLOW}You can run SSL setup later: sudo bash scripts/setup-ssl.sh${NC}"
        fi
    else
        save_state "ssl"
        print_info "SSL setup skipped (can be done later)"
    fi
}

# Step 7: Setup Systemd
step_setup_systemd() {
    if is_completed "systemd"; then
        print_warning "Systemd service already configured, skipping..."
        return 0
    fi

    print_step "Step 7/8: Setting Up Systemd Service"

    if SERVICE_NAME="$SERVICE_NAME" bash "$SCRIPT_DIR/setup-systemd.sh"; then
        save_state "systemd"
        print_success "Systemd service configured and started"
    else
        print_error "Systemd setup failed"
        exit 1
    fi
}

# Step 8: Final Verification
step_verify_installation() {
    print_step "Step 8/8: Verifying Installation"

    # Check service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Redirect service is running"
    else
        print_warning "Service is not running"
    fi

    # Check nginx
    if systemctl is-active --quiet nginx; then
        print_success "Nginx is running"
    else
        print_warning "Nginx is not running"
    fi

    # Test health endpoint
    sleep 2
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT:-3077}/health" | grep -q "200"; then
        print_success "Health check passed"
    else
        print_warning "Health check failed (service may still be starting)"
    fi

    save_state "verified"
}

# Print final summary
print_summary() {
    echo -e "\n${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║                  ✓ Installation Complete!                     ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    # Load domain from .env
    DOMAIN=""
    if [ -f "$ROOT_DIR/.env" ]; then
        DOMAIN=$(grep -E "^DOMAIN=" "$ROOT_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "localhost")
        API_TOKEN=$(grep -E "^API_TOKEN=" "$ROOT_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "")
    fi

    echo -e "${BOLD}Your Universal Redirect Service is now running!${NC}\n"

    echo -e "${BOLD}Service URLs:${NC}"
    if is_completed "ssl"; then
        echo "  Production: ${GREEN}https://$DOMAIN${NC}"
    else
        echo "  Production: ${YELLOW}http://$DOMAIN${NC}"
    fi
    echo "  Health:     ${GREEN}http://localhost:${PORT:-3077}/health${NC}"
    echo "  API Stats:  ${GREEN}http://localhost:${PORT:-3077}/api/stats${NC}"
    echo ""

    echo -e "${BOLD}API Token (save this for n8n):${NC}"
    echo "  ${CYAN}$API_TOKEN${NC}"
    echo ""

    echo -e "${BOLD}Service Management:${NC}"
    echo "  Status:  ${YELLOW}sudo systemctl status $SERVICE_NAME${NC}"
    echo "  Logs:    ${YELLOW}sudo journalctl -u $SERVICE_NAME -f${NC}"
    echo "  Restart: ${YELLOW}sudo systemctl restart $SERVICE_NAME${NC}"
    echo ""

    echo -e "${BOLD}Configuration Files:${NC}"
    echo "  Environment: ${CYAN}$ROOT_DIR/.env${NC}"
    echo "  Sites:       ${CYAN}$ROOT_DIR/config/sites.json${NC}"
    echo "  UTM Sources: ${CYAN}$ROOT_DIR/config/utm-sources.json${NC}"
    echo ""

    echo -e "${BOLD}Next Steps:${NC}"
    echo "  1. Test a redirect: ${YELLOW}curl -I http://$DOMAIN/yoursite/123${NC}"
    echo "  2. Setup n8n integration using API token above"
    echo "  3. Monitor logs: ${YELLOW}sudo journalctl -u $SERVICE_NAME -f${NC}"
    echo ""

    if ! is_completed "ssl"; then
        echo -e "${YELLOW}Note: SSL is not configured. Run: sudo bash scripts/setup-ssl.sh${NC}"
        echo ""
    fi

    echo -e "${BOLD}Documentation:${NC}"
    echo "  README:        ${CYAN}$ROOT_DIR/README.md${NC}"
    echo "  Configuration: ${CYAN}$ROOT_DIR/docs/CONFIGURATION.md${NC}"
    echo "  API Docs:      ${CYAN}$ROOT_DIR/docs/API.md${NC}"
    echo ""

    echo -e "${GREEN}Installation log saved to: $INSTALL_STATE_FILE${NC}"
    echo ""
}

# Cleanup on error
cleanup_on_error() {
    echo -e "\n${RED}${BOLD}Installation failed!${NC}"
    echo -e "${YELLOW}Check the logs above for errors${NC}"
    echo -e "${YELLOW}Installation state saved to: $INSTALL_STATE_FILE${NC}"
    echo -e "${YELLOW}You can re-run this script to continue from where it failed${NC}\n"
    exit 1
}

###############################################################################
# Main Installation Flow
###############################################################################

main() {
    # Trap errors
    trap cleanup_on_error ERR

    # Print header
    print_header

    # Check root
    check_root

    # Check installation directory
    check_installation_directory

    # Show disclaimer
    echo -e "${BOLD}This script will install and configure:${NC}"
    echo "  • Universal Redirect Service"
    echo "  • Database (MySQL/MariaDB)"
    echo "  • Nginx reverse proxy"
    echo "  • SSL certificate (Let's Encrypt)"
    echo "  • Systemd service for auto-start"
    echo ""

    echo -e "${YELLOW}Continue with installation? [y/N]:${NC}"
    read -r -n 1 REPLY
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi

    # Run installation steps
    step_check_requirements
    step_setup_wizard
    step_install_dependencies
    step_setup_database
    step_setup_nginx
    step_setup_ssl
    step_setup_systemd
    step_verify_installation

    # Print summary
    print_summary

    # Success
    echo -e "${GREEN}${BOLD}✓ All done! Your redirect service is ready to use.${NC}\n"
}

# Run main function
main "$@"
