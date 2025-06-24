FROM alpine:3.22
LABEL Maintainer="Michael Henry <mikethenry@proton.me>"
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
	php84 \
	php84-ctype \
	php84-curl \
	php84-dom \
	php84-dev \
	php84-fileinfo \
	php84-fpm \
	php84-gd \
	php84-iconv \
	php84-intl \
	php84-json \
	php84-mbstring \
	php84-mysqli \
	php84-opcache \
	php84-openssl \
	php84-pcntl \
	php84-phar \
	php84-pdo \
	php84-session \
	php84-simplexml \
	php84-tokenizer \
	php84-xml \
	php84-xmlreader \
	php84-xmlwriter \
	php84-zlib \
	php84-zip \
	supervisor \
	wget

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php84/php-fpm.d/www.conf
COPY config/php.ini /etc/php84/conf.d/custom.ini

# Normalize version specific php & phpize & php-config
RUN ln -sf /usr/bin/php84 /usr/bin/php
RUN ln -sf /usr/bin/phpize84 /usr/bin/phpize
RUN ln -sf /usr/bin/php-config84 /usr/bin/php-config
RUN ln -sf /etc/php84 /etc/php

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
RUN chown -R webuser:webuser /var/www/html && \
	chown -R webuser:webuser /run && \
	chown -R webuser:webuser /var/lib/nginx && \
	chown -R webuser:webuser /var/log/nginx && \
	chown -R webuser:webuser /var/log/php84
USER webuser

# Add application
WORKDIR /var/www/html

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
