# Arch Linux + Hyprland (HyDE) — Lenovo Legion 7
## Intel i7 + RTX 40-series | Full Dev Workstation Guide

---

## What You're Building

- **OS:** Arch Linux (rolling release)
- **Desktop:** Hyprland compositor + HyDE dotfiles (gorgeous tiling Wayland)
- **GPU:** Nvidia RTX 4000-series with proprietary open-kernel drivers
- **Containers:** Podman (rootless, daemonless)
- **VMs:** KVM/QEMU with virt-manager
- **Dev Tools:** Claude Code, Tailscale, git, base-devel
- **Laptop Extras:** LenovoLegionLinux (fan control, power profiles)

---

## Phase 1: Prepare Install Media

1. Download the latest Arch ISO: https://archlinux.org/download/
2. Flash to USB with Ventoy, Rufus, or: `dd bs=4M if=archlinux.iso of=/dev/sdX status=progress oflag=sync`
3. Boot the Legion 7 from USB (spam F12 at boot for boot menu)
4. **BIOS settings first** (F2 at boot):
   - Disable Secure Boot
   - Set boot mode to UEFI only
   - Set GPU mode to **dGPU Only** or **Dynamic** (avoid iGPU-only mode — it causes Nvidia detection issues on Linux)

---

## Phase 2: Install Base Arch

The easiest path is `archinstall`. From the live USB:

```bash
# Connect to wifi if needed
iwctl
# Inside iwctl:
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "YOUR_NETWORK"
exit

# Verify internet
ping -c3 archlinux.org

# Update keyring
pacman -Sy archlinux-keyring

# Launch guided installer
archinstall
```

### archinstall settings — pick these:

| Setting | Value |
|---|---|
| **Mirrors** | Select your region |
| **Locales** | en_US.UTF-8, UTF-8 |
| **Disk config** | Use best-effort, select your NVMe, **ext4** or **btrfs** (btrfs recommended for snapshots) |
| **Disk encryption** | Optional — LUKS if you want FDE |
| **Bootloader** | **systemd-boot** (lighter than GRUB, HyDE supports both) |
| **Swap** | zram (or True if you want hibernate support) |
| **Hostname** | whatever you want (e.g. `legion`) |
| **Root password** | Set one |
| **User account** | Create your user, add to `wheel` group, set sudo |
| **Profile** | **Minimal** — do NOT pick a desktop here, HyDE handles that |
| **Audio** | pipewire |
| **Kernel** | linux (standard) |
| **Additional packages** | `git base-devel wget curl vim networkmanager linux-headers intel-ucode` |
| **Network config** | NetworkManager |
| **Timezone** | America/Vancouver |

Hit install, let it finish, then **reboot into your fresh Arch install** (remove USB).

---

## Phase 3: First Boot — Pre-HyDE Setup

Log in at the TTY with your user account.

```bash
# Verify internet
ping -c3 archlinux.org

# If wifi needed:
nmcli device wifi connect "YOUR_NETWORK" password "YOUR_PASSWORD"

# Ensure base-devel and git are installed
sudo pacman -S --needed git base-devel wget curl

# Install yay (AUR helper)
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf yay
```

---

## Phase 4: Install HyDE (Hyprland + Full Rice)

This is the good part. HyDE auto-detects your Nvidia RTX card and installs
`nvidia-open-dkms` drivers, configures NVIDIA DRM in your bootloader, and sets up
the full Hyprland environment with themes, waybar, rofi, SDDM, and more.

```bash
# Clone HyDE
git clone --depth 1 https://github.com/HyDE-Project/HyDE ~/HyDE
cd ~/HyDE/Scripts

# Run the installer (DO NOT use sudo — run as your normal user)
./install.sh
```

**During installation:**
- It will detect your Nvidia RTX card and install drivers automatically
- When prompted, press ENTER for defaults or select option 1
- Takes ~20-30 minutes depending on internet speed
- It installs: hyprland, waybar, rofi, kitty, dolphin, SDDM, themes, fonts, etc.

**After install completes:**
```bash
sudo reboot
```

You should boot into the SDDM login screen. Log in and you're in Hyprland + HyDE.

### Essential Keybinds

| Keys | Action |
|---|---|
| `Super + Q` | Open terminal (kitty) |
| `Super + A` | App launcher (rofi) |
| `Super + E` | File manager (dolphin) |
| `Super + F` | Firefox |
| `Super + /` | Show keybinds cheatsheet |
| `Super + 1-9` | Switch workspace |
| `Super + Shift + 1-9` | Move window to workspace |
| `Super + W` | Toggle float |
| `Super + L` | Lock screen |
| `Super + Backspace` | Logout menu |

---

## Phase 5: Nvidia Fine-Tuning

HyDE handles most of this, but verify and tweak:

```bash
# Verify Nvidia driver is loaded
nvidia-smi

# Check driver version
cat /proc/driver/nvidia/version

# Verify DRM modeset is enabled (should already be set by HyDE)
cat /sys/module/nvidia_drm/parameters/modeset
# Should output: Y
```

### Add Nvidia environment variables to Hyprland config

Edit `~/.config/hypr/userprefs.conf` (HyDE's user override file):

```bash
# Nvidia env vars (add these if not already present)
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct

# Cursor fix for Nvidia
env = WLR_NO_HARDWARE_CURSORS,1

# For electron/chromium apps on Wayland
env = ELECTRON_OZONE_PLATFORM_HINT,auto
```

Reload: `Super + Shift + R` or `hyprctl reload`

---

## Phase 6: Lenovo Legion Linux (Fan Control + Power Profiles)

```bash
# Install from AUR
yay -S lenovolegionlinux-dkms-git lenovolegionlinux-cli-git

# Load the module
sudo modprobe lenovo_legion_wmi

# Enable the service
sudo systemctl enable --now legion-wmi.service

# Verify it's working
legion-cli status

# Optional: GUI for fan curves (if you want it)
yay -S lenovolegionlinux-gui-git
```

This gives you control over:
- Fan curves (quiet/balanced/performance/custom)
- Power profiles
- GPU power limits
- Battery conservation mode

---

## Phase 7: Podman (Rootless Containers)

```bash
# Install podman and friends
sudo pacman -S podman podman-compose buildah skopeo fuse-overlayfs slirp4netns

# Verify rootless works
podman run --rm docker.io/library/alpine echo "rootless containers work"

# Enable podman socket (Docker API compatibility)
systemctl --user enable --now podman.socket

# Optional: alias docker to podman for muscle memory
echo 'alias docker=podman' >> ~/.zshrc
echo 'alias docker-compose=podman-compose' >> ~/.zshrc
```

### Container security hardening

```bash
# Edit containers.conf for security defaults
mkdir -p ~/.config/containers
cat > ~/.config/containers/containers.conf << 'EOF'
[containers]
# Drop all capabilities by default
default_capabilities = []

# No new privileges
no_new_privileges = true

# Read-only rootfs by default (override per container with --read-only=false)
read_only = false

# Default seccomp profile
seccomp_profile = "/usr/share/containers/seccomp.json"

[engine]
# Use crun for better rootless performance
runtime = "crun"
EOF
```

---

## Phase 8: KVM/QEMU + virt-manager (Virtual Machines)

```bash
# Install virtualization stack
sudo pacman -S qemu-full virt-manager virt-viewer libvirt \
  edk2-ovmf dnsmasq bridge-utils openbsd-netcat dmidecode

# Enable libvirtd
sudo systemctl enable --now libvirtd.service

# Add your user to libvirt group
sudo usermod -aG libvirt $(whoami)

# Enable default network
sudo virsh net-autostart default
sudo virsh net-start default

# Log out and back in for group changes to take effect
```

After re-login, launch `virt-manager` from rofi (`Super + A`, type "virt").

### Nested virtualization (optional, useful for testing k8s in VMs)

```bash
# Check if enabled
cat /sys/module/kvm_intel/parameters/nested
# If N:
sudo modprobe -r kvm_intel
sudo modprobe kvm_intel nested=1

# Make permanent
echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm-nested.conf
```

---

## Phase 9: Claude Code

```bash
# Install via native installer (no Node.js needed)
curl -fsSL https://claude.ai/install.sh | bash

# Verify
claude --version

# First run — will prompt for auth
claude
```

Claude Code will prompt you to authenticate via your Claude Pro/Max subscription or API key.

---

## Phase 10: Tailscale

```bash
# Install tailscale
sudo pacman -S tailscale

# Enable and start
sudo systemctl enable --now tailscaled

# Authenticate
sudo tailscale up

# Verify
tailscale status

# Optional: enable SSH via tailscale
sudo tailscale up --ssh
```

Your Legion 7 is now on your tailnet. Access it from anywhere.

---

## Phase 11: Additional Dev Tools

```bash
# Essential CLI tools
sudo pacman -S \
  ripgrep fd bat eza zoxide fzf btop \
  lazygit github-cli jq yq \
  python python-pip python-pipx \
  nodejs npm \
  go rustup \
  tmux neovim \
  nmap wireshark-qt \
  openssh wireguard-tools

# Rust toolchain
rustup default stable

# Browsers
yay -S firefox brave-bin

# VS Code (if you want it alongside Claude Code)
yay -S visual-studio-code-bin
```

---

## Phase 12: Security Hardening

```bash
# Firewall
sudo pacman -S ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on tailscale0   # Allow tailscale traffic
sudo ufw enable
sudo systemctl enable ufw

# Fail2ban for SSH
sudo pacman -S fail2ban
sudo systemctl enable --now fail2ban

# AppArmor (optional — adds MAC on top of Arch)
sudo pacman -S apparmor
# Add apparmor=1 security=apparmor to kernel params in bootloader
# For systemd-boot, edit /boot/loader/entries/arch.conf:
#   options ... apparmor=1 security=apparmor
sudo systemctl enable --now apparmor

# Audit logging
sudo pacman -S audit
sudo systemctl enable --now auditd

# Auto security updates check
yay -S informant   # warns before upgrading about Arch news
```

---

## Post-Install Checklist

- [ ] `nvidia-smi` shows your RTX card
- [ ] Hyprland runs smooth with no flickering
- [ ] `podman run --rm alpine echo "works"` succeeds
- [ ] `virt-manager` launches and can create VMs
- [ ] `claude --version` returns a version
- [ ] `tailscale status` shows connected
- [ ] `legion-cli status` shows fan/power info
- [ ] Audio works (test with `pactl info`)
- [ ] Wifi works after reboot
- [ ] Brightness keys work (`brightnessctl`)
- [ ] Battery reporting works

---

## HyDE Theme Switching

One of HyDE's killer features — theme hot-swapping:

```
Super + Shift + T    # Cycle themes
Super + Shift + W    # Cycle wallpapers
```

Or use the HyDE CLI:
```bash
# List themes
Hyde theme list

# Apply a theme
Hyde theme set "Catppuccin Mocha"

# Install more themes from gallery
Hyde theme install
```

Browse community themes: https://github.com/kRHYME7/hyde-gallery

---

## Useful Links

- Arch Wiki (your bible): https://wiki.archlinux.org
- Hyprland Wiki: https://wiki.hypr.land
- Hyprland Nvidia guide: https://wiki.hypr.land/Nvidia/
- HyDE Project: https://github.com/HyDE-Project/HyDE
- HyDE Theme Gallery: https://github.com/kRHYME7/hyde-gallery
- LenovoLegionLinux: https://github.com/johnfanv2/LenovoLegionLinux
- Tailscale Docs: https://tailscale.com/kb
- Podman Docs: https://docs.podman.io

---

*Built for Travis's Lenovo Legion 7 (Intel i7 + RTX 40-series) — Feb 2026*
