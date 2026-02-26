#!/bin/bash
# ============================================
# arch-legion: First-Boot Post-Install
# Runs once on the installed system's first boot
# Executes phases 01-11 non-interactively
# ============================================
set -euo pipefail

LOG="/var/log/arch-legion-firstboot.log"
exec > >(tee -a "$LOG") 2>&1

log() {
    echo ""
    echo "============================================"
    echo " [$(date '+%H:%M:%S')] FIRST-BOOT: $1"
    echo "============================================"
}

# Read target username from user_credentials.conf (canonical source)
# Fall back to "travis" if not found
TARGET_USER="${TARGET_USER:-}"
if [[ -z "$TARGET_USER" ]]; then
    # Try to find from the installed scripts
    for home in /home/*/arch-legion; do
        if [[ -d "$home/scripts" ]]; then
            TARGET_USER="$(basename "$(dirname "$home")")"
            break
        fi
    done
fi
if [[ -z "$TARGET_USER" ]]; then
    echo "FATAL: Could not determine target user. No arch-legion scripts found in /home/*/."
    exit 1
fi

TARGET_HOME="/home/$TARGET_USER"
LEGION_DIR="$TARGET_HOME/arch-legion"
SCRIPTS_DIR="$LEGION_DIR/scripts"

# -----------------------------------------------
# Sanity checks
# -----------------------------------------------
if [[ ! -d "$SCRIPTS_DIR" ]]; then
    echo "FATAL: arch-legion scripts not found at $SCRIPTS_DIR"
    exit 1
fi

echo "Target user: $TARGET_USER"
echo "Scripts dir: $SCRIPTS_DIR"

# -----------------------------------------------
# Wait for network
# -----------------------------------------------
log "Waiting for network..."
for i in $(seq 1 30); do
    if ping -c1 -W2 archlinux.org &>/dev/null; then
        echo "Network is up."
        break
    fi
    sleep 2
done

if ! ping -c1 -W2 archlinux.org &>/dev/null; then
    echo "WARNING: No network after 60s. Continuing anyway (some phases may fail)."
fi

# -----------------------------------------------
# Phase 01: Post-base (as root, but yay needs user)
# -----------------------------------------------
log "Phase 01: Post-Base Setup"
# Must run as user — makepkg (for yay) refuses to run as root
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/01-post-base.sh" || echo "WARNING: Phase 01 had errors, continuing..."

# -----------------------------------------------
# Phase 02: HyDE — must run as target user
# -----------------------------------------------
log "Phase 02: HyDE (Hyprland)"
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/02-hyde.sh" || echo "WARNING: Phase 02 had errors, continuing..."

# -----------------------------------------------
# Phases 03-11: Run remaining phases
# Some need root, some need user context
# -----------------------------------------------
log "Phase 03: Nvidia Tweaks"
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/03-nvidia-tweaks.sh" || echo "WARNING: Phase 03 had errors, continuing..."

log "Phase 04: Legion Hardware"
bash "$SCRIPTS_DIR/04-legion.sh" || echo "WARNING: Phase 04 had errors, continuing..."

log "Phase 05: Podman"
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/05-podman.sh" || echo "WARNING: Phase 05 had errors, continuing..."

log "Phase 06: KVM/QEMU"
bash "$SCRIPTS_DIR/06-kvm.sh" || echo "WARNING: Phase 06 had errors, continuing..."

log "Phase 07: Claude Code"
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/07-claude-code.sh" || echo "WARNING: Phase 07 had errors, continuing..."

log "Phase 08: Tailscale"
bash "$SCRIPTS_DIR/08-tailscale.sh" || echo "WARNING: Phase 08 had errors, continuing..."

log "Phase 09: Dev Tools"
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/09-dev-tools.sh" || echo "WARNING: Phase 09 had errors, continuing..."

log "Phase 10: Security Hardening"
bash "$SCRIPTS_DIR/10-hardening.sh" || echo "WARNING: Phase 10 had errors, continuing..."

log "Phase 11: Cleanup & Validation"
bash "$SCRIPTS_DIR/11-cleanup.sh" || echo "WARNING: Phase 11 had errors, continuing..."

# -----------------------------------------------
# Disable this service so it doesn't run again
# -----------------------------------------------
log "First-boot complete. Disabling first-boot service."
systemctl disable arch-legion-firstboot.service
rm -f /usr/local/bin/arch-legion-firstboot.sh
systemctl daemon-reload

echo ""
echo "============================================"
echo " arch-legion first-boot post-install DONE"
echo " Log saved to: $LOG"
echo ""
echo " Manual steps remaining:"
echo "   sudo tailscale up"
echo "   claude  (to authenticate)"
echo ""
echo " A reboot is recommended."
echo "============================================"

# Reboot to apply all changes (HyDE, SDDM, etc.)
echo "Rebooting in 30 seconds to apply changes... (Ctrl+C to cancel)"
sleep 30
reboot
