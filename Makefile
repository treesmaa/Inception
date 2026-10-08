all: up

up:
	docker compose -f srcs/docker-compose.yml up --detach --build

down:
	docker compose -f srcs/docker-compose.yml down

# add -d flag to compose up to run in detached mode get control of the terminal back
#build
#rebuild
start:
	docker compose -f srcs/docker-compose.yml start

stop:
	docker compose -f srcs/docker-compose.yml stop

restart:
	docker compose -f srcs/docker-compose.yml restart

logs:
	docker compose -f srcs/docker-compose.yml logs -f

#ps
#clean
#--volumes or -v to remove any anonymous volumes attached to the container
#fclean
#re
#prune

.PHONY: all up down start stop restart logs