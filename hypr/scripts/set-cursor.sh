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

mkdir -p "$HOME/.icons/default"
cat > "$HOME/.icons/default/index.theme" <<EOF
[Icon Theme]
Name=Default
Comment=Mirai active cursor theme
Inherits=$THEME
EOF

for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    [ -f "$f" ] || continue
    if grep -q "^gtk-cursor-theme-name=" "$f"; then
        sed -i "s|^gtk-cursor-theme-name=.*|gtk-cursor-theme-name=$THEME|" "$f"
    else
        sed -i "/^\[Settings\]/a gtk-cursor-theme-name=$THEME" "$f"
    fi
    if grep -q "^gtk-cursor-theme-size=" "$f"; then
        sed -i "s|^gtk-cursor-theme-size=.*|gtk-cursor-theme-size=$SIZE|" "$f"
    else
        sed -i "/^\[Settings\]/a gtk-cursor-theme-size=$SIZE" "$f"
    fi
done

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface cursor-theme "$THEME" || true
    gsettings set org.gnome.desktop.interface cursor-size "$SIZE" || true
fi
