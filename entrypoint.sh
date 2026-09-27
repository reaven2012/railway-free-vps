#!/bin/bash
set -e

echo "=== railway-free-vps starting ==="

# SSH host keys (in case the image build didn't create them)
ssh-keygen -A 2>/dev/null || true
mkdir -p /var/run/sshd

# Allow password auth explicitly
mkdir -p /etc/ssh/sshd_config.d
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/99-railway.conf

# Set the ubuntu user's password from env
if [ -n "${SSH_PASSWORD}" ]; then
  echo "ubuntu:${SSH_PASSWORD}" | chpasswd
  echo "SSH password set from SSH_PASSWORD env var"
else
  echo "WARNING: SSH_PASSWORD env var is empty; SSH password login will fail"
fi

# Start OpenSSH
/usr/sbin/sshd
echo "sshd started"

# Start tailscaled in userspace-networking mode (no privileged TUN on Railway)
if [ -z "${TS_AUTHKEY}" ]; then
  echo "ERROR: TS_AUTHKEY env var is not set."
  echo "Add TS_AUTHKEY in Railway -> Service -> Variables and redeploy."
else
  mkdir -p /var/lib/tailscale /var/run/tailscale
  tailscaled \
    --tun=userspace-networking \
    --state=/var/lib/tailscale/tailscaled.state \
    --socket=/var/run/tailscale/tailscaled.sock \
    > /var/log/tailscaled.log 2>&1 &
  for i in $(seq 1 30); do
    [ -S /var/run/tailscale/tailscaled.sock ] && break
    sleep 1
  done
  if tailscale up --authkey="${TS_AUTHKEY}" --hostname="${TS_HOSTNAME:-railway-vps}"; then
    echo "Tailscale is up."
    tailscale status || true
    echo "Tailscale IP: $(tailscale ip -4 2>/dev/null || echo unknown)"
  else
    echo "ERROR: 'tailscale up' failed. Check TS_AUTHKEY and see /var/log/tailscaled.log"
  fi
fi

# Listen on Railway's $PORT so the platform sees a live port (harmless landing page)
if [ -n "${PORT}" ]; then
  mkdir -p /var/www
  echo "railway-vps is running" > /var/www/index.html
  python3 -m http.server "${PORT}" --directory /var/www > /var/log/http.log 2>&1 &
  echo "HTTP placeholder listening on PORT=${PORT}"
fi

echo "=== startup complete; container staying alive ==="
tail -f /dev/null
