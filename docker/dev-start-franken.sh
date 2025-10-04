#!/usr/bin/env bash
set -e
cd /var/www/html

# Ensure Laravel project exists
if [ ! -f artisan ]; then
  composer create-project laravel/laravel . --prefer-dist --no-interaction
fi

# Ensure .env exists
if [ ! -f .env ]; then
  [ -f .env.example ] && cp .env.example .env || touch .env
fi

# Patch DB_* from environment or use defaults
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

# App key
php artisan key:generate || true

# Ensure Octane installed for FrankenPHP
if ! php -r "file_exists('vendor/autoload.php') && include 'vendor/autoload.php';"; then
  composer install --no-interaction
fi
if ! grep -qi octane composer.json 2>/dev/null; then
  composer require laravel/octane --no-interaction --no-progress
fi
php artisan octane:install --server=frankenphp --no-interaction || true

# Watcher: need local chokidar (not global)
if ! node -e "require.resolve('chokidar')" >/dev/null 2>&1; then
  test -f package.json || npm init -y >/dev/null 2>&1 || true
  npm i -D chokidar --no-audit --no-fund
fi

# Start Octane with FrankenPHP
exec php artisan octane:start --server=frankenphp --host=0.0.0.0 --port=8000 --watch
