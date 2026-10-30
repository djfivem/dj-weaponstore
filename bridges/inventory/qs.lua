DJWS.InventoryProviders['qs-inventory'] = {
    supports = { metadata = true, durability = true, weight = true },
    notes = 'Quasar exports used: CanCarryItem, AddItem, RemoveItem, GetItemTotalAmount. Metadata is passed through AddItem. SetItemMetadata is not required for new grants. Not live-tested in this repository.',
    CanCarry = function(src, item, count)
        if GetResourceState('qs-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['qs-inventory']:CanCarryItem(src, item, count)
        end)
        return DJWS.InterpretCarry('qs-inventory', ok, result)
    end,
    Add = function(src, item, count, metadata)
        if GetResourceState('qs-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['qs-inventory']:AddItem(src, item, count, nil, metadata)
        end)
        return DJWS.InterpretAdd('qs-inventory', ok, result)
    end,
    Remove = function(src, item, count, metadata)
        if GetResourceState('qs-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['qs-inventory']:RemoveItem(src, item, count, nil, metadata)
        end)
        return DJWS.InterpretRemove('qs-inventory', ok, result)
    end,
    Count = function(src, item)
        if GetResourceState('qs-inventory') ~= 'started' then return 0 end
        local ok, result = pcall(function()
            return exports['qs-inventory']:GetItemTotalAmount(src, item)
        end)
        return DJWS.InterpretCount(ok, result)
    end,
}
