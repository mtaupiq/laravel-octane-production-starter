# Laravel Octane (Swoole) + Production Variants

This bundle provides **3 deployment variants + 1 initialization variant** to simplify your Laravel app lifecycle:

1) **Octane Dev** (Swoole) behind Nginx → `docker-compose.octane.dev.yml`
2) **Octane Production** (Swoole) behind Nginx → `docker-compose.octane.prod.yml`
3) **Classic Production** (PHP‑FPM + Nginx, multi-stage) → `docker-compose.prod.classic.yml`
4) **Init Project** (dedicated initialization stack) → `docker-compose.octane.init.yml`

---

## Prerequisites
- Project root must contain a `composer.json` (Laravel app). If it’s empty, initialize using one of the **init options** below.
- Docker & Docker Compose v2.
- Default exposed port: `8080` (from Nginx). You can change it in the compose file.

## Key Files Overview
- `docker-compose.octane.dev.yml` — Dev stack (Nginx + Octane/Swoole, hot-ish reload via bind mounts)
- `docker-compose.octane.prod.yml` — Production stack (Nginx + Octane/Swoole, optimized build)
- `docker-compose.prod.classic.yml` — Classic production (Nginx + PHP‑FPM)
- `docker-compose.octane.init.yml` — Temporary stack for **project initialization**
- `Dockerfile.octane` — Base image for Octane (Swoole)
- `Dockerfile.prod` — Base image for PHP‑FPM (classic)
- `docker/nginx.octane.conf` — Example Nginx config for Octane (optional: copy to `docker/nginx.conf`)

> **Note:** The `Dockerfile.octane` uses `CMD php artisan octane:start`, meaning the Laravel app **must already exist** before the service can run properly.

---

## Project Initialization (Choose One Option)
Since the `octane` service runs `php artisan octane:start`, the Laravel app must exist before starting the dev/prod stack. Use one of the following safe methods:

### Option A — **Init Stack** (Recommended)
1. Start the init stack:
```bash
docker compose -f docker-compose.octane.init.yml up -d --build
```
2. Create the Laravel project inside the container:
```bash
docker compose -f docker-compose.octane.init.yml exec octane bash -lc \
  "composer create-project laravel/laravel . && php artisan key:generate"
```
3. Shut down the init stack:
```bash
docker compose -f docker-compose.octane.init.yml down
```
4. Proceed with **Dev** or **Prod** modes (see below).

### Option B — **One‑off container** (auto override CMD)
Run a one‑time container to initialize Laravel:
```bash
docker compose -f docker-compose.octane.dev.yml run --rm --no-deps octane \
  bash -lc "composer create-project laravel/laravel . && php artisan key:generate"
```
Then bring up your dev/prod stack normally.

### Option C — **Temporary command override**
1. Add this to the `octane` service temporarily in `docker-compose.octane.dev.yml`:
```yaml
command: ["bash", "-lc", "sleep infinity"]
```
2. Start the stack and initialize Laravel:
```bash
docker compose -f docker-compose.octane.dev.yml up -d --build

docker compose -f docker-compose.octane.dev.yml exec octane bash -lc \
  "composer create-project laravel/laravel . && php artisan key:generate"
```
3. Remove the `command:` override and rebuild:
```bash
docker compose -f docker-compose.octane.dev.yml up -d --build
```

---

## A) Octane Dev (Swoole) — Development

> Optional: Copy Nginx config template for Octane
```bash
cp docker/nginx.octane.conf docker/nginx.conf
```

### Start containers
```bash
docker compose -f docker-compose.octane.dev.yml up -d --build
```

### Install dependencies (if not using create‑project)
```bash
docker compose -f docker-compose.octane.dev.yml exec octane bash -lc \
  "composer install && php artisan key:generate && php artisan migrate"
```

### Access the app
```
http://localhost:8080
```

---

## B) Octane Production (Swoole + Nginx)
Run optimized Laravel Octane behind Nginx reverse proxy.

### .env configuration
Ensure these values are correct:
```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://yourdomain.com
TRUSTED_PROXIES=*
```
Include your production DB/Redis credentials.

### Build & Run
```bash
docker compose -f docker-compose.octane.prod.yml up -d --build
```

### Run migrations (optional but recommended)
```bash
docker compose -f docker-compose.octane.prod.yml exec octane php artisan migrate --force
```

> **SSL:** Terminate TLS at your reverse proxy/load balancer, or mount certs into the Nginx container and configure `listen 443 ssl;`.

---

## C) Classic Production (PHP‑FPM + Nginx)
If you prefer not to use Swoole in production.

### Run
```bash
docker compose -f docker-compose.prod.classic.yml up -d --build
```

### Migrate
```bash
docker compose -f docker-compose.prod.classic.yml exec php php artisan migrate --force
```

---

## Build Optimization & Caching
Before building final production images (or within Dockerfile):
```bash
composer install --optimize-autoloader --no-dev
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

---

## Healthcheck & Monitoring
- Add a `/health` route in your Laravel app for probes.
- Alternatively, run container checks like `php -v` or `curl -f http://127.0.0.1/health`.

---

## Scaling & Swoole Tuning
- Adjust worker counts in `Dockerfile.octane` (e.g., `--workers`, `--task-workers`).
- Enable OPCache and cache config/route/view in production.
- For stateful services, consider sticky sessions when scaling horizontally.

---

## Common Commands
```bash
# Tail logs
docker compose -f docker-compose.octane.dev.yml logs -f nginx

# Enter container shell
docker compose -f docker-compose.octane.dev.yml exec octane bash

# Example queue worker
docker compose -f docker-compose.octane.prod.yml exec octane php artisan queue:work --daemon
```

---

## Troubleshooting

### 1) "Project directory is not empty"
`composer create-project` requires an empty folder. Ensure no leftover files exist:
```bash
ls -la
# Make sure nothing critical exists before running:
rm -rf !(vendor|docker) 2>/dev/null || true
```

### 2) File ownership issues (Linux)
If files are owned by root, fix ownership:
```bash
docker compose -f docker-compose.octane.dev.yml exec octane \
  bash -lc "chown -R www-data:www-data ."
```
Or align UID/GID in Dockerfile.

### 3) Port conflicts
Change port mapping in Nginx service (e.g., `8080:80` → `8081:80`).

### 4) Environment and proxies
Ensure `APP_URL` is correct. Behind load balancers, use `TRUSTED_PROXIES=*` or configure `App\Http\Middleware\TrustProxies`.

---

## Security Guidelines
- Use separate `.env` files for dev/staging/prod. Never commit `.env`.
- Terminate TLS at trusted reverse proxy or LB; enable HTTP/2 if possible.
- Configure upload limits, rate limiting, and Nginx buffering properly.

---

## Next Steps
- Add CI/CD pipelines for automated build & push.
- Implement DB backups and zero‑downtime deployment (`php artisan down --render=...`).
- Optionally migrate to **RoadRunner** (replace `Dockerfile` and Octane command accordingly).

