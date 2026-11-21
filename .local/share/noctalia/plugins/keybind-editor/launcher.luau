--!nonstrict
-- On-demand Noctalia launcher bridge; no subprocess runs while typing.

local SCRIPT = noctalia.expandPath("~/.local/bin/niri-keybind-editor")
local CONFIG = noctalia.expandPath("~/.config/niri/config.kdl")

function onQuery(query)
  local text = noctalia.string.trim(query)
  launcher.setResults(query, {{
    id = "open:" .. text,
    title = "Open Keybinds editor",
    subtitle = text ~= "" and ("Search: " .. text) or "Browse and edit all Niri shortcuts",
    glyph = "keyboard",
  }})
end

function onActivate(id)
  local search = id:sub(1, 5) == "open:" and id:sub(6) or ""
  local command = {SCRIPT, "--launch-editor", "--config", CONFIG, "--category", "All"}
  if search ~= "" then
    table.insert(command, "--search")
    table.insert(command, search)
  end
  noctalia.runAsync(command)
end
