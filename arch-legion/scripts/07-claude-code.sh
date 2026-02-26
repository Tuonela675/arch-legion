#!/bin/bash
# ============================================
# Phase 07: Claude Code
# ============================================
set -e

echo "[07] Installing Claude Code (native installer)..."
if command -v claude &>/dev/null; then
    echo "[07] Claude Code already installed: $(claude --version)"
else
    curl -fsSL https://claude.ai/install.sh | bash
    echo "[07] Claude Code installed"
fi

echo "[07] ✓ Phase 07 complete"
echo "[07] Run 'claude' to authenticate with your account"
