# Arch + Hyprland (HyDE) — Lenovo Legion 7 Automation
## Intel i7 + RTX 40-series | Modular Install Scripts

---

## What's in this package

```
arch-legion/
├── README.md                     # You're reading this
├── user_credentials.conf         # *** EDIT THIS FIRST ***
├── archinstall-config.json       # archinstall configuration
├── scripts/
│   ├── 00-run-all.sh             # Orchestrator — runs all phases
│   ├── 01-post-base.sh           # Yay, base packages, prep
│   ├── 02-hyde.sh                # HyDE (Hyprland + full rice)
│   ├── 03-nvidia-tweaks.sh       # Nvidia env vars + validation
│   ├── 04-legion.sh              # LenovoLegionLinux fan/power
│   ├── 05-podman.sh              # Podman rootless + hardening
│   ├── 06-kvm.sh                 # KVM/QEMU + virt-manager
│   ├── 07-claude-code.sh         # Claude Code native installer
│   ├── 08-tailscale.sh           # Tailscale install + enable
│   ├── 09-dev-tools.sh           # CLI tools, languages, browsers
│   ├── 10-hardening.sh           # UFW, fail2ban, AppArmor, audit
│   └── 11-cleanup.sh             # Final cleanup + checklist
├── configs/
│   ├── hypr/
│   │   └── userprefs.conf        # Nvidia + custom Hyprland env vars
│   ├── containers/
│   │   └── containers.conf       # Podman security defaults
│   └── ufw-tailscale.rules       # UFW rules for tailscale
└── pkg_user.lst                  # Extra packages for HyDE installer
```

---

## Quick Start

### Step 1: Edit credentials (on Windows, before anything)

Edit `user_credentials.conf` with your desired username, hostname, timezone, etc.

### Step 2: Prep USB

1. Install Ventoy on a USB stick: https://ventoy.net
2. Copy the latest Arch ISO onto the Ventoy USB
3. Copy this entire `arch-legion/` folder onto the Ventoy USB

### Step 3: Boot & Install Base Arch

1. Boot from USB on your Legion 7
2. Connect to wifi: `iwctl station wlan0 connect "YOUR_NETWORK"`
3. Mount the Ventoy data partition:
   ```bash
   mkdir /mnt/ventoy
   mount /dev/disk/by-label/Ventoy /mnt/ventoy   # or find with lsblk
   ```
4. Run archinstall with the config:
   ```bash
   archinstall --config /mnt/ventoy/arch-legion/archinstall-config.json
   ```
5. When done, **chroot or reboot** into the new system

### Step 4: Run the automation

After rebooting into your fresh Arch install:

```bash
# Mount USB again to access scripts
sudo mkdir -p /mnt/usb
sudo mount /dev/sdX1 /mnt/usb   # find your USB with lsblk

# Copy scripts to home
cp -r /mnt/usb/arch-legion ~/arch-legion
cd ~/arch-legion/scripts

# Option A: Run everything
chmod +x *.sh
./00-run-all.sh

# Option B: Run phase by phase
chmod +x *.sh
./01-post-base.sh
# reboot if needed, then continue:
./02-hyde.sh
# reboot into HyDE, then continue from terminal:
./03-nvidia-tweaks.sh
./04-legion.sh
./05-podman.sh
./06-kvm.sh
./07-claude-code.sh
./08-tailscale.sh
./09-dev-tools.sh
./10-hardening.sh
./11-cleanup.sh
```

### Step 5: Manual steps (can't automate these)

1. `sudo tailscale up` — authenticate in browser
2. `claude` — authenticate with your Claude account
3. Test audio, brightness keys, wifi after reboot

---

## VM Testing (VirtualBox)

### Setup VirtualBox VM

1. New VM → Type: Linux, Version: Arch Linux (64-bit)
2. RAM: 8192 MB (minimum 4096)
3. CPUs: 4+
4. Disk: 60 GB dynamically allocated
5. **Settings → Display → Video Memory: 128 MB, enable 3D Acceleration**
6. **Settings → System → enable EFI**
7. Mount the Arch ISO as optical drive

### What to test in VM

- ✅ archinstall config works without errors
- ✅ All phase scripts run without errors
- ✅ HyDE installs and SDDM loads (will be software-rendered)
- ✅ Podman rootless containers work
- ✅ KVM/QEMU installs (nested virt won't work in VBox)
- ✅ Tailscale installs and daemon starts
- ✅ Claude Code installs
- ✅ UFW rules apply correctly
- ✅ All services enable without errors

### What you CAN'T test in VM

- ❌ Nvidia GPU drivers (no passthrough in VBox)
- ❌ LenovoLegionLinux (no Legion hardware)
- ❌ Hyprland performance/animations (software rendered = sluggish)
- ❌ Hibernate/suspend behavior
- ❌ Hardware brightness/audio keys

### VM-specific notes

- Script 03 (nvidia-tweaks) will detect no Nvidia card and skip gracefully
- Script 04 (legion) will skip if no Legion hardware detected
- HyDE in VM will default to software rendering — it'll look right but run slow
- Networking works normally for Tailscale/package installs

---

## Troubleshooting

**HyDE install fails:** Make sure you're running as your normal user, NOT root/sudo.

**Nvidia not detected after bare metal install:** Check BIOS GPU mode — must be
"dGPU Only" or "Dynamic", NOT "Hybrid (iGPU only)".

**No audio:** Install `sof-firmware` — `sudo pacman -S sof-firmware` and reboot.

**Wifi drops after install:** Ensure NetworkManager is enabled:
`sudo systemctl enable --now NetworkManager`

**SDDM doesn't start:** `sudo systemctl enable --now sddm`
