Framework = {}

local moneyLock = {}

local function impl()
    DJWS.RefreshBridges()
    return DJWS.FrameworkProviders[DJWS.Bridge.framework]
end

local function call(method, ...)
    local provider = impl()
    if not provider or not provider[method] then return nil end
    local ok, a, b = pcall(provider[method], ...)
    if not ok then
        DJWS.Debug(('Framework %s %s failed: %s'):format(tostring(DJWS.Bridge.framework), method, tostring(a)))
        if Config.Framework == 'auto' and DJWS.Bridge.framework == 'esx_legacy' and DJWS.FrameworkProviders.esx then
            DJWS.Bridge.framework = 'esx'
            local ok2, c = pcall(DJWS.FrameworkProviders.esx[method], ...)
            if ok2 then return c end
        end
        return nil
    end
    return a, b
end

function Framework.Name()
    DJWS.RefreshBridges()
    return DJWS.Bridge.framework
end

function Framework.GetIdentifier(src)
    local result = call('GetIdentifier', src)
    if type(result) == 'string' and result ~= '' then return result end
    return nil
end

function Framework.GetName(src)
    local result = call('GetName', src)
    if type(result) == 'string' and result ~= '' then return result end
    return GetPlayerName(src) or ('player ' .. tostring(src))
end

function Framework.GetJob(src)
    local result = call('GetJob', src)
    if type(result) ~= 'table' then
        return { name = 'unemployed', label = 'Unemployed', grade = 0, gradeLabel = '', onduty = true }
    end
    result.grade = tonumber(result.grade) or 0
    result.name = result.name or 'unemployed'
    result.label = result.label or result.name
    if result.onduty == nil then result.onduty = true end
    return result
end

function Framework.GetMoney(src, account)
    if account ~= 'cash' and account ~= 'bank' then return 0 end
    return tonumber(call('GetMoney', src, account)) or 0
end

function Framework.AddMoney(src, account, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or (account ~= 'cash' and account ~= 'bank') then return false end
    if moneyLock[src] then return false end
    moneyLock[src] = true
    local result = call('AddMoney', src, account, amount, reason)
    moneyLock[src] = nil
    return result == true
end

function Framework.RemoveMoney(src, account, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or (account ~= 'cash' and account ~= 'bank') then return false end
    if moneyLock[src] then return false end
    moneyLock[src] = true
    local result = call('RemoveMoney', src, account, amount, reason)
    moneyLock[src] = nil
    return result == true
end

function Framework.IsAdmin(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, Config.Admin.ace) then return true end
    if Config.Admin.allowCommandAce and IsPlayerAceAllowed(src, 'command') then return true end
    if Config.Admin.useFrameworkAdmin then
        return call('IsAdmin', src) == true
    end
    return false
end

function Framework.HasLicense(src, licenseType)
    if type(licenseType) ~= 'string' or licenseType == '' then return false end
    return call('HasLicense', src, licenseType) == true
end

function Framework.Notify(src, message, ntype)
    if Notify and Notify.Send then
        Notify.Send(src, message, ntype)
    end
end

AddEventHandler('playerDropped', function()
    moneyLock[source] = nil
end)
