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
