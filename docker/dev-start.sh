#!/usr/bin/env bash
set -e
cd /var/www/html

echo "[dev-start] Laravel Octane (Swoole) bootstrap"

# 1) Ensure .env exists
if [ ! -f .env ]; then
  [ -f .env.example ] && cp .env.example .env || touch .env
fi

# 2) Patch DB_* from environment (with safe defaults)
: "${DB_CONNECTION:=mysql}"
: "${DB_HOST:=db}"
: "${DB_PORT:=3306}"
: "${DB_DATABASE:=laravel}"
: "${DB_USERNAME:=laravel}"
: "${DB_PASSWORD:=laravel}"

patch_env () {
  key="$1"; val="$2"
  if grep -qE "^${key}=" .env; then
    sed -i -E "s|^${key}=.*|${key}=${val}|" .env
  else
    echo "${key}=${val}" >> .env
  fi
}
patch_env DB_CONNECTION "$DB_CONNECTION"
patch_env DB_HOST "$DB_HOST"
patch_env DB_PORT "$DB_PORT"
patch_env DB_DATABASE "$DB_DATABASE"
patch_env DB_USERNAME "$DB_USERNAME"
patch_env DB_PASSWORD "$DB_PASSWORD"

# 3) APP_KEY if missing
php artisan key:generate || true

# 4) Verify PHP extensions for Octane Swoole
if ! php -m | grep -qi swoole; then
  echo "[ERROR] PHP ext-swoole is not installed in this image. Install via PECL and enable it."
  exit 1
fi
if ! php -m | grep -qi pcntl; then
  echo "[ERROR] PHP ext-pcntl is not installed in this image. Install docker-php-ext-install pcntl."
  exit 1
fi

# 5) Ensure Octane package installed
if [ ! -f composer.json ]; then
  composer init --no-interaction || true
fi
if ! grep -qi 'laravel/octane' composer.json 2>/dev/null; then
  composer require laravel/octane --no-interaction --no-progress
fi
php artisan octane:install --server=swoole --no-interaction || true

# 6) Ensure chokidar (local) for --watch
if ! node -e "require.resolve('chokidar')" >/dev/null 2>&1; then
  test -f package.json || npm init -y >/dev/null 2>&1 || true
  npm i -D chokidar --no-audit --no-fund
fi

# 7) Run Octane (Swoole) with watch in dev
exec php artisan octane:start --server=swoole --host=0.0.0.0 --port=8000 --watch
