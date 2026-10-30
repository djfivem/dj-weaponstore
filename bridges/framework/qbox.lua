local function player(src)
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    local ok, result = pcall(function()
        return exports.qbx_core:GetPlayer(src)
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

local function moneyExport(method, src, account, amount, reason)
    if GetResourceState('qbx_core') ~= 'started' then return nil, false end
    local ok, result = pcall(function()
        return exports.qbx_core[method](src, account, amount, reason or 'dj-weaponstore')
    end)
    if not ok then return nil, false end
    return result, true
end

DJWS.FrameworkProviders.qbox = {
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
        if p and p.PlayerData and p.PlayerData.money then
            return tonumber(p.PlayerData.money[account]) or 0
        end
        local result, called = moneyExport('GetMoney', src, account)
        if called and type(result) == 'number' then return result end
        return 0
    end,
    AddMoney = function(src, account, amount, reason)
        local p = player(src)
        local before = p and p.PlayerData and p.PlayerData.money and tonumber(p.PlayerData.money[account]) or nil
        if p and p.Functions and p.Functions.AddMoney then
            local ok, result = pcall(function()
                return p.Functions.AddMoney(account, amount, reason or 'dj-weaponstore')
            end)
            if ok and result ~= false then
                local refreshed = player(src)
                local after = refreshed and refreshed.PlayerData and refreshed.PlayerData.money and tonumber(refreshed.PlayerData.money[account])
                if before and type(after) == 'number' then return after >= before + amount end
                return result == true or type(after) == 'number'
            end
        end
        local result, called = moneyExport('AddMoney', src, account, amount, reason)
        if not called or result ~= true then return false end
        return true
    end,
    RemoveMoney = function(src, account, amount, reason)
        local p = player(src)
        local before = p and p.PlayerData and p.PlayerData.money and tonumber(p.PlayerData.money[account]) or 0
        if before < amount then return false end
        if p and p.Functions and p.Functions.RemoveMoney then
            local ok, result = pcall(function()
                return p.Functions.RemoveMoney(account, amount, reason or 'dj-weaponstore')
            end)
            if ok and result ~= false then
                local refreshed = player(src)
                local after = refreshed and refreshed.PlayerData and refreshed.PlayerData.money and tonumber(refreshed.PlayerData.money[account])
                if type(after) == 'number' then return after <= before - amount end
                return result == true
            end
        end
        local result, called = moneyExport('RemoveMoney', src, account, amount, reason)
        return called and result == true
    end,
    IsAdmin = function(src)
        if GetResourceState('qbx_core') ~= 'started' then return false end
        local ok, result = pcall(function()
            return exports.qbx_core:HasPermission(src, 'admin')
        end)
        if ok and result == true then return true end
        local okGod, god = pcall(function()
            return exports.qbx_core:HasPermission(src, 'god')
        end)
        return okGod and god == true
    end,
    HasLicense = function(src, licenseType)
        local p = player(src)
        local md = p and p.PlayerData and p.PlayerData.metadata or {}
        local licences = md.licences or md.licenses or {}
        return licences[licenseType] == true
    end,
}
