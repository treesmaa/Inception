FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends mariadb-server \
    && rm -rf /var/lib/apt/lists/*

COPY /conf/70-inception.cnf /etc/mysql/mariadb.conf.d/70-inception.cnf
COPY /tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 755 /usr/local/bin/entrypoint.sh

EXPOSE 3306

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]