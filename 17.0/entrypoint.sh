#!/bin/bash

set -e

if [ -v POSTGRES_PASSWORD_FILE ]; then
    PASSWORD="$(< $POSTGRES_PASSWORD_FILE)"
fi

# set the postgres database host, port, user, and password according to the environment
# and pass them as arguments to the odoo process if not present in the config file
: ${POSTGRES_HOST:=${POSTGRES_DB_PORT_5432_TCP_ADDR:='db'}}
: ${POSTGRES_PORT:=${POSTGRES_DB_PORT_5432_TCP_PORT:=5432}}
: ${POSTGRES_USER:=${POSTGRES_DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${POSTGRES_PASSWORD:=${POSTGRES_DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$POSTGRES_HOST"
check_config "db_port" "$POSTGRES_PORT"
check_config "db_user" "$POSTGRES_USER"
check_config "db_password" "$POSTGRES_PASSWORD"

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            wait-for-psql.py ${DB_ARGS[@]} --timeout=30
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        wait-for-psql.py ${DB_ARGS[@]} --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1
