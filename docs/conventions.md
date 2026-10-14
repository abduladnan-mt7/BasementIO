# Conventions

These rules are what keep a single dashboard tidy once it holds 20+ apps. Follow them for every project.

## Projects and environments
- **One dashboard Project per product**, e.g. `acme`, `shopfront`. Name it in lowercase with hyphens, and use the same name as the GitHub repo where possible.
- **One `platform` project** for shared tools: DB consoles, GlitchTip, Umami, Uptime Kuma. Product resources never go in here.
- Every product has two environments: **`production`** and **`staging`**.
- PR previews are attached to the app and use **staging's** variables and staging's database. They never touch production data.

## Resource names: `<project>-<role>`

| Role | Example | Notes |
|---|---|---|
| `web` | `acme-web` | Frontend / Next.js |
| `api` | `acme-api` | Separate backend, if any |
| `worker` | `acme-worker` | Queue consumers, background jobs |
| `pg` / `mysql` / `mongo` | `acme-pg` | One database container per project per environment |
| `redis` | `acme-redis` | Cache, queues, sessions |

Staging resources have the same names inside the `staging` environment. Environments are already separate, so don't add a suffix.

## One database per project
Each project gets **its own** database containers, never a shared instance. That way, restoring one product's database can never roll back another's, and one runaway query can't slow the rest. Set **memory/CPU limits** on every resource (dashboard → resource → Resource Limits).

Apps connect over the database's **internal** URL (container network). Leave **"Make it publicly available" off** for every database. Use the DB consoles in the `platform` project for browsing.

## Domains
| Use | Pattern | Example |
|---|---|---|
| Production | the product's own domain | `https://acme.com`, `https://api.acme.com` |
| Staging | `<project>-staging.<platform-domain>` | `https://acme-staging.example.com` |
| PR preview | must be **one level** under a Cloudflare zone | `https://pr42-acme.example.com` |
| Consoles | `<tool>.<platform-domain>` behind Cloudflare Access | `https://db.example.com` |

Cloudflare's free certificate covers `*.example.com` but **not** `*.acme.example.com`. Set the app's **Preview URL Template** so it produces a single-level hostname. The default `{{pr_id}}.{{domain}}` only works when the app's domain is a zone apex. Every domain is entered in the dashboard with `https://`, with **Redirect HTTP to HTTPS disabled** (the Tunnel handles HTTPS).

## Environment variables
- Secrets live **only in the dashboard**: never in git, never in Docker images (`.dockerignore` excludes `.env*`).
- Values shared by several resources (e.g. `DATABASE_URL`, `REDIS_URL`) go in **project-level shared variables** and are referenced from each resource.
- Anything compiled into the frontend (`NEXT_PUBLIC_*`, `VITE_*`) must be ticked as a **Build Variable** and declared as `ARG` in the Dockerfile.
- Keep a `.env.example` in each repo listing every variable name, with no values.

## Defaults for new projects
Next.js (plus a Node `api` only if needed) → Postgres → Redis. Postgres is the only engine that gets point-in-time restore (Phase 3). Existing MongoDB or MySQL projects keep their engine and rely on hourly dumps.

## Backups
| Environment | Schedule | Retention in R2 |
|---|---|---|
| production | hourly (`0 * * * *`) | 14 days |
| staging | daily | 7 days |

Redis has no scheduled backups in the dashboard. Turn on AOF persistence wherever Redis holds queues or sessions, and never keep data in Redis that you can't afford to lose.
