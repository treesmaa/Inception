COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml
DATA_DIR = /home/teesmaa/data

all: up

setup: 
	mkdir -p $(DATA_DIR)/wordpress
	mkdir -p $(DATA_DIR)/mariadb

up: setup
	$(COMPOSE) up --detach --build

rebuild: setup
	$(COMPOSE) build --no-cache
	$(COMPOSE) up --detach --force-recreate

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down --rmi all

.PHONY: all setup up rebuild down start stop restart logs clean
