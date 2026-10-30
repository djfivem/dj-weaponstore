local function call(exportKey, ...)
    local conf = Config.CustomInventory or {}
    local resource = conf.resource
    local exportName = conf.exports and conf.exports[exportKey]
    if type(resource) ~= 'string' or resource == '' or type(exportName) ~= 'string' then
        return nil, false
    end
    if GetResourceState(resource) ~= 'started' then return nil, false end
    local args = { ... }
    local ok, result = pcall(function()
        return exports[resource][exportName](table.unpack(args))
    end)
    if not ok then
        DJWS.Debug(('Custom inventory %s failed: %s'):format(exportName, tostring(result)))
        return nil, false
    end
    return result, true
end

DJWS.InventoryProviders.custom = {
    supports = { metadata = true, durability = false, weight = false },
    notes = 'Calls only the exports named in Config.CustomInventory. Success requires a truthy return. Unconfigured exports fail closed.',
    CanCarry = function(src, item, count, metadata)
        local result, called = call('canCarry', src, item, count, metadata)
        if not called then return false, 'inventory_unavailable' end
        if result == true then return true end
        return false, 'inventory_full'
    end,
    Add = function(src, item, count, metadata)
        local result, called = call('addItem', src, item, count, metadata)
        if not called then return false, 'inventory_unavailable' end
        if result == true or type(result) == 'number' or type(result) == 'table' then return true, result end
        return false, 'add_failed'
    end,
    Remove = function(src, item, count, metadata)
        local result, called = call('removeItem', src, item, count, metadata)
        if not called then return false, 'inventory_unavailable' end
        return result == true
    end,
    Count = function(src, item)
        local result, called = call('getCount', src, item)
        if not called then return 0 end
        return DJWS.InterpretCount(true, result)
    end,
}
