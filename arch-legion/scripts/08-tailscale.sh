#!/bin/bash
# ============================================
# Phase 08: Tailscale
# ============================================
set -e

echo "[08] Installing Tailscale..."
sudo pacman -S --needed --noconfirm tailscale

echo "[08] Enabling tailscaled..."
sudo systemctl enable --now tailscaled

echo "[08] ✓ Phase 08 complete"
echo "[08] ============================================"
echo "[08] Run these manually to authenticate:"
echo "[08]   sudo tailscale up"
echo "[08]   sudo tailscale up --ssh    (for Tailscale SSH)"
echo "[08] Then verify: tailscale status"
echo "[08] ============================================"
