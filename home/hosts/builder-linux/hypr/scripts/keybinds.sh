#!/usr/bin/env bash
# Show a searchable cheatsheet of all keybinds, parsed live from hyprland.conf.
# The trailing "# comment" on each bind line is used as its description.

CONFIG="$HOME/.config/hypr/hyprland.conf"

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

grep -E '^[[:space:]]*bind[[:alpha:]]*[[:space:]]*=' "$CONFIG" | while IFS= read -r line; do
    body="${line#*=}"

    desc=""
    case "$body" in
        *'#'*)
            desc="$(trim "${body#*#}")"
            body="${body%%#*}"
            ;;
    esac

    IFS=',' read -r mods key action <<< "$body"
    mods="$(trim "$mods")"
    key="$(trim "$key")"
    action="$(trim "$action")"

    mods="${mods//\$mainMod/SUPER}"
    combo="$key"
    [ -n "$mods" ] && combo="${mods// / + } + $key"

    [ -z "$desc" ] && desc="$(trim "${action%,}")"

    printf '%-22s  %s\n' "$combo" "$desc"
done | wofi --dmenu --insensitive --prompt "Keybinds" --width 720 --height 560 \
    --style "$HOME/.config/hypr/scripts/keybinds.css" > /dev/null
