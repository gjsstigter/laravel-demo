# syntax=docker/dockerfile:1.7

FROM dunglas/frankenphp:1.10.1-php8.4 AS php-deps

WORKDIR /app

RUN install-php-extensions \
    bcmath \
    intl \
    opcache \
    pcntl \
    pdo_mysql \
    pdo_pgsql \
    pdo_sqlite \
    zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --prefer-dist \
    --optimize-autoloader \
    --no-scripts

COPY . .
RUN composer dump-autoload --classmap-authoritative --no-dev --no-interaction

FROM node:22-alpine AS frontend-build

WORKDIR /app

COPY package.json ./
RUN npm install

COPY resources ./resources
COPY vite.config.js ./vite.config.js
RUN npm run build

FROM dunglas/frankenphp:1.10.1-php8.4 AS app

WORKDIR /app

RUN install-php-extensions \
    bcmath \
    intl \
    opcache \
    pcntl \
    pdo_mysql \
    pdo_pgsql \
    pdo_sqlite \
    zip

COPY --from=php-deps /app /app
COPY --from=frontend-build /app/public/build /app/public/build
COPY Caddyfile /etc/caddy/Caddyfile

RUN mkdir -p storage/framework/cache storage/framework/sessions storage/framework/testing storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R ug+rwx storage bootstrap/cache

ENV APP_ENV=production
ENV APP_DEBUG=false

EXPOSE 80

CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]

