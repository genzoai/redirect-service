#!/bin/bash

###############################################################################
# Universal Redirect Service - Systemd Setup Script
# Creates systemd service for automatic startup
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

# Service name
SERVICE_NAME="redirect-service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

###############################################################################
# Functions
###############################################################################

print_header() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║   Universal Redirect Service - Systemd Setup          ║"
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
        print_success ".env file found"
    else
        print_error ".env file not found"
        echo -e "${YELLOW}Please run setup wizard first: node scripts/setup-wizard.js${NC}"
        exit 1
    fi
}

# Check for existing service
check_existing_service() {
    print_step "Checking for Existing Service"

    # Check if service file exists
    if [ -f "$SERVICE_FILE" ]; then
        print_warning "Systemd service '$SERVICE_NAME' already exists"
        echo ""

        # Show current service status
        echo "Current service status:"
        systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null || echo "  Service exists but not loaded"
        echo ""

        # Show service file location
        echo "Service file: $SERVICE_FILE"
        echo ""

        echo "Options:"
        echo "  1) Overwrite and reconfigure service (recommended for updates)"
        echo "  2) Keep existing service and exit"
        echo "  3) Show current service configuration"
        echo ""

        while true; do
            read -p "Choose option [1-3]: " choice
            case $choice in
                1)
                    print_warning "Will overwrite existing service"

                    # Stop service if running
                    if systemctl is-active --quiet "$SERVICE_NAME"; then
                        print_info "Stopping current service..."
                        systemctl stop "$SERVICE_NAME"
                    fi

                    return 0
                    ;;
                2)
                    print_info "Keeping existing service, exiting..."
                    exit 0
                    ;;
                3)
                    echo ""
                    echo "=== Current Service Configuration ==="
                    cat "$SERVICE_FILE" 2>/dev/null || echo "Cannot read service file"
                    echo "====================================="
                    echo ""
                    ;;
                *)
                    echo "Invalid option, please choose 1-3"
                    ;;
            esac
        done
    else
        print_success "No existing service found"
    fi
}

# Get service user
get_service_user() {
    print_step "Step 1: Service User Configuration"

    # Check if running from a specific directory
    INSTALL_DIR="$ROOT_DIR"

    # Determine user
    if [ -n "$SUDO_USER" ]; then
        SERVICE_USER="$SUDO_USER"
        print_info "Will run service as user: $SERVICE_USER (current sudo user)"
    else
        echo -e "${YELLOW}Enter the user to run the service (default: www-data):${NC}"
        read -r INPUT_USER
        SERVICE_USER="${INPUT_USER:-www-data}"
    fi

    # Validate user exists
    if ! id "$SERVICE_USER" &>/dev/null; then
        print_error "User '$SERVICE_USER' does not exist"
        echo ""
        echo "Options:"
        echo "  1) Create user '$SERVICE_USER' (system user, no login)"
        echo "  2) Enter different username"
        echo "  3) Exit installation"
        echo ""

        while true; do
            read -p "Choose option [1-3]: " choice
            case $choice in
                1)
                    # Create system user
                    print_info "Creating system user '$SERVICE_USER'..."
                    useradd -r -s /bin/false -m -d "/var/lib/$SERVICE_USER" "$SERVICE_USER"
                    print_success "Created user: $SERVICE_USER"
                    break
                    ;;
                2)
                    echo -e "${YELLOW}Enter username:${NC}"
                    read -r INPUT_USER
                    SERVICE_USER="$INPUT_USER"

                    if ! id "$SERVICE_USER" &>/dev/null; then
                        print_error "User '$SERVICE_USER' does not exist either"
                    else
                        print_success "User '$SERVICE_USER' exists"
                        break
                    fi
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
        print_success "User '$SERVICE_USER' exists"
    fi

    # Check user permissions on directory
    print_info "Checking directory permissions..."

    # Ensure user has access to install directory
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    print_success "Updated ownership of $INSTALL_DIR"

    # Verify .env is readable
    if [ -f "$INSTALL_DIR/.env" ]; then
        if ! sudo -u "$SERVICE_USER" test -r "$INSTALL_DIR/.env"; then
            print_warning "User '$SERVICE_USER' cannot read .env file"
            chmod 640 "$INSTALL_DIR/.env"
            chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/.env"
            print_success "Fixed .env permissions (640)"
        else
            print_success "User can read .env file"
        fi
    fi

    # Verify node_modules is accessible
    if [ -d "$INSTALL_DIR/node_modules" ]; then
        if ! sudo -u "$SERVICE_USER" test -r "$INSTALL_DIR/node_modules"; then
            print_warning "User '$SERVICE_USER' cannot access node_modules"
            chmod -R 755 "$INSTALL_DIR/node_modules"
            print_success "Fixed node_modules permissions"
        else
            print_success "User can access node_modules"
        fi
    fi

    echo ""
    print_success "Service user configuration complete: $SERVICE_USER"
}

# Create systemd service file
create_service_file() {
    print_step "Step 2: Creating Systemd Service File"

    # Get Node.js path
    NODE_PATH=$(which node)
    if [ -z "$NODE_PATH" ]; then
        print_error "Node.js not found in PATH"
        exit 1
    fi

    # Create service file
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Universal Redirect Service - UTM tracking and OG preview
Documentation=https://github.com/genzoai/redirect-service
After=network.target mysql.service mariadb.service
Wants=mysql.service

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$ROOT_DIR
ExecStart=$NODE_PATH $ROOT_DIR/src/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

# Environment
Environment=NODE_ENV=production
EnvironmentFile=$ROOT_DIR/.env

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

# Resource limits
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    print_success "Service file created: $SERVICE_FILE"
}

# Reload systemd daemon
reload_systemd() {
    print_step "Step 3: Reloading Systemd Daemon"

    systemctl daemon-reload
    print_success "Systemd daemon reloaded"
}

# Enable service
enable_service() {
    print_step "Step 4: Enabling Service"

    systemctl enable "$SERVICE_NAME"
    print_success "Service enabled (will start on boot)"
}

# Start service
start_service() {
    print_step "Step 5: Starting Service"

    # Check if service is already running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_warning "Service is already running"
        echo -e "${YELLOW}Restart service? [y/N]:${NC}"
        read -r -n 1 REPLY
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            systemctl restart "$SERVICE_NAME"
            print_success "Service restarted"
        fi
    else
        systemctl start "$SERVICE_NAME"
        print_success "Service started"
    fi

    # Wait a moment for service to start
    sleep 2
}

# Verify service
verify_service() {
    print_step "Step 6: Verifying Service"

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service is running"

        # Show status
        echo ""
        systemctl status "$SERVICE_NAME" --no-pager -l | head -n 15
    else
        print_error "Service failed to start"

        # Show logs
        echo -e "\n${BOLD}Recent logs:${NC}"
        journalctl -u "$SERVICE_NAME" -n 20 --no-pager

        exit 1
    fi
}

# Print summary
print_summary() {
    echo -e "\n${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║            ✓ Systemd Setup Complete!                  ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${BOLD}Service Configuration:${NC}"
    echo "  Name:         $SERVICE_NAME"
    echo "  User:         $SERVICE_USER"
    echo "  Directory:    $ROOT_DIR"
    echo "  Service file: $SERVICE_FILE"
    echo ""

    echo -e "${BOLD}Service Management Commands:${NC}"
    echo "  Start:    ${YELLOW}sudo systemctl start $SERVICE_NAME${NC}"
    echo "  Stop:     ${YELLOW}sudo systemctl stop $SERVICE_NAME${NC}"
    echo "  Restart:  ${YELLOW}sudo systemctl restart $SERVICE_NAME${NC}"
    echo "  Status:   ${YELLOW}sudo systemctl status $SERVICE_NAME${NC}"
    echo "  Logs:     ${YELLOW}sudo journalctl -u $SERVICE_NAME -f${NC}"
    echo "  Disable:  ${YELLOW}sudo systemctl disable $SERVICE_NAME${NC}"
    echo ""

    echo -e "${BOLD}Service is configured to:${NC}"
    echo "  ${GREEN}✓${NC} Start automatically on boot"
    echo "  ${GREEN}✓${NC} Restart automatically if it crashes"
    echo "  ${GREEN}✓${NC} Log to systemd journal"
    echo ""

    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Check service status: ${YELLOW}sudo systemctl status $SERVICE_NAME${NC}"
    echo "  2. View logs: ${YELLOW}sudo journalctl -u $SERVICE_NAME -f${NC}"
    echo "  3. Test the service: ${YELLOW}curl -I http://localhost:${PORT:-3077}/health${NC}"
    echo ""
}

###############################################################################
# Main
###############################################################################

main() {
    print_header

    # Check root
    check_root

    # Load environment
    load_env

    # Setup steps
    check_existing_service
    get_service_user
    create_service_file
    reload_systemd
    enable_service
    start_service
    verify_service

    # Print summary
    print_summary
}

# Run main function
main "$@"
