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

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
if ! wait-for-psql.py --db_host="$POSTGRES_HOST" --db_port="$POSTGRES_PORT" --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD" --timeout=60; then
    echo "PostgreSQL is not available. Exiting."
    exit 1
fi

echo "PostgreSQL is ready"

# Start Odoo
echo "Starting Odoo..."
ODOO_CMD="/usr/bin/odoo"
if [ ! -f "$ODOO_CMD" ]; then
    echo "Error: Odoo executable not found at $ODOO_CMD"
    exit 1
fi

$ODOO_CMD "$@" "${DB_ARGS[@]}" &
ODOO_PID=$!

# Wait for Odoo to become responsive
echo "Waiting for Odoo to start..."
for i in {1..30}; do
    if curl -s http://localhost:8069 > /dev/null; then
        echo "Odoo is up and running"
        break
    fi
    if ! ps -p $ODOO_PID > /dev/null; then
        echo "Odoo process has died. Exiting."
        exit 1
    fi
    echo "Waiting for Odoo to become responsive... (attempt $i)"
    sleep 2
done

if [ $i -eq 30 ]; then
    echo "Odoo did not start within 60 seconds. Exiting."
    exit 1
fi

# Substitute environment variables in Nginx config
envsubst '${PORT} ${SERVER_NAME}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Validate the Nginx configuration
nginx -t || exit 1

# Start Nginx
echo "Starting Nginx..."
nginx

# Keep the container running
wait $ODOO_PID
