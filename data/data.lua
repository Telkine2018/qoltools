local commons = require "scripts.commons"

local modname = commons.prefix

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
    key_sequence = "SHIFT+G",
    consuming = "none"
}
table.insert(declarations, control)


data:extend(declarations)
