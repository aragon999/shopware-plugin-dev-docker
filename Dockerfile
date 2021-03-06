FROM php:7.4-cli-alpine

ARG SHOPWARE_VERSION=dev-master
ARG TEMPLATE_REPOSITORY=https://github.com/shopware/production
ARG PLUGIN_UPLOADER_VERSION=0.3.2

COPY --from=composer:2.0 /usr/bin/composer /usr/bin/composer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/

COPY rootfs/ /
ENV PATH="/opt/bin:/opt/shopware/bin:${PATH}"

RUN \
    apk add --no-cache git zip unzip zlib-dev libpng-dev icu-dev libzip-dev bash \
        mysql mysql-client npm python3 make g++ && \
    echo 'alias ll="ls -lha"' >> ~/.bashrc && \
    install-php-extensions gd intl pdo_mysql zip

RUN \
    mysql_install_db --datadir=/var/lib/mysql --user=mysql && \
    echo "pdo_mysql.default_socket=/run/mysqld/mysqld.sock" > /usr/local/etc/php/conf.d/pdo_mysql.ini && \
    echo "mysqli.default_socket=/run/mysqld/mysqld.sock" > /usr/local/etc/php/conf.d/mysqli.ini && \
    echo "memory_limit=1G" > /usr/local/etc/php/conf.d/memory.ini && \
    mkdir /run/mysqld/ && chown -R mysql:mysql /run/mysqld/

ENV SHOPWARE_BUILD_DIR /opt/shopware

RUN \
    start-mysql && \
    mysql -e "CREATE DATABASE shopware" && \
    mysqladmin --user=root password 'root' && \
    mkdir -p /opt/shopware && \
    git clone -b ${SHOPWARE_VERSION} --depth 1 "${TEMPLATE_REPOSITORY}" "${SHOPWARE_BUILD_DIR}" && \
    cd "${SHOPWARE_BUILD_DIR}" && \
        composer install --no-interaction -o && \
        php bin/console system:setup --database-url=mysql://root:root@localhost:3306/shopware --generate-jwt-keys -nq && \
        php bin/console system:install -fnq --create-database && \
        composer clearcache && \
        rm -rf "${SHOPWARE_BUILD_DIR}/custom/plugins" && \
        mkdir -p /plugins && ln -s /plugins "${SHOPWARE_BUILD_DIR}/custom/plugins" && \
    wget https://github.com/FriendsOfShopware/FroshPluginUploader/releases/download/${PLUGIN_UPLOADER_VERSION}/frosh-plugin-upload.phar -O /opt/bin/plugin-uploader && \
    chmod +x /opt/bin/plugin-uploader

VOLUME /plugins
WORKDIR /opt/shopware
