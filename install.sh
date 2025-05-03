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
EXPO_TOKEN="${EXPO_TOKEN}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"

# =====================================
# System Configuration
# =====================================
# Define system paths and PHP settings
APP_DIR="/var/www/linkuy_connect_services"
LOG_DIR="/var/log"
PHP_MEMORY_LIMIT="256M"
PHP_MAX_EXECUTION_TIME="300"
PHP_MAX_INPUT_VARS="2000"

# =====================================
# Ensure required directories exist
# =====================================
mkdir -p /var/www
mkdir -p "$LOG_DIR"

# =====================================
# Update and Install Required Packages
# =====================================
dnf update -y
dnf install -y \
  php-cli php-fpm php-pgsql php-pdo php-mbstring php-xml php-bcmath php-curl php-sodium php-intl \
  unzip git nginx htop python3 python3-pip

# =====================================
# Install Supervisor using pip
# =====================================
pip install supervisor
mkdir -p /etc/supervisor/conf.d
echo_supervisord_conf > /etc/supervisor/supervisord.conf

# Add conf.d directory to supervisor config
cat <<'EOF' >> /etc/supervisor/supervisord.conf
[include]
files = /etc/supervisor/conf.d/*.conf
EOF

# Create supervisor systemd service
cat <<'EOF' > /usr/lib/systemd/system/supervisord.service
[Unit]
Description=Process Monitoring and Control Daemon
After=rc-local.service nss-user-lookup.target

[Service]
Type=forking
ExecStart=/usr/local/bin/supervisord -c /etc/supervisor/supervisord.conf

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable supervisor
systemctl daemon-reload
systemctl enable supervisord
systemctl start supervisord

# =====================================
# Configure Git safe directory
# =====================================
git config --global --add safe.directory "$APP_DIR" || true

# =====================================
# Configure PHP-FPM for Nginx
# =====================================
sed -i 's/^user = .*/user = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/^group = .*/group = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/^listen = .*/listen = \/run\/php-fpm\/www.sock/g' /etc/php-fpm.d/www.conf
sed -i 's/^listen.owner = .*/listen.owner = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/^listen.group = .*/listen.group = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/^listen.mode = .*/listen.mode = 0660/g' /etc/php-fpm.d/www.conf

# =====================================
# Configure PHP settings
# =====================================
sed -i "s/^memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/" /etc/php.ini
sed -i "s/^max_execution_time = .*/max_execution_time = $PHP_MAX_EXECUTION_TIME/" /etc/php.ini
sed -i "s/^max_input_vars = .*/max_input_vars = $PHP_MAX_INPUT_VARS/" /etc/php.ini
sed -i 's/^;date.timezone =.*/date.timezone = UTC/' /etc/php.ini
sed -i 's/^expose_php = On/expose_php = Off/' /etc/php.ini

# =====================================
# Optimize Opcache settings for Production
# =====================================
if [ -f /etc/php.d/10-opcache.ini ]; then
    sed -i 's/^;opcache.enable=1/opcache.enable=1/' /etc/php.d/10-opcache.ini
    sed -i 's/^;opcache.memory_consumption=128/opcache.memory_consumption=128/' /etc/php.d/10-opcache.ini
    sed -i 's/^;opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=8/' /etc/php.d/10-opcache.ini
    sed -i 's/^;opcache.max_accelerated_files=10000/opcache.max_accelerated_files=10000/' /etc/php.d/10-opcache.ini
    sed -i 's/^;opcache.validate_timestamps=1/opcache.validate_timestamps=0/' /etc/php.d/10-opcache.ini
    sed -i 's/^;opcache.revalidate_freq=2/opcache.revalidate_freq=0/' /etc/php.d/10-opcache.ini
    sed -i 's/^;opcache.fast_shutdown=0/opcache.fast_shutdown=1/' /etc/php.d/10-opcache.ini
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
mkdir -p "$APP_DIR/var"
mkdir -p "$APP_DIR/public"

# =====================================
# Set Correct Permissions for Application Directory
# =====================================
chown -R nginx:nginx "$APP_DIR"
chmod -R 775 "$APP_DIR/var"
chmod -R 755 "$APP_DIR/public"

# =====================================
# Adjust permissions for Symfony generated files
# =====================================
if [ -f "$APP_DIR/.env.local.php" ]; then
    chown nginx:nginx "$APP_DIR/.env.local.php"
    chmod 644 "$APP_DIR/.env.local.php"
fi

# =====================================
# Create .env.prod with Production Variables
# =====================================
cat <<EOF > "$APP_DIR/.env.prod"
APP_ENV=prod
APP_DEBUG=0

###> doctrine/doctrine-bundle ###
DATABASE_URL="pgsql://${DB_USERNAME}:${DB_PASSWORD}@${RDS_ENDPOINT}/${DB_NAME}?serverVersion=${RDS_ENGINE_VERSION}&charset=utf8"
###< doctrine/doctrine-bundle ###

###> aws ###
AWS_REGION="${AWS_REGION}"
AWS_SDK_VERSION="latest"
AWS_SQS_QUEUE_URL="${SQS_QUEUE_URL}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
###< aws ###

###> symfony/expo-notifier ###
EXPO_DSN="expo://${EXPO_TOKEN}@default"
###< symfony/expo-notifier ###
EOF

chown nginx:nginx "$APP_DIR/.env.prod"
chmod 600 "$APP_DIR/.env.prod"

# =====================================
# Set Production Environment Variables and Prepare Environment File
# =====================================
export APP_ENV=prod
export APP_DEBUG=0
composer dump-env prod

# =====================================
# Run Doctrine Migrations
# =====================================
echo "Running database migrations..."
sudo -u nginx php bin/console doctrine:migrations:migrate --no-interaction
if [ $? -ne 0 ]; then
    echo "Error: Database migrations failed"
    exit 1
fi

# =====================================
# Clear and Warm Up Symfony Cache for Production (executed as nginx)
# =====================================
sudo -u nginx php bin/console cache:clear
sudo -u nginx php bin/console cache:warmup

# =====================================
# Fix permissions for Symfony cache and log directories (if generated)
# =====================================
if [ -d "$APP_DIR/var/cache" ]; then
    chown -R nginx:nginx "$APP_DIR/var/cache"
    chmod -R 775 "$APP_DIR/var/cache"
fi

if [ -d "$APP_DIR/var/log" ]; then
    chown -R nginx:nginx "$APP_DIR/var/log"
    chmod -R 775 "$APP_DIR/var/log"
fi

# =====================================
# Install assets and generate JWT keypair (executed as nginx)
# =====================================
sudo -u nginx php bin/console assets:install --symlink --relative
sudo -u nginx php bin/console lexik:jwt:generate-keypair --skip-if-exists --no-interaction

# =====================================
# Configure PHP Memory Limit and Supervisor
# =====================================
# Create Supervisor configuration for SQS message processor
cat <<'EOF' > /etc/supervisor/conf.d/sqs-processor.conf
[program:sqs-processor]
command=php -d memory_limit=256M /var/www/linkuy_connect_services/bin/console app:process-sqs-messages
directory=/var/www/linkuy_connect_services
user=nginx
autostart=true
autorestart=true
startretries=3
stderr_logfile=/var/log/sqs-processor.err.log
stdout_logfile=/var/log/sqs-processor.out.log
environment=APP_ENV="prod"
EOF

# Set proper permissions for Supervisor config
chmod 644 /etc/supervisor/conf.d/sqs-processor.conf

# Create log files and set permissions
touch "$LOG_DIR/sqs-processor.err.log" "$LOG_DIR/sqs-processor.out.log"
chown nginx:nginx "$LOG_DIR/sqs-processor.err.log" "$LOG_DIR/sqs-processor.out.log"
chmod 644 "$LOG_DIR/sqs-processor.err.log" "$LOG_DIR/sqs-processor.out.log"

# Create systemd service for senior inactivity check
cat <<'EOF' > /etc/systemd/system/senior-inactivity.service
[Unit]
Description=Senior Inactivity Check Service
After=network.target

[Service]
Type=simple
User=nginx
ExecStart=/usr/bin/php -d memory_limit=256M /var/www/linkuy_connect_services/bin/console app:check-senior-inactivity
StandardOutput=append:/var/log/senior-inactivity.log
StandardError=append:/var/log/senior-inactivity.log

[Install]
WantedBy=multi-user.target
EOF

# Create systemd timer for senior inactivity check
cat <<'EOF' > /etc/systemd/system/senior-inactivity.timer
[Unit]
Description=Run Senior Inactivity Check every 5 minutes

[Timer]
OnCalendar=*:0/5
Unit=senior-inactivity.service

[Install]
WantedBy=timers.target
EOF

# Set proper permissions for systemd files
chmod 644 /etc/systemd/system/senior-inactivity.service
chmod 644 /etc/systemd/system/senior-inactivity.timer

# Create and set permissions for the log file
touch /var/log/senior-inactivity.log
chown nginx:nginx /var/log/senior-inactivity.log
chmod 644 /var/log/senior-inactivity.log

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

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";

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
# Start and Enable All Services
# =====================================
# Reload systemd to recognize new services
systemctl daemon-reload

# Enable and start services
systemctl enable senior-inactivity.timer
systemctl start senior-inactivity.timer
systemctl restart supervisord
systemctl restart nginx
systemctl restart php-fpm

# Verify all services are running
if ! systemctl is-active --quiet senior-inactivity.timer; then
    echo "Error: senior-inactivity.timer failed to start"
    exit 1
fi

if ! systemctl is-active --quiet supervisord; then
    echo "Error: supervisord failed to start"
    exit 1
fi

if ! systemctl is-active --quiet nginx; then
    echo "Error: nginx failed to start"
    exit 1
fi

if ! systemctl is-active --quiet php-fpm; then
    echo "Error: php-fpm failed to start"
    exit 1
fi

echo "All services started successfully"
