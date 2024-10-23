local commons = require("scripts.commons")
local tools = require("scripts.tools")

local modname = commons.modname
local prefix = modname

local copy_paste = {}

---@param player any
---@return LuaEntity?
---@return LuaRecipe?
---@return LuaEntity?
function copy_paste.get_info(player)
    local machine = player.entity_copy_source
    if machine and machine.type == "assembling-machine" then
        local selected = player.selected
        if not selected or not selected.valid then return nil end

        if selected.type ~= "logistic-container" or
            (selected.prototype.logistic_mode ~= "requester" and selected.prototype.logistic_mode ~= "buffer") then
            return nil
        end

        local recipe = machine.get_recipe()
        if not recipe then return nil end

        return machine, recipe, selected
    end
    return nil
end

---@param player LuaPlayer
---@return LuaGuiElement
function copy_paste.get_frame(player)
    return player.gui.center[modname .. "-copy-frame"]
end

---@param player LuaPlayer
function copy_paste.close(player)
    local frame = copy_paste.get_frame(player)
    tools.get_vars(player).copy_info = nil
    if frame then
        frame.destroy()
    end
end

---@param flow LuaGuiElement
---@param recipe LuaRecipe
---@param ratio integer
---@param machine LuaEntity
function copy_paste.add_detail(flow, recipe, ratio, machine)
    flow.clear()

    local last
    for _, ingredient in pairs(recipe.ingredients) do
        if ingredient.type == "item" then
            local amount = ratio * ingredient.amount
            local name = ingredient.name

            local field = flow.add {
                type = "textfield",
                name = prefix .. "-" .. name,
                numeric = true,
                text = tostring(amount),
                tags = { ingredient = name },
                clear_and_focus_on_right_click = true
            }
            field.style.width = 50
            flow.add { type = "label", caption = " x " }
            last                    = flow.add { type = "sprite", sprite = "item/" .. name }
            last.style.right_margin = 10
        end
    end

    local count = ratio / machine.crafting_speed * recipe.energy
    local time = string.format("%.2f s", count)
    flow.add { type = "label", caption = time }
end

---@param player LuaPlayer
---@return boolean?
function copy_paste.open(player)
    copy_paste.close(player)

    local machine, recipe, chest = copy_paste.get_info(player)
    if not machine or not recipe or not chest then return false end

    local ratio = tools.get_vars(player).selected_ratio
    if not ratio then
        local target = player.mod_settings[modname .. "-consumption-target"].value

        ratio = math.floor(target / recipe.energy * machine.crafting_speed)
        if ratio < 1 then
            ratio = 1
        end
    end


    copy_paste.allocate_section(chest)

    local frame = player.gui.center.add { type = "frame", caption = { prefix .. "-dialog.production_count" }, name =
        modname .. "-copy-frame", direction = "vertical" }

    local inner_frame = frame.add { type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" }

    local flow = inner_frame.add { type = "flow", direction = "horizontal" }
    flow.add { type = "label", caption = { prefix .. "-dialog.count" } }
    local f = flow.add { type = "textfield", numeric = true, text = tostring(ratio), name = modname .. "-copy_ratio" }
    f.style.width = 80
    local f_ratio = f
    f = flow.add { type = "button", caption = "+", name = modname .. "-copy-up", tooltip = { prefix .. "-tooltip.up" } }
    f.style.width = 30
    f = flow.add { type = "button", caption = "-", name = modname .. "-copy-down", tooltip = { prefix .. "-tooltip.down" } }
    f.style.width = 30
    flow.add { type = "button", caption = { prefix .. "-dialog.ok" }, name = modname .. "-copy-ok" }
    flow.add { type = "button", caption = { prefix .. "-dialog.cancel" }, name = modname .. "-copy-cancel" }

    local flow2 = inner_frame.add { type = "flow", direction = "horizontal", name = modname .. "-copy_detail" }
    flow2.style.top_margin = 10
    copy_paste.add_detail(flow2, recipe, ratio, machine)

    f_ratio.focus()

    tools.get_vars(player).copy_info = {
        machine = machine,
        recipe = recipe,
        chest = chest
    }
    return true
end

function copy_paste.apply(chest, recipe, f_detail)
    local section = copy_paste.allocate_section(chest)
    local filters = {}
    for _, ingredient in pairs(recipe.ingredients) do
        if ingredient.type == "item" then
            local name  = ingredient.name
            local field = f_detail[prefix .. "-" .. name]
            if field then
                local amount = tonumber(field.text)
                if amount and amount > 0 then
                    table.insert(filters, {
                        value = { type = "item", 
                            name = ingredient.name,
                            quality = "normal",
                            comparator = "="
                         },
                        min = amount
                    })
                end
            end
        end
    end
    section.filters = filters
end

function copy_paste.update_detail(player)
    local frame = copy_paste.get_frame(player)
    local f_ratio = tools.get_child(frame, modname .. "-copy_ratio") or {}
    local ratio = tonumber(f_ratio.text)
    if not ratio then return end


    local info = tools.get_vars(player).copy_info
    if not info or not info.machine.valid or not info.chest.valid then return end

    local flow2 = tools.get_child(frame, modname .. "-copy_detail") --[[@as LuaGuiElement]]
    copy_paste.add_detail(flow2, info.recipe, ratio, info.machine)
end

tools.on_gui_click(modname .. "-copy-up", function(e)
    local player = game.players[e.player_index]
    local f_ratio = tools.get_child(copy_paste.get_frame(player), modname .. "-copy_ratio") or {}
    local ratio = tonumber(f_ratio.text)
    if not ratio then return end
    if e.shift then
        ratio = ratio + 10
    else
        ratio = ratio + 1
    end
    f_ratio.text = tostring(ratio)
    copy_paste.update_detail(player)
end)

tools.on_gui_click(modname .. "-copy-down", function(e)
    local player = game.players[e.player_index]
    local f_ratio = tools.get_child(copy_paste.get_frame(player), modname .. "-copy_ratio") or {}
    local ratio = tonumber(f_ratio.text)
    if not ratio then return end
    if e.shift then
        ratio = ratio - 10
    else
        ratio = ratio - 1
    end
    if ratio <= 0 then ratio = 1 end
    f_ratio.text = tostring(ratio)
    copy_paste.update_detail(player)
end)

function copy_paste.valid(player)
    local f_detail = tools.get_child(copy_paste.get_frame(player), modname .. "-copy_detail")
    if not f_detail then return end

    local info = tools.get_vars(player).copy_info
    if not info or not info.machine.valid or not info.chest.valid then return end

    local vars = tools.get_vars(player)
    vars.saved_filters = nil
    copy_paste.apply(info.chest, info.recipe, f_detail)
end

---@param chest LuaEntity
---@return LuaLogisticSection?
function copy_paste.allocate_section(chest)
    local rpoint = chest.get_requester_point()
    if not rpoint then return nil end
    for i = 2, rpoint.sections_count do
        rpoint.remove_section(1)
    end
    local section
    if rpoint.sections_count == 1 then
        section = rpoint.get_section(1)
        section.filters = {}
        return section
    else
        section = rpoint.add_section()
        return section
    end
end

---@param chest LuaEntity
---@return LuaLogisticSection?
function copy_paste.clear_sections(chest)
    local rpoint = chest.get_requester_point()
    if not rpoint then return nil end
    for i = 1, rpoint.sections_count do
        rpoint.remove_section(1)
    end
end


function copy_paste.restore(player)
    local vars = tools.get_vars(player)
    local recipe = vars.saved_recipe
    local chest = vars.saved_chest --[[@as LuaEntity]]
    local saved_filters = vars.saved_filters
    if not (recipe and recipe.valid and chest and chest.valid and saved_filters) then return end


    copy_paste.clear_sections(chest)
    
    local rpoint = chest.get_requester_point()
    if not rpoint then return end
    for _, def in pairs(saved_filters) do
        local section = rpoint.add_section(def.group)
        section.filters = def.filters
    end
end

tools.on_gui_click(modname .. "-copy-ok", function(e)
    local player = game.players[e.player_index]
    copy_paste.valid(player)
    copy_paste.close(player)
end)

tools.on_gui_click(modname .. "-copy-cancel", function(e)
    local player = game.players[e.player_index]
    copy_paste.close(player)
    copy_paste.restore(player)
end)

tools.on_event(defines.events.on_gui_text_changed, function(e)
    if e.element and e.element.name == modname .. "-copy_ratio" then
        local player = game.players[e.player_index]
        copy_paste.update_detail(player)
    end
end)

tools.on_event(defines.events.on_gui_confirmed, function(e)
    if e.element and string.find(e.element.name, modname) then
        local player = game.players[e.player_index]
        copy_paste.valid(player)
        copy_paste.close(player)
    end
end)

tools.on_event(defines.events.on_gui_closed, function(e)
    local player = game.players[e.player_index]
    copy_paste.close(player)
end)

tools.on_event(defines.events.on_gui_opened, function(e)
    local player = game.players[e.player_index]
    copy_paste.close(player)
end)

function copy_paste.try_copy_to_loader(player)
    ---@type LuaEntity
    local machine = player.entity_copy_source
    if not machine or (machine.type ~= "assembling-machine" and machine.type ~= "furnace") then
        return
    end

    ---@type LuaEntity
    local selected = player.selected
    if not selected or not selected.valid then return end

    if selected.type ~= "loader-1x1" and selected.type ~= "loader" then
        return
    end

    local recipe = machine.get_recipe() or (machine.type == "furnace" and machine.previous_recipe)
    if not recipe then return end

    local ingredients = recipe.ingredients
    if not ingredients then
        return
    end

    local index = 1
    for _, ingredient in pairs(ingredients) do
        if ingredient.type == "item" then
            selected.set_filter(index, ingredient.name)
            index = index + 1
            if index > selected.filter_slot_count then
                break
            end
        end
    end
end

script.on_event(commons.prefix .. "-shift-click",
    ---@param e EventData.on_gui_click
    function(e)
        copy_paste.try_copy_to_loader(game.players[e.player_index])
    end)


local function on_entity_settings_pasted(e)
    local player = game.players[e.player_index]
    if player.mod_settings[modname .. "-input-ingredient"].value then
        if not copy_paste.open(player) then
            copy_paste.try_copy_to_loader(player)
        end
    end
end

---@param e EventData.on_selected_entity_changed
local function on_selected_entity_changed(e)
    local player = game.players[e.player_index]

    local machine, recipe, chest = copy_paste.get_info(player)
    if not (machine and recipe and chest) then return end

    local vars = tools.get_vars(player)
    vars.selected_ratio = nil

    local point = chest.get_requester_point()
    local saved_filters = {}

    if point and point.sections_count > 0 then
        for i = 1, point.sections_count do
            local section = point.get_section(i)
            for _, filter in pairs(section.filters) do
                local signal = filter.value
                local ratio
                if signal and signal.name and filter.min then
                    for _, ingredient in pairs(recipe.ingredients) do
                        if ingredient.name == signal.name and ingredient.type == 'item' then
                            ratio = filter.min / ingredient.amount
                            if ratio == 0 then ratio = 1 end
                            tools.get_vars(player).selected_ratio = ratio
                            goto found
                        end
                    end
                end
            end
        end
        ::found::
        for j = 1, point.sections_count do
            local section = point.get_section(j)
            table.insert(saved_filters, {
                filters = section.filters,
                group = section.group
            })
        end
    end


    vars.saved_filters = saved_filters
    vars.saved_chest = chest
    vars.saved_recipe = recipe
end

tools.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)
tools.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)
