# BasementIO: design spec

## Problem
A developer pays for Vercel (plus Neon/Upstash-style services) **and** rents a server that sits mostly idle. The goal is one place to run everything (apps, Postgres, MySQL, MongoDB, Redis), organized the same way for every product, without anyone needing to SSH in and arrange processes by hand.

## Decisions
| Decision | Choice | Why |
|---|---|---|
| Audience | Internal tool first | Prove it on our own projects before considering a product |
| Build vs adopt | **Adopt a mature open-source self-hosted dashboard and add to it** | It already covers deploys, previews, databases, scheduled backups, cron, web terminal and alerts. Building that again would take months. |
| Stacks | Next.js, Node, Python, static/Vite | Everything currently deployed |
| Databases | Postgres (default), MySQL/MariaDB, MongoDB, Redis | Existing projects use all of them; new ones default to Postgres |
| Public traffic | Cloudflare Tunnel | No inbound ports; CDN, WAF and SSL included |
| Admin access | Tailscale (dashboard, SSH); Cloudflare Access (DB consoles) | Nothing admin-related is publicly reachable. Access is used for the consoles because port-binding containers to the Tailscale IP fails if Docker starts before Tailscale. |
| Object storage | Cloudflare R2 | Free downloads, S3 API, and not on the same disk as the server |
| Point-in-time restore | WAL-G to R2 (Phase 3, Postgres only) | The dashboard's backups are logical dumps only |

## Dashboard coverage (checked against its docs, 2026-10)
- **Built in:** git deploys, PR previews, rollbacks, env vars, logs; one-click Postgres/MySQL/MariaDB/MongoDB/Redis/KeyDB/Dragonfly/ClickHouse; scheduled backups (cron) to S3-compatible storage for Postgres/MySQL/MariaDB/MongoDB/ClickHouse/SQLite; Scheduled Tasks; web terminal; notifications.
- **One-click catalog:** CloudBeaver, pgAdmin, Drizzle Gateway, Redis Insight, GlitchTip, Umami, Uptime Kuma, Beszel, Grafana.
- **Gaps:**
  - No point-in-time restore: backups are `pg_dump`.
  - No scheduled backups for Redis/KeyDB/Dragonfly.
  - No database branching.
  - CDN/WAF comes from Cloudflare.

## Architecture
```
GitHub ── push / PR ──► dashboard (builds + deploys) ──► Docker containers
Visitors ─► Cloudflare (DNS, CDN, WAF, SSL) ─► Cloudflare Tunnel ─► proxy (Traefik) ─► apps
Admin    ─► Tailscale ─► dashboard (:8000), SSH
         ─► Cloudflare Access ─► CloudBeaver / Redis Insight / mongo-express
Backups  ─► R2: hourly dumps (prod), daily (staging), dashboard self-backup; WAL-G in Phase 3
Alerts   ─► dashboard notifications + external uptime monitor
```
The firewall is set at the **hosting provider**: all inbound traffic blocked. Docker bypasses UFW for published ports, so UFW alone isn't enough.

## Organization
See [`conventions.md`](conventions.md): one project per product, `production` and `staging` environments, `<project>-<role>` resource names, one database container per project, single-level preview hostnames, secrets only in the dashboard.

## Existing servers: side-by-side migration
1. Read-only inventory (`server/inventory.sh`) and a baseline health check (`server/healthcheck.sh`).
2. Back up all existing data off the server.
3. Install the dashboard (`server/install-dashboard.sh`) in a low-traffic window. It may restart the Docker daemon.
4. If 80/443 are in use, move the dashboard's proxy to 8080/8443 and point the Tunnel there. Existing sites stay on their current web server.
5. Move services one at a time, re-running the health check after each.
6. When the old web server serves nothing, stop it and close all inbound ports.

## Phases
| Phase | Scope |
|---|---|
| 0: Audit | inventory, baseline health check, off-server backups |
| 1: Core | hardening, Tailscale, dashboard, Tunnel, firewall, R2 backups, alerts, `platform` consoles, test app ([`server/setup.md`](../server/setup.md)) |
| 2: Migrate | Vercel projects and existing services, one at a time ([`runbooks/migrate-from-vercel.md`](runbooks/migrate-from-vercel.md)) |
| 3: Safety | WAL-G point-in-time restore for production Postgres, GlitchTip, Umami, Beszel |
| Later | DB branch per PR, a second server / high availability, own UI on the dashboard API |

## Not doing now, and why
- **DB branch per PR:** needs glue code to create and drop a database per PR, and copying production data to preview URLs anyone can open is a privacy risk. Previews share a staging database with test data instead.
- **High availability:** a single server is acceptable while downtime costs little. Backups in R2 plus these runbooks make a rebuild possible.
- **Own UI:** only worth it if this becomes a product.

## Verification
- Every service from the inventory still answers after the dashboard is installed (health check before vs after).
- Template app: valid `https://`, PR preview works, merge deploys, rollback works.
- An external port scan of the public IP shows nothing open. The dashboard is reachable only over Tailscale.
- A backup appears in R2, and the restore drill into scratch matches row counts (repeat monthly).
- Alerts fire when a container stops and when the tunnel is down.
- Each migrated app works on staging, then runs for 1 week in parallel before Vercel is removed.
