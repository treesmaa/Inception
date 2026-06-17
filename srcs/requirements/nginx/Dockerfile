FROM debian:bookworm

#WORKDIR /var/www/html

RUN apt-get update \
	&& apt-get install -y nginx \
 	&& rm -rf /var/lib/apt/lists/*

#COPY will have to be defined 

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
