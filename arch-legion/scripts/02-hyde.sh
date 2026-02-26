#!/bin/bash
# ============================================
# Phase 02: HyDE (Hyprland + Full Rice)
# Auto-detects Nvidia and installs drivers
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../user_credentials.conf"

echo "[02] Cloning HyDE..."
if [[ -d ~/HyDE ]]; then
    echo "[02] HyDE directory exists, pulling latest..."
    cd ~/HyDE
    git fetch --update-shallow --depth 1 origin master
    git reset --hard origin/master
else
    git clone --depth 1 https://github.com/HyDE-Project/HyDE ~/HyDE
fi

# Copy our custom package list alongside HyDE
if [[ -f "$SCRIPT_DIR/../pkg_user.lst" ]]; then
    cp "$SCRIPT_DIR/../pkg_user.lst" ~/HyDE/Scripts/pkg_user.lst
    echo "[02] Custom package list copied"
fi

cd ~/HyDE/Scripts

echo "[02] ============================================"
echo "[02] Starting HyDE installer"
echo "[02] This will take 20-30 minutes"
echo "[02] It will auto-detect Nvidia and install drivers"
echo "[02] Press ENTER for defaults at each prompt"
echo "[02] ============================================"

if [[ "$SKIP_NVIDIA" == "true" ]]; then
    echo "[02] VM mode: skipping Nvidia detection"
    ./install.sh -dn pkg_user.lst
else
    ./install.sh -d pkg_user.lst
fi

echo "[02] ✓ Phase 02 complete"
echo "[02] ============================================"
echo "[02] REBOOT NOW: sudo reboot"
echo "[02] Log into Hyprland via SDDM after reboot"
echo "[02] Then continue with Phase 03"
echo "[02] ============================================"
