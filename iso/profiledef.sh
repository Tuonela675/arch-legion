#!/usr/bin/env bash
# archiso profile definition for arch-legion custom ISO

iso_name="arch-legion"
iso_label="ARCH_LEGION_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="arch-legion <https://github.com/arch-legion>"
iso_application="Arch Linux Live/Install ISO (arch-legion)"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
            'uefi-ia32.grub.esp' 'uefi-x64.grub.esp'
            'uefi-ia32.grub.eltorito' 'uefi-x64.grub.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '-19')

# File permissions for airootfs overlay
# [path]="uid:gid:permissions"
file_permissions=(
  ["/root"]="0:0:750"
  ["/root/run-install.sh"]="0:0:755"
  ["/root/arch-legion-firstboot.sh"]="0:0:755"
  ["/root/creds.json"]="0:0:600"
  ["/root/archinstall-config.json"]="0:0:644"
)
