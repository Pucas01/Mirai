#!/bin/bash
set -euo pipefail

NAME="$1"
EXEC="$2"
DIR="$HOME/.config/autostart"
mkdir -p "$DIR"

slug=$(printf '%s' "$NAME" | tr -c 'a-zA-Z0-9_-' '-' | sed 's/-\+/-/g; s/^-\|-$//g')
[ -n "$slug" ] || slug="mirai-autostart"

FILE="$DIR/mirai-$slug.desktop"
n=1
while [ -e "$FILE" ]; do
    FILE="$DIR/mirai-$slug-$n.desktop"
    n=$((n + 1))
done

cat > "$FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$NAME
Exec=$EXEC
Terminal=false
X-Mirai-Managed=true
EOF

systemctl --user daemon-reload 2>/dev/null || true

escaped=$(systemd-escape "$(basename "$FILE" .desktop)")
systemctl --user start "app-$escaped@autostart.service" 2>/dev/null || true

basename "$FILE"
