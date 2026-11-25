# Developer documentation

This document explains how to set up, run, and maintain the Inception development environment.

## Prerequisites

Install the following on the host machine:

- Docker Engine and the Docker Compose plugin
- GNU Make
- Git

Verify the installation before continuing:

```bash
docker --version
docker compose version
make --version
```

The Docker daemon must be running, and the current user must either have permission to use Docker or run Docker commands with the appropriate privileges. The current configuration uses Debian Bookworm as the base image for all three custom images.

The site is configured for `teesmaa.42.fr`, and the Compose file binds host port `443`. Make sure port 443 is available. Add the domain to the host file if it does not already resolve locally:

```text
127.0.0.1 teesmaa.42.fr
```

On Linux, edit `/etc/hosts` with administrator privileges.

## Initial setup

### 1. Clone the repository

If the project is not already available locally, clone it and enter its root directory:

```bash
git clone https://github.com/treesmaa/Inception.git
cd Inception
```

All Makefile commands in this document must be run from this directory.

### 2. Configure the local hostname

The host entry described above must be configured before opening the site.

### 3. Create configuration and secret files

Run these commands from the repository root:

```bash
cp srcs/.env.example srcs/.env
cp -r secrets_example secrets
```

Edit `srcs/.env` and replace the placeholder values in `secrets/` with local values. Do not commit real passwords or expose them in logs.

The environment file contains non-secret settings used by Compose and the entrypoint scripts:

| Variable | Purpose |
| --- | --- |
| `MARIADB_DATABASE` | WordPress database name |
| `MARIADB_USER` | WordPress database user |
| `MARIADB_HOST` | Compose service name used by WordPress |
| `WP_URL` | Full HTTPS URL used during WordPress installation |
| `WP_TITLE` | Initial site title |
| `WP_ADMIN_USER`, `WP_ADMIN_EMAIL` | Initial administrator account |
| `WP_USER`, `WP_USER_EMAIL` | Initial author account |

`DOMAIN_NAME` is present in the template, but the current Compose file does not substitute it into the NGINX configuration. The active hostname is currently hardcoded as `teesmaa.42.fr` in `nginx.conf`, the NGINX Dockerfile, and `WP_URL`. If you use another domain, update all of those locations as well as `/etc/hosts`.

The `MARIADB_ROOT_PASSWORD_FILE` and `MARIADB_PASSWORD_FILE` entries in the template are not used by the current Compose file. Database passwords are supplied through the Docker secrets described below.

The password file contents are:

| File | Contents |
| --- | --- |
| `secrets/db_root_password.txt` | MariaDB root password |
| `secrets/db_password.txt` | MariaDB application-user password |
| `secrets/credentials.txt` | Lines in the form `WP_ADMIN_PWD=<password>` and `WP_USER_PWD=<password>` |

The Compose file mounts the database passwords at `/run/secrets/`. The container entrypoint scripts read them from there; they are intentionally not passed as normal environment variables. The database and WordPress entrypoints use these secrets on every container start, but database creation and the initial WordPress installation only happen when the persistent data is empty.

The `secrets_example/` directory and `srcs/.env.example` are templates only. Keep the generated `secrets/` directory and `srcs/.env` local.

### Configuration files

The project has two kinds of configuration: files that a developer must create or edit before the first launch, and service configuration files that are already included in the repository.

#### Files to create or edit

- **`srcs/.env`** contains non-secret values passed to WordPress and MariaDB by Compose. At minimum, check the domain, database name, database user, WordPress URL, site title, and WordPress user details. `WP_URL` should match the hostname configured in `/etc/hosts`.
- **`secrets/db_root_password.txt`** contains the MariaDB root password as a single line.
- **`secrets/db_password.txt`** contains the password for the MariaDB user configured by `MARIADB_USER`.
- **`secrets/credentials.txt`** contains the two WordPress passwords in this format:

  ```text
  WP_ADMIN_PWD=choose-an-admin-password
  WP_USER_PWD=choose-a-user-password
  ```

The passwords in the secret files must not be empty. Keep these files private; they are excluded from version control by `.gitignore`.

#### Service configuration already provided

These files are copied into the images or loaded by Compose. They normally do not need to be changed for a first launch:

| File | Role |
| --- | --- |
| `srcs/docker-compose.yml` | Defines the services, network, secrets, ports, and persistent volumes |
| `srcs/requirements/nginx/conf/nginx.conf` | Configures HTTPS on port 443 and forwards PHP requests to `wordpress:9000` |
| `srcs/requirements/wordpress/conf/www.conf` | Configures PHP-FPM to listen on port 9000 as `www-data` |
| `srcs/requirements/mariadb/conf/70-inception.cnf` | Configures MariaDB's data directory and network binding |
| `srcs/requirements/*/Dockerfile` | Defines how each custom service image is built |
| `srcs/requirements/*/tools/entrypoint.sh` | Performs first-start initialization for MariaDB and WordPress |

The Compose file reads `srcs/.env` and mounts the files in `secrets/` into the containers. It does not read the example files automatically, which is why the local files must be created before running `make`.

### 4. Build and start

Once the hostname, environment file, and secrets are ready, continue to [Build and launch](#build-and-launch). The `make up` target creates the persistent-data directories automatically before it builds and starts the containers.

## Project structure

```text
.
├── Makefile
├── DEV_DOC.md
├── README.md
├── USER_DOC.md
├── secrets/                 # local credentials; do not commit
├── srcs/
│   ├── .env
│   ├── docker-compose.yml
│   └── requirements/
│       ├── nginx/            # HTTPS reverse proxy
│       ├── wordpress/        # WordPress and PHP-FPM
│       └── mariadb/          # database server
└── secrets_example/
```

## Architecture

Docker Compose builds and runs three services on the `inception` bridge network:

- **NGINX** is the only service published to the host. It listens on HTTPS port `443`, serves the site, and forwards PHP requests to WordPress over FastCGI.
- **WordPress** runs PHP-FPM on the internal port `9000`. Its entrypoint waits for MariaDB, downloads WordPress on first start, and performs the initial installation.
- **MariaDB** stores the WordPress database. Its entrypoint initializes the database and creates the configured application user on first start.

All images are built locally from the Dockerfiles in `srcs/requirements/`. The NGINX image creates a self-signed certificate, so browsers will display a certificate warning when the site is opened locally.

## Build and launch

The recommended command is:

```bash
make
```

This creates the host data directories, builds the images, and starts the stack in the background. On the first start, MariaDB initializes its system tables and WordPress downloads and installs its core files. This can take a little longer than subsequent starts.

The Makefile expands to the following Compose command:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml up --detach --build
```

To build and start without Make, use that command directly. Compose creates the `inception` bridge network and starts NGINX, WordPress, and MariaDB. Only NGINX publishes a host port: `443:443`.

Check the result with:

```bash
docker ps
make logs
```

Open [https://teesmaa.42.fr](https://teesmaa.42.fr) after the services have finished initializing.

## Container lifecycle commands

Run these targets from the repository root:

| Command | Action |
| --- | --- |
| `make up` | Build images if needed and start the containers |
| `make stop` | Stop containers without removing them |
| `make start` | Start stopped containers |
| `make restart` | Restart running containers |
| `make down` | Stop and remove containers and the Compose network |
| `make rebuild` | Rebuild without cache and recreate the containers |
| `make logs` | Follow logs from all services |
| `make clean` | Remove containers, network, and service images |

Useful direct Compose commands are:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs -f wordpress
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec wordpress bash
```

Replace `wordpress` with `nginx` or `mariadb` when needed.

The equivalent direct Compose commands for common operations are:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml up --detach --build
docker compose --env-file srcs/.env -f srcs/docker-compose.yml stop
docker compose --env-file srcs/.env -f srcs/docker-compose.yml start
docker compose --env-file srcs/.env -f srcs/docker-compose.yml restart
docker compose --env-file srcs/.env -f srcs/docker-compose.yml down
```

Use `docker compose --env-file srcs/.env -f srcs/docker-compose.yml config` to render and validate the final configuration before starting it. Use the same full Compose prefix followed by `logs -f <service>` to follow one service instead of the whole stack:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs -f wordpress
```

## Accessing MariaDB

MariaDB is not published to the host. Access it by running the MariaDB client inside the already-running `mariadb` container.

Open an interactive session as root:

```bash
docker exec -it mariadb mariadb -u root -p
```

When prompted, enter the password stored in `secrets/db_root_password.txt`. To connect as the WordPress application user, use:

```bash
docker exec -it mariadb mariadb -u wpuser -p wordpress
```

Enter the password stored in `secrets/db_password.txt`. Replace `wpuser` and `wordpress` if `MARIADB_USER` or `MARIADB_DATABASE` have been changed in `srcs/.env`.

Useful checks inside the MariaDB client include:

```sql
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
SELECT ID, user_login FROM wp_users;
```

The database name and table prefix may differ if the configuration changes. Do not publish port `3306` just to access the database, and avoid placing passwords directly in shell history or documentation. Exit the MariaDB client with `exit` or `Ctrl+D`.

## Persistent data

The Compose file defines two named volumes backed by host directories:

| Volume | Host path | Container path | Contents |
| --- | --- | --- | --- |
| `wordpress` | `/home/teesmaa/data/wordpress` | `/var/www/html` | WordPress core, uploads, configuration, and plugins |
| `mariadb` | `/home/teesmaa/data/mariadb` | `/var/lib/mysql` | MariaDB database files |

The `make setup` target creates these directories. The Docker volume objects are named `wordpress` and `mariadb`, but their data is stored in the listed host directories through bind-backed local volumes.

Data survives container recreation: `make stop`, `make start`, `make restart`, `make down`, `make rebuild`, and `make clean` do not delete the host directories. A new container mounts the same data and continues using the existing WordPress installation and MariaDB database. Changing a password in `secrets/` does not change an already-created database user or WordPress account.

Inspect the volumes with:

```bash
docker volume ls
docker volume inspect wordpress mariadb
```

To remove the Docker volume objects after stopping the stack, use:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml down --volumes
```

Because the volumes are bind-backed, this removes the Docker volume references but does not delete the host directories. Removing `/home/teesmaa/data/wordpress` or `/home/teesmaa/data/mariadb` permanently deletes the corresponding data, so back up those directories before doing so.

## Making changes

After changing a Dockerfile, Compose configuration, or build-time configuration, rebuild the affected images:

```bash
make rebuild
```

Changes to WordPress data are stored in `/home/teesmaa/data/wordpress`. Changes to database data are stored in `/home/teesmaa/data/mariadb`. Changes to environment variables or secrets may only affect first-time initialization; existing WordPress users and database contents are not automatically recreated.

Before committing, verify the configuration and inspect the generated service status:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml config
docker ps -a
```

## Troubleshooting

- **The site cannot be reached:** check `docker ps`, confirm that `teesmaa.42.fr` points to `127.0.0.1`, and review `make logs`.
- **502 Bad Gateway:** check the WordPress container and confirm that PHP-FPM is listening on port `9000`.
- **Database connection errors:** check the MariaDB and WordPress logs, then verify the database values in `srcs/.env` and the password files in `secrets/`.
- **The browser shows a certificate warning:** this is expected because the NGINX certificate is self-signed.
- **A changed password has no effect:** credentials are used during initialization. Change existing WordPress passwords from the WordPress administration panel and preserve the existing database if it contains data.
