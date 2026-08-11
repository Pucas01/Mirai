#!/bin/bash
set -euo pipefail

FILENAME="$1"
ENABLE="$2"
FILE="$HOME/.config/autostart/$FILENAME"

[ -f "$FILE" ] || exit 1

if grep -q '^X-GNOME-Autostart-enabled=' "$FILE"; then
    sed -i "s/^X-GNOME-Autostart-enabled=.*/X-GNOME-Autostart-enabled=$ENABLE/" "$FILE"
else
    printf 'X-GNOME-Autostart-enabled=%s\n' "$ENABLE" >> "$FILE"
fi

if grep -q '^Hidden=' "$FILE"; then
    sed -i "s/^Hidden=.*/Hidden=$([ "$ENABLE" = "true" ] && echo false || echo true)/" "$FILE"
fi

systemctl --user daemon-reload 2>/dev/null || true

escaped=$(systemd-escape "$(basename "$FILE" .desktop)")
unit="app-$escaped@autostart.service"
if [ "$ENABLE" = "true" ]; then
    systemctl --user start "$unit" 2>/dev/null || true
else
    systemctl --user stop "$unit" 2>/dev/null || true
fi
