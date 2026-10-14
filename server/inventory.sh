#!/usr/bin/env bash
# BasementIO Phase 0: READ-ONLY server inventory.
#
# Changes nothing on the system. The only things it writes are two report files
# in the current directory:
#   inventory-<host>-<timestamp>.txt   full report (chmod 600)
#   healthcheck-targets.txt            site URLs found in nginx, for healthcheck.sh
#
# Usage:  sudo bash inventory.sh
#
# Review the report before sharing it with anyone: crontabs and web-server
# config can contain secrets.

set -uo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo so every process, port and config is visible: sudo bash $0" >&2
  exit 1
fi

OUT="inventory-$(hostname)-$(date +%Y%m%d-%H%M).txt"
TARGETS="healthcheck-targets.txt"
umask 077

have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n\n===== %s =====\n' "$1"; }
run() { printf '\n$ %s\n' "$1"; bash -c "$1" 2>&1 || true; }

{
  echo "BasementIO inventory: $(hostname) at $(date -Is)"

  section "SYSTEM"
  run "lsb_release -ds 2>/dev/null || cat /etc/os-release"
  run "uname -r"
  run "uptime"
  run "nproc"
  run "free -h"
  run "df -hT -x tmpfs -x devtmpfs -x overlay -x squashfs"

  section "CPU STEAL (st column; consistently above ~5 means the vCPUs are oversold)"
  run "vmstat 1 5"

  section "LISTENING PORTS"
  run "ss -tulpn"

  section "PORTS THE DASHBOARD NEEDS (22 ssh, 80/443 proxy, 8000 dashboard, 6001 realtime, 6002 terminal; 8080/8443 fallback proxy)"
  for p in 22 80 443 8000 6001 6002 8080 8443; do
    owner=$(ss -Htlpn "sport = :$p" 2>/dev/null | grep -o 'users:(([^)]*' | head -1)
    if [[ -n "$owner" ]]; then echo "port $p: IN USE  ${owner#users:((}"; else echo "port $p: free"; fi
  done

  section "RUNNING SERVICES"
  run "systemctl list-units --type=service --state=running --no-pager --no-legend"

  section "DATABASES INSTALLED ON THE HOST"
  run "systemctl list-units --type=service --all --no-pager --no-legend | grep -Ei 'postgres|mysql|mariadb|mongo|redis|keydb|valkey' || echo 'none found as systemd services'"
  for p in 5432 3306 27017 6379; do
    ss -Htlpn "sport = :$p" 2>/dev/null | grep -q . && echo "port $p is listening (database?)"
  done

  section "TOP PROCESSES BY MEMORY"
  run "ps -eo user,pid,etime,rss,args --sort=-rss | head -40"

  section "WEB SERVERS"
  if have nginx; then
    run "nginx -v"
    echo "--- nginx sites (config file, listen, server_name, proxy_pass, root) ---"
    nginx -T 2>/dev/null | grep -E '^# configuration file|^\s*(listen|server_name|proxy_pass|root)\b' || true
  else
    echo "nginx: not installed"
  fi
  have apache2ctl && run "apache2ctl -S"
  have caddy && run "cat /etc/caddy/Caddyfile"
  have certbot && run "certbot certificates"

  section "DOCKER"
  if have snap && snap list docker >/dev/null 2>&1; then
    echo "!! Docker is installed via SNAP. The dashboard does NOT support this. Plan a migration to Docker Engine (apt)."
  fi
  if have docker; then
    run "docker version --format 'client {{.Client.Version}} / server {{.Server.Version}}'"
    run "docker info --format 'root dir: {{.DockerRootDir}}  storage: {{.Driver}}  containers: {{.Containers}}'"
    run "cat /etc/docker/daemon.json"
    run "docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
    run "docker compose ls"
    run "docker system df"
  else
    echo "docker: not installed (install-dashboard.sh will install it)"
  fi

  section "PM2 (per user; 'pm2 list' only, never jlist, which prints env vars)"
  pm2_users=$(ps -eo user:32,args | grep -i '[P]M2 v' | awk '{print $1}' | sort -u)
  if [[ -z "$pm2_users" ]]; then
    echo "no PM2 daemons running"
  else
    for u in $pm2_users; do
      echo "--- user: $u ---"
      sudo -u "$u" -H bash -lc 'pm2 list' 2>&1 || true
    done
  fi

  section "CRON (review for secrets before sharing)"
  run "ls -la /etc/cron.d"
  for f in /var/spool/cron/crontabs/*; do
    [[ -f "$f" ]] || continue
    echo "--- crontab: $(basename "$f") ---"
    grep -v '^#' "$f" | sed '/^\s*$/d'
  done
  run "systemctl list-timers --no-pager"

  section "FIREWALL"
  have ufw && run "ufw status verbose"
  run "iptables -S 2>/dev/null | head -60"

  section "SSH"
  run "mkdir -p /run/sshd 2>/dev/null; sshd -T 2>/dev/null | grep -Ei '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication) '"
  run "ls -la /etc/ssh/sshd_config.d/"
  for home in /root /home/*; do
    [[ -s "$home/.ssh/authorized_keys" ]] && echo "authorized_keys present: $home ($(grep -c . "$home/.ssh/authorized_keys") keys)"
  done

  section "LOGIN USERS"
  run "getent passwd | awk -F: '\$7 ~ /(bash|zsh|sh)\$/ {print \$1, \$6}'"

  section "DISK USAGE OF DATA DIRECTORIES"
  run "du -sh /var/lib/docker /var/lib/postgresql /var/lib/mysql /var/lib/mongodb /var/lib/redis /var/www /opt /home/* 2>/dev/null"

} > "$OUT"

# Site list for healthcheck.sh, taken from nginx server_name directives.
if have nginx; then
  nginx -T 2>/dev/null \
    | grep -E '^\s*server_name\b' \
    | sed -E 's/^\s*server_name\s+//; s/;.*$//' \
    | tr ' \t' '\n\n' \
    | grep -vE '^$|^_$|^localhost$|[*~]' \
    | sort -u \
    | sed 's#^#https://#; s#$#/#' > "$TARGETS"
  echo "Wrote $(wc -l < "$TARGETS") site URLs to $TARGETS (edit it to add APIs or health endpoints)."
fi

chmod 600 "$OUT"
echo "Inventory written to $OUT"
echo
echo "Quick summary:"
grep -E '^port [0-9]+: IN USE|^!!' "$OUT" || echo "  no port conflicts with the dashboard"
