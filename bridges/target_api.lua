Target = { zones = {}, entities = {} }

local function provider()
    DJWS.RefreshBridges()
    local name = DJWS.Bridge.target
    if name == 'fallback' then return nil end
    return DJWS.TargetProviders[name]
end

function Target.UsingTarget()
    DJWS.RefreshBridges()
    return DJWS.Bridge.target ~= 'fallback' and DJWS.TargetProviders[DJWS.Bridge.target] ~= nil and DJWS.Bridge.target ~= nil
end

function Target.AddEntity(entity, option)
    local impl = provider()
    if not impl or not impl.AddEntity then return false end
    local ok, err = pcall(impl.AddEntity, entity, option)
    if not ok then
        DJWS.Debug('Target entity failed: ' .. tostring(err))
        return false
    end
    Target.entities[option.name] = entity
    return true
end

function Target.RemoveEntity(entity, optionName)
    local impl = provider()
    if impl and impl.RemoveEntity and entity then
        pcall(impl.RemoveEntity, entity, optionName)
    end
    if optionName then Target.entities[optionName] = nil end
end

function Target.AddZone(option)
    local impl = provider()
    if not impl or not impl.AddZone then return nil end
    local ok, zoneId = pcall(impl.AddZone, option)
    if not ok then
        DJWS.Debug('Target zone failed: ' .. tostring(zoneId))
        return nil
    end
    Target.zones[option.name] = zoneId or option.name
    return Target.zones[option.name]
end

function Target.RemoveZone(name)
    local impl = provider()
    local zoneId = Target.zones[name]
    if impl and impl.RemoveZone and zoneId then
        pcall(impl.RemoveZone, zoneId)
    end
    Target.zones[name] = nil
end

function Target.Clear()
    for name, entity in pairs(Target.entities) do
        Target.RemoveEntity(entity, name)
    end
    for name in pairs(Target.zones) do
        Target.RemoveZone(name)
    end
end
