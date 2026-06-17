FROM debian:bookworm

#WORKDIR /var/lib/mysql (maybe not needed)

COPY

RUN apt-get update && apt-get install -y mariadb-server \
	rm -rf /var/lib/apt/lists/*
#is this correct?
CMD ["mariadbd"]
