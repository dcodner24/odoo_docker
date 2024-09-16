#!/bin/bash

set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting entrypoint script..."

# Log environment variables (be careful not to log sensitive information)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Current environment variables:"
env | grep -v PASSWORD | sort

# Use the provided PostgreSQL environment variables
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

# Set up DB_ARGS
DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" | cut -d " " -f3 | sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$DB_HOST"
check_config "db_port" "$DB_PORT"
check_config "db_user" "$DB_USER"
check_config "db_password" "$DB_PASSWORD"
check_config "database" "$DB_NAME"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] DB_ARGS: ${DB_ARGS[@]}"

# Wait for PostgreSQL
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for PostgreSQL..."
python3 /usr/local/bin/wait-for-psql.py --db_host $DB_HOST --db_port $DB_PORT --db_user $DB_USER --db_password $DB_PASSWORD --timeout 30

if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to connect to PostgreSQL. Exiting."
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] PostgreSQL is ready."

# Test database connection
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Testing database connection..."
if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "\l" > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Successfully connected to PostgreSQL and listed databases."
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to list databases. Connection might be failing."
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "\l"
    exit 1
fi

# ... (rest of your script)

# Start Odoo
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Odoo..."
exec odoo "$@" "${DB_ARGS[@]}"