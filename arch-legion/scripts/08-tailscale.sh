#!/bin/bash
# ============================================
# Phase 08: Tailscale
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../user_credentials.conf"

echo "[08] Installing Tailscale..."
sudo pacman -S --needed --noconfirm tailscale

echo "[08] Enabling tailscaled..."
sudo systemctl enable --now tailscaled

# Auto-register if auth key is provided
if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
    echo "[08] Registering with Tailscale using auth key..."
    sudo tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh
    echo "[08] Tailscale registered. Status:"
    tailscale status
else
    echo "[08] No TAILSCALE_AUTHKEY set — skipping auto-registration."
    echo "[08] Run manually later:"
    echo "[08]   sudo tailscale up"
    echo "[08]   sudo tailscale up --ssh    (for Tailscale SSH)"
fi

echo "[08] ✓ Phase 08 complete"
