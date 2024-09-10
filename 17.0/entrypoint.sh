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

# Start Nginx
nginx || (echo "Nginx failed to start" && cat /var/log/nginx/error.log)

# Wait for PostgreSQL to be ready
wait-for-psql.py "${DB_ARGS[@]}" --timeout=30

# Start Odoo
exec odoo "$@" "${DB_ARGS[@]}"
