# Laravel Octane (Swoole) + Production Variants

This bundle gives you:
1) **Octane Dev** (Swoole) behind Nginx → `docker-compose.octane.dev.yml`
2) **Octane Production** (Swoole) behind Nginx → `docker-compose.octane.prod.yml`
3) **Classic Production** (PHP-FPM + Nginx) multi-stage → `docker-compose.prod.classic.yml`

## Prereqs
- Project root with `composer.json` (Laravel app). If empty folder, run composer create-project inside the dev container first.

---

## A) Octane Dev (Hot reload)
```bash
cp docker/nginx.octane.conf docker/nginx.conf  # optional
docker compose -f docker-compose.octane.dev.yml up -d --build
# Install app (first time)
docker compose -f docker-compose.octane.dev.yml exec octane bash -lc "composer install && php artisan key:generate && php artisan migrate"
```
Open http://localhost:8080

---

## B) Octane Production
Builds optimized app and serves via Octane (Swoole) with Nginx reverse proxy.
```bash
docker compose -f docker-compose.octane.prod.yml up -d --build
```
Ensure `.env` contains production DB/Redis and `APP_ENV=production`, `APP_DEBUG=false`.
You may run `php artisan migrate --force`:
```bash
docker compose -f docker-compose.octane.prod.yml exec octane php artisan migrate --force
```

---

## C) Classic Production (PHP-FPM + Nginx)
Suitable if you prefer not to run Swoole in prod.
```bash
docker compose -f docker-compose.prod.classic.yml up -d --build
```
Migrate:
```bash
docker compose -f docker-compose.prod.classic.yml exec php php artisan migrate --force
```

---

## Notes
- Adjust worker counts in `Dockerfile.octane` CMD for your server.
- Put `APP_URL` correctly; behind a load balancer, also set `TRUSTED_PROXIES=*` in `.env` or configure `App\Http\Middleware\TrustProxies`.
- For SSL, terminate TLS at your reverse proxy or load balancer, or mount certs into Nginx and listen on 443.
- Health checks: add `/health` route or use `php -v` inside containers.
