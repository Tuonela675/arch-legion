#!/bin/bash
# ============================================
# Phase 00: Run All Phases
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../user_credentials.conf"

echo "============================================"
echo " Arch + Hyprland (HyDE) Automated Setup"
echo " Lenovo Legion 7 — Intel i7 + RTX 40-series"
echo "============================================"
echo ""
echo "Username:   $USERNAME"
echo "Hostname:   $HOSTNAME"
echo "Timezone:   $TIMEZONE"
echo "VM Mode:    $VM_TEST_MODE"
echo "Skip Nvidia: $SKIP_NVIDIA"
echo "Skip Legion: $SKIP_LEGION"
echo ""
read -p "Proceed with installation? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

log() {
    echo ""
    echo "============================================"
    echo " PHASE $1: $2"
    echo "============================================"
    echo ""
}

log "01" "Post-Base Setup"
bash "$SCRIPT_DIR/01-post-base.sh"

log "02" "HyDE (Hyprland)"
bash "$SCRIPT_DIR/02-hyde.sh"

echo ""
echo "============================================"
echo " HyDE installed. REBOOT REQUIRED."
echo " After reboot, log into Hyprland via SDDM"
echo " then open a terminal (Super+Q) and run:"
echo ""
echo "   cd ~/arch-legion/scripts"
echo "   ./00-run-all.sh --continue"
echo "============================================"

# If called with --continue, skip to post-HyDE phases
if [[ "$1" == "--continue" ]]; then
    log "03" "Nvidia Fine-Tuning"
    bash "$SCRIPT_DIR/03-nvidia-tweaks.sh"

    log "04" "Lenovo Legion Linux"
    bash "$SCRIPT_DIR/04-legion.sh"

    log "05" "Podman (Rootless Containers)"
    bash "$SCRIPT_DIR/05-podman.sh"

    log "06" "KVM/QEMU (Virtual Machines)"
    bash "$SCRIPT_DIR/06-kvm.sh"

    log "07" "Claude Code"
    bash "$SCRIPT_DIR/07-claude-code.sh"

    log "08" "Tailscale"
    bash "$SCRIPT_DIR/08-tailscale.sh"

    log "09" "Dev Tools"
    bash "$SCRIPT_DIR/09-dev-tools.sh"

    log "10" "Security Hardening"
    bash "$SCRIPT_DIR/10-hardening.sh"

    log "11" "Cleanup & Validation"
    bash "$SCRIPT_DIR/11-cleanup.sh"

    echo ""
    echo "============================================"
    echo " ALL DONE!"
    echo " Manual steps remaining:"
    echo "   sudo tailscale up"
    echo "   claude  (to authenticate)"
    echo "============================================"
fi
