# Setup PHP
FROM php:8.2-cli-alpine3.17

LABEL maintainer="JHIH-SIOU LI"

ENV TZ=UTC
ENV ENV="/root/.ashrc"
ENV DEBIAN_FRONTEND noninteractive

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN set -eux; \
    chmod +x /usr/local/bin/install-php-extensions \
    # Install persistent / runtime deps
    && apk --update add --no-cache tzdata gnupg su-exec zip unzip git supervisor sqlite libcap nodejs npm \
    # Install PHP extensions
    && install-php-extensions pcntl ldap redis intl soap imap pdo_mysql pcov msgpack bcmath igbinary gd zip opcache @composer

# Clean up
RUN rm -rf /usr/share/php /usr/share/php8 /usr/src/* /usr/local/bin/phpdbg \
        /usr/local/bin/install-php-extensions /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    # Miscellany
    && setcap "cap_net_bind_service=+ep" /usr/local/bin/php \
    && adduser --disabled-password --gecos "" -u 1337 -s /bin/sh -G www-data sail \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Setup working directory & environment
RUN mkdir /app
ADD . /app
COPY staging/.env.staging /app/.env
COPY staging/nginx.conf /etc/nginx/nginx.conf
COPY staging/database.sqlite /app/database/database.sqlite
COPY staging/php-fpm.conf /usr/local/etc/php-fpm.conf
WORKDIR /app

# Install dependencies
RUN composer update
RUN composer install --optimize-autoloader --no-dev
RUN composer require fakerphp/faker
RUN npm ci && npm run build

# Laravel settings
RUN php artisan key:generate
RUN php artisan storage:link

# Laravel Optimizations
RUN php artisan optimize:clear
RUN php artisan config:clear

# Get the database ready
RUN php artisan migrate:refresh --seed

# start the application
#CMD nginx -g "daemon off;"
CMD php artisan serve --host=0.0.0.0 --port=8000
EXPOSE 8000

