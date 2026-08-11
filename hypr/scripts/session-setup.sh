#!/bin/bash
set -uo pipefail

dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

systemctl --user reset-failed hyprpolkitagent.service 2>/dev/null
systemctl --user start hyprpolkitagent.service

bash "$(dirname "${BASH_SOURCE[0]}")/start-autostart-apps.sh"
