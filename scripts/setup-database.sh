#!/bin/bash

###############################################################################
# Universal Redirect Service - Database Setup Script
# Creates database, user, and runs migrations
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

# Load environment variables
if [ -f "$ROOT_DIR/.env" ]; then
    export $(cat "$ROOT_DIR/.env" | grep -v '^#' | xargs)
else
    echo -e "${RED}${BOLD}Error: .env file not found${NC}"
    echo -e "${YELLOW}Please run setup wizard first: node scripts/setup-wizard.js${NC}"
    exit 1
fi

###############################################################################
# Functions
###############################################################################

print_header() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║   Universal Redirect Service - Database Setup         ║"
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

# Check if MySQL/MariaDB is running
check_mysql() {
    print_step "Step 1: Checking MySQL/MariaDB"

    if ! command -v mysql &> /dev/null; then
        print_error "MySQL client not found"
        exit 1
    fi

    # Try to connect
    if mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" -e "SELECT 1;" &> /dev/null; then
        print_success "MySQL/MariaDB is running and accessible"
    else
        print_error "Cannot connect to MySQL/MariaDB"
        echo -e "${YELLOW}Please check:"
        echo "  - MySQL/MariaDB is running"
        echo "  - DB_ROOT_PASSWORD in .env is correct"
        echo "  - DB_HOST is correct (${DB_HOST})${NC}"
        exit 1
    fi
}

# Create database
create_database() {
    print_step "Step 2: Creating Database"

    # Check if database exists
    DB_EXISTS=$(mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" \
        -sse "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$DB_NAME';" 2>/dev/null || echo "0")

    if [ "$DB_EXISTS" -eq "1" ]; then
        print_warning "Database '$DB_NAME' already exists!"
        echo ""

        # Show database info
        echo "Database information:"
        mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" <<EOF 2>/dev/null || true
SELECT
    TABLE_SCHEMA as 'Database',
    COUNT(*) as 'Tables',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as 'Size (MB)'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = '$DB_NAME'
GROUP BY TABLE_SCHEMA;
EOF
        echo ""

        echo -e "${RED}${BOLD}⚠️  WARNING: Dropping the database will DELETE ALL DATA!${NC}"
        echo ""
        echo "Options:"
        echo "  1) Keep existing database and continue (recommended)"
        echo "  2) Drop and recreate database (${RED}DESTROYS ALL DATA!${NC})"
        echo "  3) Exit installation"
        echo ""

        while true; do
            read -p "Choose option [1-3]: " choice
            case $choice in
                1)
                    print_info "Using existing database '$DB_NAME'"
                    return 0
                    ;;
                2)
                    echo ""
                    echo -e "${RED}${BOLD}FINAL WARNING: This will DELETE ALL DATA in database '$DB_NAME'!${NC}"
                    echo -e "${YELLOW}To confirm, type the database name: ${BOLD}$DB_NAME${NC}"
                    read -r CONFIRM_DB_NAME

                    if [ "$CONFIRM_DB_NAME" = "$DB_NAME" ]; then
                        print_warning "Dropping database '$DB_NAME'..."
                        mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" \
                            -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
                        print_success "Database dropped"
                        break
                    else
                        print_error "Database name doesn't match. Aborting drop."
                        print_info "Using existing database"
                        return 0
                    fi
                    ;;
                3)
                    print_info "Installation cancelled by user"
                    exit 0
                    ;;
                *)
                    echo "Invalid option, please choose 1-3"
                    ;;
            esac
        done
    else
        print_info "Database '$DB_NAME' does not exist, will create"
    fi

    # Create database
    mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" \
        -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

    print_success "Database '$DB_NAME' created"
}

# Create user and grant permissions
create_user() {
    print_step "Step 3: Creating Database User"

    # Check if user exists
    USER_EXISTS=$(mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" \
        -sse "SELECT COUNT(*) FROM mysql.user WHERE user='$DB_USER';" 2>/dev/null || echo "0")

    if [ "$USER_EXISTS" -gt "0" ]; then
        print_warning "User '$DB_USER' already exists!"
        echo ""

        # Show user info
        echo "User information:"
        mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" <<EOF 2>/dev/null || true
SELECT
    user as 'Username',
    host as 'Host',
    COUNT(DISTINCT Db) as 'Databases with Access'
FROM mysql.db
WHERE user = '$DB_USER'
GROUP BY user, host;
EOF
        echo ""

        echo -e "${YELLOW}${BOLD}WARNING:${NC} Updating this user will:"
        echo "  - Change the password (may break other applications)"
        echo "  - Grant access to database '$DB_NAME'"
        echo ""
        echo "Options:"
        echo "  1) Update user password and permissions (may affect other apps)"
        echo "  2) Keep existing user unchanged (use current password)"
        echo "  3) Create different user"
        echo "  4) Exit installation"
        echo ""

        while true; do
            read -p "Choose option [1-4]: " choice
            case $choice in
                1)
                    # Update password and permissions
                    print_warning "Updating user '$DB_USER'..."
                    mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" <<EOF
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
                    print_success "User '$DB_USER' updated (password changed!)"
                    echo -e "${YELLOW}Note: If other applications use this user, you must update their passwords too!${NC}"
                    return 0
                    ;;
                2)
                    # Keep existing user, just grant permissions
                    print_info "Keeping existing user, granting access to database..."
                    mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" <<EOF
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
                    print_success "Granted permissions to existing user (password unchanged)"
                    echo -e "${YELLOW}Note: Make sure DB_PASSWORD in .env matches the CURRENT password!${NC}"
                    return 0
                    ;;
                3)
                    echo -e "${YELLOW}Enter new username:${NC}"
                    read -r NEW_USER
                    DB_USER="$NEW_USER"

                    # Check if new user exists
                    USER_EXISTS=$(mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" \
                        -sse "SELECT COUNT(*) FROM mysql.user WHERE user='$DB_USER';" 2>/dev/null || echo "0")

                    if [ "$USER_EXISTS" -gt "0" ]; then
                        print_error "User '$DB_USER' also exists. Try again."
                    else
                        print_info "Will create new user: $DB_USER"
                        # Continue to create new user
                        break
                    fi
                    ;;
                4)
                    print_info "Installation cancelled"
                    exit 0
                    ;;
                *)
                    echo "Invalid option, please choose 1-4"
                    ;;
            esac
        done
    fi

    # Create new user (if doesn't exist or chose option 3)
    if [ "$USER_EXISTS" -eq "0" ]; then
        print_info "Creating user '$DB_USER'..."
        mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASSWORD" <<EOF
CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
        print_success "User '$DB_USER' created"
    fi
}

# Run SQL migrations
run_migrations() {
    print_step "Step 4: Running Migrations"

    if [ ! -d "$SQL_DIR" ]; then
        print_error "SQL directory not found: $SQL_DIR"
        exit 1
    fi

    # Find and sort SQL files
    SQL_FILES=$(find "$SQL_DIR" -name "*.sql" -type f | sort)

    if [ -z "$SQL_FILES" ]; then
        print_warning "No migration files found"
        return 0
    fi

    # Run each migration
    for sql_file in $SQL_FILES; then
        filename=$(basename "$sql_file")
        echo -n "  Running $filename... "

        if mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$sql_file" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}⚠ (may have already been applied)${NC}"
        fi
    done

    print_success "Migrations completed"
}

# Verify setup
verify_setup() {
    print_step "Step 5: Verifying Setup"

    # Check if tables exist
    TABLES=$(mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
        -sse "SHOW TABLES;" 2>/dev/null | wc -l)

    if [ "$TABLES" -gt "0" ]; then
        print_success "Database setup verified ($TABLES tables created)"

        # List tables
        echo -e "\n${BOLD}Tables:${NC}"
        mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
            -e "SHOW TABLES;" | tail -n +2 | while read table; do
            echo "  - $table"
        done
    else
        print_error "No tables found. Migration may have failed."
        exit 1
    fi
}

# Print summary
print_summary() {
    echo -e "\n${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║              ✓ Database Setup Complete!               ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${BOLD}Database Configuration:${NC}"
    echo "  Host:     $DB_HOST:${DB_PORT:-3306}"
    echo "  Database: $DB_NAME"
    echo "  User:     $DB_USER"
    echo ""

    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Test the connection: ${YELLOW}node -e 'require(\"./src/config/database.js\")'${NC}"
    echo "  2. Start the service: ${YELLOW}npm start${NC}"
    echo ""
}

###############################################################################
# Main
###############################################################################

main() {
    print_header

    # Check required variables
    if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_ROOT_PASSWORD" ]; then
        print_error "Missing required environment variables"
        echo -e "${YELLOW}Required: DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, DB_ROOT_PASSWORD${NC}"
        exit 1
    fi

    # Run setup steps
    check_mysql
    create_database
    create_user
    run_migrations
    verify_setup

    # Print summary
    print_summary
}

# Run main function
main "$@"
