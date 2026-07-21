#!/bin/bash
# Nominatim Docker Database Setup Script
# This script checks and creates required database users for Nominatim
# when using an external PostgreSQL database (e.g., Docker).
#
# Usage: ./utils/setup-docker-db.sh [admin_user] [admin_password] [host] [port]
#
# Examples:
#   ./utils/setup-docker-db.sh postgres dnmp123456 localhost 5432
#   PGPASSWORD=dnmp123456 ./utils/setup-docker-db.sh postgres localhost 5432

set -e

# Default values
ADMIN_USER="${1:-postgres}"
ADMIN_PASSWORD="${2:-}"
HOST="${3:-localhost}"
PORT="${4:-5432}"
DB_NAME="nominatim"
IMPORT_USER="nominatim_import"
IMPORT_PASSWORD="nominatim123"
WEB_USER="nominatim_web"
WEB_PASSWORD="nominatim123"

# If password not provided as argument, try from environment
if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD="${PGPASSWORD:-}"
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    echo "Error: Admin password required."
    echo "Provide it as the second argument or set PGPASSWORD environment variable."
    echo "Usage: $0 [admin_user] [admin_password] [host] [port]"
    exit 1
fi

export PGPASSWORD="$ADMIN_PASSWORD"

echo "=========================================="
echo "Nominatim Docker Database Setup"
echo "=========================================="
echo "Admin User: $ADMIN_USER"
echo "Host: $HOST"
echo "Port: $PORT"
echo "Database: $DB_NAME"
echo "Import User: $IMPORT_USER"
echo "Web User: $WEB_USER"
echo "=========================================="

# Test connection
echo ""
echo "Testing connection to PostgreSQL..."
if ! psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "Error: Cannot connect to PostgreSQL at $HOST:$PORT as $ADMIN_USER"
    echo "Please check your connection settings."
    exit 1
fi
echo "Connection successful!"

# Check and create database
echo ""
echo "Checking database '$DB_NAME'..."
if psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME';" | grep -q 1; then
    echo "Database '$DB_NAME' already exists."
    echo "Note: If you need a fresh database, run:"
    echo "  PGPASSWORD=$ADMIN_PASSWORD psql -h $HOST -U $ADMIN_USER -c \"DROP DATABASE IF EXISTS $DB_NAME;\""
else
    echo "Creating database '$DB_NAME'..."
    createdb -h "$HOST" -p "$PORT" -U "$ADMIN_USER" "$DB_NAME"
    echo "Database '$DB_NAME' created."
fi

# Check and create import user (requires SUPERUSER for extension installation)
echo ""
echo "Checking import user '$IMPORT_USER'..."
if psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$IMPORT_USER';" | grep -q 1; then
    echo "User '$IMPORT_USER' already exists."
    # Ensure superuser privilege (required for PostGIS extension installation)
    psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -c "ALTER USER $IMPORT_USER WITH SUPERUSER;"
else
    echo "Creating user '$IMPORT_USER' with SUPERUSER privilege..."
    psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -c "CREATE USER $IMPORT_USER WITH PASSWORD '$IMPORT_PASSWORD' CREATEDB SUPERUSER;"
    echo "User '$IMPORT_USER' created."
fi

# Check and create web user
echo ""
echo "Checking web user '$WEB_USER'..."
if psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$WEB_USER';" | grep -q 1; then
    echo "User '$WEB_USER' already exists."
else
    echo "Creating user '$WEB_USER'..."
    psql -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -c "CREATE USER $WEB_USER WITH PASSWORD '$WEB_PASSWORD';"
    echo "User '$WEB_USER' created."
fi

# Skip grant permissions - import user has SUPERUSER so it will handle this
echo ""
echo "Note: Import user has SUPERUSER privileges, so manual grants are not needed."
echo "The import process will set up proper permissions during database creation."

echo ""
echo "=========================================="
echo "Database setup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Create/update .env file in your project directory:"
echo ""
echo "   NOMINATIM_DATABASE_DSN=\"pgsql:dbname=$DB_NAME;host=$HOST;port=$PORT;user=$IMPORT_USER;password=$IMPORT_PASSWORD\""
echo "   NOMINATIM_DATABASE_WEBUSER=\"$WEB_USER\""
echo "   NOMINATIM_TOKENIZER=\"icu\""
echo "   NOMINATIM_IMPORT_STYLE=\"extratags\""
echo ""
echo "2. Run import:"
echo "   nominatim import --osm-file <your-osm-file>"
echo "=========================================="

# Unset password
unset PGPASSWORD