# Runbook: add a new project

Names follow [`conventions.md`](../conventions.md). The example project is `acme`.

## 1. Repo
- [ ] Copy the right template into the repo root: `templates/nextjs`, `node`, `python` or `static` (Dockerfile + `.dockerignore`).
- [ ] Next.js: set `output: 'standalone'` in `next.config`.
- [ ] Commit a lockfile and a `.env.example`.

## 2. Dashboard project
- [ ] **+ New Project** → `acme`. Create the environments `production` and `staging`.

## 3. Databases (in each environment)
- [ ] **+ New → Database → PostgreSQL** (or Redis / MySQL / MongoDB) → name it `acme-pg` / `acme-redis`.
- [ ] Leave "Make it publicly available" **off**. Set resource limits.
- [ ] Postgres/MySQL/MongoDB: **Backups → + Add**, choose the R2 storage, schedule `0 * * * *` in production or daily in staging, and set the retention.
- [ ] Redis used for queues or sessions: turn on AOF persistence.
- [ ] Copy each **internal** connection URL into the project's shared variables (`DATABASE_URL`, `REDIS_URL`).

## 4. App
- [ ] **+ New → Application → GitHub App source** → pick the repo and branch (`main` for production, `staging` or `develop` for staging).
- [ ] Build pack: **Dockerfile**.
- [ ] Domain: `https://acme.com` (production) / `https://acme-staging.example.com` (staging). Set **Redirect HTTP to HTTPS: Disabled**.
- [ ] Environment variables: reference the shared variables and add the rest. Tick **Build Variable** on `NEXT_PUBLIC_*` / `VITE_*`.
- [ ] Set resource limits. Add a health check path if the app has one.
- [ ] Production app: turn on **Preview Deployments** and set the preview URL template to a single-level hostname (see conventions).
- [ ] Cron jobs: **Scheduled Tasks**, using the same schedules as `vercel.json` crons.

## 5. Cloudflare
- [ ] If the domain is new to the Tunnel, add a route: hostname → `http://localhost:80` (or `:8080`). Add or replace the DNS record with a proxied CNAME to `<tunnel-id>.cfargotunnel.com`.

## 6. Monitoring
- [ ] Add the production URL to the external uptime monitor.

## 7. Check
- [ ] Deploy, open the site, and check its logs in the dashboard.
- [ ] Trigger one manual backup and confirm it appears in R2.
