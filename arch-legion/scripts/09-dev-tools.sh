#!/bin/bash
# ============================================
# Phase 09: Dev Tools, Languages, CLI Utils
# ============================================
set -e

echo "[09] Installing CLI tools..."
sudo pacman -S --needed --noconfirm \
    ripgrep fd bat eza zoxide fzf btop \
    lazygit github-cli jq yq \
    tmux neovim tree unzip zip \
    nmap wireshark-qt \
    openssh wireguard-tools \
    man-db man-pages

echo "[09] Installing development languages..."
sudo pacman -S --needed --noconfirm \
    python python-pip python-pipx \
    nodejs npm \
    go rustup

echo "[09] Setting up Rust toolchain..."
if command -v rustup &>/dev/null; then
    rustup default stable 2>/dev/null || true
    echo "[09] Rust stable toolchain ready"
fi

echo "[09] Installing AUR packages..."
yay -S --needed --noconfirm brave-bin visual-studio-code-bin 2>/dev/null || \
    echo "[09] Some AUR packages may have failed — install manually if needed"

echo "[09] ✓ Phase 09 complete"
