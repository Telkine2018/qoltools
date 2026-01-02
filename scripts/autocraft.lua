local commons = require("scripts.commons")
local tools = require("scripts.tools")
local modname = commons.modname

local area_size = 40

local function scan_sector()
    for _, player in pairs(game.players) do
        local autocraft = tools.get_vars(player).autocraft
        local character = player.character

        if autocraft and player.controller_type == defines.controllers.character and character then
            local surface = player.surface
            local pos = player.position

            local area = { { pos.x - area_size, pos.y - area_size }, { pos.x + area_size, pos.y + area_size } }
            local ghosts = surface.find_entities_filtered { name = "entity-ghost", area = area, force = player.force }

            local needed = {}
            local function add_need(proto)
                local items = proto.items_to_place_this
                if items and #items > 0 then
                    local item = items[1]
                    needed[item.name] = (needed[item.name] or 0) + 1
                end
            end

            for _, ghost in pairs(ghosts) do
                local proto = ghost.ghost_prototype
                add_need(proto)
            end

            local upgrades = surface.find_entities_filtered { area = area, force = player.force, to_be_upgraded = true }
            if upgrades and #upgrades > 0 then
                for _, u in pairs(upgrades) do
                    local proto = u.get_upgrade_target()
                    add_need(proto)
                end
            end

            if table_size(needed) == 0 then
                return
            end

            local stock = {}

            local cq = player.crafting_queue
            if cq then
                for _, craft in pairs(cq) do
                    local recipe_name = craft.recipe
                    local recipe = prototypes.recipe[recipe_name]
                    local craft_count = craft.count
                    for _, product in pairs(recipe.products) do
                        if product.type == "item" then
                            stock[product.name] = (stock[product.name] or 0) + (craft_count * product.amount)
                        end
                    end
                end
            end

            local robots = surface.find_entities_filtered { type = "construction-robot", area = area, force = player.force }
            if robots and #robots > 0 then
                for _, robot in pairs(robots) do
                    local inv = robot.get_inventory(defines.inventory.robot_cargo)
                    if inv then
                        for _, c in pairs(inv.get_contents()) do
                            stock[c.name] = (stock[c.name] or 0) + c.count
                        end
                    end
                end
            end

            network = character.surface.find_logistic_network_by_position(character.position, player.force_index)
            if network then

                for item, _ in pairs(needed) do
                    local count = network.get_item_count(item)
                    if count and count > 0 then
                        stock[item] = (stock[item] or 0) + count
                    end
                end
            end


            local proto               = player.character.prototype
            local crafting_categories = proto.crafting_categories
            if not crafting_categories then return end

            local inv = player.get_main_inventory()

            for item, count in pairs(needed) do
                local current_count = (stock[item] or 0) + (inv and inv.get_item_count(item) or 0)
                if current_count < count then
                    local recipes = prototypes.get_recipe_filtered {
                        { filter = "has-product-item", elem_filters = { { filter = "name", name = item } }, mode = "and" }
                    }

                    if #recipes > 0 then
                        for _, recipe in pairs(recipes) do
                            if crafting_categories[recipe.category] then
                                local amount
                                for _, product in pairs(recipe.products) do
                                    if product.name == item then
                                        amount = product.amount
                                        break
                                    end
                                end
                                count = math.ceil((count - current_count) / amount)
                                player.begin_crafting { recipe = recipe, count = count }
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

local autocraft_name = modname .. "-autocraft"

tools.on_load(function()
    tools.on_nth_tick(60, scan_sector)
end)


tools.on_init(function()
    tools.fire_on_load()
end)


tools.on_event(defines.events.on_lua_shortcut,
    ---@parem e EventData
    function(e)
        if e.prototype_name ~= autocraft_name then return end
        local player = game.players[e.player_index]
        local vars = tools.get_vars(player)

        local autocraft = vars.autocraft
        autocraft = not autocraft
        player.set_shortcut_toggled(autocraft_name, autocraft)
        vars.autocraft = autocraft
    end)
