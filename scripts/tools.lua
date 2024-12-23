
local log_index = 1
local tracing = true

local tools = {}
local function debug(msg)
    if not tracing then return end
    msg = "[" .. log_index .. "] " .. msg
    log_index = log_index + 1
    if game then
        for _, player in pairs(game.players) do player.print(msg) end
    end
    log(msg)
end

tools.debug = debug

local function cdebug(cond, msg) if cond then debug(msg) end end

tools.cdebug = cdebug

function tools.set_trace(trace) tracing = trace end

function tools.strip(o)
    return string.gsub(serpent.block(o), "%s", "")
end

local strip = tools.strip

function tools.get_vars(player)

    local players = storage.players
    if players == nil then
        players = {}
        storage.players = players
    end
    local vars = players[player.index]
    if vars == nil then
        vars = {}
        players[player.index] = vars
    end
    return vars
end

function tools.get_force_vars(force)

    local forces = storage.forces
    if forces == nil then
        forces = {}
        storage.forces = forces
    end
    local vars = forces[force.index]
    if vars == nil then
        vars = {}
        forces[force.index] = vars
    end
    return vars
end

function tools.close_ui(unit_number, close_proc, field)

    if not field then field = "selected" end
    if not storage.players then return end
    for index, vars in pairs(storage.players) do
        local selected = vars[field]
        if selected and selected.valid and selected.unit_number == unit_number then

            vars.selected = nil
            close_proc(game.players[index])
            return
        end
    end
end

function tools.get_id()
    local id = storage.id or 1
    storage.id = id + 1
    return id
end

function tools.comma_value(n) -- credit http://richard.warburton.it
    if not n then return "" end
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

function tools.table_count(table)
    local count = 0
    for _, _ in pairs(table) do count = count + 1 end
    return count
end

function tools.table_merge(table_list)
    local result = {}
    for _, t in ipairs(table_list) do
        if t then
            for _, e in pairs(t) do table.insert(result, e) end
        end
    end
    return result
end

function tools.table_copy(src)
    if not src then return nil end
    local copy = {}
    for _, value in pairs(src) do
        table.insert(copy, value)
    end
    return copy
end

function tools.table_dup(src)
    if not src then return nil end
    local copy = {}
    for key, value in pairs(src) do
        copy[key] = value
    end
    return copy
end

function tools.table_map(t, f)
    local result = {}
    for key, value in pairs(t) do
        local map_key, map_value = f(key, value)
        result[map_key] = map_value
    end
    return result
end

function tools.table_imap(t, f)
    local result = {}
    for _, value in ipairs(t) do
        local map_value = f(value)
        table.insert(result, map_value)
    end
    return result
end

function tools.table_find(t, f)
    local result = {}
    for key, value in pairs(f) do
        if f(key, value) then
            return key, value
        end
    end
    return nil
end

function tools.create_name_filter(name_list_list)
    local filters = {}
    for _, name_list in ipairs(name_list_list) do
        for _, name in ipairs(name_list) do
            table.insert(filters, { filter = 'name', name = name })
        end
    end
    return filters
end

------------------------------------------------

function tools.on_event(event, handler, filters)
    local previous = script.get_event_handler(event)
    if not previous then
        script.on_event(event, handler, filters)
    else
        local prev_filters = script.get_event_filter(event)
        local new_filters = nil

        if prev_filters == nil then
            new_filters = filters
        elseif filters == nil then
            new_filters = prev_filters
        else
            new_filters = tools.table_merge{prev_filters, filters}
        end

        script.on_event(event, function(e)
            previous(e)
            handler(e)
        end, new_filters)
    end
end

local on_load_handler

function tools.on_load(handler)
    if not on_load_handler then
        on_load_handler = handler
        script.on_load(function() on_load_handler() end)
    else
        local previous = on_load_handler
        on_load_handler = function()
            previous()
            handler()
        end
    end
end

function tools.fire_on_load() if on_load_handler then on_load_handler() end end

local on_init_handler

function tools.on_init(handler)
    if not on_init_handler then
        on_init_handler = handler
        script.on_init(function() on_init_handler() end)
    else
        local previous = on_init_handler
        on_init_handler = function()
            previous()
            handler()
        end
    end
end

local on_configuration_changed_handler

function tools.on_configuration_changed(handler)
    if not on_configuration_changed_handler then
        on_configuration_changed_handler = handler
        script.on_configuration_changed(function(data)
            on_configuration_changed_handler(data)
        end)
    else
        local previous = on_configuration_changed_handler
        on_configuration_changed_handler = function()
            previous()
            handler()
        end
    end
end

local on_debug_init_handler

function tools.on_debug_init(f)

    if on_debug_init_handler then
        local previous_init = on_debug_init_handler
        on_debug_init_handler = function()
            previous_init()
            f()
        end
    else
        on_debug_init_handler = f
        tools.on_event(defines.events.on_tick, function()
            if (on_debug_init_handler) then
                on_debug_init_handler()
                on_debug_init_handler = nil
            end
        end)
    end
end

local on_gui_click_map

local function on_gui_click_handler(e)

    if e.element.valid then
        local handler = on_gui_click_map[e.element.name]
        if handler then handler(e) end
    end
end

function tools.on_gui_click(button_name, f)

    if not on_gui_click_map then
        on_gui_click_map = {}
        tools.on_event(defines.events.on_gui_click, on_gui_click_handler)
    end
    on_gui_click_map[button_name] = f
end

------------------------------------------------

local function get_child(parent, name)

    local child = parent[name]
    if child then return child end

    local children = parent.children
    if not children then return nil end
    for _, e in pairs(children) do
        child = get_child(e, name)
        if child then return child end
    end
    return nil
end

tools.get_child = get_child
local build_trace = false

function tools.get_fields(parent)
    local fields = {}
    local mt = {
        __index = function(base, key)
            local value = rawget(base, key)
            if value then return value end
            value = tools.get_child(parent, key)
            rawset(base, key, value)
            return value
        end
    }
    setmetatable(fields, mt)
    return fields
end

local function recursive_build_gui(parent, def, path, refmap)

    local ref = def.ref
    local children = def.children
    local style_mods = def.style_mods
    local tabs = def.tabs

    if (build_trace) then
        debug("build: def=" .. strip(def))
    end

    def.ref = nil
    def.children = nil
    def.style_mods = nil
    def.tabs = nil

    if not def.type then
        if not build_trace then
            debug("build: def=" .. strip(def))
        end
        debug("Missing type")
    end

    local element = parent.add(def)

    if not ref and def.name then
        refmap[def.name] = element
    end

    if children then
        if def.type ~= "tabbed-pane" then
            for index, child_def in pairs(children) do
                local name = child_def.name
                if name then
                    table.insert(path, name .. ":" .. index)
                else
                    table.insert(path, index)
                end
                if build_trace then
                    debug("build: path=" .. strip(path))
                end
                recursive_build_gui(element, child_def, path, refmap)
                table.remove(path)
            end
        else
            for index, t in pairs(children) do
                local tab = t.tab
                local content = t.content

                local name = tab.name
                if name then
                    table.insert(path, name .. ":" .. index)
                else
                    table.insert(path, index)
                end
                if build_trace then
                    debug("build: path=" .. strip(path))
                end

                local ui_tab = recursive_build_gui(element, tab, path, refmap)
                local ui_content = recursive_build_gui(element, content, path,
                    refmap)
                element.add_tab(ui_tab, ui_content)

                table.remove(path)
            end
        end
    end

    if ref then
        local lmap = refmap
        for index, ipath in ipairs(ref) do
            if index == #ref then
                lmap[ipath] = element
            else
                local m = lmap[ipath]
                if not m then
                    m = {}
                    lmap[ipath] = m
                end
                lmap = m
            end
        end
    end

    if style_mods then
        if build_trace then
            debug("build: style_mods=" .. strip(style_mods))
        end
        for name, value in pairs(style_mods) do
            element.style[name] = value
        end
    end

    return element
end

function tools.build_gui(parent, def)

    local refmap = {}
    if not def.type then
        for index, subdef in ipairs(def) do
            recursive_build_gui(parent, subdef, { index }, refmap)
        end
    else
        recursive_build_gui(parent, def, {}, refmap)
    end
    return refmap
end

local user_event_handlers = {}

function tools.register_user_event(name, handler)

    local previous = user_event_handlers[name]
    if not previous then
        user_event_handlers[name] = handler
    else

        local new_handler = function(data)
            previous(data)
            handler(data)
        end
        user_event_handlers[name] = new_handler
    end
end

function tools.fire_user_event(name, data)

    local handler = user_event_handlers[name]
    if handler then
        handler(data)
    end
end

function tools.signal_to_sprite(signal)
    if not signal then return nil end
    local type = signal.type
    if type == "virtual" then
        return "virtual-signal/" .. signal.name
    else
        return type .. "/" .. signal.name
    end
end

function tools.sprite_to_signal(sprite)
    if not sprite or sprite == "" then return nil end
    local split = string.gmatch(sprite, "([^/]+)[/]([^/]+)")
    local type, name = split()
    if type == "virtual-signal" then
        type = "virtual"
    end
    return { type = type, name = name }
end

function tools.signal_to_name(signal)
    if not signal then return nil end
    local type = signal.type
    return "[" .. type .. "=" .. signal.name .. "]"
end

function tools.get_radius(master)
    local selection_box = master.selection_box
    local xradius = math.floor(selection_box.right_bottom.x - selection_box.left_top.x)/2 - 0.1
    local yradius = math.floor(selection_box.right_bottom.y - selection_box.left_top.y)/2 - 0.1
    return xradius, yradius
end

function tools.destroy_entities(master, entity_names)

    local xradius, yradius = tools.get_radius(master)
    if not master.surface.valid then return end
    local pos = master.position
	local entities = master.surface.find_entities_filtered {
		area = { left_top = { x = pos.x - xradius, y = pos.y - yradius }, right_bottom = { x = pos.x + xradius, y = pos.y + yradius } },
		name = entity_names
	}
	for _, e in pairs(entities) do
        if e.valid then
		    e.destroy()
        end
	end
end

function tools.get_event_name(index)
    for name, i in pairs(defines.events) do
        if i == index then
            return name
        end
    end
    return "[unknown:"..index.."]"
end

function tools.get_constant_name(index, base)
    for name, i in pairs(base) do
        if i == index then
            return name
        end
    end
    return "[unknown:"..index.."]"
end

------------------------------------------------

local mt = {

    __newindex = function(base, key, value)
        if key == "build_trace" then build_trace = value end
        if key == "tracing" then tracing = value end
    end,
    __index = function(base, key)
        if key == "build_trace" then return build_trace end
        if key == "tracing" then return tracing end
    end
}

setmetatable(tools, mt)

------------------------------------------------

return tools
