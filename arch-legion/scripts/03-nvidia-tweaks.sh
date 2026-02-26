#!/bin/bash
# ============================================
# Phase 03: Nvidia Fine-Tuning
# Adds env vars, validates driver
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../user_credentials.conf"

if [[ "$SKIP_NVIDIA" == "true" ]] || [[ "$VM_TEST_MODE" == "true" ]]; then
    echo "[03] Nvidia skip enabled (VM mode). Skipping."
    exit 0
fi

echo "[03] Checking Nvidia driver..."
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    echo "[03] Nvidia driver loaded ✓"
else
    echo "[03] WARNING: nvidia-smi not found. Driver may not be installed."
    echo "[03] HyDE should have handled this. Check with: lspci -k | grep -A3 NVIDIA"
    exit 1
fi

echo "[03] Checking DRM modeset..."
MODESET=$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo "N")
if [[ "$MODESET" != "Y" ]]; then
    echo "[03] WARNING: nvidia_drm.modeset is not enabled"
    echo "[03] HyDE should have set this in bootloader. Check boot params."
fi

echo "[03] Installing Hyprland Nvidia env vars..."
USERPREFS="$HOME/.config/hypr/userprefs.conf"

# Back up existing if present
if [[ -f "$USERPREFS" ]]; then
    cp "$USERPREFS" "$USERPREFS.bak.$(date +%s)"
fi

# Copy our Nvidia config
if [[ -f "$SCRIPT_DIR/../configs/hypr/userprefs.conf" ]]; then
    # Append our nvidia vars if userprefs already exists
    if [[ -f "$USERPREFS" ]]; then
        echo "" >> "$USERPREFS"
        echo "# === Nvidia vars added by arch-legion setup ===" >> "$USERPREFS"
        cat "$SCRIPT_DIR/../configs/hypr/userprefs.conf" >> "$USERPREFS"
    else
        mkdir -p "$(dirname "$USERPREFS")"
        cp "$SCRIPT_DIR/../configs/hypr/userprefs.conf" "$USERPREFS"
    fi
    echo "[03] Nvidia env vars added to $USERPREFS"
fi

echo "[03] Reloading Hyprland config..."
hyprctl reload 2>/dev/null || echo "[03] Not in Hyprland session, reload manually with Super+Shift+R"

echo "[03] ✓ Phase 03 complete"
