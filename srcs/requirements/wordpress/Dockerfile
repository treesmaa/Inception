FROM debian:bookworm

#WORKDIR /var/www/html

RUN apt-get update && apt-get install -y php-fpm \
	&& rm -rf /var/lib/apt/lists/*

CMD ["php-fpm", "-F"]
