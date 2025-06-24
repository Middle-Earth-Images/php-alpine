FROM alpine:3.22
LABEL Maintainer="Michael Henry <mikethenry@proton.me>"
LABEL Description="Lightweight container with Nginx & PHP based on Alpine Linux."

# Use a safer shell for build instructions
SHELL ["/bin/sh", "-euo", "pipefail", "-c"]

# Install packages and remove default server definition
RUN apk --no-cache upgrade \
    && apk --no-cache add \
		curl \
		gcompat \
		libaio \
		libaio-dev \
		libc6-compat \
		libnsl \
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
		wget \
	&& apk add --no-cache --virtual .build-deps \
		g++ \
		gcc \
		make \
		musl-dev \
		freetds-dev \
	&& wget https://github.com/FriendsOfPHP/pickle/releases/latest/download/pickle.phar \
	&& chmod +x pickle.phar \
	&& mv pickle.phar /usr/bin/pickle \
	&& apk del .build-deps \
	&& find /usr/lib/python3.12/site-packages -type d \( -name "*.dist-info" -o -name "*.egg-info" \) -exec rm -rf {} + \
	&& rm -rf /var/cache/apk/*

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php84/php-fpm.d/www.conf
COPY config/php.ini /etc/php84/conf.d/custom.ini

# Normalize version specific php & phpize & php-config
RUN ln -sf /usr/bin/php84 /usr/bin/php && \
    ln -sf /usr/bin/phpize84 /usr/bin/phpize && \
    ln -sf /usr/bin/php-config84 /usr/bin/php-config && \
    ln -sf /etc/php84 /etc/php

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

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

# Docker HEALTHCHECK (ignored by Kubernetes unless probes are set in the Pod spec)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
	CMD wget -qO- http://localhost:8080 || exit 1

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
