# Phase 1: Platform core setup

Do these steps in order. **⚠** marks a step that can break something if skipped.

## Before you start
- [ ] Phase 0 done: `inventory.sh` report reviewed, `healthcheck.sh` run and saved as `healthcheck-before.log`.
- [ ] **⚠ Every existing database and data directory backed up off the server** (R2, S3 or your laptop).
- [ ] Your domain's DNS is managed by Cloudflare.
- [ ] You have a Cloudflare R2 bucket for backups (e.g. `basementio-backups`) and a Tailscale account.
- [ ] Pick a low-traffic window for step 3.

## 1. Harden SSH and the OS
```bash
sudo bash harden.sh
```
The script refuses to run if your SSH key isn't installed. **⚠ Keep the current session open** and confirm a fresh login works before you close it.

## 2. Tailscale (private admin network)
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4        # note this 100.x.y.z address
```
Install Tailscale on your laptop/phone as well. From now on, admin access goes through the 100.x address.

## 3. Install the dashboard
```bash
sudo bash install-dashboard.sh
```
- It asks for the admin username, email and password, and creates the account during install, so the registration page is never left open.
- **⚠ It refuses to run if Docker was installed via snap**, because that isn't supported. Replace it with Docker Engine first.
- The installer configures Docker and may restart the Docker daemon, which briefly restarts existing containers. Run it in your low-traffic window, then run `healthcheck.sh` again.
- Open the dashboard at `http://<tailscale-ip>:8000`.

The dashboard uses these ports: 8000 (UI), 6001 (live updates), 6002 (web terminal), 80/443 (its proxy).

### If ports 80/443 are already in use (nginx, Apache, etc.)
The dashboard's proxy can't start on ports another web server is using. Move the proxy to other ports instead of stopping your current sites:
1. Dashboard → **Servers → localhost → Proxy**, then stop the proxy if it's running.
2. In the proxy configuration, change the port mappings `80:80` → `8080:80` and `443:443` → `8443:443`. Save and start the proxy.
3. In step 4, point the Tunnel at `http://localhost:8080` instead of `:80`.

The old sites keep running on nginx. Move them over one at a time in Phase 2, and once nginx serves nothing, stop it and switch back to 80/443 (optional, since the Tunnel doesn't care).

## 4. Cloudflare Tunnel (public traffic without open ports)
1. Cloudflare dashboard → **Zero Trust → Networks → Tunnels → Create a tunnel** → type **Cloudflared**. Copy the Debian/Ubuntu install command it shows (it includes your token) and run it on the server.
2. In the tunnel's **routes / public hostnames**, add a **Published application**:
   - Subdomain `*`, domain `example.com`, service **`http://localhost:80`** (or `:8080` from step 3). If `localhost` resolves to IPv6 and fails, use `http://127.0.0.1:80`.
   - Add the apex `example.com` the same way if apps live there. Every other domain you host gets its own route to the same service. You don't need another tunnel.
3. DNS: Cloudflare doesn't overwrite existing records. If the hostname already has a record, replace it with a **proxied CNAME** `*` → `<tunnel-id>.cfargotunnel.com`.
4. Turn on **SSL/TLS → Edge Certificates → Always Use HTTPS**.

**In the dashboard, for every app on the Tunnel:**
- Enter domains with **`https://`**, e.g. `https://app.example.com`.
- **⚠ On the resource's Domains page, set "Redirect HTTP to HTTPS" to Disabled.** Otherwise you'll get `TOO_MANY_REDIRECTS`, because the Tunnel talks to the proxy over plain HTTP.

## 5. Close the server
Use your **hosting provider's firewall panel**, not just UFW. Docker writes its own iptables rules and **bypasses UFW** for any port a container publishes.
1. First confirm the dashboard works over Tailscale and a test site works through the Tunnel.
2. Then block **all inbound** traffic: 22, 80, 443, 8000, 6001 and 6002 included. Tailscale and cloudflared both connect outbound, so nothing breaks. Optionally allow UDP 41641 so Tailscale can connect directly instead of through a relay.
3. SSH only over Tailscale: `ssh user@100.x.y.z`.

## 6. Backups to R2
1. Cloudflare → R2 → **Manage API tokens** → create a token with *Object Read & Write*, scoped to the backup bucket.
2. Dashboard → **Storages → + Add**:
   - Endpoint: `https://<account-id>.r2.cloudflarestorage.com`
   - Region: `auto`
   - Bucket, access key and secret from the token.
   - Click **Validate**.
3. Dashboard → **Settings → Backup**: enable S3 backups of the dashboard's own database to the same storage.
4. Per-database backups are set up when each project is created (see `docs/runbooks/new-project.md`).

## 7. Alerts and server settings
- Dashboard → **Notifications**: connect Telegram, Slack, Discord or email. Turn on deployment failures, backup failures, container stopped and server disk usage.
- Dashboard → **Servers → localhost**:
  - Concurrent builds: **3–4** (a Next.js build can use 2–4 GB of RAM).
  - Docker cleanup: on, with a threshold around 80% disk.
- **External** uptime monitor (Better Stack or UptimeRobot, both have free tiers) on every production URL. It has to run somewhere other than this server, so it still alerts when the server is down.

## 8. The `platform` project (shared tools)
Create a project named `platform`, environment `production`, and add these from **+ New → Services**:

| Service | Purpose | Hostname example |
|---|---|---|
| CloudBeaver | Postgres / MySQL web console | `db.example.com` |
| Redis Insight | Redis web console | `redis.example.com` |
| mongo-express (Docker image) | MongoDB console; CloudBeaver Community has no MongoDB support | `mongo.example.com` |

**⚠ Put every console behind Cloudflare Access before using it:** Zero Trust → **Access → Applications → Self-hosted**, one app per hostname, with a policy that allows only your email (one-time code login). Free for up to 50 users.

## 9. Test the whole flow
Deploy `templates/nextjs` as a throwaway app with a Postgres and a Redis attached (follow `docs/runbooks/new-project.md`), then check:
- [ ] The site loads at its `https://` domain with a valid certificate.
- [ ] Opening a PR creates a preview URL that works; merging deploys production.
- [ ] Rollback to the previous deployment works from the dashboard.
- [ ] A manual database backup shows up in R2. Restore it into a scratch database (`docs/runbooks/restore-db.md`).
- [ ] Stopping the container sends an alert.
- [ ] An external port scan of the server's public IP shows **no open ports**.
- [ ] `healthcheck.sh` gives the same results as `healthcheck-before.log`.
