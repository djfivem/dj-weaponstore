DJWS.InventoryProviders['ps-inventory'] = {
    supports = { metadata = true, durability = false, weight = false },
    notes = 'ps-inventory is called with the qb-inventory-style exports AddItem, RemoveItem, GetItemByName, and CanAddItem. Not live-tested in this repository. Weight limits are left to ps-inventory.',
    CanCarry = function(src, item, count)
        if GetResourceState('ps-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['ps-inventory']:CanAddItem(src, item, count)
        end)
        return DJWS.InterpretCarry('ps-inventory', ok, result)
    end,
    Add = function(src, item, count, metadata)
        if GetResourceState('ps-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['ps-inventory']:AddItem(src, item, count, false, metadata, 'dj-weaponstore')
        end)
        return DJWS.InterpretAdd('ps-inventory', ok, result)
    end,
    Remove = function(src, item, count)
        if GetResourceState('ps-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['ps-inventory']:RemoveItem(src, item, count, false, 'dj-weaponstore')
        end)
        return DJWS.InterpretRemove('ps-inventory', ok, result)
    end,
    Count = function(src, item)
        if GetResourceState('ps-inventory') ~= 'started' then return 0 end
        local ok, result = pcall(function()
            return exports['ps-inventory']:GetItemByName(src, item)
        end)
        return DJWS.InterpretCount(ok, result)
    end,
}
