#!/bin/bash
set -euo pipefail

OUT_DIR="$HOME/.cache/mirai-cursor-previews"
mkdir -p "$OUT_DIR"

for base in /usr/share/icons "$HOME/.local/share/icons" "$HOME/.icons"; do
    [ -d "$base" ] || continue
    for dir in "$base"/*/; do
        name=$(basename "$dir")
        cursor_file="${dir}cursors/left_ptr"
        [ -f "$cursor_file" ] || continue

        out="$OUT_DIR/$name.png"
        [ -f "$out" ] && continue

        tmp=$(mktemp -d)
        xcur2png -q -d "$tmp" "$cursor_file" >/dev/null 2>&1 || { rm -rf "$tmp"; continue; }

        best=""
        best_diff=999999
        for png in "$tmp"/*.png; do
            [ -f "$png" ] || continue
            w=$(identify -format "%w" "$png" 2>/dev/null || echo 0)
            diff=$(( w > 32 ? w - 32 : 32 - w ))
            if [ "$diff" -lt "$best_diff" ]; then
                best_diff=$diff
                best="$png"
            fi
        done

        [ -n "$best" ] && cp "$best" "$out"
        rm -rf "$tmp"
    done
done
