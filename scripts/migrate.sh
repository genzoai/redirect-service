#!/bin/bash

###############################################################################
# Universal Redirect Service - Database Migration Script
# Runs pending database migrations
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
SQL_DIR="$ROOT_DIR/sql"

# Migration tracking
MIGRATIONS_TABLE="schema_migrations"

###############################################################################
# Functions
###############################################################################

print_header() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║   Universal Redirect Service - Database Migrations    ║"
    echo "╚════════════════════════════════════════════════════════╝"
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

# Load environment variables
load_env() {
    if [ -f "$ROOT_DIR/.env" ]; then
        export $(cat "$ROOT_DIR/.env" | grep -v '^#' | grep -v '^$' | xargs)
        print_success "Environment loaded"
    else
        print_error ".env file not found"
        echo -e "${YELLOW}Please ensure .env exists in: $ROOT_DIR${NC}"
        exit 1
    fi
}

# Check database connection
check_database() {
    print_step "Checking Database Connection"

    if ! command -v mysql &> /dev/null; then
        print_error "MySQL client not found"
        exit 1
    fi

    # Test connection
    if mysql -h"${DB_HOST}" -P"${DB_PORT:-3306}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" -e "SELECT 1;" &> /dev/null; then
        print_success "Database connection successful"
    else
        print_error "Cannot connect to database"
        echo -e "${YELLOW}Check DB credentials in .env${NC}"
        exit 1
    fi
}

# Create migrations tracking table
create_migrations_table() {
    print_step "Initializing Migration Tracking"

    mysql -h"${DB_HOST}" -P"${DB_PORT:-3306}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" <<EOF 2>/dev/null
CREATE TABLE IF NOT EXISTS $MIGRATIONS_TABLE (
    id INT AUTO_INCREMENT PRIMARY KEY,
    migration_name VARCHAR(255) NOT NULL UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_migration_name (migration_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOF

    print_success "Migration tracking table ready"
}

# Check if migration was applied
is_migration_applied() {
    local migration_name="$1"

    COUNT=$(mysql -h"${DB_HOST}" -P"${DB_PORT:-3306}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" \
        -sse "SELECT COUNT(*) FROM $MIGRATIONS_TABLE WHERE migration_name='$migration_name';" 2>/dev/null)

    [ "$COUNT" -gt "0" ]
}

# Mark migration as applied
mark_migration_applied() {
    local migration_name="$1"

    mysql -h"${DB_HOST}" -P"${DB_PORT:-3306}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" \
        -e "INSERT INTO $MIGRATIONS_TABLE (migration_name) VALUES ('$migration_name');" 2>/dev/null
}

# Run migrations
run_migrations() {
    print_step "Running Pending Migrations"

    if [ ! -d "$SQL_DIR" ]; then
        print_warning "SQL directory not found: $SQL_DIR"
        print_info "No migrations to run"
        return 0
    fi

    # Find all SQL files
    SQL_FILES=$(find "$SQL_DIR" -name "*.sql" -type f | sort)

    if [ -z "$SQL_FILES" ]; then
        print_info "No migration files found"
        return 0
    fi

    APPLIED_COUNT=0
    SKIPPED_COUNT=0
    FAILED_COUNT=0

    # Run each migration
    while IFS= read -r sql_file; do
        filename=$(basename "$sql_file")

        # Check if already applied
        if is_migration_applied "$filename"; then
            echo -e "  ${YELLOW}⊘${NC} $filename (already applied)"
            ((SKIPPED_COUNT++))
            continue
        fi

        # Apply migration
        echo -n "  ${CYAN}▶${NC} $filename ... "

        if mysql -h"${DB_HOST}" -P"${DB_PORT:-3306}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < "$sql_file" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"

            # Mark as applied
            mark_migration_applied "$filename"
            ((APPLIED_COUNT++))
        else
            echo -e "${RED}✗${NC}"
            print_error "Migration failed: $filename"
            ((FAILED_COUNT++))

            # Ask if should continue
            echo -e "${YELLOW}Continue with remaining migrations? [y/N]:${NC}"
            read -r -n 1 REPLY
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_error "Migration process aborted"
                exit 1
            fi
        fi
    done <<< "$SQL_FILES"

    # Summary
    echo ""
    print_info "Migration Summary:"
    echo "  Applied: $APPLIED_COUNT"
    echo "  Skipped: $SKIPPED_COUNT"

    if [ $FAILED_COUNT -gt 0 ]; then
        echo "  ${RED}Failed: $FAILED_COUNT${NC}"
    fi

    if [ $APPLIED_COUNT -eq 0 ] && [ $FAILED_COUNT -eq 0 ]; then
        print_success "All migrations are up to date"
    elif [ $APPLIED_COUNT -gt 0 ] && [ $FAILED_COUNT -eq 0 ]; then
        print_success "All pending migrations applied successfully"
    elif [ $FAILED_COUNT -gt 0 ]; then
        print_error "Some migrations failed"
        exit 1
    fi
}

# Show migration status
show_migration_status() {
    print_step "Migration Status"

    # Get applied migrations
    APPLIED_MIGRATIONS=$(mysql -h"${DB_HOST}" -P"${DB_PORT:-3306}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" \
        -sse "SELECT migration_name, applied_at FROM $MIGRATIONS_TABLE ORDER BY applied_at;" 2>/dev/null)

    if [ -z "$APPLIED_MIGRATIONS" ]; then
        print_info "No migrations applied yet"
    else
        echo -e "${BOLD}Applied Migrations:${NC}"
        echo "$APPLIED_MIGRATIONS" | while IFS=$'\t' read -r name date; do
            echo "  ${GREEN}✓${NC} $name (applied: $date)"
        done
    fi

    echo ""

    # Check for pending migrations
    if [ -d "$SQL_DIR" ]; then
        SQL_FILES=$(find "$SQL_DIR" -name "*.sql" -type f | sort)

        if [ -n "$SQL_FILES" ]; then
            PENDING=false

            while IFS= read -r sql_file; do
                filename=$(basename "$sql_file")

                if ! is_migration_applied "$filename"; then
                    if [ "$PENDING" = false ]; then
                        echo -e "${BOLD}Pending Migrations:${NC}"
                        PENDING=true
                    fi
                    echo "  ${YELLOW}⊘${NC} $filename"
                fi
            done <<< "$SQL_FILES"

            if [ "$PENDING" = false ]; then
                print_success "No pending migrations"
            fi
        fi
    fi
}

# Rollback last migration (optional feature)
rollback_last() {
    print_step "Rolling Back Last Migration"

    LAST_MIGRATION=$(mysql -h"${DB_HOST}" -P"${DB_PORT:-3306}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" \
        -sse "SELECT migration_name FROM $MIGRATIONS_TABLE ORDER BY applied_at DESC LIMIT 1;" 2>/dev/null)

    if [ -z "$LAST_MIGRATION" ]; then
        print_warning "No migrations to rollback"
        return 0
    fi

    print_warning "Rolling back migration: $LAST_MIGRATION"
    echo -e "${RED}This operation cannot be undone!${NC}"
    echo -e "${YELLOW}Are you sure? [y/N]:${NC}"
    read -r -n 1 REPLY
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove from tracking table
        mysql -h"${DB_HOST}" -P"${DB_PORT:-3306}" -u"${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" \
            -e "DELETE FROM $MIGRATIONS_TABLE WHERE migration_name='$LAST_MIGRATION';" 2>/dev/null

        print_success "Migration $LAST_MIGRATION rolled back (removed from tracking)"
        print_warning "Note: Database changes were NOT reverted - manual cleanup may be required"
    else
        print_info "Rollback cancelled"
    fi
}

# Print summary
print_summary() {
    echo -e "\n${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║           ✓ Migrations Complete!                      ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

###############################################################################
# Main
###############################################################################

main() {
    # Parse command
    COMMAND="${1:-migrate}"

    case $COMMAND in
        migrate|up)
            print_header
            load_env
            check_database
            create_migrations_table
            run_migrations
            print_summary
            ;;
        status)
            print_header
            load_env
            check_database
            create_migrations_table
            show_migration_status
            ;;
        rollback)
            print_header
            load_env
            check_database
            create_migrations_table
            rollback_last
            ;;
        *)
            echo "Usage: bash scripts/migrate.sh [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  migrate, up  Run pending migrations (default)"
            echo "  status       Show migration status"
            echo "  rollback     Rollback last migration"
            echo ""
            echo "Examples:"
            echo "  bash scripts/migrate.sh"
            echo "  bash scripts/migrate.sh status"
            echo "  bash scripts/migrate.sh rollback"
            exit 1
            ;;
    esac
}

# Run main
main "$@"
