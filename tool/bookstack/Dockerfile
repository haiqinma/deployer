# Stage 1: Build frontend assets
FROM node:22-alpine AS build

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Copy source files for building
COPY resources ./resources
COPY dev ./dev
COPY public ./public

# Install dependencies
RUN npm install && npm rebuild node-sass

# Build assets
RUN npm run production

FROM php:8.3-apache

# Install additional dependencies
RUN apt-get update && \
    apt-get install -y \
        git \
        zip \
        unzip \
        libfreetype-dev \
        libjpeg62-turbo-dev \
        libldap2-dev \
        libpng-dev \
        libzip-dev \
        wait-for-it && \
    rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure ldap --with-libdir="lib/$(gcc -dumpmachine)" && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) pdo_mysql gd ldap zip && \
    pecl install xdebug && \
    docker-php-ext-enable xdebug

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configure apache
RUN a2enmod rewrite && \
    sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf && \
    sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Use the default production configuration and update it as required
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" && \
    sed -i 's/memory_limit = 128M/memory_limit = 512M/g' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/post_max_size = 8M/post_max_size = 2048M/g' "$PHP_INI_DIR/php.ini" && \
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 2048M/g' "$PHP_INI_DIR/php.ini"

ENV APACHE_DOCUMENT_ROOT="/app/public"

WORKDIR /app

# Copy application source
COPY . .

# Copy built frontend assets from the build stage
COPY --from=build /app/public/dist /app/public/dist

# Install PHP dependencies
ARG  GITHUB_TOKEN
RUN set -eux; \
    # 配置 GitHub Token（如果提供）
    if [ -n "$GITHUB_TOKEN" ]; then \
        composer config -g github-oauth.github.com $GITHUB_TOKEN; \
    fi; \
    # 禁用 GitHub API，使用 Packagist
    composer config -g use-github-api false; \
    # 增加超时时间
    composer config -g process-timeout 3000; \
    # 优先使用 dist 包
    composer config -g preferred-install dist; \
    composer install --no-dev --optimize-autoloader --prefer-dist

# Set permissions for storage and cache
RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache

EXPOSE 80
CMD ["apache2-foreground"]
