local modname = "qoltools"

data:extend({
    {
        type = "bool-setting",
        name = modname .. "-input-ingredient",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "aa"
    }, 
    {
        type = "int-setting",
        name = modname .. "-consumption-target",
        setting_type = "runtime-per-user",
        default_value = 4,
        order = "ab"
    }, {
        type = "bool-setting",
        name = modname .. "-clean-auto-sort",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "ae"
    } , {
        type = "bool-setting",
        name = modname .. "-feed-auto-sort",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "af"
    }
})
