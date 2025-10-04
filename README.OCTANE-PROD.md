# Laravel Octane Production Multi-Runtime Starter

> **Run Laravel Octane with either Swoole or FrankenPHP** using Docker. This starter provides dev and production setups, automatic environment bootstrapping, and practical troubleshooting notes tailored for containerized workflows.

---

## Table of Contents
- [Overview](#overview)
- [Directory Layout](#directory-layout)
- [Prerequisites](#prerequisites)
- [Initialization (First-Time Setup)](#initialization-first-time-setup)
  - [Option A — Init Compose Stack](#option-a--init-compose-stack)
  - [Option B — One-off Run](#option-b--one-off-run)
- [Development](#development)
  - [A) Swoole Dev (`docker-compose.octane.dev.yml`)](#a-swoole-dev-docker-composeoctanedevyml)
  - [B) FrankenPHP Dev (`docker-compose.franken.dev.yml`)](#b-frankenphp-dev-docker-composefrankendevyml)
- [Production](#production)
  - [A) Swoole Prod (`docker-compose.octane.prod.yml`)](#a-swoole-prod-docker-composeoctane-prodyml)
  - [B) FrankenPHP Prod (`docker-compose.franken.prod.yml`)](#b-frankenphp-prod-docker-composefrankenprodyml)
- [Environment Auto-Configuration](#environment-auto-configuration)
- [Watcher (`--watch`) & Chokidar](#watcher---watch--chokidar)
- [Troubleshooting](#troubleshooting)
- [Performance Tips](#performance-tips)
- [Optional: Makefile Shortcuts](#optional-makefile-shortcuts)

---

## Overview
This starter supports **two Octane runtimes**:

- **Swoole**: Longstanding high‑performance server for Octane. Requires PHP extensions `pcntl` and `swoole`.
- **FrankenPHP**: Modern PHP application server bundling Caddy, supports worker mode; simpler networking (Nginx optional), great for containerized deploys.

You can keep **both** modes in the same repo and choose at runtime via different Dockerfiles & compose files.

---

## Directory Layout
```
.
├── app/                           # Laravel application source (bind-mounted in dev)
├── docker/
│   ├── nginx.octane.conf          # Nginx (Swoole) reverse proxy (dev/prod variants)
│   ├── dev-start.sh               # Dev start script (Swoole) – .env patch + watcher
│   ├── dev-start-franken.sh       # Dev start script (FrankenPHP) – .env patch + watcher
│   └── php.ini                    # Optional PHP overrides (e.g., disable_functions=)
├── Dockerfile.octane              # Swoole dev/prod stages
├── Dockerfile.franken             # FrankenPHP dev/prod stages
├── docker-compose.octane.init.yml # Bootstrap-only stack (keeps octane alive w/ sleep)
├── docker-compose.octane.dev.yml  # Dev: Swoole + Nginx
├── docker-compose.octane.prod.yml # Prod: Swoole (+ Nginx proxy)
├── docker-compose.franken.dev.yml # Dev: FrankenPHP (no Nginx required)
└── docker-compose.franken.prod.yml# Prod: FrankenPHP (proxy optional)
```

> **Tip**: Keep your infrastructure files in repo root and the Laravel app inside `./app` to avoid `create-project` collisions with Docker files.

---

## Prerequisites
- Docker & Docker Compose v2
- For **Swoole** builds: PHP extensions `pcntl` and `swoole` must be installed in the image (see `Dockerfile.octane`).
- For **FrankenPHP** builds: image `ghcr.io/dunglas/frankenphp:*` (see `Dockerfile.franken`).
- Default dev port is **8080** (mapped to 8000 inside the container).

---

## Initialization (First-Time Setup)
You need a Laravel app in `./app`. Choose one option below. (Added to dev-start script)

### Option A — Init Compose Stack
1. Create the `app` folder:
   ```bash
   mkdir -p app
   ```
2. Start the **init** stack (keeps Octane container alive):
   ```bash
   docker compose -f docker-compose.octane.init.yml up -d --build
   ```
3. Inside the `octane` container, create the app and install Octane:
   ```bash
   docker compose -f docker-compose.octane.init.yml exec octane bash -lc 'set -e; [ -f artisan ] || composer create-project laravel/laravel .; php artisan key:generate || true; composer require laravel/octane --no-interaction --no-progress; php artisan octane:install --server=swoole || true'
   ```
4. Stop the init stack:
   ```bash
   docker compose -f docker-compose.octane.init.yml down
   ```

### Option B — One-off Run
Run Laravel setup without starting the whole stack:
```bash
docker compose -f docker-compose.octane.dev.yml run --rm --no-deps octane \
  bash -lc "composer create-project laravel/laravel . && php artisan key:generate"
```

> If you plan to use **FrankenPHP** dev, you can switch the server during `octane:install` using `--server=frankenphp`.

---

## Development

### A) Swoole Dev (`docker-compose.octane.dev.yml`)
1. **Ensure** `Dockerfile.octane` installs `pcntl` and `swoole`.
2. Start dev stack:
   ```bash
   docker compose -f docker-compose.octane.dev.yml up -d --build
   ```
3. Access the app at: `http://localhost:8080`
4. (First time) Install PHP deps & migrate:
   ```bash
   docker compose -f docker-compose.octane.dev.yml exec octane bash -lc "composer install && php artisan migrate"
   ```
5. **Auto reload** (watch mode): ensure local `chokidar` exists:
   ```bash
   cd app && npm init -y && npm i -D chokidar
   ```
   Then either set in compose:
   ```yaml
   services:
     octane:
       command: ["php","artisan","octane:start","--watch"]
   ```
   or use `docker/dev-start.sh` to auto-install watcher and patch `.env` at startup.

### B) FrankenPHP Dev (`docker-compose.franken.dev.yml`)
1. Start dev stack (no Nginx needed):
   ```bash
   docker compose -f docker-compose.franken.dev.yml up -d --build
   ```
2. Access the app at: `http://localhost:8080`
3. First-time deps & migrate:
   ```bash
   docker compose -f docker-compose.franken.dev.yml exec octane php artisan migrate
   ```
4. Watch mode requires local `chokidar` as well:
   ```bash
   cd app && npm init -y && npm i -D chokidar
   ```
   The provided `docker/dev-start-franken.sh` script auto-installs it and patches `.env`.

---

## Production

### A) Swoole Prod (`docker-compose.octane.prod.yml`)
- Build an optimized image via `Dockerfile.octane` (`target: prod`).
- Run behind Nginx (compose includes an Nginx service) or your preferred reverse proxy.
- Minimal run:
  ```bash
  docker compose -f docker-compose.octane.prod.yml up -d --build
  docker compose -f docker-compose.octane.prod.yml exec octane php artisan migrate --force
  ```
- Make sure your `.env` or environment variables contain:
  ```env
  APP_ENV=production
  APP_DEBUG=false
  DB_CONNECTION=mysql
  DB_HOST=db
  DB_PORT=3306
  DB_DATABASE=laravel
  DB_USERNAME=laravel
  DB_PASSWORD=laravel
  ```

### B) FrankenPHP Prod (`docker-compose.franken.prod.yml`)
- Single service (Nginx optional). Expose `8000` or place a reverse proxy in front.
- Minimal run:
  ```bash
  docker compose -f docker-compose.franken.prod.yml up -d --build
  docker compose -f docker-compose.franken.prod.yml exec octane php artisan migrate --force
  ```
- Env recommendations same as Swoole prod. The FrankenPHP CMD caches config at start to pick up latest ENV values.

---

## Environment Auto-Configuration
For **dev** ergonomics, use a start script that ensures `.env` exists and patches DB settings from container ENV. Example (`docker/dev-start.sh` / `docker/dev-start-franken.sh`):

```bash
# Pseudocode: ensure .env exists
[ -f .env ] || cp .env.example .env || touch .env

# Patch DB_* with safe defaults or values from compose
DB_CONNECTION=${DB_CONNECTION:-mysql}
DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-3306}
DB_DATABASE=${DB_DATABASE:-laravel}
DB_USERNAME=${DB_USERNAME:-laravel}
DB_PASSWORD=${DB_PASSWORD:-laravel}
# sed -i to set or append those keys
```

> In **prod**, prefer passing DB settings via environment variables and run `php artisan config:cache` **at container start**, not at build time, so the container always uses the orchestrator-provided values.

---

## Watcher (`--watch`) & Chokidar
Octane’s file watcher uses Node’s **`chokidar`** and requires it as a **local** dependency:

```bash
cd app
npm init -y           # if package.json is missing
npm install -D chokidar
```

Global installs (`npm i -g`) won’t work because Octane resolves `require('chokidar')` from the project’s `node_modules`.

---

## Performance Tips
- **Swoole**: tune `--workers` and `--task-workers` (via Dockerfile CMD or compose). Enable OPCache (`opcache.enable=1`, `opcache.enable_cli=1`, set generous memory and disable timestamp validation in prod).
- **FrankenPHP**: you can run without Nginx; for TLS/HTTP/2/3, either rely on FrankenPHP’s Caddy or put a reverse proxy in front.
- Cache config/routes/views in prod. Avoid `--watch` in production.

---

## Optional: Makefile Shortcuts
```makefile
init:
	@docker compose -f docker-compose.octane.init.yml up -d --build
	@docker compose -f docker-compose.octane.init.yml exec octane bash -lc "composer create-project laravel/laravel . && php artisan key:generate"
	@docker compose -f docker-compose.octane.init.yml down

up-dev-swoole:
	docker compose -f docker-compose.octane.dev.yml up -d --build

up-dev-franken:
	docker compose -f docker-compose.franken.dev.yml up -d --build

up-prod-swoole:
	docker compose -f docker-compose.octane.prod.yml up -d --build

up-prod-franken:
	docker compose -f docker-compose.franken.prod.yml up -d --build

migrate-dev-swoole:
	docker compose -f docker-compose.octane.dev.yml exec octane php artisan migrate

migrate-dev-franken:
	docker compose -f docker-compose.franken.dev.yml exec octane php artisan migrate
```

---

Happy shipping with Octane — whether you choose **Swoole** or **FrankenPHP**! 🚀

