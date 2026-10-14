#!/usr/bin/env bash
# BasementIO Phase 1: install the dashboard (deploys, previews, databases,
# backups, proxy, web terminal).
#
# The admin account is created DURING install, so the public registration page
# is never left open: whoever registers first becomes admin with root access to
# the server. The password is asked at a hidden prompt so it stays out of your
# shell history.
#
# Usage:  sudo bash install-dashboard.sh
#
# Run it in a low-traffic window: the installer configures Docker and may restart
# the Docker daemon, which briefly restarts existing containers.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

if command -v snap >/dev/null 2>&1 && snap list docker >/dev/null 2>&1; then
  echo "ABORT: Docker is installed via snap, which is not supported." >&2
  echo "Replace it with Docker Engine from apt first (see Docker's install docs)." >&2
  exit 1
fi

read -rp "Admin username (3+ chars): " ROOT_USERNAME
read -rp "Admin email: " ROOT_USER_EMAIL
read -rsp "Admin password: " ROOT_USER_PASSWORD; echo

if [[ ${#ROOT_USER_PASSWORD} -lt 8 \
   || ! $ROOT_USER_PASSWORD =~ [A-Z] || ! $ROOT_USER_PASSWORD =~ [a-z] \
   || ! $ROOT_USER_PASSWORD =~ [0-9] || ! $ROOT_USER_PASSWORD =~ [^A-Za-z0-9] ]]; then
  echo "ABORT: password needs 8+ characters with upper, lower, a number and a symbol." >&2
  exit 1
fi

export ROOT_USERNAME ROOT_USER_EMAIL ROOT_USER_PASSWORD
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

echo
echo "Done. Open the dashboard over Tailscale: http://$(tailscale ip -4 2>/dev/null || echo '<tailscale-ip>'):8000"
