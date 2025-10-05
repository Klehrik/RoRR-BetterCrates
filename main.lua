-- Better Crates
-- Klehrik

mods["LuaENVY-ENVY"].auto()
mods["ReturnsAPI-ReturnsAPI"].auto{
    namespace   = "betterCrates",
    mp          = true
}

local item
local packet
local saved_selections = {}

local function init()
    hotloaded = true
    
    -- Add Cancel item
    item = Item.new("cancel")
    item:set_sprite(Sprite.new("cancel", "~/sCancel.png", 1, 16, 16))

    -- Packet
    packet_free_actor = Packet.new()
    packet_free_actor:set_serializers(
        function(buffer, actor)
            buffer:write_instance(actor)
        end,

        function(buffer, player)
            local actor = buffer:read_instance()

            GM.actor_activity_set(actor, 0)

            -- [Host]  Send to all players
            if Net.host then
                packet_free_actor:send_exclude(player, actor)
            end
        end
    )

    -- Add callback to all crates
    for id = 0, #Global.custom_object - 1 do
        local obj = Object.wrap(Object.CUSTOM_START + id)
        if obj.base == gm.constants.oCustomObject_pInteractableCrate then
            
            Callback.add(obj.on_step, Callback.Priority.BEFORE, function(inst)
                local inst_data = Instance.get_data(inst)
                local actor = inst.activator
                local object_index = inst:get_object_index()

                -- Reset variables
                if inst.active == 0 then
                    inst_data.loaded_selection = false
                    
                    -- Delete `contents`
                    inst.contents = nil


                -- Item selection UI
                elseif inst.active == 1 then
                    local contents = inst.contents
                    if not contents then return end

                    -- Insert Cancel item
                    -- `contents` does not exist until this point
                    if not contents:contains(item.object_id) then
                        contents:insert(0, item.object_id)
                    end

                    -- Load saved selection
                    if  (not inst_data.loaded_selection)
                    and saved_selections[object_index] then
                        inst_data.loaded_selection = true
                        inst.selection = math.min(saved_selections[object_index], #contents - 1)
                    end


                -- Cancel crate selection if Cancel is selected
                elseif inst.active >= 3 then
                    local contents = inst.contents
                    if not contents then return end

                    -- Save selection for this crate type
                    -- if activator is this game client
                    if Player.get_local() == actor then
                        saved_selections[object_index] = inst.selection
                    end

                    -- Check if current selection is Cancel
                    if contents:get(inst.selection) == item.object_id then
                        inst.active = 0

                        -- Hide item UI
                        inst.last_move_was_mouse = true
                        inst.owner = -4

                        -- Free actor activity
                        GM.actor_activity_set(actor, 0)
                    end

                end
            end)

        end
    end
end

Initialize.add(Callback.Priority.AFTER, init)
if hotloaded then init() end


Hook.add_pre(gm.constants.net_send_instance_message, function(self, other, result, args)
    -- Intercept net message that is sent on choosing an item
    -- (pInteractableCrate_Step_2 line 209)
    if (args[1].value ~= 14)
    or (args[3].value ~= 3)
    or (self.object_index ~= gm.constants.oCustomObject_pInteractableCrate)
    then return end

    local contents = self.contents
    if not contents then return end
    
    -- Check if current selection is Cancel
    if contents:get(self.selection) == item.object_id then
        -- Send signal to free actor activity
        if      Net.host    then packet_free_actor:send_to_all(args[2].value)
        elseif  Net.client  then packet_free_actor:send_to_host(args[2].value)
        end
        
        return false
    end
end)

Hook.add_post(gm.constants.run_create, function(self, other, result, args)
    -- Reset saved selections every run
    saved_selections = {}
end)