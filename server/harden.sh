#!/usr/bin/env bash
# BasementIO Phase 1: baseline hardening. Safe to run more than once.
#
#   - SSH: key-only login. Root is allowed with a key only (the dashboard
#     connects to localhost as root over SSH).
#   - fail2ban with the default sshd jail.
#   - Automatic security updates (unattended-upgrades, no automatic reboot).
#
# Usage:  sudo bash harden.sh
#
# KEEP YOUR CURRENT SSH SESSION OPEN until you've confirmed a new login works.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

# --- Lockout guard: refuse to disable passwords unless a key is already installed.
login_user="${SUDO_USER:-root}"
login_home=$(getent passwd "$login_user" | cut -d: -f6)
if [[ ! -s "$login_home/.ssh/authorized_keys" ]]; then
  echo "ABORT: $login_home/.ssh/authorized_keys is empty or missing." >&2
  echo "Add your public key first (ssh-copy-id $login_user@<server>), log in with it, then re-run." >&2
  exit 1
fi
echo "OK: SSH key found for $login_user"

# --- Packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q unattended-upgrades fail2ban

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
echo "OK: automatic security updates enabled"

systemctl enable --now fail2ban
echo "OK: fail2ban running (default sshd jail)"

# --- SSH. sshd uses the FIRST value it reads for each setting, and files in
# sshd_config.d are read in name order, so 01- wins over e.g. 50-cloud-init.conf
# (which often sets PasswordAuthentication yes).
dropin=/etc/ssh/sshd_config.d/01-basementio.conf
cat > "$dropin" <<'EOF'
# Managed by BasementIO harden.sh
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
EOF

mkdir -p /run/sshd   # needed for 'sshd -t' when ssh is socket-activated (Ubuntu 24.04)
if ! sshd -t; then
  rm -f "$dropin"
  echo "ABORT: sshd rejected the config; drop-in removed, nothing changed." >&2
  exit 1
fi
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null \
  || echo "note: ssh.service not running (socket-activated); new connections read the new config"

echo "OK: SSH hardened. Effective settings:"
sshd -T | grep -Ei '^(passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin) ' || true

cat <<'EOF'

NEXT: open a NEW terminal and confirm you can still log in with your key
before closing this session. To undo: rm /etc/ssh/sshd_config.d/01-basementio.conf && systemctl reload ssh
EOF
