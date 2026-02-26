#!/bin/bash
# ============================================
# Phase 04: Lenovo Legion Linux
# Fan control, power profiles
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../user_credentials.conf"

if [[ "$SKIP_LEGION" == "true" ]] || [[ "$VM_TEST_MODE" == "true" ]]; then
    echo "[04] Legion hardware skip enabled (VM mode). Skipping."
    exit 0
fi

# Check if we're actually on a Legion
if ! sudo dmidecode -s system-product-name 2>/dev/null | grep -qi "legion"; then
    echo "[04] Not running on Lenovo Legion hardware. Skipping."
    exit 0
fi

echo "[04] Installing LenovoLegionLinux..."
yay -S --noconfirm lenovolegionlinux-dkms-git lenovolegionlinux-cli-git

echo "[04] Loading kernel module..."
sudo modprobe lenovo_legion_wmi || echo "[04] Module may already be loaded or not supported on this model"

echo "[04] Enabling service..."
sudo systemctl enable --now legion-wmi.service 2>/dev/null || \
    echo "[04] legion-wmi service not available, may need different service name for your model"

echo "[04] Checking status..."
legion-cli status 2>/dev/null || echo "[04] legion-cli not responding, may need reboot"

echo "[04] ✓ Phase 04 complete"
echo "[04] Use 'legion-cli' to manage fan curves and power profiles"
