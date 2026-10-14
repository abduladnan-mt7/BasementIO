# BasementIO

Turn one rented server into your own **Vercel + Neon + Upstash**: git-push deploys, PR previews, managed Postgres / MySQL / MongoDB / Redis, backups, DB consoles and alerts, all in one dashboard and without SSH-ing in to run things by hand.

BasementIO is a **tested setup kit**: server scripts, Dockerfile templates, naming rules and runbooks that combine an open-source self-hosted dashboard with Cloudflare and R2 into one organized platform.

```
GitHub ── push / PR ──► BasementIO dashboard (builds + deploys) ──► Docker containers
Visitors ─► Cloudflare (DNS, CDN, WAF, SSL) ─► Cloudflare Tunnel ─► proxy (Traefik) ─► apps
Founder  ─► Tailscale (private) ─► dashboard
         ─► Cloudflare Access  ─► DB consoles (CloudBeaver, Redis Insight, mongo-express)
Backups  ─► Cloudflare R2 (hourly DB dumps; WAL-G point-in-time restore in Phase 3)
Alerts   ─► dashboard notifications + external uptime monitor
```

When the setup is finished, **the server has no inbound ports open**. Public traffic arrives through the Tunnel, and admin access goes through Tailscale.

## What you get vs. the hosted services

| Hosted service | BasementIO equivalent |
|---|---|
| Vercel deploys, previews, rollbacks | Dashboard |
| Vercel Cron | Scheduled Tasks |
| Vercel Blob | Cloudflare R2 (S3 API) |
| Vercel KV / Upstash | Redis (one-click) |
| Neon / Vercel Postgres | Postgres (one-click) + hourly backups to R2 |
| Neon console | CloudBeaver / Redis Insight / mongo-express behind Cloudflare Access |
| Neon point-in-time restore | WAL-G continuous archiving to R2 (Phase 3) |
| Vercel Analytics, Sentry | Umami, GlitchTip (Phase 3) |

## Repository layout

```
docs/
  spec.md                 full design and the reasons behind it
  conventions.md          naming, environments, domains, env-var rules
  runbooks/               new project, migrate from Vercel, restore DB, incidents
server/
  inventory.sh            READ-ONLY audit of an existing server (Phase 0)
  healthcheck.sh          before/after check of every site on the server
  harden.sh               SSH key-only login, fail2ban, automatic security updates
  install-dashboard.sh    installs the dashboard with the admin account pre-created
  setup.md                Phase 1: Tailscale, dashboard, Tunnel, R2, alerts
templates/
  nextjs/ node/ python/ static/   Dockerfiles + .dockerignore per stack
```

## Getting started

1. **Phase 0 (audit, nothing changes):** copy `server/` to the server, run `sudo bash inventory.sh`, then run `bash healthcheck.sh healthcheck-targets.txt` and keep the result. Back up any existing databases.
2. **Phase 1 (platform core):** follow [`server/setup.md`](server/setup.md).
3. **Phase 2 (migrate):** move projects one at a time with [`docs/runbooks/migrate-from-vercel.md`](docs/runbooks/migrate-from-vercel.md).
4. **Phase 3 (safety):** point-in-time restore for production Postgres, error tracking, analytics.

Requirements: Ubuntu 22.04/24.04 LTS (2+ vCPU, 2+ GB RAM), a Cloudflare account with your domain, and a Tailscale account. The reference server has 16 vCPU and 32 GB RAM.

## Built by

**Abdul Adnan**, founder of **Mt7 Pvt Ltd** ([mt7.io](https://mt7.io) · [mt7.in](https://mt7.in)). *"We build SaaS products that ship."*

What we do at Mt7:
- **Websites & apps:** from a marketing site to a full platform, through to native iOS, Android and desktop
- **AI agents & workflows:** voice dispatchers, WhatsApp bots and automations, wired into your systems
- **Our own SaaS products:** products we build, run and sell ourselves
- **People:** AI training and developers on demand

BasementIO is how we host our own products. Want it set up on your server? Get in touch at **[mt7.io](https://mt7.io)** or **[mt7.in](https://mt7.in)**.

## License

[MIT](LICENSE) © 2026 Mt7 Pvt Ltd
