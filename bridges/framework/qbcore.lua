local function core()
    if GetResourceState('qb-core') ~= 'started' then return nil end
    local ok, obj = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok then return obj end
    return nil
end

local function player(src)
    local qb = core()
    if not qb or not qb.Functions then return nil end
    local ok, result = pcall(function()
        return qb.Functions.GetPlayer(src)
    end)
    if ok then return result end
    return nil
end

local function jobOf(data)
    local job = data or {}
    local grade = job.grade
    local level, gradeLabel = 0, ''
    if type(grade) == 'table' then
        level = tonumber(grade.level) or 0
        gradeLabel = grade.name or grade.label or ''
    else
        level = tonumber(grade) or 0
    end
    return {
        name = job.name or 'unemployed',
        label = job.label or job.name or 'Unemployed',
        grade = level,
        gradeLabel = gradeLabel,
        onduty = job.onduty ~= false,
    }
end

DJWS.FrameworkProviders.qbcore = {
    GetIdentifier = function(src)
        local p = player(src)
        if not p or not p.PlayerData then return nil end
        return p.PlayerData.citizenid
    end,
    GetName = function(src)
        local p = player(src)
        local info = p and p.PlayerData and p.PlayerData.charinfo or {}
        local name = ((info.firstname or '') .. ' ' .. (info.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        if name == '' then return GetPlayerName(src) end
        return name
    end,
    GetJob = function(src)
        local p = player(src)
        if not p or not p.PlayerData then return { name = 'unemployed', label = 'Unemployed', grade = 0, onduty = true } end
        return jobOf(p.PlayerData.job)
    end,
    GetMoney = function(src, account)
        local p = player(src)
        if not p or not p.PlayerData or not p.PlayerData.money then return 0 end
        return tonumber(p.PlayerData.money[account]) or 0
    end,
    AddMoney = function(src, account, amount, reason)
        local p = player(src)
        if not p or not p.Functions or not p.Functions.AddMoney then return false end
        local before = tonumber(p.PlayerData.money and p.PlayerData.money[account]) or 0
        local ok, result = pcall(function()
            return p.Functions.AddMoney(account, amount, reason or 'dj-weaponstore')
        end)
        if not ok or result == false then return false end
        local refreshed = player(src)
        local after = refreshed and refreshed.PlayerData and refreshed.PlayerData.money and tonumber(refreshed.PlayerData.money[account])
        if type(after) == 'number' then return after >= before + amount end
        return result == true
    end,
    RemoveMoney = function(src, account, amount, reason)
        local p = player(src)
        if not p or not p.Functions or not p.Functions.RemoveMoney then return false end
        local before = tonumber(p.PlayerData.money and p.PlayerData.money[account]) or 0
        if before < amount then return false end
        local ok, result = pcall(function()
            return p.Functions.RemoveMoney(account, amount, reason or 'dj-weaponstore')
        end)
        if not ok or result == false then return false end
        local refreshed = player(src)
        local after = refreshed and refreshed.PlayerData and refreshed.PlayerData.money and tonumber(refreshed.PlayerData.money[account])
        if type(after) == 'number' then return after <= before - amount end
        return result == true
    end,
    IsAdmin = function(src)
        local qb = core()
        if not qb or not qb.Functions or not qb.Functions.HasPermission then return false end
        local ok, admin = pcall(function()
            return qb.Functions.HasPermission(src, 'admin')
        end)
        local okGod, god = pcall(function()
            return qb.Functions.HasPermission(src, 'god')
        end)
        return (ok and admin == true) or (okGod and god == true)
    end,
    HasLicense = function(src, licenseType)
        local p = player(src)
        local md = p and p.PlayerData and p.PlayerData.metadata or {}
        local licences = md.licences or md.licenses or {}
        return licences[licenseType] == true
    end,
}
