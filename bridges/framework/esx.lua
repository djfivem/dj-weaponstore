local object

local function esx()
    if object then return object end
    if GetResourceState('es_extended') ~= 'started' then return nil end
    local p = promise.new()
    local settled = false
    TriggerEvent('esx:getSharedObject', function(obj)
        if settled then return end
        settled = true
        p:resolve(obj)
    end)
    SetTimeout(1500, function()
        if settled then return end
        settled = true
        p:resolve(nil)
    end)
    object = Citizen.Await(p)
    return object
end

local function xPlayer(src)
    local core = esx()
    if not core or not core.GetPlayerFromId then return nil end
    local ok, result = pcall(function()
        return core.GetPlayerFromId(src)
    end)
    if not ok then
        object = nil
        return nil
    end
    return result
end

local function balance(player, account)
    if account == 'cash' then
        local ok, money = pcall(function() return player.getMoney() end)
        if ok then return tonumber(money) or 0 end
        return 0
    end
    local ok, acc = pcall(function() return player.getAccount('bank') end)
    if ok and type(acc) == 'table' then return tonumber(acc.money) or 0 end
    return 0
end

DJWS.FrameworkProviders.esx = {
    GetIdentifier = function(src)
        local player = xPlayer(src)
        if not player then return nil end
        return player.identifier
    end,
    GetName = function(src)
        local player = xPlayer(src)
        if player and player.getName then
            local ok, name = pcall(function() return player.getName() end)
            if ok and type(name) == 'string' and name ~= '' then return name end
        end
        return GetPlayerName(src)
    end,
    GetJob = function(src)
        local player = xPlayer(src)
        local job = player and player.job or {}
        return {
            name = job.name or 'unemployed',
            label = job.label or job.name or 'Unemployed',
            grade = tonumber(job.grade) or 0,
            gradeLabel = job.grade_label or job.grade_name or '',
            onduty = true,
        }
    end,
    GetMoney = function(src, account)
        local player = xPlayer(src)
        if not player then return 0 end
        return balance(player, account)
    end,
    AddMoney = function(src, account, amount, reason)
        local player = xPlayer(src)
        if not player then return false end
        local before = balance(player, account)
        local ok
        if account == 'cash' then
            ok = pcall(function() player.addMoney(amount, reason or 'dj-weaponstore') end)
        else
            ok = pcall(function() player.addAccountMoney('bank', amount, reason or 'dj-weaponstore') end)
        end
        if not ok then return false end
        return balance(player, account) >= before + amount
    end,
    RemoveMoney = function(src, account, amount, reason)
        local player = xPlayer(src)
        if not player then return false end
        local before = balance(player, account)
        if before < amount then return false end
        local ok
        if account == 'cash' then
            ok = pcall(function() player.removeMoney(amount, reason or 'dj-weaponstore') end)
        else
            ok = pcall(function() player.removeAccountMoney('bank', amount, reason or 'dj-weaponstore') end)
        end
        if not ok then return false end
        return balance(player, account) <= before - amount
    end,
    IsAdmin = function(src)
        local player = xPlayer(src)
        if not player or not player.getGroup then return false end
        local ok, group = pcall(function() return player.getGroup() end)
        if not ok then return false end
        return group == 'admin' or group == 'superadmin'
    end,
    HasLicense = function(src, licenseType)
        local player = xPlayer(src)
        if not player or not player.identifier or not DB or not DB.single then return false end
        local row = DB.single('SELECT type FROM user_licenses WHERE owner = ? AND type = ? LIMIT 1', { player.identifier, licenseType })
        return type(row) == 'table'
    end,
}
