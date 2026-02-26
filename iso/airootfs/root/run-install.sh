#!/bin/bash
# ============================================
# arch-legion: Master Auto-Install Script
# Runs from the live ISO environment
# ============================================
set -euo pipefail

LOG="/root/arch-legion-install.log"
MOUNT="/mnt/archinstall"
CONFIG="/root/archinstall-config.json"
CREDS="/root/creds.json"
SCRIPTS_SRC="/root/arch-legion"

exec > >(tee -a "$LOG") 2>&1

log() {
    echo ""
    echo "============================================"
    echo " [$(date '+%H:%M:%S')] $1"
    echo "============================================"
}

die() {
    echo "FATAL: $1" >&2
    echo "Install log saved to $LOG"
    echo "Dropping to shell for debugging..."
    exec /bin/bash
}

# -----------------------------------------------
# 1. Wait for network
# -----------------------------------------------
log "Waiting for network connectivity..."
for i in $(seq 1 30); do
    if ping -c1 -W2 archlinux.org &>/dev/null; then
        echo "Network is up."
        break
    fi
    echo "Waiting for network... ($i/30)"
    sleep 2
done
ping -c1 -W2 archlinux.org &>/dev/null || die "No network after 60s. Check your connection."

# -----------------------------------------------
# 2. Sync clock
# -----------------------------------------------
log "Synchronizing system clock..."
timedatectl set-ntp true
sleep 2

# -----------------------------------------------
# 3. Run archinstall
# -----------------------------------------------
log "Running archinstall (unattended)..."

# archinstall expects configs via --config and --creds flags
if [[ ! -f "$CONFIG" ]]; then
    die "archinstall config not found at $CONFIG"
fi
if [[ ! -f "$CREDS" ]]; then
    die "archinstall creds not found at $CREDS"
fi

# Extract target username from creds for later use
if command -v jq &>/dev/null; then
    TARGET_USER=$(jq -r '.["!users"][0].username' "$CREDS" 2>/dev/null) || TARGET_USER=""
fi
# Fallback: parse with grep if jq unavailable or failed
if [[ -z "${TARGET_USER:-}" ]]; then
    TARGET_USER=$(grep -oP '"username"\s*:\s*"\K[^"]+' "$CREDS" | head -1)
fi
if [[ -z "${TARGET_USER:-}" ]]; then
    die "Could not extract username from $CREDS"
fi
echo "Target user: $TARGET_USER"

archinstall --config "$CONFIG" --creds "$CREDS" --mountpoint "$MOUNT" --silent \
    || die "archinstall failed. Check $LOG for details."

log "archinstall completed successfully."

# -----------------------------------------------
# 4. Verify the installed system exists
# -----------------------------------------------
if [[ ! -d "$MOUNT/etc" ]]; then
    die "Installed system not found at $MOUNT. archinstall may have failed silently."
fi

# -----------------------------------------------
# 5. Copy arch-legion scripts into installed system
# -----------------------------------------------
log "Copying arch-legion scripts to installed system..."

TARGET_HOME="$MOUNT/home/$TARGET_USER"
if [[ ! -d "$TARGET_HOME" ]]; then
    # archinstall might not have created home yet; create it
    mkdir -p "$TARGET_HOME"
fi

cp -r "$SCRIPTS_SRC" "$TARGET_HOME/arch-legion"

# Fix ownership (get uid/gid from installed system's passwd)
TARGET_UID=$(grep "^${TARGET_USER}:" "$MOUNT/etc/passwd" | cut -d: -f3)
TARGET_GID=$(grep "^${TARGET_USER}:" "$MOUNT/etc/passwd" | cut -d: -f4)
if [[ -n "$TARGET_UID" && -n "$TARGET_GID" ]]; then
    chown -R "${TARGET_UID}:${TARGET_GID}" "$TARGET_HOME/arch-legion"
else
    echo "WARNING: Could not determine uid/gid for $TARGET_USER, skipping chown"
fi

echo "Scripts copied to $TARGET_HOME/arch-legion"

# -----------------------------------------------
# 6. Install first-boot service into installed system
# -----------------------------------------------
log "Installing first-boot service..."

# Copy the first-boot script
cp /root/arch-legion-firstboot.sh "$MOUNT/usr/local/bin/arch-legion-firstboot.sh"
chmod 755 "$MOUNT/usr/local/bin/arch-legion-firstboot.sh"

# Create the first-boot systemd service (pass TARGET_USER via Environment)
cat > "$MOUNT/etc/systemd/system/arch-legion-firstboot.service" << UNIT
[Unit]
Description=arch-legion first-boot post-install
After=network-online.target multi-user.target
Wants=network-online.target
ConditionPathExists=/usr/local/bin/arch-legion-firstboot.sh

[Service]
Type=oneshot
Environment="TARGET_USER=$TARGET_USER"
ExecStart=/usr/local/bin/arch-legion-firstboot.sh
StandardOutput=journal+console
StandardError=journal+console
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

# Enable the service in the installed system via chroot
arch-chroot "$MOUNT" systemctl enable arch-legion-firstboot.service

echo "First-boot service installed and enabled."

# -----------------------------------------------
# 7. Enable essential services in installed system
# -----------------------------------------------
log "Enabling essential services..."
arch-chroot "$MOUNT" systemctl enable NetworkManager
arch-chroot "$MOUNT" systemctl enable sshd

# -----------------------------------------------
# 8. Done — prompt for reboot
# -----------------------------------------------
log "Installation complete!"
echo ""
echo "  The base system is installed at $MOUNT."
echo "  On first boot, arch-legion will automatically run"
echo "  phases 01-11 for full system configuration."
echo ""
echo "  Rebooting in 10 seconds... (Ctrl+C to cancel)"
echo "  REMOVE THE USB/ISO BEFORE REBOOT!"
echo ""
sleep 10
sync
fuser -km "$MOUNT" 2>/dev/null || true
sleep 2
umount -R "$MOUNT" 2>/dev/null || true
reboot
