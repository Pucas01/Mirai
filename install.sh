#!/bin/bash
# Mirai dotfiles installer.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

LINKS=(
    "hypr:hypr"
    "quickshell:quickshell"
    "kitty:kitty"
    "fish:fish"
    "fastfetch:fastfetch"
    "gtk-3.0:gtk-3.0"
    "gtk-4.0:gtk-4.0"
)

link_one() {
    local src="$REPO_DIR/$1"
    local dest="$CONFIG_HOME/$2"

    if [ ! -e "$src" ]; then
        echo "skip: $1 (not in repo)"
        return
    fi

    if [ -L "$dest" ]; then
        if [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
            echo "ok:   $2 (already linked)"
            return
        fi
        echo "warn: $2 is a symlink to somewhere else, leaving it alone"
        return
    fi

    if [ -e "$dest" ]; then
        if [ -d "$dest" ] && [ -z "$(ls -A "$dest" 2>/dev/null)" ]; then
            rmdir "$dest"
        else
            echo "warn: $dest already exists and isn't empty, leaving it alone"
            return
        fi
    fi

    mkdir -p "$CONFIG_HOME"
    ln -s "$src" "$dest"
    echo "link: $2 -> $src"
}

echo "== linking configs into $CONFIG_HOME =="
for pair in "${LINKS[@]}"; do
    link_one "${pair%%:*}" "${pair##*:}"
done

echo
echo "== creating picture folders =="
for dir in Wallpapers Avatars StartIcon Logos; do
    target="$HOME/Pictures/Mirai/$dir"
    mkdir -p "$target"
    echo "ok:   $target"
done

echo
echo "== split-monitor-workspaces plugin =="
PLUGIN_DIR="$REPO_DIR/hypr/plugins/split-monitor-workspaces"
PLUGIN_URL="https://github.com/zjeffer/split-monitor-workspaces"
if [ -d "$PLUGIN_DIR/.git" ]; then
    echo "ok:   already cloned at $PLUGIN_DIR"
elif [ -e "$PLUGIN_DIR" ]; then
    echo "warn: $PLUGIN_DIR exists but isn't a git repo, leaving it alone"
elif command -v git >/dev/null 2>&1; then
    mkdir -p "$REPO_DIR/hypr/plugins"
    git clone "$PLUGIN_URL" "$PLUGIN_DIR"
    echo "ok:   cloned split-monitor-workspaces"
else
    echo "warn: git not found, clone this manually: $PLUGIN_URL -> $PLUGIN_DIR"
fi

echo
echo "== checking dependencies =="

DEP_PKGS=(
    "git:git"
    "hyprctl:hyprland"
    "quickshell:quickshell"
    "kitty:kitty"
    "fish:fish"
    "fastfetch:fastfetch"
    "starship:starship"
    "cava:cava"
    "hyprpicker:hyprpicker"
    "grim:grim"
    "slurp:slurp"
    "wl-copy:wl-clipboard"
    "cliphist:cliphist"
    "nautilus:nautilus"
    "brightnessctl:brightnessctl"
)

missing_pkgs=()
missing_bins=()
for pair in "${DEP_PKGS[@]}"; do
    bin="${pair%%:*}"
    pkg="${pair##*:}"
    if ! command -v "$bin" >/dev/null 2>&1; then
        missing_bins+=("$bin")
        case " ${missing_pkgs[*]-} " in
            *" $pkg "*) ;;
            *) missing_pkgs+=("$pkg") ;;
        esac
    fi
done

if [ ${#missing_pkgs[@]} -eq 0 ]; then
    echo "ok:   all dependencies found"
else
    echo "warn: missing binaries: ${missing_bins[*]}"
    echo "warn: missing packages: ${missing_pkgs[*]}"

    if ! command -v pacman >/dev/null 2>&1; then
        echo "warn: pacman not found, install these manually: ${missing_pkgs[*]}"
    else
        INSTALLER="sudo pacman -S"
        if ! pacman -Si "${missing_pkgs[0]}" >/dev/null 2>&1; then
            if command -v yay >/dev/null 2>&1; then
                INSTALLER="yay -S"
            elif command -v paru >/dev/null 2>&1; then
                INSTALLER="paru -S"
            fi
        fi

        read -r -p "Install missing packages now with '$INSTALLER'? [y/N] " reply
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            $INSTALLER "${missing_pkgs[@]}"
        else
            echo "skip: install these yourself when ready: ${missing_pkgs[*]}"
        fi
    fi
fi

echo
echo "done. restart Hyprland (or at least Quickshell/kitty) to pick everything up."
