# Runbook: move a project from Vercel

Move **one project at a time, least important first**. Keep Vercel running for a week after each switch, so going back is just a DNS change.

## 1. Inventory the Vercel project
- [ ] `vercel env pull .env.vercel --environment=production`. Keep this file local; `.gitignore` excludes it.
- [ ] Note which Vercel-only features the project uses, and how each is replaced:

| Vercel feature | How to spot it | Replace with |
|---|---|---|
| Vercel Blob | `@vercel/blob` | Cloudflare R2 through any S3 SDK (`@aws-sdk/client-s3`, endpoint `https://<account-id>.r2.cloudflarestorage.com`) |
| Vercel KV / Upstash | `@vercel/kv`, `@upstash/redis` | Redis from the dashboard + `ioredis` / `redis` |
| Vercel Postgres / Neon | `@vercel/postgres`, `@neondatabase/serverless` | Postgres from the dashboard + `pg` / `postgres` driver (the Neon HTTP driver won't work) |
| Cron | `crons` in `vercel.json` | Scheduled Tasks calling the same route (`curl`) |
| Analytics / Speed Insights | `@vercel/analytics`, `@vercel/speed-insights` | Umami (Phase 3), or remove |
| Edge runtime | `export const runtime = 'edge'` | Usually works as-is on the Node server; test it |
| Image optimization | `next/image` | Works in standalone mode; nothing to change |
| Redirects / headers | `vercel.json` | Move them to `next.config` `redirects()` / `headers()` |

## 2. Database (if it lives on Neon or Vercel Postgres)
- [ ] Create `acme-pg` in the dashboard (see `new-project.md`).
- [ ] Copy the data. Run these from a machine that can reach both databases, e.g. through the dashboard's web terminal on a temporary container:
  ```bash
  pg_dump --format=custom --no-owner --no-acl "$NEON_URL" > acme.dump
  pg_restore --no-owner --no-acl -d "$NEW_PG_URL" acme.dump
  ```
- [ ] Compare row counts on the important tables in both databases.

## 3. App
- [ ] Add the template Dockerfile and set `output: 'standalone'`.
- [ ] Create the app in the dashboard on the **staging domain** first (`new-project.md`). Copy the env vars over and update `DATABASE_URL`/`REDIS_URL` to the internal URLs.
- [ ] Test on staging: key pages, sign-in, forms, uploads (land in R2), cron routes, webhooks.

## 4. Switch
- [ ] Shortly before switching: freeze writes if possible, then run a final `pg_dump` / `pg_restore` so the data is current.
- [ ] Add the production domain in the dashboard. Add a Tunnel route for it, then change the DNS record in Cloudflare to the tunnel CNAME (proxied).
- [ ] Update external webhook URLs and OAuth redirect URLs if the domain changed.
- [ ] Add the URL to the uptime monitor.

## 5. After
- [ ] Watch the dashboard's logs and alerts for 24 hours.
- [ ] After **one stable week**, delete the Vercel project. When all projects have moved, downgrade or cancel the Vercel plan.

**Rollback:** point DNS back at Vercel. If data was written on the new server, dump it and load it into the old database first.
