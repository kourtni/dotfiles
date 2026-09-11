# Arch Linux host layer

Home Manager covers the user environment, but the OS underneath the
`builder-linux*` GitHub Actions runners is plain Arch Linux. This directory
captures the parts of that layer that are not derivable from the flake, so a
second (or third) identical box can be stood up from a fresh Arch install.

| File | Purpose |
|---|---|
| `pkglist-native.txt` | Explicitly installed packages from the official repos (`pacman -Qqen`) |
| `pkglist-aur.txt` | Explicitly installed AUR packages (`pacman -Qqem`, debug packages dropped) |
| `zram-generator.conf` | Copied to `/etc/systemd/zram-generator.conf` for zram swap |

## Standing up a new runner box

1. Install Arch with `archinstall` (or by hand): same partition layout as the
   existing box (EFI, ext4 `/boot`, LVM with `lv_root` and `lv_home`), create
   the `kourtni` user in the `wheel` group, and get networking up.
2. Log in as that user and run:

   ```bash
   git clone https://github.com/kourtni/dotfiles.git ~/dotfiles
   ~/dotfiles/scripts/bootstrap-arch-runner.sh
   ```

3. Copy `user-config.nix` and `~/.config/sops/age/keys.txt` over from the
   existing box (neither is in git), then re-run the script. It picks up where
   it left off: every step is idempotent.
4. Register the runner. The script does this automatically when `gh` is
   authenticated or `RUNNER_TOKEN` is exported; otherwise it prints the exact
   `config.sh` command to run.

## Refreshing the package lists

Run this on the reference box after installing or removing packages:

```bash
pacman -Qqen > ~/dotfiles/arch/pkglist-native.txt
pacman -Qqem | grep -v -- '-debug$' > ~/dotfiles/arch/pkglist-aur.txt
```
