# arch-legion Custom ISO Builder

Builds a custom Arch Linux ISO that auto-installs the full arch-legion stack (Hyprland + HyDE + all tooling) with zero user interaction.

## How it works

1. **Boot the ISO** → live environment starts with auto-login
2. **`arch-legion-install.service`** triggers `run-install.sh` automatically
3. **`run-install.sh`** runs `archinstall` silently with our config, copies scripts to the installed system, installs a first-boot service, then reboots
4. **`arch-legion-firstboot.service`** runs phases 01-11 on first real boot, then disables itself

## Prerequisites

- An Arch Linux system (the running VM works)
- `archiso` package installed (`sudo pacman -S archiso`)

## Building

```bash
# From inside the Arch VM:
cd ~/arch-legion/iso    # or wherever you cloned the repo
sudo bash build-iso.sh
```

The ISO will be output to `~/iso-out/`.

## Copying to Windows host

```bash
scp ~/iso-out/arch-legion-*.iso user@windows-host:/path/to/arch-legion/vm/
```

## Testing

1. Create a new VirtualBox VM (8GB RAM, 60GB disk, EFI enabled)
2. Attach the built ISO
3. Boot — installation should proceed automatically
4. After first reboot, phases 01-11 run unattended
5. After second reboot, log into Hyprland via SDDM

## Configuration

- **Credentials**: Edit `airootfs/root/creds.json` to change username/password
- **Disk layout**: Edit `arch-legion/archinstall-config.json` (auto-copied at build time)
- **VM vs bare metal**: Edit `arch-legion/user_credentials.conf` toggle flags

## File structure

```
iso/
├── build-iso.sh                              # Build helper script
├── profiledef.sh                             # archiso profile definition
├── packages.x86_64                           # Packages for the live ISO
├── pacman.conf                               # pacman config for ISO build
├── README.md                                 # This file
└── airootfs/                                 # Overlay → becomes the live filesystem
    ├── root/
    │   ├── run-install.sh                    # Master install (runs archinstall)
    │   ├── arch-legion-firstboot.sh          # First-boot post-install (phases 01-11)
    │   ├── creds.json                        # archinstall credentials
    │   ├── archinstall-config.json           # (copied at build time)
    │   └── arch-legion/                      # (copied at build time)
    └── etc/systemd/system/
        └── arch-legion-install.service       # Auto-start service
```
