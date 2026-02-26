#!/bin/bash
# ============================================
# arch-legion: Build Custom ISO
# Run this inside an Arch Linux VM/system
# ============================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$SCRIPT_DIR"
WORK_DIR="/tmp/archiso-work"
OUT_DIR="$HOME/iso-out"

echo "============================================"
echo " arch-legion ISO Builder"
echo "============================================"
echo ""
echo " Profile:  $PROFILE_DIR"
echo " Work dir: $WORK_DIR"
echo " Output:   $OUT_DIR"
echo ""

# -----------------------------------------------
# 1. Check prerequisites
# -----------------------------------------------
if ! command -v mkarchiso &>/dev/null; then
    echo "archiso not found. Installing..."
    sudo pacman -S --noconfirm archiso
fi

if [[ $EUID -ne 0 ]]; then
    echo "mkarchiso requires root. Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# -----------------------------------------------
# 2. Populate airootfs with arch-legion scripts
# -----------------------------------------------
echo "Populating airootfs with arch-legion scripts..."

# The arch-legion project root (one level up from iso/)
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AIROOTFS="$PROFILE_DIR/airootfs/root/arch-legion"

# Copy the full arch-legion directory (scripts, configs, pkg list, etc.)
# Exclude the iso/ directory itself and git artifacts
mkdir -p "$AIROOTFS"
rsync -av --delete \
    --exclude='iso/' \
    --exclude='.git/' \
    --exclude='vm/' \
    --exclude='*.iso' \
    "$PROJECT_ROOT/arch-legion/" "$AIROOTFS/"

# Copy archinstall config to root's home in the ISO
cp "$PROJECT_ROOT/arch-legion/archinstall-config.json" "$PROFILE_DIR/airootfs/root/archinstall-config.json"

echo "airootfs populated."

# -----------------------------------------------
# 3. Enable the auto-install service
# -----------------------------------------------
# Create the symlink so systemd enables the service on boot
mkdir -p "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/arch-legion-install.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/arch-legion-install.service"

# -----------------------------------------------
# 4. Set up auto-login on tty1 for the live environment
# -----------------------------------------------
# archiso's releng profile uses getty override for autologin
mkdir -p "$PROFILE_DIR/airootfs/etc/systemd/system/getty@tty1.service.d"
cat > "$PROFILE_DIR/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf" << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 115200,38400,9600 $TERM
EOF

# -----------------------------------------------
# 5. Clean previous build artifacts
# -----------------------------------------------
if [[ -d "$WORK_DIR" ]]; then
    echo "Cleaning previous work directory..."
    rm -rf "$WORK_DIR"
fi
mkdir -p "$OUT_DIR"

# -----------------------------------------------
# 6. Build the ISO
# -----------------------------------------------
echo ""
echo "============================================"
echo " Building ISO..."
echo " This will take several minutes."
echo "============================================"
echo ""

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo ""
echo "============================================"
echo " ISO built successfully!"
echo " Output: $(ls -lh "$OUT_DIR"/*.iso)"
echo ""
echo " To copy to Windows host:"
echo "   scp $OUT_DIR/*.iso user@host:C:/repo/arch-legion/vm/"
echo "============================================"
