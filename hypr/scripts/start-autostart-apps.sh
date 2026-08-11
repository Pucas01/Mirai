#!/bin/bash
set -uo pipefail

systemctl --user daemon-reload 2>/dev/null

units=$(systemctl --user list-unit-files "app-*@autostart.service" --no-legend 2>/dev/null | awk '{print $1}')
for unit in $units; do
    systemctl --user start "$unit" 2>/dev/null
done
