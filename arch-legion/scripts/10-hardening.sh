#!/bin/bash
# ============================================
# Phase 10: Security Hardening
# UFW firewall, fail2ban, AppArmor, audit
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../user_credentials.conf"

# --- Firewall (UFW) ---
echo "[10] Installing and configuring UFW..."
sudo pacman -S --needed --noconfirm ufw

sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow Tailscale traffic
sudo ufw allow in on tailscale0 comment "Tailscale"

# Allow SSH (needed for remote management)
sudo ufw allow 22/tcp comment "SSH"

sudo ufw --force enable
sudo systemctl enable ufw
echo "[10] UFW configured and enabled"

# --- Fail2ban ---
echo "[10] Installing fail2ban..."
sudo pacman -S --needed --noconfirm fail2ban
sudo systemctl enable --now fail2ban
echo "[10] fail2ban enabled"

# --- AppArmor ---
echo "[10] Installing AppArmor..."
sudo pacman -S --needed --noconfirm apparmor

# Add kernel params for AppArmor
# Detect bootloader type
if [[ -d /boot/loader/entries ]]; then
    echo "[10] Detected systemd-boot. Adding AppArmor kernel params..."
    for entry in /boot/loader/entries/*.conf; do
        if ! grep -q "apparmor=1" "$entry" 2>/dev/null; then
            sudo sed -i 's|^options\(.*\)|options\1 apparmor=1 security=apparmor|' "$entry"
            echo "[10] Updated: $entry"
        fi
    done
elif [[ -f /etc/default/grub ]]; then
    echo "[10] Detected GRUB. Adding AppArmor kernel params..."
    if ! grep -q "apparmor=1" /etc/default/grub; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 apparmor=1 security=apparmor"/' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
fi

sudo systemctl enable --now apparmor
echo "[10] AppArmor enabled (active after next boot)"

# --- Audit ---
echo "[10] Installing audit framework..."
sudo pacman -S --needed --noconfirm audit
sudo systemctl enable --now auditd
echo "[10] auditd enabled"

# --- Misc hardening ---
echo "[10] Applying misc hardening..."

# Restrict kernel log access
echo "kernel.dmesg_restrict=1" | sudo tee /etc/sysctl.d/51-dmesg-restrict.conf
# Restrict kernel pointer access
echo "kernel.kptr_restrict=2" | sudo tee /etc/sysctl.d/51-kptr-restrict.conf
# Disable core dumps for SUID
echo "fs.suid_dumpable=0" | sudo tee /etc/sysctl.d/51-coredump.conf

sudo sysctl --system &>/dev/null

echo "[10] ✓ Phase 10 complete"
echo "[10] AppArmor will be fully active after next reboot"
