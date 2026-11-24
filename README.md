
*This project has been created as part of the 42 curriculum by teesmaa.*

# Inception

## Description

Inception is a Docker-based system administration project. The project consists of setting up a multi-container infrastructure using custom Docker images. It hosts a WordPress website, uses MariaDB as its database management system, and uses NGINX as a reverse proxy with HTTPS enabled through a self-signed SSL certificate.

The infrastructure consists of three containers:

- **NGINX:** Acts as the entry point to the infrastructure. It handles incoming HTTPS connections and forwards requests to the WordPress service.
- **WordPress + PHP-FPM:** Runs the WordPress application and processes PHP requests using PHP-FPM.
- **MariaDB:** Stores the WordPress database, including website content, user information, and application data.

Each service runs in its own container, built from a custom Docker image. Docker Compose is used to orchestrate the containers, configure their network, and manage persistent storage through Docker volumes.

The infrastructure is designed to be isolated, modular, and reproducible. Each service has a clearly defined responsibility and communicates with the other services through a dedicated Docker network.

## Architecture

The infrastructure follows a three-tier architecture:

```text
                  User
                    |
                    | HTTPS (443)
                    |
               +---------+
               |  NGINX  |
               +---------+
                    |
                    | FastCGI
                    |
          +-------------------+
          | WordPress + PHP-FPM|
          +-------------------+
                    |
                    | SQL
                    |
              +-----------+
              |  MariaDB  |
              +-----------+
```

Each container has its own responsibilities:

- NGINX handles incoming HTTPS requests.
- WordPress processes application logic and communicates with MariaDB.
- MariaDB stores persistent application data.

Only NGINX is exposed to the host machine. The other services communicate through an internal Docker network.

## Docker Concepts

### Virtual Machines vs Docker

Both virtual machines and Docker provide isolated environments in which applications can run. However, they use different approaches to virtualization.

A virtual machine virtualizes an entire computer, including its hardware resources. Each VM runs its own operating system and kernel on top of a hypervisor.

Docker uses operating-system-level virtualization. Containers share the host operating system's kernel while keeping their processes, filesystems, and network environments isolated.

| Feature | Virtual Machine | Docker |
|---|---|---|
| Virtualization | Hardware-level virtualization | Operating-system-level virtualization |
| Operating system | Each VM has its own OS | Containers share the host kernel |
| Kernel | Separate kernel per VM | Shared host kernel |
| Resource usage | Generally higher | Generally lower |
| Startup time | Usually slower | Usually faster |
| Isolation | Strong isolation through virtualization | Process and resource isolation |
| Portability | Depends on VM image and hypervisor | Portable container images |
| Use case | Running different operating systems | Packaging and deploying applications |

Docker containers are generally more lightweight than virtual machines because they do not need to run a complete operating system.

### Docker Network vs Host Network

Docker networks allow containers to communicate with each other in an isolated network environment.

In this project, a dedicated Docker network connects NGINX, WordPress, and MariaDB. Each service can communicate with the others using its service name as its hostname.

For example:

- NGINX forwards requests to WordPress.
- WordPress connects to MariaDB to access the database.

The Docker network isolates internal communication from the host network. Only explicitly published ports are accessible from outside the Docker network.

The host network mode is different: it removes network isolation and makes the container share the host's network namespace. This means the container uses the host's network interfaces and ports directly.

| Feature | Docker Network | Host Network |
|---|---|---|
| Network isolation | Yes | No |
| Container communication | Through the Docker network | Through the host network |
| IP address | Own container IP | Uses host network namespace |
| Port mapping | Supported | Not required |
| Use case | Isolated multi-container applications | Applications requiring direct host networking |

### Docker Volumes vs Bind Mounts

Docker volumes and bind mounts are both mechanisms for sharing and persisting data between the host and containers.

**Docker volumes**

Volumes are managed by Docker and are stored in a location controlled by the Docker engine.

They allow data to persist independently of a container's lifecycle. Removing or recreating a container does not automatically remove its associated volume.

In this project, volumes are used to persist:

- MariaDB database files.
- WordPress website files.

**Bind mounts**

Bind mounts connect a specific file or directory on the host machine to a path inside a container.

Unlike volumes, bind mounts depend on an explicitly defined host filesystem path.

They are useful when files need to be directly accessible or modified from the host, for example, during development.

| Feature | Docker Volume | Bind Mount |
|---|---|---|
| Storage location | Managed by Docker | Defined by the user |
| Host path | Managed internally | Explicit host path |
| Persistence | Independent of container lifecycle | Independent of container lifecycle |
| Portability | More portable | Depends on host directory structure |
| Typical use | Database and application data | Development and configuration files |

### Environment Variables vs Docker Secrets

Environment variables are used to configure applications and services at runtime.

They are suitable for general configuration values, such as database names, usernames, and service settings.

However, environment variables are not ideal for storing sensitive information. Depending on how they are configured, they may be visible through commands such as `docker inspect`, process information, or application logs.

Docker secrets provide a mechanism for handling sensitive information, such as passwords and credentials.

Secrets are mounted inside containers as files rather than being directly exposed as environment variables. This helps prevent sensitive information from being unnecessarily exposed through container configuration or application environments.

In this project, environment variables and secrets are used to separate general configuration from sensitive credentials.

## Requirements

Before starting the project, make sure the following tools are installed:

- Docker
- Docker Compose
- GNU Make
- Git

You also need to configure the required local hostname so that the domain points to your machine.

For this project, the expected domain is:

```text
teesmaa.42.fr
```

Add the following entry to your hosts file:

```text
127.0.0.1 teesmaa.42.fr
```

On Linux and macOS, the hosts file is located at:

```text
/etc/hosts
```

## Instructions

### 1. Clone the repository

```bash
git clone https://github.com/treesmaa/Inception.git
cd Inception
```

### 2. Configure secrets and environment variables

If configuration templates (`secrets_example` and `.env.example`) are provided, create the local configuration files by copying the provided templates. From the root of the repository, run:

```bash
cp -r secrets_example secrets
cp srcs/.env.example srcs/.env

```
If the templates are not provided, manually create a `secrets/` directory at the root of the repository and an `.env` file inside the `srcs/` directory.

For the required environment variables, secret files, and their expected contents, refer to the [Developer Documentation](DEV_DOC.md).

Edit the `.env` file to configure the services and replace the placeholder values in the secret files with secure passwords.

Make sure all required environment variables and secrets are configured before starting the infrastructure.

The directory structure should now look similar to this:

```text
inception/
├── Makefile
├── secrets/
│   ├── credentials.txt
│   └── db_password.txt
│   └── db_root_password.txt
└── src/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        ├── nginx/
        └── wordpress/
```

### 3. Build and start the infrastructure

From the root of the repository, run:

```bash
make
```

This command builds the custom Docker images and starts the containers using Docker Compose.

### 4. Access the WordPress website

Once all containers are running, open the following URL in your browser:

[https://teesmaa.42.fr](https://teesmaa.42.fr)

The project uses a self-signed SSL certificate. Because the certificate is not issued by a publicly trusted certificate authority, your browser will display a security warning.

To continue:

1. Click **Advanced**.
2. Review the security warning.
3. Click **Proceed to teesmaa.42.fr** (the wording may vary depending on your browser).

You should now be able to access and interact with the WordPress website through HTTPS.

### 5. Stop the infrastructure

To stop and remove the containers and the Docker network, run:

```bash
make down
```

To stop and remove containers, Docker network and images from your device, run:

```bash
make clean
```

This keeps the persistent data, including the WordPress website files and the MariaDB Database.

For a complete overview of Docker management commands and Makefile targets, refer to the [Developer Documentation](DEV_DOCS.md).

## Resources

The following documentation was useful for understanding and implementing the project:

- [NGINX Documentation](https://nginx.org/en/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [MariaDB Documentation](https://mariadb.com/docs/)
- [WordPress Documentation](https://wordpress.org/documentation/)
- [PHP Documentation](https://www.php.net/docs.php)

### Use of AI

AI was used as a learning and development aid throughout the project, particularly for:

- Understanding Docker concepts, containerization, networking, persistent storage, and secrets management.
- Understanding the configuration and interaction of NGINX, MariaDB, WordPress, and PHP-FPM.
- Assitance with shell scripting, Dockerfiles, and service initialization scripts.
- Troubleshooting configuration, connectivity, and container startup issues.
- Reviewing, structuring, and editing project documentation.

AI-generated suggestions were critically reviewed and adapted to the specific requirements of the project.

## Further documentation

- [User Docs](USER_DOC.md)
- [Dev Docs](DEV_DOC.md)