#!/usr/bin/env bash
set -euo pipefail
# Bootstrap a fresh Arch Linux install into a builder-linux* GitHub Actions
# runner box matching the existing one. Run as the regular (wheel) user, not
# root. Every step is idempotent, so re-running after fixing something is safe.
#
# Environment overrides:
#   RUNNER_NAME    runner name to register (default: hostname)
#   RUNNER_LABELS  extra comma-separated labels (default: none beyond GitHub's)
#   RUNNER_REPO    owner/repo the runner is registered to (default: Chan-Ko-LLC/ck)
#   RUNNER_TOKEN   registration token; fetched via `gh` if unset and gh is logged in

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH_DIR="$DOTFILES/arch"
RUNNER_REPO="${RUNNER_REPO:-Chan-Ko-LLC/ck}"
RUNNER_NAME="${RUNNER_NAME:-$(hostnamectl --static)}"
RUNNER_LABELS="${RUNNER_LABELS:-}"
RUNNER_DIR="$HOME/actions-runner"

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your regular user, not root (it uses sudo where needed)." >&2
    exit 1
fi
if [ ! -f /etc/arch-release ]; then
    echo "This script is for Arch Linux only." >&2
    exit 1
fi

# Ask for the sudo password once and keep the session alive for the whole
# run, so a long AUR build does not end with an expired sudo prompt.
log "Checking sudo access"
sudo -v
( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

log "Checking that the package mirrors respond"
if ! timeout 90 sudo pacman -Sy >/dev/null 2>&1; then
    warn "pacman could not sync in 90s; the mirrorlist copied from the ISO is probably stale. Falling back to two known-good mirrors."
    sudo tee /etc/pacman.d/mirrorlist >/dev/null <<'MIRRORS'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirrors.xtom.com/archlinux/$repo/os/$arch
MIRRORS
    sudo pacman -Syy
fi

log "Installing packages from the official repos"
# shellcheck disable=SC2024  # stdin is the package list, not a privileged file
sudo pacman -Syu --needed --noconfirm - < "$ARCH_DIR/pkglist-native.txt"

if ! command -v paru >/dev/null 2>&1; then
    log "Bootstrapping paru (AUR helper)"
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -s --noconfirm)
    sudo pacman -U --noconfirm "$tmp"/paru/paru-[0-9]*.pkg.tar.zst
    rm -rf "$tmp"
fi

log "Installing AUR packages"
paru -S --needed --noconfirm - < "$ARCH_DIR/pkglist-aur.txt"

log "Installing zram swap config"
sudo install -Dm644 "$ARCH_DIR/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo systemctl daemon-reload
sudo systemctl start /dev/zram0
if ! swapon --show=NAME --noheadings | grep -q '^/dev/zram0$'; then
    warn "zram0 is not active as swap; check 'systemctl status systemd-zram-setup@zram0.service'."
fi

log "Configuring the Nix daemon"
features="$(grep -E '^experimental-features' /etc/nix/nix.conf 2>/dev/null || true)"
if [ -z "$features" ]; then
    echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf >/dev/null
elif ! { grep -qw nix-command <<<"$features" && grep -qw flakes <<<"$features"; }; then
    sudo sed -i -E 's/^(experimental-features *=.*)$/\1 nix-command flakes/' /etc/nix/nix.conf
fi
# Arch's nix package has no nix-users group; the daemon socket is world-writable,
# so any user can talk to it once nix-daemon is running.

log "Enabling system services"
sudo systemctl enable --now NetworkManager.service sshd.service nix-daemon.service
sudo systemctl enable sddm.service

# Arch's nix package ships no /nix/store; the daemon creates it lazily, and a
# client that races it fails with 'opening file "/nix/store": No such file'.
if [ ! -d /nix/store ]; then
    log "Initialising the Nix store"
    sudo install -d -o root -g nixbld -m 1775 /nix/store
    sudo install -d -m 755 /nix/var/nix/db /nix/var/nix/profiles /nix/var/nix/gcroots /nix/var/nix/temproots
    sudo systemctl restart nix-daemon.service
fi
if ! nix store info >/dev/null 2>&1 && ! nix store ping >/dev/null 2>&1; then
    warn "Cannot talk to the Nix daemon. Check 'systemctl status nix-daemon.service' and re-run this script."
    exit 1
fi

# The runner is only registered once the host is fully configured, so a
# half-built box never starts picking up jobs.
HOST_READY=
if [ -f "$DOTFILES/user-config.nix" ]; then
    log "Applying Home Manager configuration"
    (cd "$DOTFILES" && nix run .#home-manager -- switch --flake ".#$USER@x86_64-linux")
    HOST_READY=1
else
    warn "$DOTFILES/user-config.nix is missing. Copy it (and ~/.config/sops/age/keys.txt) from the existing box, then re-run this script."
fi

log "Installing the GitHub Actions runner"
mkdir -p "$RUNNER_DIR"
if [ ! -x "$RUNNER_DIR/config.sh" ]; then
    # Capture first, then parse: piping curl into grep -m1 makes grep close the
    # pipe early and curl fail with "(23) Failure writing output".
    release_json="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest)"
    version="$(grep -o '"tag_name": *"[^"]*"' <<<"$release_json" | cut -d'"' -f4 | sed 's/^v//')"
    [ -n "$version" ] || { warn "Could not determine the latest runner version from the GitHub API."; exit 1; }
    tarball="actions-runner-linux-x64-${version}.tar.gz"
    curl -fsSL -o "$RUNNER_DIR/$tarball" "https://github.com/actions/runner/releases/download/v${version}/${tarball}"
    tar -xzf "$RUNNER_DIR/$tarball" -C "$RUNNER_DIR"
fi

if [ -f "$RUNNER_DIR/.runner" ]; then
    log "Runner already registered as $(grep -o '"agentName": *"[^"]*"' "$RUNNER_DIR/.runner" | cut -d'"' -f4); skipping registration"
elif [ -z "$HOST_READY" ]; then
    warn "Host configuration is not complete yet; skipping runner registration until the next run."
else
    token="${RUNNER_TOKEN:-}"
    if [ -z "$token" ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        token="$(gh api -X POST "repos/$RUNNER_REPO/actions/runners/registration-token" --jq .token)"
    fi
    if [ -n "$token" ]; then
        log "Registering runner $RUNNER_NAME with $RUNNER_REPO"
        (cd "$RUNNER_DIR" && ./config.sh --unattended \
            --url "https://github.com/$RUNNER_REPO" \
            --token "$token" \
            --name "$RUNNER_NAME" \
            ${RUNNER_LABELS:+--labels "$RUNNER_LABELS"})
    else
        warn "No registration token. Get one from https://github.com/$RUNNER_REPO/settings/actions/runners/new, then run:"
        cat <<MSG
  cd $RUNNER_DIR
  ./config.sh --url https://github.com/$RUNNER_REPO --token <TOKEN> --name $RUNNER_NAME${RUNNER_LABELS:+ --labels $RUNNER_LABELS}
  sudo ./svc.sh install $USER && sudo ./svc.sh start
MSG
    fi
fi

# Ensure the service exists and is running whenever the runner is registered,
# including when registration was done by hand or a previous run stopped early.
if [ -f "$RUNNER_DIR/.runner" ]; then
    log "Ensuring the runner service is installed and running"
    if [ ! -f "$RUNNER_DIR/.service" ]; then
        (cd "$RUNNER_DIR" && sudo ./svc.sh install "$USER")
    fi
    if ! systemctl is-active --quiet "$(cat "$RUNNER_DIR/.service")"; then
        (cd "$RUNNER_DIR" && sudo ./svc.sh start)
    fi
fi

log "Done"
