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
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
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

log "Installing packages from the official repos"
# shellcheck disable=SC2024  # stdin is the package list, not a privileged file
sudo pacman -Syu --needed --noconfirm - < "$ARCH_DIR/pkglist-native.txt"

if ! command -v paru >/dev/null 2>&1; then
    log "Bootstrapping paru (AUR helper)"
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

log "Installing AUR packages"
paru -S --needed --noconfirm - < "$ARCH_DIR/pkglist-aur.txt"

log "Installing zram swap config"
sudo install -Dm644 "$ARCH_DIR/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo systemctl daemon-reload
sudo systemctl start /dev/zram0 2>/dev/null || true

log "Configuring the Nix daemon"
if ! grep -q '^experimental-features.*flakes' /etc/nix/nix.conf 2>/dev/null; then
    echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf >/dev/null
fi
if ! id -nG "$USER" | grep -qw nix-users; then
    sudo usermod -aG nix-users "$USER"
    warn "Added $USER to nix-users; log out and back in before running Home Manager."
    NEED_RELOGIN=1
fi

log "Enabling system services"
sudo systemctl enable --now NetworkManager.service sshd.service nix-daemon.service
sudo systemctl enable sddm.service

if [ -z "${NEED_RELOGIN:-}" ]; then
    if [ -f "$DOTFILES/user-config.nix" ]; then
        log "Applying Home Manager configuration"
        (cd "$DOTFILES" && nix run .#home-manager -- switch --flake ".#$USER@x86_64-linux")
    else
        warn "$DOTFILES/user-config.nix is missing. Copy it (and ~/.config/sops/age/keys.txt) from the existing box, then re-run this script."
    fi
fi

log "Installing the GitHub Actions runner"
mkdir -p "$RUNNER_DIR"
if [ ! -x "$RUNNER_DIR/config.sh" ]; then
    version="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')"
    tarball="actions-runner-linux-x64-${version}.tar.gz"
    curl -fsSL -o "$RUNNER_DIR/$tarball" "https://github.com/actions/runner/releases/download/v${version}/${tarball}"
    tar -xzf "$RUNNER_DIR/$tarball" -C "$RUNNER_DIR"
fi

if [ -f "$RUNNER_DIR/.runner" ]; then
    log "Runner already registered as $(grep -o '"agentName": *"[^"]*"' "$RUNNER_DIR/.runner" | cut -d'"' -f4); skipping registration"
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
        (cd "$RUNNER_DIR" && sudo ./svc.sh install "$USER" && sudo ./svc.sh start)
    else
        warn "No registration token. Get one from https://github.com/$RUNNER_REPO/settings/actions/runners/new, then run:"
        cat <<MSG
  cd $RUNNER_DIR
  ./config.sh --url https://github.com/$RUNNER_REPO --token <TOKEN> --name $RUNNER_NAME${RUNNER_LABELS:+ --labels $RUNNER_LABELS}
  sudo ./svc.sh install $USER && sudo ./svc.sh start
MSG
    fi
fi

log "Done"
[ -n "${NEED_RELOGIN:-}" ] && echo "Log out, log back in, and re-run this script to finish Home Manager setup."
exit 0
