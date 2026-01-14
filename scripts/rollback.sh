#!/bin/bash

###############################################################################
# Universal Redirect Service - Manual Rollback Script
# Restores service from a backup
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
BACKUP_DIR="$ROOT_DIR/../redirect-service-backups"
SERVICE_NAME="${SERVICE_NAME:-redirect-service}"

###############################################################################
# Functions
###############################################################################

print_header() {
    clear
    echo -e "${BOLD}${RED}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║      Universal Redirect Service - Rollback Manager            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
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
        exit 1
    fi
}

# List available backups
list_backups() {
    echo -e "${BOLD}Available Backups:${NC}\n"

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        print_warning "No backups found in $BACKUP_DIR"
        return 1
    fi

    # List backups with details
    BACKUPS=$(ls -1dt "$BACKUP_DIR"/backup_* 2>/dev/null || true)

    if [ -z "$BACKUPS" ]; then
        print_warning "No backups found"
        return 1
    fi

    INDEX=1
    while IFS= read -r backup; do
        backup_name=$(basename "$backup")
        backup_date=$(echo "$backup_name" | sed 's/backup_//' | sed 's/_/ /g')
        backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)

        # Try to get version from backup
        version="unknown"
        if [ -f "$backup/package.json" ]; then
            version=$(grep '"version"' "$backup/package.json" | head -n 1 | cut -d'"' -f4 2>/dev/null || echo "unknown")
        fi

        echo -e "${CYAN}[$INDEX]${NC} $backup_date"
        echo "    Path:    $backup"
        echo "    Version: $version"
        echo "    Size:    $backup_size"
        echo ""

        ((INDEX++))
    done <<< "$BACKUPS"

    return 0
}

# Select backup
select_backup() {
    local backup_path="$1"

    # If backup path provided as argument, use it
    if [ -n "$backup_path" ]; then
        if [ -d "$backup_path" ]; then
            SELECTED_BACKUP="$backup_path"
            return 0
        else
            print_error "Backup not found: $backup_path"
            exit 1
        fi
    fi

    # Otherwise, show selection menu
    if ! list_backups; then
        exit 1
    fi

    echo -e "${YELLOW}Enter backup number to restore (or 'q' to quit):${NC}"
    read -r SELECTION

    if [ "$SELECTION" = "q" ] || [ "$SELECTION" = "Q" ]; then
        echo "Rollback cancelled"
        exit 0
    fi

    # Get backup by index
    BACKUPS=$(ls -1dt "$BACKUP_DIR"/backup_* 2>/dev/null)
    SELECTED_BACKUP=$(echo "$BACKUPS" | sed -n "${SELECTION}p")

    if [ -z "$SELECTED_BACKUP" ]; then
        print_error "Invalid selection"
        exit 1
    fi

    if [ ! -d "$SELECTED_BACKUP" ]; then
        print_error "Backup directory not found: $SELECTED_BACKUP"
        exit 1
    fi
}

# Confirm rollback
confirm_rollback() {
    echo -e "\n${RED}${BOLD}WARNING: This will replace the current installation!${NC}"
    echo -e "${YELLOW}Selected backup: $SELECTED_BACKUP${NC}\n"

    # Get current version
    if [ -f "$ROOT_DIR/package.json" ]; then
        CURRENT_VERSION=$(grep '"version"' "$ROOT_DIR/package.json" | head -n 1 | cut -d'"' -f4 2>/dev/null || echo "unknown")
        echo "Current version: $CURRENT_VERSION"
    fi

    # Get backup version
    if [ -f "$SELECTED_BACKUP/package.json" ]; then
        BACKUP_VERSION=$(grep '"version"' "$SELECTED_BACKUP/package.json" | head -n 1 | cut -d'"' -f4 2>/dev/null || echo "unknown")
        echo "Backup version:  $BACKUP_VERSION"
    fi

    echo ""
    echo -e "${YELLOW}Continue with rollback? [y/N]:${NC}"
    read -r -n 1 REPLY
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Rollback cancelled"
        exit 0
    fi
}

# Perform rollback
perform_rollback() {
    print_info "Starting rollback process..."

    # Step 1: Stop service
    echo -e "\n${CYAN}Step 1/5: Stopping service...${NC}"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        print_success "Service stopped"
    else
        print_warning "Service was not running"
    fi

    # Step 2: Backup current state (in case rollback fails)
    echo -e "\n${CYAN}Step 2/5: Creating safety backup...${NC}"
    SAFETY_BACKUP="$BACKUP_DIR/rollback-safety_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$SAFETY_BACKUP"
    cp -r "$ROOT_DIR" "$SAFETY_BACKUP/current"
    print_success "Safety backup created: $SAFETY_BACKUP"

    # Step 3: Remove current installation (preserve config)
    echo -e "\n${CYAN}Step 3/5: Removing current installation...${NC}"
    print_info "Preserving configuration files..."

    # Preserve config
    TMP_CONFIG="/tmp/rollback-config-$$"
    mkdir -p "$TMP_CONFIG"
    cp "$ROOT_DIR/.env" "$TMP_CONFIG/.env" 2>/dev/null || true
    cp -r "$ROOT_DIR/config" "$TMP_CONFIG/" 2>/dev/null || true
    cp -r "$ROOT_DIR/logs" "$TMP_CONFIG/" 2>/dev/null || true

    # Remove current installation
    rm -rf "$ROOT_DIR"
    print_success "Current installation removed"

    # Step 4: Restore from backup
    echo -e "\n${CYAN}Step 4/5: Restoring from backup...${NC}"
    cp -r "$SELECTED_BACKUP" "$ROOT_DIR"

    # Restore preserved config
    cp "$TMP_CONFIG/.env" "$ROOT_DIR/.env" 2>/dev/null || true
    cp -r "$TMP_CONFIG/config" "$ROOT_DIR/" 2>/dev/null || true
    cp -r "$TMP_CONFIG/logs" "$ROOT_DIR/" 2>/dev/null || true
    rm -rf "$TMP_CONFIG"

    print_success "Files restored from backup"

    # Step 5: Reinstall dependencies
    echo -e "\n${CYAN}Step 5/5: Reinstalling dependencies...${NC}"
    cd "$ROOT_DIR"

    if npm install --production; then
        print_success "Dependencies installed"
    else
        print_error "Failed to install dependencies"
        print_warning "Attempting to restore from safety backup..."

        # Restore from safety backup
        rm -rf "$ROOT_DIR"
        cp -r "$SAFETY_BACKUP/current" "$ROOT_DIR"

        print_error "Rollback failed - restored to pre-rollback state"
        exit 1
    fi

    # Step 6: Restart service
    echo -e "\n${CYAN}Starting service...${NC}"
    systemctl start "$SERVICE_NAME"

    sleep 3

    # Step 7: Verify
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service started successfully"

        # Health check
        PORT=$(grep '^PORT=' "$ROOT_DIR/.env" | cut -d'=' -f2 || echo "3077")
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/health" 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" = "200" ]; then
            print_success "Health check passed"
        else
            print_warning "Health check failed (HTTP $HTTP_CODE)"
            print_info "Service may need a moment to fully start"
        fi
    else
        print_error "Service failed to start"
        echo "Check logs: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi

    # Cleanup safety backup if successful
    rm -rf "$SAFETY_BACKUP"
}

# Print summary
print_summary() {
    echo -e "\n${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                  ✓ Rollback Complete!                         ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${BOLD}Rollback Summary:${NC}"
    echo "  Restored from: $SELECTED_BACKUP"

    if [ -f "$ROOT_DIR/package.json" ]; then
        RESTORED_VERSION=$(grep '"version"' "$ROOT_DIR/package.json" | head -n 1 | cut -d'"' -f4)
        echo "  Version:       $RESTORED_VERSION"
    fi

    echo ""

    echo -e "${BOLD}Service Status:${NC}"
    systemctl status "$SERVICE_NAME" --no-pager -l | head -n 10
    echo ""

    echo -e "${BOLD}Useful Commands:${NC}"
    echo "  View logs:    ${YELLOW}sudo journalctl -u $SERVICE_NAME -f${NC}"
    echo "  Check status: ${YELLOW}sudo systemctl status $SERVICE_NAME${NC}"
    echo "  Restart:      ${YELLOW}sudo systemctl restart $SERVICE_NAME${NC}"
    echo ""
}

###############################################################################
# Main
###############################################################################

main() {
    print_header

    # Check root
    check_root

    # Select backup to restore
    select_backup "$1"

    # Confirm rollback
    confirm_rollback

    # Perform rollback
    perform_rollback

    # Print summary
    print_summary

    echo -e "${GREEN}${BOLD}✓ Service successfully rolled back${NC}\n"
}

# Run main
main "$@"
