
local commons = require("scripts.commons")
local tools = require("scripts.tools")
local modname = commons.modname

local sort_inventory
local sort_train

local function get_spider_max_logistic_slots(player) return 200 end

local function get_player_max_logistic_slots(player) return 200 end

local function is_special(stack)

    if stack.is_blueprint then
        return true
    elseif stack.is_blueprint_book then
        return true
    elseif stack.is_mining_tool then
        return true
    elseif stack.is_armor then
        return true
    elseif stack.is_repair_tool then
        return true
    elseif stack.is_item_with_label then
        return true
    elseif stack.is_item_with_inventory then
        return true
    elseif stack.is_item_with_entity_data then
        return true
    elseif stack.is_selection_tool then
        return true
    elseif stack.is_item_with_tags then
        return true
    elseif stack.is_deconstruction_item then
        return true
    elseif stack.is_upgrade_item then
        return true
    elseif stack.is_tool then
        if not stack.durability then return false end
        if stack.durability == stack.prototype.durability then
            return false
        end
        return true
    elseif stack.type == "spidertron-remote" then
        return true
    elseif stack.name == "artillery-targeting-remote" then
        return true
    elseif stack.health ~= 1.0 then
        return true
    elseif stack.prototype.magazine_size and stack.ammo <
        stack.prototype.magazine_size then
        return true
    end
    return false
end

local function clean_inv(limits, ammo_inv, fuel_inv, trunk_inv, trash_inv)

    local content = {}
    local trash = {}
    local protos = {}

    if ammo_inv then
        local ammo_content = ammo_inv.get_contents()
        for name, count in pairs(ammo_content) do
            content[name] = (content[name] or 0) + count
            protos[name] = game.item_prototypes[name]
        end
    end

    if fuel_inv then
        local fuel_content = fuel_inv.get_contents()
        for name, count in pairs(fuel_content) do
            content[name] = (content[name] or 0) + count
            protos[name] = game.item_prototypes[name]
        end
    end

    local base = {}
    for name, count in pairs(content) do base[name] = count end

    for i = 1, #trunk_inv do
        local stack = trunk_inv[i]

        if stack.valid and stack.valid_for_read then

            if not is_special(stack) then
                local name = stack.name
                local limit = limits[name] or 0
                local count = stack.count
                local current = content[name] or 0

                current = current + count
                local dif = math.min(current - limit, count)
                if dif > 0 then
                    trash[name] = (trash[name] or 0) + dif
                    if dif == count then
                        stack.clear()
                    else
                        local stack_count = count - dif
                        stack.count = stack_count
                        content[name] = (content[name] or 0) + stack_count
                    end
                else
                    content[name] = (content[name] or 0) + count
                end
            end
        end
    end

    for name, count in pairs(trash) do
        local real = trash_inv.insert({ name = name, count = count })
        if real and real < count then
            trunk_inv.insert({ name = name, count = count - real })
        end
    end
end

local function clean_spider(player, spider)

    local trunk_inv = spider.get_inventory(defines.inventory.spider_trunk)
    local ammo_inv = spider.get_inventory(defines.inventory.spider_ammo)
    local fuel_inv = spider.get_inventory(defines.inventory.fuel)
    local trash_inv = spider.get_inventory(defines.inventory.spider_trash)

    local logistics = {}
    local limits = {}
    for i = 1, get_spider_max_logistic_slots(spider) do
        local slot = spider.get_vehicle_logistic_slot(i)
        if slot.name then limits[slot.name] = slot.min end
    end

    clean_inv(limits, ammo_inv, fuel_inv, trunk_inv, trash_inv)

    if player.mod_settings[modname .. "-clean-auto-sort"].value then
        trunk_inv.sort_and_merge()
    end

end

local function get_player_logistic_limits(player)

    local limits = {}
    for i = 1, get_player_max_logistic_slots(player) do
        local slot = player.get_personal_logistic_slot(i)
        if slot.name then limits[slot.name] = slot.min end
    end
    return limits
end

local function clean_player(player)

    local trunk_inv = player.get_inventory(defines.inventory.character_main)
    local ammo_inv = player.get_inventory(defines.inventory.character_ammo)
    local trash_inv = player.get_inventory(defines.inventory.character_trash)

    local limits = get_player_logistic_limits(player)
    clean_inv(limits, ammo_inv, nil, trunk_inv, trash_inv)
end

local function clean_player_to_car(player, car)

    local trunk_inv = player.get_inventory(defines.inventory.character_main)
    local ammo_inv = player.get_inventory(defines.inventory.character_ammo)
    local trash_inv = car.get_inventory(defines.inventory.car_trunk)

    local limits = get_player_logistic_limits(player)
    clean_inv(limits, ammo_inv, nil, trunk_inv, trash_inv)

    if player.mod_settings[modname .. "-feed-auto-sort"].value then
        trash_inv.sort_and_merge()
    end
end

local function on_inventory_clean(e)

    local player = game.players[e.player_index]
    if not player.character then return end

    local vehicle = tools.get_vars(player).selected
    local noclean_player = true
    if vehicle and vehicle.valid then
        if vehicle.type == "spider-vehicle" then
            if remote.interfaces["spidersentinel"]["get_spider_in_squad"] then
                local spiders = remote.call("spidersentinel",
                    "get_spider_in_squad",
                    vehicle.unit_number)
                if spiders then
                    for _, spider in pairs(spiders) do
                        clean_spider(player, spider)
                    end
                else
                    clean_spider(player, vehicle)
                end
            else
                clean_spider(player, vehicle)
            end
            clean_player(player)
        elseif vehicle.type == "car" then
            clean_player_to_car(player, vehicle)
            noclean_player = true
        elseif vehicle.type == "locomotive" or vehicle.type == "cargo-wagon" then
            local train = vehicle.train

            local trunk_inv = player.get_inventory(defines.inventory
                .character_main)
            local ammo_inv = player.get_inventory(defines.inventory
                .character_ammo)

            local limits = get_player_logistic_limits(player)
            clean_inv(limits, ammo_inv, nil, trunk_inv, train)

            if player.mod_settings[modname .. "-feed-auto-sort"].value then
                sort_train(train)
            end

            noclean_player = true
        end
    end

    if noclean_player then clean_player(player) end
end

local function feed_from_inventory(from_inv, to_inv, limits, player)

    for i = 1, #from_inv do
        local stack = from_inv[i]
        if stack.valid and stack.valid_for_read then
            if not is_special(stack) then
                local name = stack.name
                local limit_count = limits[stack.name]
                if limit_count then
                    local to_count = to_inv.get_item_count(name) or 0
                    local dif = limit_count - to_count
                    if dif > 0 then
                        dif = to_inv.insert({ name = name, count = dif })
                        from_inv.remove({ name = name, count = dif })
                        if player then
                            player.print {
                                modname .. "-messages.insert_items", dif,
                                "[item=" .. name .. "]"
                            }
                        end
                    end
                end
            end
        end
    end

    if player.mod_settings[modname .. "-feed-auto-sort"].value then
        from_inv.sort_and_merge()
    end
end

local function feed_from_spider(spider, player)
    local from_inv = spider.get_inventory(defines.inventory.spider_trunk)
    local to_inv = player.get_inventory(defines.inventory.character_main)
    local limits = get_player_logistic_limits(player)

    feed_from_inventory(from_inv, to_inv, limits, player)
end

local function feed_from_car(vehicle, player)
    local from_inv = vehicle.get_inventory(defines.inventory.car_trunk)
    local to_inv = player.get_inventory(defines.inventory.character_main)
    local limits = get_player_logistic_limits(player)

    feed_from_inventory(from_inv, to_inv, limits, player)
end

local function feed_from_vehicle(vehicle, player)

    if vehicle.type == "spider-vehicle" then
        if remote.interfaces["spidersentinel"]["get_spider_in_squad"] then
            local spiders = remote.call("spidersentinel", "get_spider_in_squad",
                vehicle.unit_number)
            if spiders then
                for _, spider in pairs(spiders) do
                    feed_from_spider(spider, player)
                end
            else
                feed_from_spider(vehicle, player)
            end
        else
            feed_from_spider(vehicle, player)
        end
        return true
    elseif vehicle.type == "car" then
        feed_from_car(vehicle, player)
        return true
    elseif vehicle.type == "locomotive" or vehicle.type == "cargo-wagon" then
        local train = vehicle.train
        local to_inv = player.get_inventory(defines.inventory.character_main)
        local limits = get_player_logistic_limits(player)

        local carriages = train.carriages
        for _, c in pairs(carriages) do
            if c.type == "cargo-wagon" then
                local from_inv = c.get_inventory(defines.inventory.cargo_wagon)
                if from_inv then
                    feed_from_inventory(from_inv, to_inv, limits, player)
                end
            end
        end
        return true
    end
    return false
end

local function on_inventory_feed(e)
    local player = game.players[e.player_index]
    local vehicle = tools.get_vars(player).selected

    if not player.character then return end
    if not vehicle or not vehicle.valid or
        not feed_from_vehicle(vehicle, player) then
        vehicle = player.vehicle
        if vehicle and vehicle.valid then
            feed_from_vehicle(vehicle, player)
        end
    end
end

local function on_gui_opened(e)
    local player = game.players[e.player_index]

    local entity = e.entity
    if entity then
        if entity.type ~= "spider-vehicle" and entity.type ~= "car" and
            entity.type ~= "locomotive" and entity.type ~= "cargo-wagon" and
            entity.type ~= "container" and entity.type ~= "logistic-container" then
            entity = nil
        end
    end
    tools.get_vars(player).selected = entity
end

local function on_gui_closed(e)
    local player = game.players[e.player_index]
    tools.get_vars(player).selected = nil
end

sort_train = function(train)
    local carriages = train.carriages
    for _, c in pairs(carriages) do
        if c.type == "cargo-wagon" then
            local inv = c.get_inventory(defines.inventory.cargo_wagon)
            inv.sort_and_merge()
        end
    end
end

sort_inventory = function(player, container)

    if not container then return false end

    if container.type == "spider-vehicle" then
        local inv = container.get_inventory(defines.inventory.spider_trunk)
        inv.sort_and_merge()
        return true
    elseif container.type == "car" then
        local inv = container.get_inventory(defines.inventory.car_trunk)
        inv.sort_and_merge()
        return true
    elseif container.type == "cargo-wagon" then
        local inv = container.get_inventory(defines.inventory.cargo_wagon)
        inv.sort_and_merge()
    elseif container.type == "locomotive" then
        local train = container.train
        sort_train(train)
        return true
    elseif container.type == "container" or container.type == "logistic-container" or container.type == "linked-container"  then
        local inv = container.get_inventory(defines.inventory.chest)
        inv.sort_and_merge()
        return true
    end
    return false
end

local function on_inventory_sort(e)

    local player = game.players[e.player_index]
    local selected = tools.get_vars(player).selected

    if selected and selected.valid then sort_inventory(player, selected) end
end

script.on_event(modname .. "-feed", on_inventory_feed)
script.on_event(modname .. "-sort", on_inventory_sort)

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
