#!/bin/bash
# ============================================
# Phase 11: Cleanup & Validation
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../user_credentials.conf"

echo "[11] Running validation checks..."
echo ""

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; }
skip() { echo "  ○ $1 (skipped)"; }

echo "=== System ==="
command -v hyprctl &>/dev/null && pass "Hyprland installed" || fail "Hyprland not found"
systemctl is-active --quiet sddm && pass "SDDM running" || fail "SDDM not running"
[[ -f ~/.config/hypr/hyprland.conf ]] && pass "HyDE config present" || fail "HyDE config missing"

echo ""
echo "=== GPU ==="
if [[ "$SKIP_NVIDIA" == "true" ]] || [[ "$VM_TEST_MODE" == "true" ]]; then
    skip "Nvidia (VM mode)"
else
    command -v nvidia-smi &>/dev/null && pass "Nvidia driver loaded" || fail "Nvidia driver not found"
    [[ "$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null)" == "Y" ]] && \
        pass "DRM modeset enabled" || fail "DRM modeset not enabled"
fi

echo ""
echo "=== Containers ==="
command -v podman &>/dev/null && pass "Podman installed" || fail "Podman not found"
podman run --rm alpine echo "ok" &>/dev/null 2>&1 && pass "Rootless containers working" || fail "Rootless containers broken"

echo ""
echo "=== Virtualization ==="
command -v virsh &>/dev/null && pass "libvirt installed" || fail "libvirt not found"
systemctl is-active --quiet libvirtd && pass "libvirtd running" || fail "libvirtd not running"
groups | grep -q libvirt && pass "User in libvirt group" || fail "User NOT in libvirt group (re-login)"

echo ""
echo "=== Tools ==="
command -v claude &>/dev/null && pass "Claude Code installed" || fail "Claude Code not found"
command -v tailscale &>/dev/null && pass "Tailscale installed" || fail "Tailscale not found"
systemctl is-active --quiet tailscaled && pass "tailscaled running" || fail "tailscaled not running"

echo ""
echo "=== Security ==="
sudo ufw status | grep -q "active" && pass "UFW active" || fail "UFW not active"
systemctl is-active --quiet fail2ban && pass "fail2ban running" || fail "fail2ban not running"
systemctl is-active --quiet apparmor && pass "AppArmor running" || fail "AppArmor not running"
systemctl is-active --quiet auditd && pass "auditd running" || fail "auditd not running"

echo ""
echo "=== Legion Hardware ==="
if [[ "$SKIP_LEGION" == "true" ]] || [[ "$VM_TEST_MODE" == "true" ]]; then
    skip "Legion hardware (VM mode)"
else
    command -v legion-cli &>/dev/null && pass "LenovoLegionLinux installed" || fail "LenovoLegionLinux not found"
fi

echo ""
echo "=== Dev Tools ==="
command -v git &>/dev/null && pass "git" || fail "git"
command -v python3 &>/dev/null && pass "Python $(python3 --version 2>&1 | awk '{print $2}')" || fail "Python"
command -v node &>/dev/null && pass "Node $(node --version 2>&1)" || fail "Node"
command -v go &>/dev/null && pass "Go $(go version 2>&1 | awk '{print $3}')" || fail "Go"
command -v rustc &>/dev/null && pass "Rust $(rustc --version 2>&1 | awk '{print $2}')" || fail "Rust"
command -v nvim &>/dev/null && pass "Neovim" || fail "Neovim"

echo ""
echo "============================================"
echo " Validation complete!"
echo ""
echo " Manual steps remaining:"
echo "   sudo tailscale up         (authenticate)"
echo "   claude                    (authenticate)"
echo "   Reboot for AppArmor to fully activate"
echo "============================================"

# Clean up package cache to save space
echo ""
read -p "Clean pacman cache? [y/N] " clean
if [[ "$clean" =~ ^[Yy]$ ]]; then
    sudo pacman -Scc --noconfirm
    echo "[11] Cache cleaned"
fi

echo "[11] ✓ Phase 11 complete. You're done!"
