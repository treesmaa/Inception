#!/bin/bash

set -euo pipefail

DATADIR="/var/lib/mysql"
INIT_FILE="/tmp/init.sql"

# ---- Validate required variables ----
: "${MARIADB_DATABASE:?MARIADB_DATABASE must be set}"
: "${MARIADB_USER:?MARIADB_USER must be set}"

MARIADB_PASSWORD=$(cat /run/secrets/mdb_password) || exit 1
MARIADB_ROOT_PASSWORD=$(cat /run/secrets/mdb_root_password) || exit 1

# ---- Runtime directories ----
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

mkdir -p "$DATADIR"
chown -R mysql:mysql "$DATADIR"

# ---- Initialize MariaDB system tables if necessary ----
if [ ! -d "$DATADIR/mysql" ]; then
    echo "Initializing MariaDB system tables"

    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR"
fi

# ---- Prepare application initialization SQL ----
cat > "$INIT_FILE" <<EOF
CREATE DATABASE IF NOT EXISTS \`$MARIADB_DATABASE\`;

ALTER USER 'root'@'%' 
    IDENTIFIED BY '$MARIADB_ROOT_PASSWORD';

CREATE USER IF NOT EXISTS '$MARIADB_USER'@'%'
    IDENTIFIED BY '$MARIADB_PASSWORD';

GRANT ALL PRIVILEGES
    ON \`$MARIADB_DATABASE\`.*
    TO '$MARIADB_USER'@'%';
EOF

# MariaDB should be able to read the file
chown mysql:mysql "$INIT_FILE"
chmod 600 "$INIT_FILE"

# ---- Start MariaDB normally in foreground ----
exec mariadbd --init-file="$INIT_FILE"