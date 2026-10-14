# Runbook: incidents

Admin access in every case: Tailscale → `http://<tailscale-ip>:8000` (dashboard) or `ssh user@<tailscale-ip>`.

## One site is down
1. Dashboard → the app → **Logs**. Is it crashing, or failing its health check?
2. If it started after a deploy: **Deployments → previous deployment → Redeploy/Rollback**. Fix afterwards.
3. Out of memory (exit code 137 in the logs): raise its memory limit, or look for a leak.
4. The app runs but the URL fails: check its Domains entry (`https://`, redirect disabled), then the Tunnel route for that hostname.

## Every site is down
1. Can you reach the dashboard over Tailscale?
   - **No:** the server or its network is down. Check the hosting provider's panel or console and reboot from there. Docker and the dashboard restart on their own.
   - **Yes:** check the tunnel with `systemctl status cloudflared` (restart it), then the proxy (Servers → localhost → Proxy → restart).
2. Cloudflare status page: is Cloudflare itself having problems?

## Disk full
1. `df -h` to confirm. Then `docker system df` to see what's using space.
2. Dashboard → Servers → localhost → run **Docker cleanup** (old images and build cache).
3. If backups are filling the local disk, set local backups to delete after upload to R2.
4. Find the next-largest users with `du -sh /var/lib/docker/volumes/* | sort -h | tail`. Growing database volumes mean it's time for more disk.

## A deploy keeps failing
- **Build out of memory:** reduce concurrent builds, or raise the server's swap.
- **"No lockfile found":** commit the lockfile.
- **Variable undefined in the frontend:** it wasn't ticked as a Build Variable or declared as `ARG`.

## Bad data or a bad migration
Follow [`restore-db.md`](restore-db.md). Restore into scratch first, always.

## Suspected break-in
1. Turn on Cloudflare **Under Attack mode** if the traffic is hostile.
2. Rotate secrets: dashboard admin password, R2 token, database passwords (dashboard → database → change password, then update `DATABASE_URL`), and app API keys.
3. Check `last`, `/var/log/auth.log`, `fail2ban-client status sshd`, and the dashboard's team members and API tokens.
4. If you're unsure: build a fresh server from these runbooks and restore databases from R2. Keeping everything rebuildable is what makes that possible.
