#!/bin/bash
set -euo pipefail

FILENAME="$1"
FILE="$HOME/.config/autostart/$FILENAME"

[ -f "$FILE" ] || exit 1

escaped=$(systemd-escape "$(basename "$FILE" .desktop)")
systemctl --user stop "app-$escaped@autostart.service" 2>/dev/null || true

rm -f "$FILE"

systemctl --user daemon-reload 2>/dev/null || true
