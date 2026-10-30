local function licenseOf(src)
    if GetPlayerIdentifierByType then
        local ok, id = pcall(function()
            return GetPlayerIdentifierByType(src, 'license')
        end)
        if ok and type(id) == 'string' and id ~= '' then return id end
    end
    local count = GetNumPlayerIdentifiers(src) or 0
    for i = 0, count - 1 do
        local id = GetPlayerIdentifier(src, i)
        if type(id) == 'string' and id:sub(1, 8) == 'license:' then
            return id
        end
    end
    return GetPlayerIdentifier(src, 0)
end

local function ensureWallet(identifier)
    if not DB or not DB.update then return false end
    DB.update(
        'INSERT IGNORE INTO dj_ws_wallets (identifier, cash, bank) VALUES (?, ?, ?)',
        { identifier, Config.Standalone.startingCash or 0, Config.Standalone.startingBank or 0 }
    )
    return true
end

local function balance(identifier, account)
    ensureWallet(identifier)
    local row = DB.single('SELECT cash, bank FROM dj_ws_wallets WHERE identifier = ?', { identifier })
    if not row then return 0 end
    return tonumber(row[account]) or 0
end

DJWS.FrameworkProviders.standalone = {
    GetIdentifier = function(src)
        return licenseOf(src)
    end,
    GetName = function(src)
        return GetPlayerName(src)
    end,
    GetJob = function()
        return { name = 'civilian', label = 'Civilian', grade = 0, gradeLabel = '', onduty = true }
    end,
    GetMoney = function(src, account)
        local identifier = licenseOf(src)
        if not identifier or not DB or not DB.ready or not DB.ready() then return 0 end
        return balance(identifier, account)
    end,
    AddMoney = function(src, account, amount)
        local identifier = licenseOf(src)
        if not identifier or not DB or not DB.ready or not DB.ready() then return false end
        ensureWallet(identifier)
        local column = account == 'bank' and 'bank' or 'cash'
        local affected = DB.affected(DB.update(('UPDATE dj_ws_wallets SET %s = %s + ? WHERE identifier = ?'):format(column, column), { amount, identifier }))
        return affected >= 1
    end,
    RemoveMoney = function(src, account, amount)
        local identifier = licenseOf(src)
        if not identifier or not DB or not DB.ready or not DB.ready() then return false end
        ensureWallet(identifier)
        local column = account == 'bank' and 'bank' or 'cash'
        local affected = DB.affected(DB.update(
            ('UPDATE dj_ws_wallets SET %s = %s - ? WHERE identifier = ? AND %s >= ?'):format(column, column, column),
            { amount, identifier, amount }
        ))
        return affected >= 1
    end,
    IsAdmin = function()
        return false
    end,
    HasLicense = function()
        return false
    end,
}
