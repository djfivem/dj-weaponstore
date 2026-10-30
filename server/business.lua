Business = {}

function Business.Config(storeId)
    for i = 1, #Config.Stores do
        local store = Config.Stores[i]
        if store.id == storeId and store.enabled ~= false then
            return store
        end
    end
    return nil
end

function Business.Row(storeId)
    if not DB.ready() then return nil end
    return DB.single('SELECT * FROM dj_ws_stores WHERE id = ?', { storeId })
end

function Business.Settings(row, cfg)
    local settings = {
        taxPercent = math.floor(tonumber(Config.Payments.taxPercent) or 0),
        commissionPercent = math.floor(tonumber(Config.Payments.commissionPercent) or 0),
        directSales = Config.Payments.allowDirectManufacturingSales == true,
        licenseRequired = Config.Payments.license and Config.Payments.license.enabled == true or false,
        blip = not (cfg and cfg.blip and cfg.blip.enabled == false),
        jobRestrictions = {},
        label = cfg and cfg.label or storeIdFallback(row),
    }
    local baseJobs = Config.Payments.jobRestrictions or {}
    for i = 1, #baseJobs do
        if type(baseJobs[i]) == 'string' then
            settings.jobRestrictions[#settings.jobRestrictions + 1] = baseJobs[i]
        end
    end
    if row and type(row.settings) == 'string' and row.settings ~= '' then
        local ok, decoded = pcall(json.decode, row.settings)
        if ok and type(decoded) == 'table' then
            if decoded.taxPercent ~= nil then settings.taxPercent = math.floor(tonumber(decoded.taxPercent) or settings.taxPercent) end
            if decoded.commissionPercent ~= nil then settings.commissionPercent = math.floor(tonumber(decoded.commissionPercent) or settings.commissionPercent) end
            if decoded.directSales ~= nil then settings.directSales = decoded.directSales == true end
            if decoded.licenseRequired ~= nil then settings.licenseRequired = decoded.licenseRequired == true end
            if decoded.blip ~= nil then settings.blip = decoded.blip == true end
            if type(decoded.label) == 'string' and decoded.label ~= '' then settings.label = decoded.label:sub(1, 80) end
            if type(decoded.jobRestrictions) == 'table' then
                settings.jobRestrictions = {}
                for i = 1, math.min(#decoded.jobRestrictions, 12) do
                    local name = decoded.jobRestrictions[i]
                    if type(name) == 'string' and name:match('^[%w_]+$') then
                        settings.jobRestrictions[#settings.jobRestrictions + 1] = name
                    end
                end
            end
        end
    end
    settings.taxPercent = DJWS.Clamp(settings.taxPercent, 0, Config.Payments.maxTax or 25)
    settings.commissionPercent = DJWS.Clamp(settings.commissionPercent, 0, Config.Payments.maxCommission or 30)
    if not Config.Payments.allowDirectManufacturingSales then
        settings.directSales = false
    end
    return settings
end

function storeIdFallback(row)
    return (row and row.label) or 'DJ Weapon Store'
end

function Business.IsOwner(identifier, row)
    return identifier and row and row.owner_identifier == identifier
end

function Business.PermissionMap(storeId, identifier, row)
    local map = {}
    if not identifier then return map, false end
    if Business.IsOwner(identifier, row) then
        for i = 1, #DJWS.Permissions do
            map[DJWS.Permissions[i]] = true
        end
        return map, true
    end
    local rows = DB.query('SELECT permission FROM dj_ws_permissions WHERE store_id = ? AND identifier = ?', { storeId, identifier }) or {}
    for i = 1, #rows do
        if DJWS.PermissionSet[rows[i].permission] then
            map[rows[i].permission] = true
        end
    end
    return map, next(map) ~= nil
end

function Business.Has(src, storeId, permission)
    local identifier = Framework.GetIdentifier(src)
    if Framework.IsAdmin(src) then return true end
    local row = Business.Row(storeId)
    if not row or not identifier then return false end
    if Business.IsOwner(identifier, row) then return true end
    local found = DB.scalar(
        'SELECT permission FROM dj_ws_permissions WHERE store_id = ? AND identifier = ? AND permission = ? LIMIT 1',
        { storeId, identifier, permission }
    )
    return found ~= nil
end

function Business.AddBalance(storeId, amount, identifier, kind, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return false, 'bad_quantity' end
    local affected
    if amount > 0 then
        affected = DB.affected(DB.update('UPDATE dj_ws_stores SET balance = balance + ? WHERE id = ?', { amount, storeId }))
    else
        local take = math.abs(amount)
        affected = DB.affected(DB.update('UPDATE dj_ws_stores SET balance = balance - ? WHERE id = ? AND balance >= ?', { take, storeId, take }))
    end
    if affected < 1 then return false, 'insufficient_funds' end
    local row = Business.Row(storeId)
    local balance = row and tonumber(row.balance) or 0
    DB.insert('INSERT INTO dj_ws_transactions (store_id, identifier, kind, amount, balance_after, reason) VALUES (?, ?, ?, ?, ?, ?)', {
        storeId, identifier, kind or (amount > 0 and 'credit' or 'debit'), amount, balance, reason and tostring(reason):sub(1, 180) or nil,
    })
    return true, balance
end

function Business.SourceByIdentifier(identifier)
    if not identifier then return nil end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and Framework.GetIdentifier(src) == identifier then
            return src
        end
    end
    return nil
end

function Business.GetXp(identifier)
    return tonumber(DB.scalar('SELECT xp FROM dj_ws_xp WHERE identifier = ?', { identifier })) or 0
end

function Business.AddXp(identifier, amount)
    amount = math.floor(tonumber(amount) or 0)
    if not identifier or amount <= 0 then return end
    DB.update('INSERT INTO dj_ws_xp (identifier, xp) VALUES (?, ?) ON DUPLICATE KEY UPDATE xp = xp + VALUES(xp)', { identifier, amount })
end

function Business.Seed()
    for i = 1, #Config.Stores do
        local store = Config.Stores[i]
        if store.enabled ~= false then
            DB.update('INSERT IGNORE INTO dj_ws_stores (id, label, balance, commission_owed, manufactured, sold, settings) VALUES (?, ?, 0, 0, 0, 0, ?)', {
                store.id, store.label, '{}',
            })
            for material in pairs(Config.Materials) do
                DB.update('INSERT IGNORE INTO dj_ws_materials (store_id, item, count) VALUES (?, ?, 0)', { store.id, material })
            end
        end
    end
    local existing = {}
    local rows = DB.query('SELECT store_id, COUNT(*) AS total FROM dj_ws_benches GROUP BY store_id', {}) or {}
    for i = 1, #rows do
        existing[rows[i].store_id] = tonumber(rows[i].total) or 0
    end
    for i = 1, #Config.DefaultBenches do
        local bench = Config.DefaultBenches[i]
        local cfg = Business.Config(bench.store)
        if cfg and (existing[bench.store] or 0) == 0 then
            DB.insert([[INSERT INTO dj_ws_benches
                (store_id, label, bench_type, model, x, y, z, heading, z_offset, output_mode, jobs, min_grade, invisible, public_craft, created_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, 0, 0, 'seed')]], {
                bench.store, bench.label, bench.benchType, bench.model,
                bench.coords.x, bench.coords.y, bench.coords.z, bench.heading or 0.0,
                bench.output or 'stock', bench.jobs or '', bench.minGrade or 0,
            })
        end
    end
end

function Business.Dashboard(storeId, cfg, row)
    local stockRows = DB.query('SELECT catalog_id, count, price, manufactured, sold FROM dj_ws_stock WHERE store_id = ?', { storeId }) or {}
    local stockCount, stockValue = 0, 0
    for i = 1, #stockRows do
        local entry = DJWS.Get(stockRows[i].catalog_id)
        local count = tonumber(stockRows[i].count) or 0
        stockCount = stockCount + count
        if entry then
            local price = Stock.UnitPrice(entry, stockRows[i])
            stockValue = stockValue + (price * count)
        end
    end
    local employees = tonumber(DB.scalar('SELECT COUNT(*) FROM dj_ws_employees WHERE store_id = ?', { storeId })) or 0
    local tx = DB.query('SELECT id, kind, amount, reason, created_at FROM dj_ws_transactions WHERE store_id = ? ORDER BY id DESC LIMIT 8', { storeId }) or {}
    local crafts = DB.query('SELECT id, catalog_id, quantity, success, name, created_at FROM dj_ws_manufacturing WHERE store_id = ? ORDER BY id DESC LIMIT 8', { storeId }) or {}
    for i = 1, #crafts do
        local entry = DJWS.Get(crafts[i].catalog_id)
        crafts[i].label = entry and entry.label or crafts[i].catalog_id
        crafts[i].success = crafts[i].success == 1 or crafts[i].success == true
    end
    local salesToday = DB.single('SELECT COUNT(*) AS sales, COALESCE(SUM(total), 0) AS revenue FROM dj_ws_sales WHERE store_id = ? AND created_at >= CURDATE()', { storeId }) or {}
    return {
        balance = tonumber(row.balance) or 0,
        commissionOwed = tonumber(row.commission_owed) or 0,
        manufactured = tonumber(row.manufactured) or 0,
        sold = tonumber(row.sold) or 0,
        stockCount = stockCount,
        stockValue = stockValue,
        employees = employees,
        salesToday = tonumber(salesToday.sales) or 0,
        revenueToday = tonumber(salesToday.revenue) or 0,
        transactions = tx,
        crafts = crafts,
        label = (cfg and cfg.label) or row.label,
    }
end

function Business.SaveSettings(src, storeId, payload)
    local cfg = Business.Config(storeId)
    local row = Business.Row(storeId)
    if not cfg or not row then return DJWS.Fail('invalid_store') end
    if not Business.Has(src, storeId, 'settings') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'saveSettings') then return DJWS.Fail('too_far') end
    local current = Business.Settings(row, cfg)
    local nextSettings = {
        taxPercent = Security.Int(payload.taxPercent, 0, Config.Payments.maxTax or 25) or current.taxPercent,
        commissionPercent = Security.Int(payload.commissionPercent, 0, Config.Payments.maxCommission or 30) or current.commissionPercent,
        directSales = payload.directSales == true and Config.Payments.allowDirectManufacturingSales == true,
        licenseRequired = payload.licenseRequired == true,
        blip = payload.blip ~= false,
        label = Security.Text(payload.label, 80) or current.label,
        jobRestrictions = {},
    }
    if type(payload.jobRestrictions) == 'table' then
        for i = 1, math.min(#payload.jobRestrictions, 12) do
            local name = payload.jobRestrictions[i]
            if type(name) == 'string' and name:match('^[%w_]+$') then
                nextSettings.jobRestrictions[#nextSettings.jobRestrictions + 1] = name
            end
        end
    end
    local encoded = json.encode(nextSettings)
    DB.update('UPDATE dj_ws_stores SET label = ?, settings = ? WHERE id = ?', { nextSettings.label, encoded, storeId })
    local identifier = Framework.GetIdentifier(src)
    Logs.Audit(storeId, identifier, 'settings', nextSettings)
    Logs.Webhook('settings', 'Store settings updated', {
        { name = 'Store', value = storeId },
        { name = 'By', value = identifier or tostring(src) },
    })
    return DJWS.Ok({ message = L('saved'), settings = nextSettings })
end
