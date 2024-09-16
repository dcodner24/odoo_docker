#!/bin/bash

set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting entrypoint script..."

# Set database connection details from environment variables
DB_HOST="${POSTGRES_HOST:-db}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_USER="${POSTGRES_USER:-odoo}"
DB_PASSWORD="${POSTGRES_PASSWORD:-odoo}"
DB_NAME="${POSTGRES_DB:-postgres}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Database connection details:"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Host: $DB_HOST"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Port: $DB_PORT"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] User: $DB_USER"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Database: $DB_NAME"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Password: [REDACTED]"

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

# Update ADDONS_PATH
update_addons_path() {
    local custom_modules_path="/mnt/custom-modules"
    local extra_addons_path="/mnt/extra-addons"
    local default_addons_path="/usr/lib/python3/dist-packages/odoo/addons"
    
    ADDONS_PATH="${default_addons_path},${extra_addons_path}"
    
    if [ -d "$custom_modules_path" ] && [ "$(ls -A $custom_modules_path)" ]; then
        echo "Custom modules found. Adding to addons path."
        ADDONS_PATH="${custom_modules_path},${ADDONS_PATH}"
    fi
    
    export ADDONS_PATH
    echo "Updated ADDONS_PATH: $ADDONS_PATH"
}

update_addons_path

# Run as root
# Update Nginx configuration
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating Nginx configuration..."
if [ -f /etc/nginx/nginx.conf ]; then
    envsubst '${PORT} ${SERVER_NAME}' < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp
    mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Nginx configuration updated successfully."
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: /etc/nginx/nginx.conf not found."
    exit 1
fi

# Ensure Nginx can write to its log files
touch /var/log/nginx/access.log /var/log/nginx/error.log
chown odoo:odoo /var/log/nginx/access.log /var/log/nginx/error.log

# Start Nginx
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Nginx..."
nginx

# Give odoo user access to the configuration file
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ensuring odoo user has access to the configuration file..."
if [ -f /etc/odoo/odoo.conf ]; then
    chown odoo:odoo /etc/odoo/odoo.conf
    chmod 644 /etc/odoo/odoo.conf
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions updated for /etc/odoo/odoo.conf"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: /etc/odoo/odoo.conf not found"
    exit 1
fi

# Switch to odoo user
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Switching to odoo user..."
exec gosu odoo bash << EOF
# Set a full PATH to ensure all directories are included
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\$PATH"

# Start Odoo
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Odoo..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Current PATH: \$PATH"

# Try to find the Odoo executable
ODOO_CMD=\$(which odoo || true)
if [ -z "\$ODOO_CMD" ] && [ -x "/usr/bin/odoo" ]; then
    ODOO_CMD="/usr/bin/odoo"
fi

if [ -z "\$ODOO_CMD" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Odoo executable not found in PATH"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Searching for Odoo executable..."
    find / -name odoo -type f 2>/dev/null || echo "No 'odoo' executable found"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking permissions of /usr/bin/odoo:"
    ls -l /usr/bin/odoo
    exit 1
fi

# Start Odoo server
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing Odoo command..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DB_ARGS: ${DB_ARGS[@]}"
exec $ODOO_CMD -c /etc/odoo/odoo.conf "$@" "${DB_ARGS[@]}"
EOF
