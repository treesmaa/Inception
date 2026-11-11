#!/bin/bash

set -euo pipefail

DATADIR="/var/lib/mysql"
INIT_SOCKET="/run/mysqld/init.sock"

# Validate required variables
: "${MARIADB_DATABASE:?MARIADB_DATABASE must be set}"
: "${MARIADB_USER:?MARIADB_USER must be set}"

MARIADB_PASSWORD=$(cat /run/secrets/mdb_password) || exit 1
MARIADB_ROOT_PASSWORD=$(cat /run/secrets/mdb_root_password) || exit 1

# Runtime directories
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

mkdir -p "$DATADIR"
chown -R mysql:mysql "$DATADIR"

# Initialize MariaDB system tables if necessary
if [ ! -d "$DATADIR/mysql" ]; then
    echo "Initializing MariaDB system tables"

    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR"
fi

# Start MariaDB temporarily for application initialization
# Use a private Unix socket and disable TCP networking while initialization runs.
rm -f "$INIT_SOCKET"
mariadbd \
    --skip-networking \
    --socket="$INIT_SOCKET" \
    --pid-file=/run/mysqld/init.pid &
INIT_PID=$!

cleanup() {
    if kill -0 "$INIT_PID" 2>/dev/null; then
        kill "$INIT_PID" 2>/dev/null || true
        wait "$INIT_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

until mariadb-admin --socket="$INIT_SOCKET" ping >/dev/null 2>&1; do
    if ! kill -0 "$INIT_PID" 2>/dev/null; then
        echo "MariaDB initialization server stopped unexpectedly" >&2
        exit 1
    fi
    sleep 1
done

# Feed SQL through stdin instead of writing a password-containing SQL file.
# The local root account uses socket authentication during initialization.
mariadb --protocol=socket --socket="$INIT_SOCKET" -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`$MARIADB_DATABASE\`;

CREATE USER IF NOT EXISTS 'root'@'%'
    IDENTIFIED BY '$MARIADB_ROOT_PASSWORD';

ALTER USER 'root'@'%'
    IDENTIFIED BY '$MARIADB_ROOT_PASSWORD';

CREATE USER IF NOT EXISTS '$MARIADB_USER'@'%'
    IDENTIFIED BY '$MARIADB_PASSWORD';

GRANT ALL PRIVILEGES
    ON \`$MARIADB_DATABASE\`.*
    TO '$MARIADB_USER'@'%';
SQL

# Stop the temporary server before starting the normal foreground process.
mariadb-admin --protocol=socket --socket="$INIT_SOCKET" -uroot shutdown
wait "$INIT_PID"
trap - EXIT

# ---- Start MariaDB normally in foreground ----
exec mariadbd