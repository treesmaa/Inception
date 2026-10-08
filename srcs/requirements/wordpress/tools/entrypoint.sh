#!/bin/bash

set -eu

cd /var/www/html

# Check required environment variables
: "${MARIADB_HOST:?MARIADB_HOST must be set}"
: "${MARIADB_DATABASE:?MARIADB_DATABASE must be set}"
: "${MARIADB_USER:?MARIADB_USER must be set}"

: "${WP_URL:?WP_URL must be set}"
: "${WP_TITLE:?WP_TITLE must be set}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER must be set}"
: "${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL must be set}"

: "${WP_USER:?WP_USER must be set}"
: "${WP_USER_EMAIL:?WP_USER_EMAIL must be set}"

MARIADB_PASSWORD=$(cat /run/secrets/mdb_password) || exit 1
WP_ADMIN_PASS=$(cat /run/secrets/wp_admin_password) || exit 1
WP_USER_PWD=$(cat /run/secrets/wp_user_password) || exit 1

# Wait until MariaDB is reachable
echo "Waiting for MariaDB..."

while ! mariadb \
    -h"${MARIADB_HOST}" \
    -u"${MARIADB_USER}" \
    -p"${MARIADB_PASSWORD}" \
    -e "SELECT 1;" \
    >/dev/null 2>&1
do
    sleep 1
done

echo "MariaDB is ready"


# Download WordPress core if files don't exist
if [ ! -f /var/www/html/wp-load.php ]; then
    echo "Downloading WordPress..."

    wp core download --allow-root
fi


# Create wp-config.php if it doesn't exist
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Configuring WordPress..."

    wp config create \
        --allow-root \
        --dbname="${MARIADB_DATABASE}" \
        --dbuser="${MARIADB_USER}" \
        --dbpass="${MARIADB_PASSWORD}" \
        --dbhost="${MARIADB_HOST}"
fi


# Install WordPress if it isn't already installed in the database
if ! wp core is-installed --allow-root; then
    echo "Installing WordPress..."

    wp core install \
        --allow-root \
        --url="${WP_URL}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASS}" \
        --admin_email="${WP_ADMIN_EMAIL}"
fi

if ! wp user get "${WP_USER}" --allow-root >/dev/null 2>&1; then
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
    --user_pass="${WP_USER_PWD}" \
    --role=author \
    --allow-root
fi

echo "Checking title..."
TITLE="$(wp option get blogname --allow-root)"

if [ "$TITLE" != "$WP_TITLE" ]; then
    echo "Correcting title..."
    wp option update blogname "$WP_TITLE" --allow-root
fi

# PHP-FPM runs as www-data
chown -R www-data:www-data /var/www/html

# Replace shell with Dockerfile CMD:
# php-fpm8.2 -F
exec "$@"