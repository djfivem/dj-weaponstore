DJWS.InventoryProviders['codem-inventory'] = {
    supports = { metadata = true, durability = false, weight = false },
    notes = 'Exports used: AddItem, RemoveItem, GetItemByName, HasItem, and CanCarryItem when it exists. Not live-tested in this repository. A missing carry export blocks the grant instead of assuming the inventory has room.',
    CanCarry = function(src, item, count)
        if GetResourceState('codem-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['codem-inventory']:CanCarryItem(src, item, count)
        end)
        return DJWS.InterpretCarry('codem-inventory', ok, result)
    end,
    Add = function(src, item, count, metadata)
        if GetResourceState('codem-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['codem-inventory']:AddItem(src, item, count, false, metadata)
        end)
        return DJWS.InterpretAdd('codem-inventory', ok, result)
    end,
    Remove = function(src, item, count)
        if GetResourceState('codem-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['codem-inventory']:RemoveItem(src, item, count, false)
        end)
        return DJWS.InterpretRemove('codem-inventory', ok, result)
    end,
    Count = function(src, item)
        if GetResourceState('codem-inventory') ~= 'started' then return 0 end
        local ok, result = pcall(function()
            return exports['codem-inventory']:GetItemByName(src, item)
        end)
        local count = DJWS.InterpretCount(ok, result)
        if count > 0 then return count end
        local hasOk, has = pcall(function()
            return exports['codem-inventory']:HasItem(src, item, 1)
        end)
        if hasOk and has == true then return 1 end
        return 0
    end,
}
