#!/bin/bash

set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting entrypoint script..."

# set the postgres database host, port, user and password according to the environment
# and pass them as arguments to the odoo process if not present in the config file
: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Database connection details:"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Host: $HOST"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Port: $PORT"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] User: $USER"
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
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] DB_ARGS: ${DB_ARGS[@]}"

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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Odoo executable found at \$ODOO_CMD"

# Use envsubst to replace \${ADDONS_PATH} in odoo.conf
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating Odoo configuration..."
envsubst '\${ADDONS_PATH}' < /etc/odoo/odoo.conf > /etc/odoo/odoo.conf.tmp
mv /etc/odoo/odoo.conf.tmp /etc/odoo/odoo.conf
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updated Odoo configuration:"
cat /etc/odoo/odoo.conf

exec \$ODOO_CMD -c /etc/odoo/odoo.conf "\$@" "\${DB_ARGS[@]}"
EOF