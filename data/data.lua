local commons = require "scripts.commons"

local modname = commons.prefix
local png = commons.png


local declarations = {}

local control = {
    type = "custom-input",
    name = modname .. "-feed",
    key_sequence = "ALT + G",
    consuming = "none"
}
table.insert(declarations, control)

control = {
    type = "custom-input",
    name = modname .. "-sort",
    key_sequence = "SHIFT + G",
    consuming = "none"
}
table.insert(declarations, control)


data:extend(declarations)

data:extend
{
  {
    type = "shortcut",
    name = modname .. "-autocraft",
    order = "a[autocraft]]",
    action = "lua",
    icon = png("icons/autocraft-x32"),
    icon_size = 32,
    small_icon = png("icons/autocraft-x24"),
    small_icon_size = 24,
    toggleable = true
  },
}
