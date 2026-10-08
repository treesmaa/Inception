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


## Docker Containers

This project combines three containers: NGINX, Wordpress + php-fpm and MariaDB. Each container is built from a custom image with Debian Bookworm (penultimate stable version during the completion of this project) as the base image. 

### NGINX

NGINX is the externally exposed web server and entry point of the application stack. It listens for client connections on port 443, handles TLS termination using TLSv1.2 and/or TLSv1.3, and processes incoming HTTP requests. Static resources can be served directly by NGINX, while requests for PHP scripts are forwarded to the WordPress/PHP-FPM service over the FastCGI protocol. Request handling and routing behavior are defined through the NGINX configuration.

#### Dockerfile
The NGINX container image is built based on the Dockerfile that consists of the following commands.

Get the base image:
```
FROM debian:bookworm
```
Install the NGINX itself and OpenSSL, which is needed to implement TLS:
```
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

```
RUN mkdir -p /etc/nginx/ssl/
RUN openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/inception.key \
  -out /etc/nginx/ssl/inception.crt \
  -subj "/C=AT/ST=Vienna/L=Vienna/O=42/OU=42/CN=teesmaa.42.fr/UID=teesmaa"
```
Copy the configuration file into the container's filesystem:
```
COPY /conf/nginx.conf /etc/nginx/nginx.conf
```
Create the directory for WordPress files, change ownership to www-data (the web-server/PHP user) and change permissions.
```
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www/html && \
    chmod 755 /var/www/html
```
Document the port through which connections are possible. This itself does not expose the port. The port must be publically accessible through configuration and docker compose. This should be port 443, which is the standard port used for encrypted HTTPS web traffic secured by SSL/TLS protocols.
```
EXPOSE 443
```
Run nginx in the foreground. Normally, NGINX may detach itself from the terminal and run in the background as a daemon. In a traditional server, that is normal.
In Docker, that is usually undesirable because Docker expects the container's main process, PID 1, to keep running. If the main process exits, Docker considers the container finished.
 - `daemon off;` disables daemon mode
 - `-g` sets a global NGINX directive
```
CMD ["nginx", "-g", "daemon off;"]
```
#### Configuration

The way NGINX and its modules work is determined in the configuration file. Debian's packaged NGINX uses `/etc/nginx/nginx.conf` as its normal main configuration file. As we saw, we write our own `nginx.conf` and copy it into the `/etc/nginx/` directory in the Dockerfile.

There are two specific requirements for which nginx is configured in this project.
1) NGINX must be configured to use HTTPS (TLSv1.2 or TLSv1.3). NGINX listens on 443, which is the standard HTTPS port.
2) Wordpress is a PHP application, which serves up PHP files. NGINX itself cannot execute PHP. This is done by the PHP-FPM, which in the Wordpress docker container. NGINX uses FastCGI protocol to send PHP-related requests to PHP-FPM, which executes PHP code.Because of this, the configuration should set up FastCGI proxying.

Here is the complete configuration file:

```
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

MariaDB is the database container. 

#### Dockerfile

Install the base image:
```
FROM debian:bookworm
```
Install the MariaDB server:
```
RUN apt-get update \
    && apt-get install -y --no-install-recommends mariadb-server \
    && rm -rf /var/lib/apt/lists/*
```
Copy the configuration file into the container's filesystem:
```
COPY /conf/70-inception.cnf /etc/mysql/mariadb.conf.d/70-inception.cnf
```
Copy the entrypoint script into the container's filesystem:
```
COPY /tools/entrypoint.sh /usr/local/bin/entrypoint.sh
```
Change permissions on the entrypoint script to make it executable:
```
RUN chmod 755 /usr/local/bin/entrypoint.sh
```
Document the port:
```
EXPOSE 3306
```
Run the entrypoint script when the container starts. The next section is about what the entrypoint script does.
```
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
````
#### Entrypoint script


#### Configuration
Configuration file

### WordPress + PHP-FPM

#### Dockerfile
```
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        php-fpm \
        php-cli \
        php-mysql \
        mariadb-client \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["php-fpm8.2", "-F"]
```
#### Entrypoint script

#### Configuration

## Docker Compose

## Secrets

## Environment Variables

## Notes

- [Installing Docker and Docker compose on Debian](https://docs.docker.com/engine/install/debian/#install-using-the-repository)

- [Writing your own Mariadb image](https://mariadb.com/docs/server/server-management/automated-mariadb-deployment-and-administration/docker-and-mariadb/creating-a-custom-container-image)

- https://docs.openssl.org/3.2/man7/ossl-guide-tls-introduction/#certificates
- https://docs.openssl.org/3.6/man1/openssl-req/#options

- https://mangohost.net/blog/understanding-the-nginx-configuration-file-structure-and-contexts/

- https://www.digitalocean.com/community/tutorials/understanding-the-nginx-configuration-file-structure-and-configuration-contexts