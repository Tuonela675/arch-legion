# Code Review: ISO Profile Files

## Summary

This review examines the newly created ISO profile files in `C:\repo\arch-legion\iso\` including:
- `profiledef.sh` - archiso profile definition
- `build-iso.sh` - ISO build orchestrator
- `pacman.conf` - package manager config
- `airootfs/root/run-install.sh` - unattended archinstall wrapper
- `airootfs/root/arch-legion-firstboot.sh` - first-boot phase runner
- `airootfs/root/creds.json` - archinstall credentials
- `airootfs/etc/systemd/system/arch-legion-install.service` - ISO-time service
- `airootfs/etc/systemd/system/arch-legion-install.service` - first-boot service (created by run-install.sh)

The ISO profile implements a three-stage installation workflow:
1. **Live ISO boot** → Auto-run `run-install.sh` via systemd service
2. **Base system install** → archinstall configured via JSON + creds
3. **First-boot setup** → Execute phases 01-11 in correct user context

---

## Risk Assessment: MEDIUM

The implementation is generally sound but has several issues that could cause installation failures or incorrect privilege escalation. All issues are fixable without architectural changes.

---

## Issues Found

### Critical (must fix)

#### 1. **arch-legion-firstboot.sh line 82: Hardcoded username breaks flexibility**

The first-boot script hardcodes `TARGET_USER="travis"` but the ISO build uses `user_credentials.conf` which allows customization. This creates a mismatch where:
- `creds.json` defines username (currently "travis")
- `run-install.sh` hardcodes TARGET_USER="travis"
- `arch-legion-firstboot.sh` hardcodes TARGET_USER="travis"

**Risk**: If someone changes `creds.json` username to "alice", the first-boot script will try to run phases as "travis" (wrong user) and copy scripts to wrong home directory.

**Fix**: Extract username from `creds.json` in `run-install.sh` and pass it to first-boot script:

```bash
# In run-install.sh, after line 61:
TARGET_USER=$(jq -r '.!users[0].username' "$CREDS")
if [[ -z "$TARGET_USER" ]]; then
    die "Could not extract username from creds.json"
fi

# When creating first-boot service (line 113-129), embed it:
cat > "$MOUNT/etc/systemd/system/arch-legion-firstboot.service" << UNIT
[Service]
Environment="TARGET_USER=$TARGET_USER"
ExecStart=/usr/local/bin/arch-legion-firstboot.sh
UNIT

# In arch-legion-firstboot.sh, read from environment (line 19):
TARGET_USER="${TARGET_USER:-travis}"  # fallback to travis if not set
```

---

#### 2. **run-install.sh line 82: Hardcoded username doesn't match archinstall config**

Similar to issue #1, but in the install script:
```bash
TARGET_USER="travis"  # LINE 82
```

This is inconsistent with:
- `creds.json` which defines the actual user
- `user_credentials.conf` USERNAME setting

**Fix**: Same as #1 — extract from `creds.json`:
```bash
TARGET_USER=$(jq -r '.!users[0].username' "$CREDS") || die "Could not read username from creds"
```

---

#### 3. **arch-legion-firstboot.sh: Phase execution context is incorrect for several phases**

The script has **inconsistent and incorrect privilege escalation**. Analysis of phase requirements:

| Phase | Needs | Current Script | Correct? |
|-------|-------|---|---|
| 01-post-base.sh | root (pacman, systemctl) | bash (root) ✓ | YES |
| 02-hyde.sh | **user** (git, ~/) | sudo -u $USER ✓ | YES |
| 03-nvidia.sh | **user** (config files in ~) | sudo -u $USER ✓ | YES |
| 04-legion.sh | root (yay, systemctl) | bash (root) ✓ | YES |
| 05-podman.sh | **user** (systemctl --user) | sudo -u $USER ✓ | YES |
| 06-kvm.sh | root (modprobe, virsh) | bash (root) ✓ | YES |
| 07-claude-code.sh | **user** (install via curl \| bash) | sudo -u $USER ✓ | YES |
| 08-tailscale.sh | root (systemctl) | bash (root) ✓ | YES |
| 09-dev-tools.sh | **user** (yay) | sudo -u $USER ✓ | YES |
| 10-hardening.sh | root | bash (root) ✓ | YES |
| 11-cleanup.sh | root | bash (root) ✓ | YES |

**Wait — the script actually looks correct!** However, there are subtle issues:

**Issue 3a**: Lines 53, 69, 75, 81, 87, 90 all run as root when they should be user:
```bash
# Line 53 - WRONG
bash "$SCRIPTS_DIR/01-post-base.sh"  # root context, good

# Line 59 - correct
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/02-hyde.sh"

# Line 66 - WRONG
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/03-nvidia-tweaks.sh"
# 03-nvidia-tweaks.sh sources user_credentials.conf and reads/writes to ~/.config/
# This is correct (needs user context)

# Line 69 - correct
bash "$SCRIPTS_DIR/04-legion.sh"  # root, correct

# Line 75 - correct
bash "$SCRIPTS_DIR/06-kvm.sh"  # root, correct

# Line 81 - WRONG
bash "$SCRIPTS_DIR/08-tailscale.sh"  # root, correct

# Line 84 - correct
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/09-dev-tools.sh"
# 09-dev-tools.sh calls yay which needs user context, correct
```

Actually reviewing the scripts more carefully:
- **01-post-base.sh** line 25: `sudo pacman` — expects to be run as normal user (will sudo)
- **01-post-base.sh** line 42: `makepkg -si` — expects unprivileged user context

So **01-post-base.sh must run as the target user**, not root!

**CRITICAL FIX needed for arch-legion-firstboot.sh line 53**:
```bash
# WRONG:
bash "$SCRIPTS_DIR/01-post-base.sh"

# CORRECT:
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/01-post-base.sh"
```

---

#### 4. **01-post-base.sh line 42: makepkg -si will fail when run by root**

The script runs `makepkg -si` to build yay from AUR. According to Arch Linux policy, **makepkg explicitly refuses to run as root**:

```bash
if [[ $EUID -eq 0 ]]; then
  error "Do not run makepkg as root..."
fi
```

Current flow:
1. firstboot script runs "01-post-base.sh" (currently as root - ISSUE #3)
2. Script tries `makepkg -si` as root
3. **makepkg exits with error**
4. Installation fails

**Fix**: This is automatically fixed if you implement the fix for Issue #3 above (run phase 01 as target user).

---

#### 5. **profiledef.sh lines 24-26: File permissions directive missing creds.json and archinstall-config.json**

The profiledef.sh has:
```bash
file_permissions=(
  ["/root"]="0:0:750"
  ["/root/run-install.sh"]="0:0:755"
  ["/root/arch-legion-firstboot.sh"]="0:0:755"
)
```

But missing:
- `/root/creds.json` (needs to be readable by install script)
- `/root/archinstall-config.json` (needs to be readable by install script)

While these likely get correct permissions via rsync, explicitly declaring them in `file_permissions` ensures reproducibility.

**Fix**: Add to profiledef.sh:
```bash
file_permissions=(
  ["/root"]="0:0:750"
  ["/root/run-install.sh"]="0:0:755"
  ["/root/arch-legion-firstboot.sh"]="0:0:755"
  ["/root/creds.json"]="0:0:600"
  ["/root/archinstall-config.json"]="0:0:644"
)
```

---

#### 6. **run-install.sh lines 57-62: No validation of creds.json format**

The script checks if files exist but doesn't validate JSON structure:
```bash
if [[ ! -f "$CONFIG" ]]; then
    die "archinstall config not found at $CONFIG"
fi
if [[ ! -f "$CREDS" ]]; then
    die "archinstall creds not found at $CREDS"
fi
```

If `creds.json` has invalid JSON or missing required fields, archinstall will fail mid-installation with cryptic errors.

**Fix**: Add validation:
```bash
if [[ ! -f "$CONFIG" ]]; then
    die "archinstall config not found at $CONFIG"
fi
if [[ ! -f "$CREDS" ]]; then
    die "archinstall creds not found at $CREDS"
fi

# Validate JSON and required fields
if ! jq -e '.["!users"][0].username' "$CREDS" &>/dev/null; then
    die "Invalid creds.json: missing .!users[0].username"
fi
if ! jq -e '.["!root-password"]' "$CREDS" &>/dev/null; then
    die "Invalid creds.json: missing .!root-password"
fi
```

---

#### 7. **arch-legion-firstboot.sh lines 96-97: Missing systemd daemon-reload**

After disabling the service, the script should reload systemd:
```bash
log "First-boot complete. Disabling first-boot service."
systemctl disable arch-legion-firstboot.service
rm -f /usr/local/bin/arch-legion-firstboot.sh
```

**Fix**: Add daemon-reload:
```bash
log "First-boot complete. Disabling first-boot service."
systemctl disable arch-legion-firstboot.service
systemctl daemon-reload
rm -f /usr/local/bin/arch-legion-firstboot.sh
```

---

### Suggestions (should fix)

#### 1. **run-install.sh lines 54-55: Unused archinstall-config.json copy**

The script copies archinstall-config.json:
```bash
cp "$PROJECT_ROOT/arch-legion/archinstall-config.json" "$PROFILE_DIR/airootfs/root/archinstall-config.json"
```

But this is already copied by the rsync on line 52. This line is redundant.

**Note**: Line 55 also references a location that build-iso.sh doesn't prepare. Check if this is needed:
- Line 10: CONFIG="/root/archinstall-config.json"
- build-iso.sh line 55: copies to `$PROFILE_DIR/airootfs/root/archinstall-config.json`

This should work, but having it in both places (rsync + explicit cp) is confusing.

**Fix**: Remove line 55 from build-iso.sh (rsync already copies it), or update run-install.sh to reference the rsync-copied version.

---

#### 2. **run-install.sh line 14: Logging via tee can lose output on failure**

```bash
exec > >(tee -a "$LOG") 2>&1
```

If the script exits early (via `die`), output buffering in the pipe may not flush. This can hide critical errors from the log file.

**Fix**: Ensure explicit log flushing on errors:
```bash
die() {
    echo "FATAL: $1" >&2
    sync  # ensure filesystem writes complete
    echo "Install log saved to $LOG"
    echo "Dropping to shell for debugging..."
    exec /bin/bash
}
```

Or use a simpler approach:
```bash
log_file="/root/arch-legion-install.log"
exec 1> >(tee -a "$log_file")
exec 2> >(tee -a "$log_file" >&2)
```

---

#### 3. **arch-legion-firstboot.sh line 99: Hardcoded directory path**

```bash
log "First-boot complete. Disabling first-boot service."
systemctl disable arch-legion-firstboot.service
rm -f /usr/local/bin/arch-legion-firstboot.sh
```

The path `/usr/local/bin/arch-legion-firstboot.sh` is hardcoded but also set in run-install.sh line 109. This is brittle.

**Fix**: Use environment variable or consistent path variable:
```bash
FIRSTBOOT_SCRIPT="/usr/local/bin/arch-legion-firstboot.sh"
rm -f "$FIRSTBOOT_SCRIPT"
```

---

#### 4. **build-iso.sh line 42: arch-legion directory copy doesn't include hidden files**

```bash
rsync -av --delete \
    --exclude='iso/' \
    --exclude='.git/' \
    --exclude='vm/' \
    --exclude='*.iso' \
    "$PROJECT_ROOT/arch-legion/" "$AIROOTFS/"
```

This excludes `.git` but the arch-legion directory may have other dot-files like `.env` or `.gitignore` that should be included or explicitly excluded.

**Fix**: Be explicit about what to exclude:
```bash
rsync -av --delete \
    --exclude='iso/' \
    --exclude='vm/' \
    --exclude='*.iso' \
    --exclude='.git/' \
    --exclude='.github/' \
    "$PROJECT_ROOT/arch-legion/" "$AIROOTFS/"
```

---

#### 5. **creds.json: Weak default passwords in versioned file**

The file contains:
```json
{
    "!users": [{"username": "travis", "!password": "arch", ...}],
    "!root-password": "arch"
}
```

Both passwords are weak ("arch") and the file is committed to version control. While this is for a test/development ISO, it should have a warning comment.

**Fix**: Add a comment to creds.json:
```json
{
    "_comment": "SECURITY: These are default credentials for development/testing. Change before production deployment.",
    "!users": [ ... ]
}
```

And update `.gitignore` to optionally exclude modified versions.

---

#### 6. **pacman.conf: Missing testing/multilib repos**

The pacman.conf only includes `[core]` and `[extra]`:
```bash
[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist
```

But many packages (e.g., lib32-* for 32-bit libraries needed by some wine/games) are in `[multilib]`. For a Lenovo Legion gaming machine, this is likely needed.

**Fix**: Add multilib repo:
```bash
[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist
```

---

#### 7. **run-install.sh line 156: umount -R may fail silently, preventing reboot**

```bash
sleep 10
umount -R "$MOUNT" 2>/dev/null || true
reboot
```

If there are processes holding the mount (background jobs, services), `umount -R` will fail silently but the reboot will still happen. This can corrupt the filesystem.

**Fix**: Use fuser to identify and kill blocking processes:
```bash
echo "Unmounting..."
fuser -km "$MOUNT" 2>/dev/null || true  # kill processes using mount
sleep 2
umount -R "$MOUNT" || die "Failed to unmount $MOUNT. Fix manually before rebooting."
reboot
```

---

#### 8. **arch-legion-firstboot.sh: Phases should have explicit error handling, not just warnings**

The script uses `|| echo "WARNING: Phase X had errors..."` but continues:
```bash
bash "$SCRIPTS_DIR/01-post-base.sh" || echo "WARNING: Phase 01 had errors, continuing..."
```

For critical phases like 01 (base packages) or 02 (display server), failures should typically halt the boot sequence, not silently continue.

**Suggestion**: Be more selective about which phase failures are non-fatal:
```bash
log "Phase 01: Post-Base Setup"
if ! sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/01-post-base.sh"; then
    echo "ERROR: Phase 01 failed. Cannot continue without base packages."
    exit 1
fi

log "Phase 02: HyDE (Hyprland)"
if ! sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/02-hyde.sh"; then
    echo "ERROR: Phase 02 failed. GUI installation is essential."
    exit 1
fi

log "Phase 03: Nvidia Tweaks"
sudo -u "$TARGET_USER" bash "$SCRIPTS_DIR/03-nvidia-tweaks.sh" || \
    echo "WARNING: Phase 03 had errors (non-critical, continuing...)"
```

---

### Nits (optional)

#### 1. **build-iso.sh line 8: Redundant PROFILE_DIR assignment**

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$SCRIPT_DIR"
```

Since build-iso.sh is in the profile root, PROFILE_DIR is just SCRIPT_DIR. Could be:
```bash
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

---

#### 2. **run-install.sh line 8: Missing SCRIPT_DIR usage**

The script doesn't define SCRIPT_DIR but it's referenced implicitly. For consistency with other scripts, add:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

Though it's not strictly necessary here since paths are absolute.

---

#### 3. **arch-legion-firstboot.sh line 95: Exit code should reflect success/failure**

```bash
log "First-boot complete. Disabling first-boot service."
systemctl disable arch-legion-firstboot.service
rm -f /usr/local/bin/arch-legion-firstboot.sh
```

The script ends without explicit exit code. If any phase failed, the overall exit should be non-zero:
```bash
EXIT_CODE=0
# ... track failures ...
exit $EXIT_CODE
```

---

#### 4. **arch-legion-firstboot.sh line 113-114: Auto-reboot may surprise users**

```bash
echo "Rebooting in 30 seconds to apply changes... (Ctrl+C to cancel)"
sleep 30
reboot
```

Some users may want to stay in the freshly-installed system to verify things. Consider making this interactive:
```bash
read -p "Press ENTER to reboot now, or Ctrl+C to cancel... " -t 30 || true
reboot
```

---

#### 5. **Inconsistent log prefix format**

- `run-install.sh` uses: `[$(date '+%H:%M:%S')] Message`
- `arch-legion-firstboot.sh` uses: `[$(date '+%H:%M:%S')] FIRST-BOOT: Message`

Should standardize. The FIRST-BOOT prefix is helpful for distinguishing ISO-time vs. first-boot-time logs, so suggest keeping it. Apply the same to run-install.sh phases 01-11 that get re-executed... wait, they're executed by first-boot script, so they'll already have the [01], [02] prefix from their own logging.

**Nit**: Just note the inconsistency; it's minor.

---

## Approval

**REQUEST_CHANGES**

The implementation is architecturally sound but has **critical bugs** that will cause installation failures:

1. **Phase 01 runs as root** (will fail at makepkg due to policy)
2. **Hardcoded username** breaks customization
3. **Missing JSON validation** in install script
4. **Missing systemd daemon-reload** in first-boot cleanup

These are all quick fixes (5-10 lines each). I recommend creating a branch, applying these fixes, testing with a build, and re-submitting.

---

## Files Requiring Changes

| File | Issues |
|------|--------|
| `arch-legion-firstboot.sh` | #1, #3, #7, #8 |
| `run-install.sh` | #1, #2, #3, #6, #14 |
| `profiledef.sh` | #5 |
| `pacman.conf` | #6 |
| `creds.json` | #5 (add comment) |

---

## Testing Recommendations

1. **Test on actual ISO build** in a VM
2. **Verify archinstall completes** and system boots
3. **Confirm first-boot service runs** and phases execute
4. **Check logs** for yay AUR builds (they must succeed)
5. **Test with custom username** in creds.json to verify dynamic extraction works
6. **Verify multilib packages** install if needed
7. **Test error recovery** by intentionally breaking a phase and confirming appropriate halt or warning

