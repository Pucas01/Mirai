hl.on("hyprland.start", function ()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("nohup quickshell >/dev/null 2>&1 &")
    hl.exec_cmd("bash ~/.config/hypr/scripts/quickshell-watchdog.sh")
    
    hl.exec_cmd("bash ~/.config/hypr/scripts/session-setup.sh")
end)

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
