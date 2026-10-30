--[[
    core_inventory inventory ids differ between versions. This bridge does not
    try several ids, because a wrong-but-successful call could grant items into
    an unexpected inventory. Set Config.InventoryOptions.core_inventory.idMode.
    Modes: source, identifier, content, primary.
    The export names addItem, removeItem, and getItemCount are the commonly
    documented ones and were not live-tested here.
]]

local function inventoryId(src)
    local mode = Config.InventoryOptions and Config.InventoryOptions.core_inventory and Config.InventoryOptions.core_inventory.idMode or 'source'
    if mode == 'source' then return src end
    local identifier = Framework.GetIdentifier(src)
    if not identifier then return nil end
    if mode == 'identifier' then return identifier end
    if mode == 'content' then return 'content-' .. identifier end
    if mode == 'primary' then return 'primary-' .. identifier end
    return src
end

DJWS.InventoryProviders.core_inventory = {
    supports = { metadata = true, durability = true, weight = false },
    notes = 'Unverified inventory id. See Config.InventoryOptions.core_inventory.idMode.',
    CanCarry = function(src, item, count)
        if GetResourceState('core_inventory') ~= 'started' then return false, 'inventory_stopped' end
        local inv = inventoryId(src)
        if not inv then return false, 'inventory_unavailable' end
        local ok, result = pcall(function()
            return exports.core_inventory:canCarry(inv, item, count)
        end)
        if not ok then
            return false, 'carry_check_unverified'
        end
        return DJWS.InterpretCarry('core_inventory', ok, result)
    end,
    Add = function(src, item, count, metadata)
        if GetResourceState('core_inventory') ~= 'started' then return false, 'inventory_stopped' end
        local inv = inventoryId(src)
        if not inv then return false, 'inventory_unavailable' end
        local ok, result = pcall(function()
            return exports.core_inventory:addItem(inv, item, count, metadata)
        end)
        return DJWS.InterpretAdd('core_inventory', ok, result)
    end,
    Remove = function(src, item, count)
        if GetResourceState('core_inventory') ~= 'started' then return false, 'inventory_stopped' end
        local inv = inventoryId(src)
        if not inv then return false, 'inventory_unavailable' end
        local ok, result = pcall(function()
            return exports.core_inventory:removeItem(inv, item, count)
        end)
        return DJWS.InterpretRemove('core_inventory', ok, result)
    end,
    Count = function(src, item)
        if GetResourceState('core_inventory') ~= 'started' then return 0 end
        local inv = inventoryId(src)
        if not inv then return 0 end
        local ok, result = pcall(function()
            return exports.core_inventory:getItemCount(inv, item)
        end)
        if not ok then
            local ok2, result2 = pcall(function()
                return exports.core_inventory:getItem(inv, item)
            end)
            return DJWS.InterpretCount(ok2, result2)
        end
        return DJWS.InterpretCount(ok, result)
    end,
}
