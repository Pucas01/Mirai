package.path = package.path .. ";./?.lua;./?/init.lua"
local smw = require("plugins.split-monitor-workspaces")

smw.setup({
    workspace_count = 10,
})

local mainMod = "SUPER"
for i = 1, smw.get_amount_of_workspaces() do
    local n = tostring(i)
    if n == "10" then n = "0" end

    hl.bind(mainMod .. " +" .. n, smw.workspace(n), { description = "Go to workspace " .. n })

    hl.bind(mainMod .. " + SHIFT +" .. n, smw.move_to_workspace_silent(n), { description = "Move window to workspace " .. n })
end

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
