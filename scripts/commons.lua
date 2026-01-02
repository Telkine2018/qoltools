

local commons = {}

commons.modname = "qoltools"
commons.prefix = "qoltools"
local prefix = commons.prefix

commons.debug_mode = false
commons.modpath = "__" .. prefix .. "__"
commons.graphic_path = commons.modpath .. '/graphics/%s.png'

---@param name string
---@return string
function commons.png(name) 
    return string.format(commons.graphic_path,name)
end

return commons