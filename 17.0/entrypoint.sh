#!/bin/bash

set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting entrypoint script..."

# Log environment variables (be careful not to log sensitive information)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Current environment variables:"
env | grep -v PASSWORD | sort

# Set database connection details from environment variables
DB_HOST="${POSTGRES_HOST:-db}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_USER="${POSTGRES_USER:-odoo}"
DB_PASSWORD="${POSTGRES_PASSWORD:-odoo}"
DB_NAME="${POSTGRES_DB:-postgres}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Database connection details:"
echo "Host: $DB_HOST"
echo "Port: $DB_PORT"
echo "User: $DB_USER"
echo "Database: $DB_NAME"
echo "Password: [REDACTED]"

# Wait for PostgreSQL
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for PostgreSQL..."
python3 /usr/local/bin/wait-for-psql.py \
    --db_host "$DB_HOST" \
    --db_port "$DB_PORT" \
    --db_user "$DB_USER" \
    --db_password "$DB_PASSWORD" \
    --db_name "$DB_NAME" \
    --timeout 30

if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to connect to PostgreSQL. Exiting."
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] PostgreSQL is ready."

# Find the Odoo executable
if command -v odoo &> /dev/null; then
    ODOO_CMD=$(command -v odoo)
elif [ -x "/usr/bin/odoo" ]; then
    ODOO_CMD="/usr/bin/odoo"
elif [ -x "/usr/local/bin/odoo" ]; then
    ODOO_CMD="/usr/local/bin/odoo"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Odoo executable not found"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Odoo executable found at: $ODOO_CMD"

# Set up DB_ARGS for Odoo
DB_ARGS=(
    "--db_host" "$DB_HOST"
    "--db_port" "$DB_PORT"
    "--db_user" "$DB_USER"
    "--db_password" "$DB_PASSWORD"
    "--database" "$DB_NAME"
)

echo "[$(date '+%Y-%m-%d %H:%M:%S')] DB_ARGS: ${DB_ARGS[@]}"

# Start Odoo
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Odoo..."
exec "$ODOO_CMD" "$@" "${DB_ARGS[@]}"