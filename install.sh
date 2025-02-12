#!/bin/bash
set -e

# ==============================
# Cargar Variables desde Terraform
# ==============================
AWS_REGION="${AWS_REGION}"
RDS_ENDPOINT="${RDS_ENDPOINT}"
RDS_ENGINE_VERSION="${RDS_ENGINE_VERSION}"
DB_USERNAME="${DB_USERNAME}"
DB_PASSWORD="${DB_PASSWORD}"
DB_NAME="${DB_NAME}"
SQS_QUEUE_URL="${SQS_QUEUE_URL}"
SNS_TOPIC_ARN="${SNS_TOPIC_ARN}"

# ==============================
# Instalar PHP, PostgreSQL, Composer y Nginx
# ==============================
sudo dnf update -y
sudo dnf install -y php-cli php-fpm php-pgsql php-pdo php-mbstring php-xml php-bcmath php-curl unzip git nginx

# ==============================
# Configurar PHP-FPM para Nginx
# ==============================
sudo sed -i 's/^user = .*/user = nginx/g' /etc/php-fpm.d/www.conf
sudo sed -i 's/^group = .*/group = nginx/g' /etc/php-fpm.d/www.conf
sudo systemctl enable --now php-fpm

# ==============================
# Instalar Composer y Symfony CLI
# ==============================
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

curl -sS https://get.symfony.com/cli/installer | bash
mv /root/.symfony/bin/symfony /usr/local/bin/symfony

# ==============================
# Descargar Código de Symfony
# ==============================
cd /var/www
sudo git clone --branch main https://github.com/nicolasmoreira/linkuy_connect_services.git
cd linkuy_connect_services

# ==============================
# Instalar Dependencias
# ==============================
composer install --no-dev --optimize-autoloader

# ==============================
# Configurar Permisos Correctos
# ==============================
sudo chown -R nginx:nginx /var/www/linkuy_connect_services
sudo chmod -R 775 /var/www/linkuy_connect_services/var
sudo chmod -R 775 /var/www/linkuy_connect_services/public

# ==============================
# Crear .env.local con Variables de Terraform
# ==============================
sudo cat <<EOF > /var/www/linkuy_connect_services/.env.local
###> doctrine/doctrine-bundle ###
DATABASE_URL="pgsql://${DB_USERNAME}:${DB_PASSWORD}@${RDS_ENDPOINT}:5432/${DB_NAME}?serverVersion=${RDS_ENGINE_VERSION}&charset=utf8"
###< doctrine/doctrine-bundle ###

###> aws ###
AWS_REGION="${AWS_REGION}"
AWS_SDK_VERSION="latest"
AWS_SQS_QUEUE_URL="${SQS_QUEUE_URL}"
AWS_SNS_TOPIC_ARN="${SNS_TOPIC_ARN}"
###< aws ###

###> symfony/expo-notifier ###
EXPO_DSN="expo://TOKEN@default"
###< symfony/expo-notifier ###
EOF

# ==============================
# Configurar Nginx para Symfony
# ==============================
sudo cat <<EOF > /etc/nginx/conf.d/linkuy_connect_services.conf
server {
    listen 80;
    server_name _;
    root /var/www/linkuy_connect_services/public;
    index index.php index.html;

    location / {
        try_files \$uri /index.php\$is_args\$args;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
    }

    location ~ \.php$ {
        deny all;
    }

    error_log /var/log/nginx/linkuy_connect_services_error.log;
    access_log /var/log/nginx/linkuy_connect_services_access.log;
}
EOF

# ==============================
# Reiniciar Nginx
# ==============================
sudo systemctl enable --now nginx

echo "🚀 Symfony + PHP 8.2 + Nginx instalado y listo con variables de Terraform!"
