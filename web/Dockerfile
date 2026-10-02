FROM php:8.2-fpm

# Base image is Debian trixie: `docker-cli` exists there (it does NOT in bookworm).
RUN apt-get update && apt-get install -y --no-install-recommends $PHPIZE_DEPS openssh-server docker-cli net-tools iputils-ping ca-certificates && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/sshd && echo 'root:root' | chpasswd && sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN docker-php-ext-install pdo_mysql

# printf answers pecl's interactive configure prompts
RUN printf '\n\n\n\n\n' | pecl install redis && docker-php-ext-enable redis

# FPM must listen on the bridge, not on loopback
RUN sed -i 's#^listen = 127.0.0.1:9000#listen = 0.0.0.0:9000#' /usr/local/etc/php-fpm.d/www.conf

COPY redis-session.ini /usr/local/etc/php/conf.d/zz-redis-session.ini

EXPOSE 9000 22
CMD ["sh", "-c", "/usr/sbin/sshd && exec php-fpm -F"]
