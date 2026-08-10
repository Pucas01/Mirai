#!/bin/bash
set -euo pipefail

THEME="$1"
SIZE="$2"
CONF="$HOME/.config/hypr/hyprland.lua"

[ -f "$CONF" ] || exit 1

set_env_line() {
    local key="$1" value="$2"
    if grep -q "^hl\.env(\"$key\"" "$CONF"; then
        sed -i "s|^hl\.env(\"$key\",.*)\$|hl.env(\"$key\", \"$value\")|" "$CONF"
    else
        sed -i "/^hl\.env(\"XCURSOR_SIZE\"/i hl.env(\"$key\", \"$value\")" "$CONF"
    fi
}

set_env_line "XCURSOR_SIZE" "$SIZE"
set_env_line "HYPRCURSOR_SIZE" "$SIZE"
set_env_line "XCURSOR_THEME" "$THEME"
set_env_line "HYPRCURSOR_THEME" "$THEME"
