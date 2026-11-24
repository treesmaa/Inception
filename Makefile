COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml

all: up

up:
	$(COMPOSE) up --detach --build

rebuild:
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

.PHONY: all up rebuild down start stop restart logs clean
