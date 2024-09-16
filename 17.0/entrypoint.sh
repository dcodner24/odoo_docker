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

# Function to update ADDONS_PATH environment variable
update_addons_path() {
    local custom_modules_path="/mnt/custom-modules"
    local extra_addons_path="/mnt/extra-addons"
    local default_addons_path="/usr/lib/python3/dist-packages/odoo/addons"
    
    ADDONS_PATH="${default_addons_path},${extra_addons_path}"

    # Check if custom modules directory exists and is not empty
    if [ -d "$custom_modules_path" ] && [ "$(ls -A $custom_modules_path)" ]; then
        echo "Custom modules found. Adding to addons path."
        ADDONS_PATH="${custom_modules_path},${ADDONS_PATH}"
    else
        echo "No custom modules found or directory is empty."
    fi

    export ADDONS_PATH
    echo "Updated ADDONS_PATH: $ADDONS_PATH"
}

# Update addons path
update_addons_path

# Substitute environment variables in Nginx config
echo "Updating Nginx configuration..."
envsubst '${PORT} ${SERVER_NAME}' < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp
mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf

# Check Nginx configuration
echo "Checking Nginx configuration..."
nginx -t || exit 1

# Start Nginx
echo "Starting Nginx..."
nginx

# Switch to odoo user
echo "Switching to odoo user..."
exec gosu odoo bash << EOF

# Start Odoo
echo "Starting Odoo..."
ODOO_CMD="/usr/bin/odoo"
if [ ! -f "$ODOO_CMD" ]; then
    echo "Error: Odoo executable not found at $ODOO_CMD"
    exit 1
fi

# Use envsubst to replace ${ADDONS_PATH} in odoo.conf
echo "Updating Odoo configuration..."
envsubst '${ADDONS_PATH}' < /odoo.conf > /odoo.conf.tmp
mv /odoo.conf.tmp /odoo.conf
echo "Updated Odoo configuration:"
cat /odoo.conf

$ODOO_CMD -c /odoo.conf "$@" "${DB_ARGS[@]}" &
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

# Start Nginx
echo "Starting Nginx..."
nginx

echo "All services started. Monitoring Odoo process..."
# Keep the container running
wait $ODOO_PID

echo "Odoo process has ended. Exiting."
exit 1