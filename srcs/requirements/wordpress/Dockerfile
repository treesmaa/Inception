FROM debian:bookworm

#WORKDIR /var/www/html

RUN apt-get update && apt-get install -y php-fpm \
	&& rm -rf /var/lib/apt/lists/*
#trying to run a versioned php-fpm
CMD ["php-fpm8.2", "-F"]
