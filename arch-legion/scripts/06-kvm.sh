#!/bin/bash
# ============================================
# Phase 06: KVM/QEMU + virt-manager
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../user_credentials.conf"

echo "[06] Installing virtualization stack..."
sudo pacman -S --needed --noconfirm \
    qemu-full virt-manager virt-viewer libvirt \
    edk2-ovmf dnsmasq openbsd-netcat dmidecode

echo "[06] Enabling libvirtd..."
sudo systemctl enable --now libvirtd.service

echo "[06] Adding $USER to libvirt group..."
sudo usermod -aG libvirt "$USER"

echo "[06] Setting up default network..."
sudo virsh net-autostart default 2>/dev/null || true
sudo virsh net-start default 2>/dev/null || echo "[06] Default network may already be running"

echo "[06] Enabling nested virtualization (Intel)..."
if grep -q "Intel" /proc/cpuinfo; then
    NESTED=$(cat /sys/module/kvm_intel/parameters/nested 2>/dev/null || echo "N")
    if [[ "$NESTED" != "Y" && "$NESTED" != "1" ]]; then
        echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm-nested.conf
        echo "[06] Nested virt will be enabled on next boot"
    else
        echo "[06] Nested virtualization already enabled"
    fi
fi

echo "[06] ✓ Phase 06 complete"
echo "[06] NOTE: Log out and back in for libvirt group to take effect"
echo "[06] Then launch virt-manager from rofi (Super+A)"
