# User Documentation

This document explains how to operate the Inception infrastructure, access the WordPress website and administration panel, manage credentials, and verify that the services are running correctly. It assumes that the installation and configuration steps have already been completed. For initial setup instructions, refer to the [README](README.md) and the [Developer Documentation](DEV_DOC.md).

## Services

The stack provides a WordPress website through three services:

- **NGINX:** The web server and sole entry point to the infrastructure. It provides access to the website over HTTPS using TLS 1.2 or TLS 1.3.
- **WordPress + PHP-FPM:** Runs the WordPress application, allowing users to create and manage website content.
- **MariaDB:** Stores website content, user accounts, settings, and other application data.

The services run in separate Docker containers and communicate through a dedicated Docker network.

## Starting and Stopping the Project

The infrastructure can be managed using the following `make` commands in the terminal. All commands must be executed from the root directory of the project.

### Starting the project

To build and launch the infrastructure, run:

```bash
make up
```

### Stopping the project

To stop the containers without removing them, run:

```bash
make stop
```

To start the stopped containers again, run:

```bash
make start
```

### Restarting the project

To restart existing containers, run:

```bash
make restart
```

### Stopping and removing containers

To stop and remove the containers and the project network, run:

```bash
make down
```

To launch the infrastructure again after this operation, use `make up`.

### Rebuilding the project

To rebuild the Docker images without using the build cache and recreate the containers, run:

```bash
make rebuild
```

### Removing the infrastructure

To remove the project's containers, network, and service images, run:

```bash
make clean
```

### Data persistence

All of the above commands preserve the persistent data stored on the host machine under `/home/teesmaa/data/`:

- `/home/teesmaa/data/wordpress`: WordPress website files.
- `/home/teesmaa/data/mariadb`: MariaDB database files.

This ensures that website content, uploaded files, settings, and user accounts remain available when the infrastructure is launched again.

## Accessing the Website

### Public Website

Once all services are ready, open the following URL in your browser:

[https://teesmaa.42.fr/](https://teesmaa.42.fr/)

The project uses a self-signed TLS certificate. Because the certificate is not issued by a publicly trusted certificate authority, your browser may display a security warning.

Only proceed if you have verified that you are connecting to the intended local Inception server.

1. Click **Advanced**.
2. Review the security warning and verify the server.
3. Click **Proceed to teesmaa.42.fr** (the wording may vary depending on your browser).

You should now be able to access and interact with the WordPress website.

### Administration Panel

To access the WordPress administration panel, open the following URL in your browser:

[https://teesmaa.42.fr/wp-admin/](https://teesmaa.42.fr/wp-admin/)

Log in using your WordPress administrator credentials. For information about locating these credentials, refer to the [Managing Credentials](#managing-credentials) section below.

The administrator can manage website content, user accounts, themes, plugins, and WordPress settings.

Users with an author account can access the same panel but have limited permissions according to their assigned role.

## Managing Credentials

### Locating credentials

WordPress usernames are configured in `srcs/.env`, while initial passwords are stored in the `secrets/` directory at the root of the repository. These files can be edited before the initial launch of the project.

| Credential | Location |
|---|---|
| WordPress administrator username | `srcs/.env` (`WP_ADMIN_USER`) |
| WordPress administrator initial password | `credentials.txt` |
| WordPress author username | `srcs/.env` (`WP_USER`) |
| WordPress author initial password | `credentials.txt` |
| MariaDB application username | `srcs/.env` (`MARIADB_USER`) |
| MariaDB application password | `secrets/db_password.txt` |
| MariaDB root password | `secrets/db_root_password.txt` |

These files must remain private and must not be shared publicly or committed to version control.

### Changing WordPress passwords

Once WordPress has been initialized, users can manage their passwords through the administration panel.

1. Log in at [https://teesmaa.42.fr/wp-admin/](https://teesmaa.42.fr/wp-admin/).
2. Navigate to **Users → Profile**, or **Profile**, depending on your user role.
3. Scroll down to **Account Management**.
4. Set a new password.
5. Save the changes by clicking **Update Profile**.

The administrator can also create new WordPress users and manage the passwords of other users through the **Users** section.

WordPress passwords are managed independently of the initial secret files after initialization. Editing the passwords in the `secrets/` directory does not automatically update the passwords of existing WordPress accounts. Use your current password to log in, rather than the initial password, if it has been changed.

### Database credentials

The database credentials are configured through environment variables and secret files. They are required for communication between WordPress and MariaDB and are not needed for normal website usage.

For information about configuring and managing database credentials, refer to the [Developer Documentation](DEV_DOC.md).

## Checking Service Status

### Checking the containers

To list the running Docker containers, run:

```bash
docker ps
```

The three project containers (NGINX, WordPress, and MariaDB) should be listed with the status `Up`.

To list all containers, including stopped containers, run:

```bash
docker ps -a
```

### Checking the network

To verify that the Docker network exists, run:

```bash
docker network ls
```

The project's `inception` network should appear in the list.

### Checking the volumes

To verify that the persistent storage volumes exist, run:

```bash
docker volume ls
```

The project's MariaDB and WordPress named volumes should appear in the list.

Docker Compose may prefix network and volume names with the Compose project name.

### Checking the service logs

To view and follow the logs of all services, run:

```bash
make logs
```

The logs provide information about service initialization, operation, and potential errors.

Press `Ctrl+C` to exit the log view. This does not stop the containers.

### Checking website availability

A running container does not necessarily mean that its service is functioning correctly.

Open [https://teesmaa.42.fr/](https://teesmaa.42.fr/) in your browser and verify that the WordPress website loads correctly.

To verify that the administration panel is also accessible, open [https://teesmaa.42.fr/wp-admin/](https://teesmaa.42.fr/wp-admin/) and log in using your WordPress credentials.

## Troubleshooting

| Problem | Suggested action |
|---|---|
| Website cannot be reached | Verify that the containers are running and the domain name is configured correctly. |
| Browser displays a certificate warning | Verify that you are accessing the intended local server. |
| 403 Forbidden | Check the NGINX and WordPress logs. |
| 502 Bad Gateway | Check whether WordPress and PHP-FPM are running correctly. |
| Error establishing a database connection | Check the MariaDB and WordPress logs. |
| Cannot log in | Verify your current WordPress credentials. |
| Container repeatedly restarts | Inspect the service logs using `make logs`. |

For more advanced troubleshooting, refer to the [Developer Documentation](DEV_DOC.md).