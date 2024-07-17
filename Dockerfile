FROM alpine:3.20
LABEL Maintainer="Middle Earth Media <middleearthmedia@proton.me>"
LABEL Description="Lightweight container with Nginx & PHP based on Alpine Linux."

# Install packages and remove default server definition
RUN apk -U upgrade \
	&& apk --no-cache add \
	curl \
	freetds-dev \
	g++ \
	gcc \
	gcompat \
	libaio \
	libaio-dev \
	libc6-compat \
	libnsl \
	make \
	musl-dev \
	nginx \
	php83 \
	php83-ctype \
	php83-curl \
	php83-dom \
	php83-dev \
	php83-fileinfo \
	php83-fpm \
	php83-gd \
	php83-intl \
	php83-json \
	php83-mbstring \
	php83-mysqli \
	php83-opcache \
	php83-openssl \
	php83-phar \
	php83-pdo \
	php83-session \
	php83-simplexml \
	php83-tokenizer \
	php83-xml \
	php83-xmlreader \
	php83-xmlwriter \
	php83-zlib \
	php83-zip \
	supervisor \
	wget

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php83/php-fpm.d/www.conf
COPY config/php.ini /etc/php83/conf.d/custom.ini

# Normalize version specific php & phpize & php-config
RUN ln -sf /usr/bin/php83 /usr/bin/php
RUN ln -sf /usr/bin/phpize83 /usr/bin/phpize
RUN ln -sf /usr/bin/php-config83 /usr/bin/php-config
RUN ln -sf /etc/php83 /etc/php

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install pickle
RUN wget https://github.com/FriendsOfPHP/pickle/releases/latest/download/pickle.phar \
	&& chmod +x pickle.phar \
	&& mv pickle.phar pickle \
	&& mv pickle /usr/bin/

# Setup document root
RUN mkdir -p /var/www/html

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN addgroup -S webuser && adduser -S webuser -G webuser
RUN chown -R webuser.webuser /var/www/html && \
	chown -R webuser.webuser /run && \
	chown -R webuser.webuser /var/lib/nginx && \
	chown -R webuser.webuser /var/log/nginx && \
	chown -R webuser.webuser /var/log/php83
USER webuser

# Add application
WORKDIR /var/www/html

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
