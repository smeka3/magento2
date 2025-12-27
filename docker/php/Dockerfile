FROM php:8.2-fpm

# Install OS packages required for Magento runtime
RUN apt-get update \
    && apt-get install -y \
        git \
        unzip \
        libzip-dev \
        libicu-dev \
        libxml2-dev \
        libxslt1-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libwebp-dev \
        libonig-dev \
        libsodium-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        librabbitmq-dev \
        libgmp-dev \
        zlib1g-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        ftp \
        gd \
        intl \
        pdo_mysql \
        soap \
        xsl \
        zip \
        sockets \
        pcntl \
        opcache \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy Composer from the official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

ENV PHP_MEMORY_LIMIT=2G \
    COMPOSER_MEMORY_LIMIT=-1

# Basic php.ini overrides suited for Magento dev
RUN { \
    echo "memory_limit=${PHP_MEMORY_LIMIT}"; \
    echo "max_execution_time=1800"; \
    echo "opcache.enable=1"; \
    echo "opcache.enable_cli=1"; \
    echo "opcache.validate_timestamps=1"; \
    echo "opcache.revalidate_freq=0"; \
    echo "session.save_handler=redis"; \
    echo "session.save_path=tcp://redis:6379"; \
    echo "realpath_cache_size=10M"; \
    echo "realpath_cache_ttl=7200"; \
} > /usr/local/etc/php/conf.d/magento.ini
