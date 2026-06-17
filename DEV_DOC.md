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

## Folder Structure


## Docker Containers

### nginx

### mariadb

### wordpress

## Docker Compose

## Notes

- [Installing Docker and Docker compose on Debian](https://docs.docker.com/engine/install/debian/#install-using-the-repository)

