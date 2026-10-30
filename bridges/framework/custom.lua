local function cfg()
    return Config.CustomFramework or {}
end

local function call(exportKey, ...)
    local conf = cfg()
    local resource = conf.resource
    local exportName = conf.exports and conf.exports[exportKey]
    if type(resource) ~= 'string' or resource == '' or type(exportName) ~= 'string' or exportName == '' then
        return nil, false
    end
    if GetResourceState(resource) ~= 'started' then return nil, false end
    local args = { ... }
    local ok, result = pcall(function()
        return exports[resource][exportName](table.unpack(args))
    end)
    if not ok then
        DJWS.Debug(('Custom framework export %s failed: %s'):format(exportName, tostring(result)))
        return nil, false
    end
    return result, true
end

DJWS.FrameworkProviders.custom = {
    GetIdentifier = function(src)
        local result, called = call('getIdentifier', src)
        if called and type(result) == 'string' and result ~= '' then return result end
        return nil
    end,
    GetName = function(src)
        local result, called = call('getName', src)
        if called and type(result) == 'string' and result ~= '' then return result end
        return GetPlayerName(src)
    end,
    GetJob = function(src)
        local result, called = call('getJob', src)
        if called and type(result) == 'table' then
            return {
                name = result.name or 'unemployed',
                label = result.label or result.name or 'Unemployed',
                grade = tonumber(result.grade) or 0,
                gradeLabel = result.gradeLabel or '',
                onduty = result.onduty ~= false,
            }
        end
        return { name = 'unemployed', label = 'Unemployed', grade = 0, onduty = true }
    end,
    GetMoney = function(src, account)
        local result, called = call('getMoney', src, account)
        if called and type(result) == 'number' then return result end
        return 0
    end,
    AddMoney = function(src, account, amount, reason)
        local result, called = call('addMoney', src, account, amount, reason or 'dj-weaponstore')
        return called and result == true
    end,
    RemoveMoney = function(src, account, amount, reason)
        local result, called = call('removeMoney', src, account, amount, reason or 'dj-weaponstore')
        return called and result == true
    end,
    IsAdmin = function(src)
        local result, called = call('isAdmin', src)
        return called and result == true
    end,
    HasLicense = function(src, licenseType)
        local result, called = call('hasLicense', src, licenseType)
        return called and result == true
    end,
}
