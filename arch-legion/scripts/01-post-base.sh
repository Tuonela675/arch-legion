#!/bin/bash
# ============================================
# Phase 01: Post-Base Setup
# Installs yay, ensures connectivity, base deps
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../user_credentials.conf"

echo "[01] Checking internet connectivity..."
if ! ping -c2 archlinux.org &>/dev/null; then
    echo "[01] No internet. Attempting wifi connection..."
    if [[ -n "$WIFI_SSID" ]]; then
        nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS"
    else
        echo "[01] ERROR: No wifi credentials in user_credentials.conf"
        echo "[01] Connect manually: nmcli device wifi connect SSID password PASS"
        exit 1
    fi
fi
echo "[01] Internet OK"

echo "[01] Updating system..."
sudo pacman -Syu --noconfirm

echo "[01] Installing base dependencies..."
sudo pacman -S --needed --noconfirm \
    git base-devel wget curl vim neovim \
    linux-headers intel-ucode sof-firmware \
    bluez bluez-utils networkmanager

echo "[01] Enabling essential services..."
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth

echo "[01] Installing yay (AUR helper)..."
if ! command -v yay &>/dev/null; then
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay
    echo "[01] yay installed"
else
    echo "[01] yay already installed, skipping"
fi

echo "[01] ✓ Phase 01 complete"
