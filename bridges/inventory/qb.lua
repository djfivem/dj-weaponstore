local function add(src, item, count, metadata)
    local ok, result = pcall(function()
        return exports['qb-inventory']:AddItem(src, item, count, false, metadata, 'dj-weaponstore')
    end)
    if ok then return ok, result end
    if Framework and Framework.Name and (Framework.Name() == 'qbcore' or Framework.Name() == 'qbox') then
        local provider = DJWS.FrameworkProviders[Framework.Name()]
        if provider and provider.GetIdentifier then
            local qb = exports['qb-core'] and GetResourceState('qb-core') == 'started' and exports['qb-core']:GetCoreObject()
            if qb and qb.Functions then
                local player = qb.Functions.GetPlayer(src)
                if player and player.Functions and player.Functions.AddItem then
                    local ok2, result2 = pcall(function()
                        return player.Functions.AddItem(item, count, false, metadata)
                    end)
                    return ok2, result2
                end
            end
        end
    end
    return ok, result
end

DJWS.InventoryProviders['qb-inventory'] = {
    supports = { metadata = true, durability = true, weight = false },
    notes = 'CanAddItem is used when the export exists. Older qb-inventory builds fall back to Player.Functions.AddItem. Weight is enforced by that inventory, not by this resource.',
    CanCarry = function(src, item, count)
        if GetResourceState('qb-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['qb-inventory']:CanAddItem(src, item, count)
        end)
        return DJWS.InterpretCarry('qb-inventory', ok, result)
    end,
    Add = function(src, item, count, metadata)
        if GetResourceState('qb-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = add(src, item, count, metadata)
        return DJWS.InterpretAdd('qb-inventory', ok, result)
    end,
    Remove = function(src, item, count)
        if GetResourceState('qb-inventory') ~= 'started' then return false, 'inventory_stopped' end
        local ok, result = pcall(function()
            return exports['qb-inventory']:RemoveItem(src, item, count, false, 'dj-weaponstore')
        end)
        if not ok and GetResourceState('qb-core') == 'started' then
            local coreOk, qb = pcall(function() return exports['qb-core']:GetCoreObject() end)
            if coreOk and qb and qb.Functions then
                local player = qb.Functions.GetPlayer(src)
                if player and player.Functions and player.Functions.RemoveItem then
                    ok, result = pcall(function()
                        return player.Functions.RemoveItem(item, count)
                    end)
                end
            end
        end
        return DJWS.InterpretRemove('qb-inventory', ok, result)
    end,
    Count = function(src, item)
        if GetResourceState('qb-inventory') ~= 'started' then return 0 end
        local ok, result = pcall(function()
            return exports['qb-inventory']:GetItemByName(src, item)
        end)
        return DJWS.InterpretCount(ok, result)
    end,
}
