#!/bin/bash
# ============================================
# Phase 05: Podman (Rootless Containers)
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../user_credentials.conf"

echo "[05] Installing Podman and container tools..."
sudo pacman -S --needed --noconfirm \
    podman podman-compose buildah skopeo \
    fuse-overlayfs slirp4netns crun

echo "[05] Configuring rootless container security defaults..."
mkdir -p ~/.config/containers
if [[ -f "$SCRIPT_DIR/../configs/containers/containers.conf" ]]; then
    cp "$SCRIPT_DIR/../configs/containers/containers.conf" ~/.config/containers/
    echo "[05] Security config installed"
fi

echo "[05] Enabling podman socket (Docker API compat)..."
systemctl --user enable --now podman.socket 2>/dev/null || \
    echo "[05] User systemd not available in this session, will activate on next login"

echo "[05] Testing rootless container..."
if podman run --rm docker.io/library/alpine echo "Podman rootless OK" 2>/dev/null; then
    echo "[05] ✓ Rootless containers working"
else
    echo "[05] ⚠ Rootless test failed — may need reboot or subuid/subgid setup"
    # Ensure subuid/subgid are configured
    if ! grep -q "^$USER:" /etc/subuid 2>/dev/null; then
        sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"
        echo "[05] Added subuid/subgid ranges for $USER"
    fi
fi

echo "[05] Adding shell aliases..."
SHELL_RC="$HOME/.zshrc"
[[ -f "$SHELL_RC" ]] || SHELL_RC="$HOME/.bashrc"

if ! grep -q "alias docker=podman" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << 'EOF'

# Podman aliases
alias docker=podman
alias docker-compose=podman-compose
EOF
    echo "[05] Aliases added to $SHELL_RC"
fi

echo "[05] ✓ Phase 05 complete"
