#!/bin/bash

set -e

# Handle Postgres credentials
if [ -v POSTGRES_PASSWORD_FILE ]; then
    POSTGRES_PASSWORD="$(< $POSTGRES_PASSWORD_FILE)"
fi

# PostgreSQL connection parameters
: ${POSTGRES_HOST:=${POSTGRES_HOST:='db'}}
: ${POSTGRES_PORT:=${POSTGRES_PORT:=5432}}
: ${POSTGRES_USER:=${POSTGRES_USER:='odoo'}}
: ${POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" | cut -d " " -f3 | sed 's/["\n\r]//g')
    fi
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}

check_config "db_host" "$POSTGRES_HOST"
check_config "db_port" "$POSTGRES_PORT"
check_config "db_user" "$POSTGRES_USER"
check_config "db_password" "$POSTGRES_PASSWORD"

# Set default SERVER_NAME if not provided
: ${SERVER_NAME:=${SERVER_NAME:='localhost'}}

# Substitute environment variables in Nginx config
envsubst '${PORT} ${SERVER_NAME}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Validate the Nginx configuration
nginx -t || exit 1

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
echo "Connection details: Host=$POSTGRES_HOST, Port=$POSTGRES_PORT, User=$POSTGRES_USER"
for i in {1..12}; do
    if wait-for-psql.py --db_host="$POSTGRES_HOST" --db_port="$POSTGRES_PORT" --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD" --timeout=30; then
        echo "PostgreSQL is ready"
        break
    fi
    echo "Attempt $i: PostgreSQL is not ready yet. Retrying in 5 seconds..."
    sleep 5
done

if [ $i -eq 12 ]; then
    echo "PostgreSQL connection failed after 12 attempts (5 minutes). Exiting."
    echo "Last connection attempt details:"
    wait-for-psql.py --db_host="$POSTGRES_HOST" --db_port="$POSTGRES_PORT" --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD" --timeout=30
    exit 1
fi

# Print database connection details
echo "Database connection successful:"
echo "Host: $POSTGRES_HOST"
echo "Port: $POSTGRES_PORT"
echo "User: $POSTGRES_USER"
echo "Database: ${POSTGRES_DB:-postgres}"

# Start Odoo
echo "Starting Odoo..."
echo "Current PATH: $PATH"
echo "Searching for Odoo executable:"
which odoo || echo "odoo not found in PATH"

if [ -f /usr/bin/odoo ]; then
    echo "Using '/usr/bin/odoo'"
    python3 /usr/bin/odoo "$@" "${DB_ARGS[@]}" &
elif [ -f /usr/local/bin/odoo ]; then
    echo "Using '/usr/local/bin/odoo'"
    python3 /usr/local/bin/odoo "$@" "${DB_ARGS[@]}" &
elif command -v odoo &> /dev/null; then
    echo "Using 'odoo' command"
    python3 $(which odoo) "$@" "${DB_ARGS[@]}" &
else
    echo "Error: Odoo executable not found"
    echo "Contents of /usr/bin:"
    ls -l /usr/bin | grep odoo
    echo "Contents of /usr/local/bin:"
    ls -l /usr/local/bin | grep odoo
    exit 1
fi

# Wait for Odoo to start
echo "Waiting for Odoo to start..."
sleep 10

# Start Nginx
echo "Starting Nginx..."
nginx

# Keep the container running
wait
