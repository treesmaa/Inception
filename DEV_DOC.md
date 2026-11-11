# Developer documentation

This file must describe how a developer can:
- Set up the environment from scratch (prerequisites, configuration files, secrets).
- Build and launch the project using the Makefile and Docker Compose.
- Use relevant commands to manage the containers and volumes.
- Identify where the project data is stored and how it persists.

## Installing Docker

### Prerequisites

To install Docker Engine on Debian, the host machine should run one of the following versions of Debian:
- Debian Trixie 13
- Debian Bookworm 12
- Debian Bullseye 11

You need sudo or root access.

Before installation, any conflicting packages need to be removed:

```json
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)
```
### Installation using ATP repository

1. Set up Docker's apt repository.

```json
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```
2. Install the Docker packages.
```json
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
After installation, verify that Docker is running:
```json
sudo systemctl status docker

#if not running, start manually
sudo systemctl start docker
```
3. Verify that the installation is successful by running the hello-world image:
```json
sudo docker run hello-world
```

This command downloads a test image and then runs it in a container. A confirmation message is printed and then the container exits.

To verify that docker and docker compose are installed:
```json
docker --version
docker compose version
```
To check if docker is enabled and running:
```json
sudo systemctl status docker
```

To start docker:
```json
sudo systemctl start docker
```
To enanable docker:
```json
sudo systemctl enable docker
```

To add user to docker group:
```json
sudo usermod -aG docker $USER
```
## Folder Structure

```text
.
├── DEV_DOC.md
├── Makefile
├── README.md
├── USER_DOC.md
└── srcs
    ├── docker-compose.yml
    └── requirements
        ├── mariadb
        │   ├── .dockerignore
        │   ├── Dockerfile
        │   ├── conf
        │   │   └── 70-inception.cnf
        │   └── tools
        │       └── entrypoint.sh
        ├── nginx
        │   ├── .dockerignore
        │   ├── Dockerfile
        │   └── conf
        │       └── nginx.conf
        └── wordpress
            ├── .dockerignore
            ├── Dockerfile
            ├── conf
            │   └── www.conf
            └── tools
                └── entrypoint.sh

11 directories, 16 files
```
## Docker Containers

This project combines three containers: NGINX, Wordpress + php-fpm and MariaDB. Each container is built from a custom image with Debian Bookworm (penultimate stable version during the completion of this project) as the base image. 

### NGINX

NGINX is the externally exposed web server and entry point of the application stack. It listens for client connections on port 443, handles TLS termination using TLSv1.2 and/or TLSv1.3, and processes incoming HTTP requests. Static resources can be served directly by NGINX, while requests for PHP scripts are forwarded to the WordPress/PHP-FPM service over the FastCGI protocol. Request handling and routing behavior are defined through the NGINX configuration.

#### Dockerfile
The NGINX container image is built based on the Dockerfile that consists of the following commands.

Get the base image:
```dockerfile
FROM debian:bookworm
```
Install the NGINX itself and OpenSSL, which is needed to implement TLS:
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*
```
Then, create a new private key and a self-signed X.509 TLS certificate. First, a directory for the key and certificate must be created. Then, `openssl req` is ran with the following options:
- `-x509` creates a self-signed certificate, rather than CSR, which would be sent to a Certificate Authority for an SSL/TLS certificate.
- `-nodes` 
- `-days [value]` number of days from today to certify the certificate for (default is 30)
- `-newkey [arg]` This option is used to generate a new private key unless -key is given. It is subsequently used as if it was given using the -key option. This option implies the -new flag to create a new certificate request or a new certificate in case -x509 is used. [rsa:]nbits generates an RSA key nbits in size. If nbits is omitted, i.e., -newkey rsa is specified, the default key size specified in the configuration file with the default_bits option is used if present, else 2048.
- `-keyout` This gives the filename to write any private key to that has been newly created or read from `-newkey`.
- `-out [filename]` Specifies the output filename to write to or standard output by default.
- `-subj [arg]` Sets subject name for new request or supersedes the subject name when processing a certificate request. The arg must be formatted as `/type0=value0/type1=value1/type2=....`

```dockerfile
RUN mkdir -p /etc/nginx/ssl/
RUN openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/inception.key \
  -out /etc/nginx/ssl/inception.crt \
  -subj "/C=AT/ST=Vienna/L=Vienna/O=42/OU=42/CN=teesmaa.42.fr/UID=teesmaa"
```
Copy the configuration file into the container's filesystem:
```dockerfile
COPY /conf/nginx.conf /etc/nginx/nginx.conf
```
Create the directory for WordPress files, change ownership to www-data (the web-server/PHP user) and change permissions.
```dockerfile
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www/html && \
    chmod 755 /var/www/html
```
Document the port through which connections are possible. This itself does not expose the port. The port must be publically accessible through configuration and docker compose. This should be port 443, which is the standard port used for encrypted HTTPS web traffic secured by SSL/TLS protocols.
```dockerfile
EXPOSE 443
```
Run nginx in the foreground. Normally, NGINX may detach itself from the terminal and run in the background as a daemon. In a traditional server, that is normal.
In Docker, that is usually undesirable because Docker expects the container's main process, PID 1, to keep running. If the main process exits, Docker considers the container finished.
 - `daemon off;` disables daemon mode
 - `-g` sets a global NGINX directive
```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```
#### Configuration

The way NGINX and its modules work is determined in the configuration file. Debian's packaged NGINX uses `/etc/nginx/nginx.conf` as its normal main configuration file. As we saw, we write our own `nginx.conf` and copy it into the `/etc/nginx/` directory in the Dockerfile.

There are two specific requirements for which nginx is configured in this project.
1) NGINX must be configured to use HTTPS (TLSv1.2 or TLSv1.3). NGINX listens on 443, which is the standard HTTPS port.
2) Wordpress is a PHP application, which serves up PHP files. NGINX itself cannot execute PHP. This is done by the PHP-FPM, which in the Wordpress docker container. NGINX uses FastCGI protocol to send PHP-related requests to PHP-FPM, which executes PHP code.Because of this, the configuration should set up FastCGI proxying.

Here is the complete configuration file:

```nginx
events {}

http {
    server {
        listen 443 ssl;
        server_name teesmaa.42.fr;

        root /var/www/html;
        index index.php index.html;

        ssl_certificate     /etc/nginx/ssl/inception.crt;
        ssl_certificate_key /etc/nginx/ssl/inception.key;

        ssl_protocols TLSv1.2 TLSv1.3;

        location / {
            try_files $uri $uri/ /index.php?$args;
        }

        location ~ \.php$ {
            try_files $uri =404;

            include fastcgi_params;

            fastcgi_pass wordpress:9000;

            fastcgi_param SCRIPT_FILENAME
                $document_root$fastcgi_script_name;
        }

        location ~ /\. {
            deny all;
        }
    }
}
```
`events {}` is the NGINX context for configuring connection handling. It is required in the main configuration file. Since no directives are set here, NGINX uses its default event settings.

In the `http` context holds most of the configuration. It defines how the program will handle HTTP or HTTPS connections. The `server` context is declared within the `http` context. It defines a virtual server that handles client requests. Within the `server` context, the following options are specified:

- `listen` defines the listening port, which is 443 for HTTPS connections. To configure an HTTPS server, the `ssl` parameter must be enabled on listening sockets in the server block.
- `server_name` defines which hostname this server block is intended to serve.  Strictly speaking, it is not necessary if there is only one server block.
- `root` tells the server in which directory the website files are located. When a request for a file is received, this filename is appended to the root directory. So the requested file can be found and delivered.
- `index` provides fallback options in order. If no filename is specified or it does not exist, then nginx tries first `index.php` and then `index.html`.
- The locations of the server certificate and private key files should be specified with `ssl_certificate` and `ssl_certificate_key`.
- `ssl_protocols` lists the versions of TLS/SSL protocols that can be used. `ssl_protocols TLSv1.2 TLSv1.3` is actually also the default configuration, so the specification is strictly speaking not necessary.

There are three `location` contexts nested inside the `server` context. These route requests to specific actions inside nginx.
- `location /` matches all files starting with `/`. `try_files` then tells nginx to check all the files/directories in order and use the first one that exists. So first, it checks if the URI file exists, then it checks id this is a directory, and finally it sends the request to Wordpress through `index.php`.
- `location ~ \.php$` matches PHP files. If the file does not exist, return HTTP 404. If it does, then the request is sent to php-fpm over FastCGI in the Wordpress container on port 9000. `fastcgi_param SCRIPT_NAME` tells php-fom which PHP file to execute.
- `location ~ /\.` matches files starting with `.`. It protects hidden files like `.env` from being served publically.

### MariaDB

MariaDB is the database service used by WordPress to store website content, users, settings and other application data. It runs in its own container and is accessible to WordPress through the internal Docker network (through port 3306). Its data is stored in the persistent volume named mariadb_data, so it survives container recreation.

#### Dockerfile

Install the base image:
```dockerfile
FROM debian:bookworm
```
Install MariaDB server:
```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends mariadb-server \
    && rm -rf /var/lib/apt/lists/*
```
Copy the configuration file into the container's filesystem:
```dockerfile
COPY /conf/70-inception.cnf /etc/mysql/mariadb.conf.d/70-inception.cnf
```
Copy the entrypoint script into the container's filesystem:
```dockerfile
COPY /tools/entrypoint.sh /usr/local/bin/entrypoint.sh
```
Change permissions on the entrypoint script to make it executable:
```dockerfile
RUN chmod 755 /usr/local/bin/entrypoint.sh
```
Document the port:
```dockerfile
EXPOSE 3306
```
Run the entrypoint script when the container starts. The next section is about what the entrypoint script does.
```dockerfile
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
```

#### Entrypoint script

The entrypoint script is the container's startup program. Its purpose is to prepare the MariaDB data directory, create the application database and accounts, and then replace itself with MariaDB running in the foreground. Keeping MariaDB as the main foreground process allows Docker to monitor the container and restart it when necessary.

The script is organized into these phases:

1. **Enable strict shell behavior and validate configuration**

    `set -euo pipefail` makes the script stop when a command fails, an unset variable is used, or a pipeline fails. The `MARIADB_DATABASE` and `MARIADB_USER` environment variables are required. The application and root passwords are read from Docker secrets mounted at `/run/secrets/mdb_password` and `/run/secrets/mdb_root_password`.

2. **Prepare MariaDB directories**

    The script creates `/run/mysqld` for runtime files and `/var/lib/mysql` for database data, then assigns both directories to the `mysql` user. The data directory is mounted from the persistent `mariadb_data` volume, so its contents survive container recreation.

3. **Initialize the system tables when necessary**

    If `/var/lib/mysql/mysql` does not exist, `mariadb-install-db` creates MariaDB's internal system tables. This check prevents the existing database from being reinitialized on later starts.

4. **Start a temporary private MariaDB server**

    MariaDB is started in the background with `--skip-networking` and a temporary Unix socket at `/run/mysqld/init.sock`. During this phase, MariaDB is not accepting TCP connections; it can only be accessed locally through that socket. A cleanup trap stops the temporary process if initialization fails.

5. **Wait until the temporary server is ready**

    `mariadb-admin ping` is retried until the temporary server responds. The script also checks that the background process is still running so that a startup failure does not result in an infinite wait.

6. **Create the database and accounts**

    SQL is passed to the `mariadb` client through standard input using a heredoc. It creates the application database, creates or updates `root@'%'`, creates the application user, and grants that user all privileges on the application database.

    The SQL is streamed directly to the client instead of being written to `/tmp/init.sql`. Therefore, the container does not leave a password-containing initialization file on disk. The passwords are still present temporarily in the shell's memory and in the SQL input while the initialization command runs.

7. **Stop the temporary server and start normally**

    `mariadb-admin shutdown` stops the temporary instance. After it exits, `exec mariadbd` starts MariaDB in the foreground and replaces the entrypoint shell process with MariaDB.

#### Configuration

The configuration file overwrites the default configured values of the MariaDB server. The configuration file is prefixed by `70-` so as to override the settings of `50-server.conf`.

- `[mysqld]` means that these settings apply to the MariaDB server process. 
- `user = mysql` runs the MariaDB server as the unprivileged mysql user instead of `root`.
- `datadir = /var/lib/mysql` defines where MariaDB stores its databases, system tables, and other database files. This directory is mounted to the `mariadb_data` volume, so that database data persists container lifecycle.
- `bind-address = 0.0.0.0` makes MariaDB listen on all network interfaces inside the container. This allows the WordPress container to connect to MariaDB through the Docker network.

### WordPress + PHP-FPM

WordPress is the PHP-based content management system used by the project. Its posts, users, settings, and other application data are stored in MariaDB, while its core files, themes, plugins, uploads, and `wp-config.php` are stored in the persistent `wordpress_data` volume.

PHP-FPM (PHP FastCGI Process Manager) runs the WordPress PHP code. NGINX does not execute PHP itself; it forwards PHP requests to PHP-FPM through FastCGI. PHP-FPM manages worker processes so that the container can handle multiple requests.

WordPress, PHP-FPM, WP-CLI, and the MariaDB client are packaged in one container. The container is connected to the internal `inception` Docker network: it connects to MariaDB on port `3306`, while NGINX connects to PHP-FPM on port `9000`. These are internal container-to-container ports, not host-published ports.

#### Dockerfile

The WordPress image is built from Debian Bookworm and contains PHP-FPM, WP-CLI, and the tools needed to connect to MariaDB and initialize WordPress.

Get the base image:
```dockerfile
FROM debian:bookworm
```

Install PHP-FPM, PHP CLI, the PHP MySQL/MariaDB extension, the MariaDB client, and the tools needed to download WP-CLI:
```dockerfile

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        php-fpm \
        php-cli \
        php-mysql \
        mariadb-client \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*
```

- `php-fpm` executes WordPress PHP requests.
- `php-cli` allows PHP commands to run from the command line.
- `php-mysql` provides PHP connectivity to MariaDB/MySQL.
- `mariadb-client` provides command-line tools for checking the database connection.
- `curl` is for downloading WP-CLI.
- `ca-certificates` enables HTTPS certificate verification when downloading WP-CLI.
- Removing `/var/lib/apt/lists/*` reduces the final image size.

Set the working directory to `/var/www/html`. This is also the directory where the `wordpress_data` volume is mounted:

```dockerfile
WORKDIR /var/www/html
```

Download WP-CLI, make it executable, and move it to `/usr/local/bin/wp` so that it is available to the entrypoint script:
```dockerfile
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp
```

Copy the PHP-FPM pool configuration into PHP-FPM's configuration directory:
```dockerfile
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
```

Copy the WordPress entrypoint script into the image and make it executable:
```dockerfile
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh
```

Document port `9000`, which PHP-FPM uses for FastCGI connections from NGINX. `EXPOSE` does not publish the port to the host:
```dockerfile
EXPOSE 9000
```

Set the entrypoint script as the container's startup program. Docker runs this script before the command defined by `CMD`, so the script can initialize WordPress first:
```dockerfile
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
```

Provide the default command for the entrypoint. `php-fpm8.2 -F` starts PHP-FPM in the foreground, allowing it to remain the container's main process:
```dockerfile
CMD ["php-fpm8.2", "-F"]
```
#### MariaDB client

The `mariadb-client` package provides command-line tools for connecting to MariaDB. The WordPress entrypoint uses the `mariadb` client to check whether the database is reachable before continuing:

```bash
mariadb -h"${MARIADB_HOST}" \
    -u"${MARIADB_USER}" \
    -p"${MARIADB_PASSWORD}" \
    -e "SELECT 1;"
```

The client connects to the MariaDB server through the internal `inception` Docker network. It does not run a database server inside the WordPress container.

#### Entrypoint script

The entrypoint script prepares WordPress and then starts PHP-FPM. It performs these steps:

1. Validates the required environment variables and reads the database and WordPress passwords from Docker secrets.
2. Waits until MariaDB is reachable at the configured host and port.
3. Downloads the WordPress core files if `/var/www/html/wp-load.php` does not exist.
4. Creates `wp-config.php` with the MariaDB connection details if it does not already exist.
5. Installs WordPress in the database if it has not already been installed.
6. Creates the configured author account if that account does not exist.
7. Ensures that the configured site title is applied.
8. Changes ownership of the WordPress files to `www-data`, the PHP-FPM user.
9. Uses `exec "$@"` to replace the shell with `php-fpm8.2 -F`, keeping PHP-FPM in the foreground as the container's main process.

#### Configuration

- `[www]` defines a PHP-FPM pool named `www`. A PHP-FPM pool is a group of PHP worker processes managed together by PHP-FPM. PHP-FPM can manage multiple pools, but this project uses one.
- `user = www-data` and `group = www-data`: PHP-FPM worker processes run as the unprivileged www-data user and group. This user must be able to read the WordPress files.
- `listen = 9000` makes PHP-FPM listen on port 9000 inside the container. NGINX connects with this (`fastcgi_pass wordpress:9000`).
- `pm = dynamic` enables dynamic process management. PHP-FPM starts with a small number of workers and adjusts the number according to demand.
- `pm.max_children = 5` Sets the maximum number of PHP-FPM worker processes. At most five PHP requests can be processed simultaneously by this pool.
- `pm.start_servers = 2` starts two worker processes when PHP-FPM launches
- `pm.min_spare_servers = 1` and `pm.max_spare_servers = 3` : keep between one and three idle worker processes available to handle incoming requests quickly. PHP-FPM creates or removes workers within the configured limits.

## Docker Compose

Docker Compose defines the services, networks, volumes, and secrets required to run the project. The configuration is stored in `srcs/docker-compose.yml` and can be started from the project root with:

```bash
docker compose -f srcs/docker-compose.yml up --detach --build
```

The Makefile provides the equivalent command through `make up`.

The file begins with the top-level `services` section. Each service describes one container, its image build context, network connections, dependencies, volumes, environment variables, and secrets.

### NGINX service

```yaml
nginx:
    container_name: nginx
    build:
        context: ./requirements/nginx/
    ports:
        - "443:443"
    restart: always
    depends_on:
        - wordpress
    networks:
        - inception
```

- `container_name` gives the container the explicit name `nginx`.
- `build.context` tells Compose to build the image using the NGINX directory as its build context.
- `ports` publishes host port `443` to container port `443`, making HTTPS accessible from outside Docker.
- `restart: always` tells Docker to restart the container if it stops.
- `depends_on` starts the WordPress service before NGINX. It does not verify that WordPress is ready to receive requests.
- `networks` connects NGINX to the internal `inception` network.

NGINX is the only service with a published host port. WordPress and MariaDB are reachable only through the internal Docker network.

### WordPress service

```yaml
wordpress:
    container_name: wordpress
    build:
        context: ./requirements/wordpress/
    restart: always
    networks:
        - inception
    volumes:
        - wordpress_data:/var/www/html
    depends_on:
        - mariadb
```

The WordPress image is built from `srcs/requirements/wordpress/`. The `wordpress_data` volume is mounted at `/var/www/html`, where WordPress core files, `wp-config.php`, themes, plugins, and uploads are stored.

The `depends_on` entry starts MariaDB before WordPress. It does not guarantee that MariaDB is ready, so the WordPress entrypoint repeatedly connects to MariaDB before continuing initialization.

The WordPress service also receives its database and WordPress settings through the `environment` section:

```yaml
environment:
    MARIADB_HOST: "${MARIADB_HOST}"
    MARIADB_DATABASE: ${MARIADB_DATABASE}
    MARIADB_USER: ${MARIADB_USER}
    WP_URL: ${WP_URL}
    WP_TITLE: ${WP_TITLE}
    WP_ADMIN_USER: ${WP_ADMIN_USER}
    WP_ADMIN_EMAIL: ${WP_ADMIN_EMAIL}
    WP_USER: ${WP_USER}
    WP_USER_EMAIL: ${WP_USER_EMAIL}
```

`${VARIABLE}` refers to a value loaded by Docker Compose from the project environment, normally from `srcs/.env`. These variables configure the MariaDB connection and the WordPress site and user accounts.

### MariaDB service

```yaml
mariadb:
    container_name: mariadb
    build:
        context: ./requirements/mariadb/
    restart: always
    networks:
        - inception
    volumes:
        - mariadb_data:/var/lib/mysql
```

The MariaDB image is built from `srcs/requirements/mariadb/`. The `mariadb_data` volume is mounted at `/var/lib/mysql`, which is MariaDB's data directory. Database tables, users, and other database files are stored there so that they survive container recreation.

MariaDB receives the database name and application username through environment variables. Its passwords are provided through Docker secrets rather than ordinary environment variables:

```yaml
environment:
    MARIADB_DATABASE: ${MARIADB_DATABASE}
    MARIADB_USER: ${MARIADB_USER}
secrets:
    - mdb_password
    - mdb_root_password
```

### Docker network and ports

The following top-level configuration creates one bridge network:

```yaml
networks:
    inception:
        driver: bridge
```

All three services are connected to the internal `inception` Docker network. Docker provides service-name DNS on this network, so containers can connect using names such as `wordpress` and `mariadb` instead of IP addresses.

- NGINX connects to the WordPress container on port `9000` using FastCGI.
- WordPress connects to the MariaDB container on port `3306` using the MariaDB service hostname.
- Port `443` is the only port published to the host. Ports `9000` and `3306` are internal container-to-container ports.

### Volumes

The top-level `volumes` section defines two named volumes backed by host directories:

```yaml
volumes:
    mariadb_data:
        driver: local
        driver_opts:
            type: none
            o: bind
            device: /Users/triinueesmaa/data/mariadb_data
    wordpress_data:
        driver: local
        driver_opts:
            type: none
            o: bind
            device: /Users/triinueesmaa/data/wordpress_data
```

`driver: local` uses Docker's local volume driver. The bind options make each named volume point to a specific directory on the host.

- `mariadb_data` is mounted at `/var/lib/mysql` and stores database tables and records.
- `wordpress_data` is mounted at `/var/www/html` and stores WordPress core files, `wp-config.php`, themes, plugins, and uploaded media.

Both volumes are required. Restoring only `mariadb_data` would restore the database content but not the WordPress files, themes, plugins, or uploads.

## Secrets

Docker Compose reads sensitive values from files and mounts them inside the relevant containers under `/run/secrets/`. This keeps passwords out of the service environment configuration and allows the entrypoint scripts to read them when needed.

The secret files are stored in `srcs/secrets/`:

```text
srcs/secrets/
├── mdb_password.txt
├── mdb_root_password.txt
├── wp_admin_password.txt
└── wp_user_password.txt
```

The top-level `secrets` section maps Compose secret names to these files:

```yaml
secrets:
    mdb_root_password:
        file: ./secrets/mdb_root_password.txt
    mdb_password:
        file: ./secrets/mdb_password.txt
    wp_admin_password:
        file: ./secrets/wp_admin_password.txt
    wp_user_password:
        file: ./secrets/wp_user_password.txt
```

- `mdb_root_password` is read by the MariaDB entrypoint to set the remote root account password.
- `mdb_password` is read by both the MariaDB and WordPress entrypoints for the application database user.
- `wp_admin_password` is read by the WordPress entrypoint when creating the administrator account.
- `wp_user_password` is read by the WordPress entrypoint when creating the regular WordPress user.

The service-level `secrets` section grants a container access to only the secrets it needs. For example:

```yaml
wordpress:
    secrets:
        - mdb_password
        - wp_admin_password
        - wp_user_password

mariadb:
    secrets:
        - mdb_password
        - mdb_root_password
```

Inside the containers, the secrets are available as files such as `/run/secrets/mdb_password`. The secret values should not be committed to version control or copied into the documentation.

## Environment Variables

Docker Compose substitutes `${VARIABLE}` expressions with values from the project environment, normally loaded from `srcs/.env`. These values configure the services without hard-coding them in `docker-compose.yml`.

The environment file contains the following groups of settings:

```dotenv
DOMAIN_NAME=...

# Database
MARIADB_DATABASE=...
MARIADB_USER=...
MARIADB_HOST=...

# WordPress
WP_URL=...
WP_TITLE=...
WP_ADMIN_USER=...
WP_ADMIN_EMAIL=...
WP_USER=...
WP_USER_EMAIL=...
```

The variables are used as follows:

- `MARIADB_DATABASE` is the application database name.
- `MARIADB_USER` is the application database username.
- `MARIADB_HOST` identifies the MariaDB service and port used by WordPress, for example `mariadb:3306`.
- `WP_URL` is the WordPress site URL.
- `WP_TITLE` is the site title.
- `WP_ADMIN_USER` and `WP_ADMIN_EMAIL` configure the WordPress administrator account.
- `WP_USER` and `WP_USER_EMAIL` configure the additional WordPress author account.

The MariaDB passwords and WordPress account passwords are not passed to the services as ordinary environment variables in `docker-compose.yml`; the entrypoint scripts read them from Docker secrets instead. Although the current `.env` file contains password-related entries, those values are not used by the service definitions for authentication. Keep the secret files as the source of truth and avoid committing passwords to version control. `DOMAIN_NAME` is available in the environment file for host configuration, while the current NGINX configuration specifies its server name directly.

## Notes

- [Installing Docker and Docker compose on Debian](https://docs.docker.com/engine/install/debian/#install-using-the-repository)

- [Writing your own Mariadb image](https://mariadb.com/docs/server/server-management/automated-mariadb-deployment-and-administration/docker-and-mariadb/creating-a-custom-container-image)

- https://docs.openssl.org/3.2/man7/ossl-guide-tls-introduction/#certificates
- https://docs.openssl.org/3.6/man1/openssl-req/#options

- https://mangohost.net/blog/understanding-the-nginx-configuration-file-structure-and-contexts/

- https://www.digitalocean.com/community/tutorials/understanding-the-nginx-configuration-file-structure-and-configuration-contexts