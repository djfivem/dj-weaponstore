DJWS.InventoryProviders['lj-inventory'] = {
    supports = { metadata = true, durability = false, weight = false },
    notes = 'lj-inventory exports used: AddItem, RemoveItem, GetItemByName, and CanAddItem when present. Carry support varies by version and is not treated as success when the export errors. Not live-tested here.',
    CanCarry = function(src, item, count)
        if GetResourceState('lj-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['lj-inventory']:CanAddItem(src, item, count)
        end)
        return DJWS.InterpretCarry('lj-inventory', ok, result)
    end,
    Add = function(src, item, count, metadata)
        if GetResourceState('lj-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['lj-inventory']:AddItem(src, item, count, false, metadata)
        end)
        return DJWS.InterpretAdd('lj-inventory', ok, result)
    end,
    Remove = function(src, item, count)
        if GetResourceState('lj-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['lj-inventory']:RemoveItem(src, item, count, false)
        end)
        return DJWS.InterpretRemove('lj-inventory', ok, result)
    end,
    Count = function(src, item)
        if GetResourceState('lj-inventory') ~= 'started' then return 0 end
        local ok, result = pcall(function()
            return exports['lj-inventory']:GetItemByName(src, item)
        end)
        if ok and (result == nil or result == false) then
            local hasOk, has = pcall(function()
                return exports['lj-inventory']:HasItem(src, item, 1)
            end)
            if hasOk and has == true then return 1 end
        end
        return DJWS.InterpretCount(ok, result)
    end,
}
