# -----------------------------
# Builder stage
# -----------------------------
FROM alpine:3.22 AS builder

LABEL Maintainer="Michael Henry <mikethenry@proton.me>"
LABEL Description="Builder for Alpine + glibc + PHP 8.4"

# Install build dependencies
RUN set -eux; \
	apk add --no-cache --virtual .build-deps curl && \
	\
	# Download glibc packages and signing key
	for i in 1 2 3 4 5; do \
        curl -sSL -o /tmp/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && break || sleep 5; \
    done; \
    for i in 1 2 3 4 5; do \
        curl -sSL -o /tmp/glibc.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-2.35-r1.apk && break || sleep 5; \
    done; \
    for i in 1 2 3 4 5; do \
        curl -sSL -o /tmp/glibc-bin.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-bin-2.35-r1.apk && break || sleep 5; \
    done; \
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

# -----------------------------
# Runtime stage
# -----------------------------
FROM alpine:3.22 AS runtime

LABEL Maintainer="Michael Henry <mikethenry@proton.me>"
LABEL Description="Production Alpine container with Nginx & PHP-FPM"

# Copy config files, pickle, multirun, and glibc from builder
COPY ./config/ /tmp/config/
COPY --from=builder /tmp/pickle.phar /usr/bin/pickle
COPY --from=builder /tmp/multirun /usr/local/bin/multirun
COPY --from=builder /tmp/glibc*.apk /tmp/
COPY --from=builder /tmp/sgerrand.rsa.pub /etc/apk/keys/

# Install glibc and runtime packages
RUN set -eux; \
	\
	# Install libgcc first (required dependency for glibc)
	apk add --no-cache libgcc && \
	\
	# Install glibc and glibc-bin without pulling in gcompat
	# Using --no-scripts prevents automatic dependency resolution that would install gcompat
	# gcompat is redundant since we have full glibc
	apk add --no-cache --allow-untrusted --force-overwrite \
		--no-scripts /tmp/glibc.apk /tmp/glibc-bin.apk && \
	\
	# Clean up apk packages
	rm -rf /tmp/glibc*.apk && \
	\
	# Manually create the dynamic linker symlink (normally done by install scripts)
	# This is the standard path where glibc binaries look for the loader
	mkdir -p /lib64 && \
	ln -sf /usr/glibc-compat/lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2 && \
	\
	# Run ldconfig to set up the shared library cache
	echo "/usr/glibc-compat/lib" > /etc/ld.so.conf && \
	/usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib && \
	\
	# Create locale (optional - skip if localedef fails, not critical for most PHP apps)
	/usr/glibc-compat/sbin/localedef -i en_US -f UTF-8 en_US.UTF-8 || echo "Locale generation failed, continuing..." && \
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
