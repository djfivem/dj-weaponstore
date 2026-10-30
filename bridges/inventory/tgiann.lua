DJWS.InventoryProviders['tgiann-inventory'] = {
    supports = { metadata = true, durability = true, weight = false },
    notes = 'Exports used: AddItem(src, item, count, slot, metadata), RemoveItem, GetItemByName, HasItem, CanCarryItem. Not live-tested in this repository. Durability is whatever metadata table this resource passes; tgiann may expect a different field name on your build.',
    CanCarry = function(src, item, count)
        if GetResourceState('tgiann-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['tgiann-inventory']:CanCarryItem(src, item, count)
        end)
        return DJWS.InterpretCarry('tgiann-inventory', ok, result)
    end,
    Add = function(src, item, count, metadata)
        if GetResourceState('tgiann-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['tgiann-inventory']:AddItem(src, item, count, nil, metadata)
        end)
        return DJWS.InterpretAdd('tgiann-inventory', ok, result)
    end,
    Remove = function(src, item, count, metadata)
        if GetResourceState('tgiann-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['tgiann-inventory']:RemoveItem(src, item, count, nil, metadata)
        end)
        return DJWS.InterpretRemove('tgiann-inventory', ok, result)
    end,
    Count = function(src, item)
        if GetResourceState('tgiann-inventory') ~= 'started' then return 0 end
        local ok, result = pcall(function()
            return exports['tgiann-inventory']:GetItemByName(src, item)
        end)
        local count = DJWS.InterpretCount(ok, result)
        if count > 0 then return count end
        local hasOk, has = pcall(function()
            return exports['tgiann-inventory']:HasItem(src, item, 1)
        end)
        if hasOk and has == true then return 1 end
        return 0
    end,
}
