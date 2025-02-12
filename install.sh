#!/bin/bash
set -e

# =====================================
# Load Variables from Terraform
# =====================================
AWS_REGION="${AWS_REGION}"
RDS_ENDPOINT="${RDS_ENDPOINT}"
RDS_ENGINE_VERSION="${RDS_ENGINE_VERSION}"
DB_USERNAME="${DB_USERNAME}"
DB_PASSWORD="${DB_PASSWORD}"
DB_NAME="${DB_NAME}"
SQS_QUEUE_URL="${SQS_QUEUE_URL}"
SNS_TOPIC_ARN="${SNS_TOPIC_ARN}"

# =====================================
# Ensure /var/www exists
# =====================================
mkdir -p /var/www

# =====================================
# Install Required Packages
# =====================================
dnf update -y
dnf install -y \
  php-cli php-fpm php-pgsql php-pdo php-mbstring php-xml php-bcmath php-curl php-sodium \
  unzip git nginx

# Configurar Git para que considere seguro el directorio del repositorio (evita error de "dubious ownership")
git config --global --add safe.directory /var/www/linkuy_connect_services || true

# =====================================
# Configure PHP-FPM for Nginx
# =====================================
sed -i 's/^user = .*/user = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/^group = .*/group = nginx/g' /etc/php-fpm.d/www.conf
systemctl enable --now php-fpm

# =====================================
# Optimize Opcache settings for Production
# =====================================
if [ -f /etc/php.d/10-opcache.ini ]; then
    sed -i 's/^;opcache.enable=1/opcache.enable=1/' /etc/php.d/10-opcache.ini
    sed -i 's/^;opcache.memory_consumption=128/opcache.memory_consumption=128/' /etc/php.d/10-opcache.ini
    sed -i 's/^;opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=8/' /etc/php.d/10-opcache.ini
    sed -i 's/^;opcache.max_accelerated_files=10000/opcache.max_accelerated_files=10000/' /etc/php.d/10-opcache.ini
    sed -i 's/^;opcache.validate_timestamps=1/opcache.validate_timestamps=0/' /etc/php.d/10-opcache.ini
fi

# =====================================
# Install Composer
# =====================================
export COMPOSER_HOME=/root/.composer
export COMPOSER_MEMORY_LIMIT=-1
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# =====================================
# Download Symfony Code
# =====================================
cd /var/www
if [ -d "linkuy_connect_services" ]; then
    rm -rf linkuy_connect_services
fi
git clone --branch main https://github.com/nicolasmoreira/linkuy_connect_services.git
cd linkuy_connect_services

# =====================================
# Install Dependencies (Production Mode)
# =====================================
composer install --no-dev --optimize-autoloader --no-scripts --no-interaction || { echo "Error in composer install"; exit 1; }

# =====================================
# Ensure required directories exist
# =====================================
mkdir -p /var/www/linkuy_connect_services/var
mkdir -p /var/www/linkuy_connect_services/public

# =====================================
# Set Correct Permissions
# =====================================
chown -R nginx:nginx /var/www/linkuy_connect_services
chmod -R 775 /var/www/linkuy_connect_services/var
chmod -R 755 /var/www/linkuy_connect_services/public

# =====================================
# Create .env.prod with Production Variables
# =====================================
cat <<EOF > /var/www/linkuy_connect_services/.env.prod
APP_ENV=prod
APP_DEBUG=0

###> doctrine/doctrine-bundle ###
DATABASE_URL="pgsql://${DB_USERNAME}:${DB_PASSWORD}@${RDS_ENDPOINT}/${DB_NAME}?serverVersion=${RDS_ENGINE_VERSION}&charset=utf8"
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

chown nginx:nginx /var/www/linkuy_connect_services/.env.prod
chmod 600 /var/www/linkuy_connect_services/.env.prod

# =====================================
# Set Production Environment Variables and Prepare Environment File
# =====================================
export APP_ENV=prod
export APP_DEBUG=0
composer dump-env prod

# =====================================
# Clear and Warm Up Symfony Cache for Production
# =====================================
php bin/console cache:clear
php bin/console cache:warmup

# =====================================
# Install assets and generate JWT keypair
# =====================================
php bin/console assets:install --symlink --relative
php bin/console lexik:jwt:generate-keypair --skip-if-exists --no-interaction

# =====================================
# (Optional) Update Doctrine Schema
# =====================================
# php bin/console doctrine:schema:update --force

# =====================================
# Configure Nginx for Symfony using HTTP only
# =====================================
cat <<'EOF' > /etc/nginx/conf.d/linkuy_connect_services.conf
server {
    listen 80;
    server_name _;
    root /var/www/linkuy_connect_services/public;
    index index.php index.html;

    # Disable HTTP header disclosure
    server_tokens off;
    proxy_pass_header Server;

    # Enable gzip compression for improved performance
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
        internal;
    }

    location ~ \.php$ {
        deny all;
    }

    error_log /var/log/nginx/linkuy_connect_services_error.log;
    access_log /var/log/nginx/linkuy_connect_services_access.log;
}
EOF

# =====================================
# Restart and Enable Services
# =====================================
systemctl daemon-reexec
systemctl restart php-fpm
systemctl restart nginx
systemctl enable php-fpm nginx

echo "Symfony + PHP 8.2 + Nginx installed and configured for production using HTTP only."
