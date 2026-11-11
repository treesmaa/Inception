FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl/
RUN openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/inception.key \
  -out /etc/nginx/ssl/inception.crt \
  -subj "/C=AT/ST=Vienna/L=Vienna/O=42/OU=42/CN=teesmaa.42.fr/UID=teesmaa"

COPY /conf/nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www/html && \
    chmod 755 /var/www/html

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]