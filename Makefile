COMPOSE = docker compose --env-file srcs/.env -f srcs/docker-compose.yml

all: up

up:
    $(COMPOSE) up --detach --build

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

.PHONY: all up down start stop restart logs