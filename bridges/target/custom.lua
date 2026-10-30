local function call(exportKey, ...)
    local conf = Config.CustomTarget or {}
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
        DJWS.Debug(('Custom target %s failed: %s'):format(exportName, tostring(result)))
        return nil, false
    end
    return result, true
end

DJWS.TargetProviders.custom = {
    AddEntity = function(entity, option)
        local _, called = call('addEntity', entity, option)
        if not called then error('custom target addEntity failed') end
    end,
    RemoveEntity = function(entity, optionName)
        call('removeEntity', entity, optionName)
    end,
    AddZone = function(option)
        local result, called = call('addZone', option)
        if not called then error('custom target addZone failed') end
        return result or option.name
    end,
    RemoveZone = function(zoneId)
        call('removeZone', zoneId)
    end,
}
