#!/bin/bash
set -euo pipefail

DIR="$HOME/.config/autostart"
mkdir -p "$DIR"

first=true
printf '['
for f in "$DIR"/*.desktop; do
    [ -e "$f" ] || continue

    name=$(grep -m1 '^Name=' "$f" | cut -d= -f2- || true)
    exec_line=$(grep -m1 '^Exec=' "$f" | cut -d= -f2- || true)
    hidden=$(grep -m1 '^Hidden=' "$f" | cut -d= -f2- || true)
    gnome_enabled=$(grep -m1 '^X-GNOME-Autostart-enabled=' "$f" | cut -d= -f2- || true)
    managed=$(grep -m1 '^X-Mirai-Managed=' "$f" | cut -d= -f2- || true)

    enabled=true
    [ "$hidden" = "true" ] && enabled=false
    [ "$gnome_enabled" = "false" ] && enabled=false

    [ "$first" = true ] && first=false || printf ','

    esc() { printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

    printf '{"filename":%s,"name":%s,"exec":%s,"enabled":%s,"managed":%s}' \
        "$(esc "$(basename "$f")")" \
        "$(esc "${name:-$(basename "$f" .desktop)}")" \
        "$(esc "$exec_line")" \
        "$enabled" \
        "$([ "$managed" = "true" ] && echo true || echo false)"
done
printf ']'
