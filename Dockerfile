# -----------------------------
# Builder stage
# -----------------------------
FROM alpine:3.22 AS builder

LABEL Maintainer="Michael Henry <mikethenry@proton.me>"
LABEL Description="Builder for Alpine + PHP 8.4"

# Install build dependencies
RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
        curl \
        g++ \
        gcc \
        make \
        musl-dev && \
    \
    # Download pickle.phar
    for i in 1 2 3 4 5; do \
        curl -sSL -o /tmp/pickle.phar https://github.com/FriendsOfPHP/pickle/releases/latest/download/pickle.phar && break || sleep 5; \
    done; \
    chmod +x /tmp/pickle.phar && \
    \
    # Download multirun
    for i in 1 2 3 4 5; do \
        curl -sSL -o /tmp/multirun.tar.gz https://github.com/nicolas-van/multirun/releases/download/1.1.3/multirun-x86_64-linux-gnu-1.1.3.tar.gz && \
		tar -xzf /tmp/multirun.tar.gz -C /tmp && \
        chmod +x /tmp/multirun && break || sleep 5; \
    done

# Copy configuration files
COPY ./config/ /tmp/config/

# -----------------------------
# Runtime stage
# -----------------------------
FROM alpine:3.22 AS runtime

LABEL Maintainer="Michael Henry <mikethenry@proton.me>"
LABEL Description="Production Alpine container with Nginx & PHP-FPM"

# Copy config files, pickle, and multirun
COPY --from=builder /tmp/config/ /tmp/config/
COPY --from=builder /tmp/pickle.phar /usr/bin/pickle
COPY --from=builder /tmp/multirun /usr/local/bin/multirun

# Install runtime packages
RUN set -eux; \
    \
	# Create directories and non-root user
	mkdir -p \
		/etc/nginx \
		/etc/php84/conf.d \
		/etc/php84/php-fpm.d \
		/var/www/html \
		/run \
		/var/lib/nginx \
		/var/log/nginx \
		/var/log/php84 && \
    addgroup -S -g 1000 webuser && \
    adduser -S -u 1000 -G webuser -h /var/www/html -s /bin/sh webuser && \
	\
	# Install runtime packages
    apk add --no-cache \
        gcompat \
        nginx \
        php84 \
        php84-ctype \
        php84-curl \
        php84-dom \
        php84-fileinfo \
        php84-fpm \
        php84-gd \
        php84-iconv \
        php84-intl \
        php84-json \
        php84-mbstring \
        php84-opcache \
        php84-openssl \
        php84-pcntl \
        php84-phar \
        php84-session \
        php84-simplexml \
        php84-tokenizer \
        php84-xml \
        php84-xmlreader \
        php84-xmlwriter \
        php84-zlib \
        php84-zip && \
    \
    # Upgrade all packages to latest versions
    apk upgrade --no-cache && \
	\
	# Move configuration files into place and normalize PHP binaries
	mv /tmp/config/nginx.conf /etc/nginx/nginx.conf && \
    mv /tmp/config/fpm-pool.conf /etc/php84/php-fpm.d/www.conf && \
    mv /tmp/config/php.ini /etc/php84/conf.d/custom.ini && \
    ln -sf /usr/bin/php84 /usr/bin/php && \
    ln -sf /usr/bin/phpize84 /usr/bin/phpize && \
    ln -sf /usr/bin/php-config84 /usr/bin/php-config && \
    ln -sf /etc/php84 /etc/php && \
	\
	# Set ownership and permissions for non-root user
	chown -R webuser:webuser /var/www/html /run /var/lib/nginx /var/log/nginx /var/log/php84 && \
	\
	# Cleanup
	rm -rf \
		/var/cache/apk/* \
		/usr/share/man \
		/usr/share/doc \
		/usr/share/info \
		/tmp/*

# Switch user, set workdir, and expose port
USER webuser
WORKDIR /var/www/html
EXPOSE 8080

# Use multirun to manage both processes
# If either php-fpm or nginx exits, multirun kills the other and exits the container
CMD ["/usr/local/bin/multirun", "php-fpm84 -F", "nginx -g 'daemon off;'"]
