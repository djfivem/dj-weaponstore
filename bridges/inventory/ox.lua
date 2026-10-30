DJWS.InventoryProviders.ox_inventory = {
    supports = { metadata = true, durability = true, weight = true },
    CanCarry = function(src, item, count, metadata)
        if GetResourceState('ox_inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports.ox_inventory:CanCarryItem(src, item, count, metadata)
        end)
        return DJWS.InterpretCarry('ox_inventory', ok, result)
    end,
    Add = function(src, item, count, metadata)
        if GetResourceState('ox_inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports.ox_inventory:AddItem(src, item, count, metadata)
        end)
        return DJWS.InterpretAdd('ox_inventory', ok, result)
    end,
    Remove = function(src, item, count, metadata)
        if GetResourceState('ox_inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports.ox_inventory:RemoveItem(src, item, count, metadata)
        end)
        return DJWS.InterpretRemove('ox_inventory', ok, result)
    end,
    Count = function(src, item)
        if GetResourceState('ox_inventory') ~= 'started' then return 0 end
        local ok, result = pcall(function()
            return exports.ox_inventory:GetItemCount(src, item)
        end)
        return DJWS.InterpretCount(ok, result)
    end,
}
