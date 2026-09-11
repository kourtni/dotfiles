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
2. Log in as that user and run (`git` is not part of a minimal Arch install,
   so install it first):

   ```bash
   sudo pacman -Syu --needed git
   git clone https://github.com/kourtni/dotfiles.git ~/dotfiles
   ~/dotfiles/scripts/bootstrap-arch-runner.sh
   ```

3. Copy `user-config.nix` and `~/.config/sops/age/keys.txt` over from the
   existing box (neither is in git), then re-run the script. It picks up where
   it left off: every step is idempotent.
4. Register the runner. The script does this automatically when `gh` is
   authenticated or `RUNNER_TOKEN` is exported; otherwise it prints the exact
   `config.sh` command to run.

## Networking

The wired connection is plain DHCP with no static address, DNS, or firewall
rules, so a new box needs nothing beyond NetworkManager being enabled (the
script does that). Two things are not carried over:

- **Wi-Fi profiles.** Saved networks and their passwords live in root-only
  files that are deliberately kept out of git. To copy them from the existing
  box (run on the *new* box, as your user):

  ```bash
  sudo scp -p 'root@builder-linux1:/etc/NetworkManager/system-connections/*.nmconnection' \
      /etc/NetworkManager/system-connections/
  sudo chmod 600 /etc/NetworkManager/system-connections/*.nmconnection
  sudo nmcli connection reload
  ```

  If root SSH is not enabled on the existing box, `sudo cat` the files there
  and paste them into place instead, or simply join the Wi-Fi once from the
  new box with `nmcli device wifi connect <SSID> --ask`.

- **Router-side settings.** If the existing box has a DHCP reservation or a
  DNS name on the `ck-runners.lan` network, add a matching entry for the new
  box on the router. Nothing on the host controls this.

## Refreshing the package lists

Run this on the reference box after installing or removing packages:

```bash
pacman -Qqen > ~/dotfiles/arch/pkglist-native.txt
pacman -Qqem | grep -v -- '-debug$' > ~/dotfiles/arch/pkglist-aur.txt
```
