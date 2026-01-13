#!/bin/bash

###############################################################################
# Universal Redirect Service - Update Script
# Updates the service to the latest version from GitHub with automatic rollback
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

# Configuration
GITHUB_REPO="genzoai/redirect-service"
BACKUP_DIR="$ROOT_DIR/../redirect-service-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"
SERVICE_NAME="redirect-service"
HEALTH_ENDPOINT="http://localhost:${PORT:-3002}/health"

# Flags
SKIP_BACKUP=false
FORCE_UPDATE=false
TARGET_VERSION=""

###############################################################################
# Functions
###############################################################################

print_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║      Universal Redirect Service - Update Manager              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
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

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --force)
                FORCE_UPDATE=true
                shift
                ;;
            --version)
                TARGET_VERSION="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help
show_help() {
    echo "Usage: sudo bash scripts/update.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-backup    Skip backup creation"
    echo "  --force          Force update even if already on latest version"
    echo "  --version VER    Update to specific version (e.g., v1.2.0)"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo bash scripts/update.sh"
    echo "  sudo bash scripts/update.sh --version v1.2.0"
    echo "  sudo bash scripts/update.sh --skip-backup --force"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Get current version
get_current_version() {
    if [ -f "$ROOT_DIR/package.json" ]; then
        CURRENT_VERSION=$(grep '"version"' "$ROOT_DIR/package.json" | head -n 1 | cut -d'"' -f4)
        print_info "Current version: $CURRENT_VERSION"
    else
        CURRENT_VERSION="unknown"
        print_warning "Cannot determine current version"
    fi
}

# Get latest version from GitHub
get_latest_version() {
    print_step "Step 1/9: Checking for Updates"

    if [ -n "$TARGET_VERSION" ]; then
        LATEST_VERSION="$TARGET_VERSION"
        print_info "Target version: $LATEST_VERSION"
    else
        print_info "Fetching latest release from GitHub..."

        LATEST_VERSION=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)

        if [ -z "$LATEST_VERSION" ]; then
            print_error "Failed to fetch latest version from GitHub"
            print_info "Check internet connection or GitHub repository"
            exit 1
        fi

        print_success "Latest version: $LATEST_VERSION"
    fi

    # Compare versions
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && [ "$FORCE_UPDATE" = false ]; then
        print_success "Already on latest version ($CURRENT_VERSION)"
        echo -e "${YELLOW}Use --force to reinstall current version${NC}"
        exit 0
    fi
}

# Create backup
create_backup() {
    if [ "$SKIP_BACKUP" = true ]; then
        print_warning "Skipping backup (--skip-backup flag)"
        return 0
    fi

    print_step "Step 2/9: Creating Backup"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    print_info "Backing up to: $BACKUP_PATH"

    # Backup application files
    cp -r "$ROOT_DIR" "$BACKUP_PATH"

    # Remove unnecessary files from backup
    rm -rf "$BACKUP_PATH/node_modules"
    rm -rf "$BACKUP_PATH/logs"
    rm -rf "$BACKUP_PATH/.git"

    print_success "Backup created: $BACKUP_PATH"

    # Keep only last 5 backups
    BACKUP_COUNT=$(ls -1d "$BACKUP_DIR"/backup_* 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 5 ]; then
        print_info "Cleaning up old backups (keeping last 5)..."
        ls -1dt "$BACKUP_DIR"/backup_* | tail -n +6 | xargs rm -rf
    fi
}

# Stop service
stop_service() {
    print_step "Step 3/9: Stopping Service"

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        print_success "Service stopped"
    else
        print_warning "Service was not running"
    fi
}

# Download new version
download_version() {
    print_step "Step 4/9: Downloading New Version"

    DOWNLOAD_URL="https://github.com/$GITHUB_REPO/archive/refs/tags/$LATEST_VERSION.tar.gz"
    TMP_DIR="/tmp/redirect-service-update-$TIMESTAMP"

    mkdir -p "$TMP_DIR"

    print_info "Downloading from: $DOWNLOAD_URL"

    if curl -L "$DOWNLOAD_URL" -o "$TMP_DIR/release.tar.gz"; then
        print_success "Downloaded release archive"
    else
        print_error "Failed to download release"
        exit 1
    fi

    # Extract archive
    print_info "Extracting archive..."
    tar -xzf "$TMP_DIR/release.tar.gz" -C "$TMP_DIR"

    # Find extracted directory
    EXTRACTED_DIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "redirect-service-*" | head -n 1)

    if [ -z "$EXTRACTED_DIR" ]; then
        print_error "Failed to find extracted directory"
        exit 1
    fi

    print_success "Extracted to: $EXTRACTED_DIR"
}

# Update files
update_files() {
    print_step "Step 5/9: Updating Files"

    # Preserve configuration files
    print_info "Preserving configuration files..."
    cp "$ROOT_DIR/.env" "$TMP_DIR/.env.backup" 2>/dev/null || true
    cp "$ROOT_DIR/config/sites.json" "$TMP_DIR/sites.json.backup" 2>/dev/null || true
    cp "$ROOT_DIR/config/utm-sources.json" "$TMP_DIR/utm-sources.json.backup" 2>/dev/null || true

    # Remove old files (except config and data)
    print_info "Removing old application files..."
    find "$ROOT_DIR" -mindepth 1 -maxdepth 1 ! -name 'config' ! -name 'logs' ! -name '.env' ! -name 'node_modules' -exec rm -rf {} +

    # Copy new files
    print_info "Installing new files..."
    cp -r "$EXTRACTED_DIR"/* "$ROOT_DIR/"

    # Restore configuration files
    print_info "Restoring configuration files..."
    cp "$TMP_DIR/.env.backup" "$ROOT_DIR/.env" 2>/dev/null || true
    cp "$TMP_DIR/sites.json.backup" "$ROOT_DIR/config/sites.json" 2>/dev/null || true
    cp "$TMP_DIR/utm-sources.json.backup" "$ROOT_DIR/config/utm-sources.json" 2>/dev/null || true

    # Set correct permissions
    chown -R $(stat -c '%U:%G' "$ROOT_DIR" 2>/dev/null || stat -f '%Su:%Sg' "$ROOT_DIR") "$ROOT_DIR"

    print_success "Files updated to version $LATEST_VERSION"
}

# Update dependencies
update_dependencies() {
    print_step "Step 6/9: Updating Dependencies"

    cd "$ROOT_DIR"

    print_info "Running npm install..."

    if npm install --production; then
        print_success "Dependencies updated"
    else
        print_error "Failed to update dependencies"
        print_warning "Attempting rollback..."
        rollback
        exit 1
    fi
}

# Run database migrations
run_migrations() {
    print_step "Step 7/9: Running Database Migrations"

    if [ -f "$ROOT_DIR/scripts/migrate.sh" ]; then
        if bash "$ROOT_DIR/scripts/migrate.sh"; then
            print_success "Migrations completed"
        else
            print_error "Migration failed"
            print_warning "Attempting rollback..."
            rollback
            exit 1
        fi
    else
        print_warning "No migration script found, skipping..."
    fi
}

# Start service
start_service() {
    print_step "Step 8/9: Starting Service"

    systemctl start "$SERVICE_NAME"
    print_info "Service started, waiting for initialization..."
    sleep 5
}

# Health check
health_check() {
    print_step "Step 9/9: Health Check"

    print_info "Testing service health..."

    # Try health check multiple times
    RETRIES=3
    for i in $(seq 1 $RETRIES); do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_ENDPOINT" 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" = "200" ]; then
            print_success "Health check passed (HTTP $HTTP_CODE)"
            return 0
        fi

        if [ $i -lt $RETRIES ]; then
            print_warning "Health check failed (attempt $i/$RETRIES), retrying..."
            sleep 3
        fi
    done

    print_error "Health check failed after $RETRIES attempts"
    print_warning "Attempting rollback..."
    rollback
    exit 1
}

# Rollback to previous version
rollback() {
    echo -e "\n${RED}${BOLD}Performing rollback...${NC}\n"

    if [ "$SKIP_BACKUP" = true ]; then
        print_error "Cannot rollback: backup was skipped"
        return 1
    fi

    if [ ! -d "$BACKUP_PATH" ]; then
        print_error "Backup not found: $BACKUP_PATH"
        return 1
    fi

    # Stop service
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true

    # Restore from backup
    print_info "Restoring from backup..."
    rm -rf "$ROOT_DIR"
    cp -r "$BACKUP_PATH" "$ROOT_DIR"

    # Reinstall dependencies
    print_info "Reinstalling dependencies..."
    cd "$ROOT_DIR"
    npm install --production

    # Restart service
    print_info "Restarting service..."
    systemctl start "$SERVICE_NAME"

    sleep 3

    # Verify rollback
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_ENDPOINT" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Rollback successful - service restored to version $CURRENT_VERSION"
    else
        print_error "Rollback failed - manual intervention required"
        print_info "Backup location: $BACKUP_PATH"
    fi
}

# Cleanup
cleanup() {
    print_info "Cleaning up temporary files..."
    rm -rf "$TMP_DIR" 2>/dev/null || true
}

# Print summary
print_summary() {
    echo -e "\n${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                  ✓ Update Complete!                           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    echo -e "${BOLD}Update Summary:${NC}"
    echo "  Previous version: ${YELLOW}$CURRENT_VERSION${NC}"
    echo "  Current version:  ${GREEN}$LATEST_VERSION${NC}"
    echo "  Backup location:  $BACKUP_PATH"
    echo ""

    echo -e "${BOLD}Service Status:${NC}"
    systemctl status "$SERVICE_NAME" --no-pager -l | head -n 10
    echo ""

    echo -e "${BOLD}Useful Commands:${NC}"
    echo "  View logs:    ${YELLOW}sudo journalctl -u $SERVICE_NAME -f${NC}"
    echo "  Check status: ${YELLOW}sudo systemctl status $SERVICE_NAME${NC}"
    echo "  Restart:      ${YELLOW}sudo systemctl restart $SERVICE_NAME${NC}"
    echo ""

    if [ "$SKIP_BACKUP" = false ]; then
        echo -e "${BOLD}Rollback (if needed):${NC}"
        echo "  ${YELLOW}sudo bash scripts/rollback.sh $BACKUP_PATH${NC}"
        echo ""
    fi
}

###############################################################################
# Main
###############################################################################

main() {
    # Parse arguments
    parse_args "$@"

    # Print header
    print_header

    # Check root
    check_root

    # Get versions
    get_current_version
    get_latest_version

    # Confirm update
    echo -e "${YELLOW}Update from $CURRENT_VERSION to $LATEST_VERSION?${NC}"
    echo -e "${YELLOW}Continue? [y/N]:${NC}"
    read -r -n 1 REPLY
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Update cancelled"
        exit 0
    fi

    # Run update steps
    create_backup
    stop_service
    download_version
    update_files
    update_dependencies
    run_migrations
    start_service
    health_check

    # Cleanup
    cleanup

    # Print summary
    print_summary

    echo -e "${GREEN}${BOLD}✓ Service successfully updated to $LATEST_VERSION${NC}\n"
}

# Trap errors
trap cleanup ERR

# Run main
main "$@"
