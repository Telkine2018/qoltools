local commons = require "scripts.commons"

if mods["PollutionSolutionsLite"] and mods["exotic-industries"] then

    local recipe = data.raw["recipe"]["iron-gear-wheel"]
    if recipe then
        recipe.visible = true
        recipe.normal.enabled = true
        recipe.expensive.enabled = true
        data:extend{recipe}
    end
end

data:extend
{
    {
        type = "custom-input",
        key_sequence = "SHIFT + mouse-button-1",
        consuming = "none",
        name = commons.prefix .. "-shift-click"
    }
}

if mods["EverythingOnNauvis"] then
    local recipe = data.raw["recipe"]["lightning-rod"]
    if recipe then
        recipe.enabled = true
        recipe.hidden = false
        data:extend {recipe}
        log("Install lightning-rod")
    end

    local item = data.raw["item"]["lightning-rod"]
    if item then
        item.send_to_orbit_mode = "automated"
        item.default_import_location = "nauvis"
        item.hidden = false
    end
end
