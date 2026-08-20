local suppressMaximizeRule = hl.window_rule({

    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({

    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name  = "float-qs-settings",
    match = { title = "qs-settings" },
    float = true,
})

hl.window_rule({
    name  = "float-qs-launcher",
    match = { title = "qs-launcher" },
    float = true,
    stay_focused = true,
})

hl.window_rule({
    name  = "float-qs-keybinds",
    match = { title = "qs-keybinds" },
    float = true,
    stay_focused = true,
})

hl.window_rule({
    name  = "float-qs-ethernet",
    match = { title = "qs-ethernet" },
    float = true,
})

hl.window_rule({
    name  = "float-qs-screenshot-editor",
    match = { title = "qs-screenshot-editor" },
    float = true,
    stay_focused = true,
})

hl.window_rule({
    name  = "float-kanade",
    match = { title = "kanade" },
    float = true,
})

hl.window_rule({
    name  = "float-github",
    match = { title = "github" },
    float = true,
})

hl.window_rule({
    name  = "stayfocused-resolve-popups",
    match = { class = ".*[Rr]esolve.*", float = true },

    stay_focused = true,
})
