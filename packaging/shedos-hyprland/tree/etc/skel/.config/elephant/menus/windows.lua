Name = "windows"
NamePretty = "Windows"
Icon = "preferences-system-windows"
Action = "hyprctl dispatch 'hl.dsp.focus({ window = \"address:%VALUE%\" })'"
HideFromProviderlist = false
Description = "switch to an open window"

function GetEntries()
    local entries = {}
    local handle = io.popen("hyprctl clients -j 2>/dev/null")
    if not handle then return entries end
    local raw = handle:read("*a")
    handle:close()
    local ok, clients = pcall(jsonDecode, raw)
    if not ok or type(clients) ~= "table" then return entries end
    for _, c in ipairs(clients) do
        if c.mapped and c.title and c.title ~= "" then
            local ws = (c.workspace and c.workspace.id) or "?"
            table.insert(entries, {
                Text = c.title,
                Subtext = "workspace " .. tostring(ws) .. " — " .. (c.class or ""),
                Value = c.address,
            })
        end
    end
    return entries
end
