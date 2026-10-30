Sales = {}

local function restrictionsAllow(src, settings, entry)
    local restrictions = settings.jobRestrictions or {}
    if #restrictions > 0 then
        local job = Framework.GetJob(src)
        local allowed = false
        for i = 1, #restrictions do
            if restrictions[i] == job.name then allowed = true end
        end
        if not allowed then return false, 'job_restricted' end
    end
    if entry.requiredJob then
        local job = Framework.GetJob(src)
        if job.name ~= entry.requiredJob then return false, 'job_restricted' end
        if entry.requiredGrade and (job.grade or 0) < entry.requiredGrade then return false, 'grade_restricted' end
    end
    return true
end

local function hasLicense(src, settings)
    local required = settings.licenseRequired or (Config.Payments.license and Config.Payments.license.enabled)
    if not required then return true end
    local item = Config.Payments.license and Config.Payments.license.item
    if type(item) == 'string' and item ~= '' and Inventory.GetCount(src, item) > 0 then
        return true
    end
    local licenseType = (Config.Payments.license and Config.Payments.license.type) or 'weapon'
    return Framework.HasLicense(src, licenseType)
end

local function payCommission(storeId, row, amount)
    if amount <= 0 then return end
    local owner = row.owner_identifier
    local ownerSrc = owner and Business.SourceByIdentifier(owner) or nil
    if ownerSrc and Framework.AddMoney(ownerSrc, 'cash', amount, 'dj-weaponstore-commission') then
        return
    end
    DB.update('UPDATE dj_ws_stores SET commission_owed = commission_owed + ? WHERE id = ?', { amount, storeId })
end

function Sales.Purchase(src, payload)
    if not DB.ready() then return DJWS.Fail('database_unavailable') end
    local storeId = Security.Text(payload.storeId, 64)
    local cfg = storeId and Business.Config(storeId)
    local row = cfg and Business.Row(storeId)
    if not cfg or not row then return DJWS.Fail('invalid_store') end
    if not Security.Gate(src, cfg, 'purchase') then return DJWS.Fail('too_far') end
    local catalogId = Security.CatalogId(payload.catalogId)
    local entry = catalogId and DJWS.Get(catalogId)
    if not entry or entry.purchasable == false then return DJWS.Fail('invalid_item') end
    local qty = Security.Int(payload.quantity, 1, Config.Security.maxPurchaseQty or 10)
    if not qty then return DJWS.Fail('bad_quantity') end
    local account = payload.account
    if account ~= 'cash' and account ~= 'bank' then return DJWS.Fail('payment_failed') end
    if account == 'cash' and Config.Payments.allowCash == false then return DJWS.Fail('payment_failed') end
    if account == 'bank' and Config.Payments.allowBank == false then return DJWS.Fail('payment_failed') end
    local settings = Business.Settings(row, cfg)
    if not hasLicense(src, settings) then return DJWS.Fail('license_required') end
    local allowed, reason = restrictionsAllow(src, settings, entry)
    if not allowed then return DJWS.Fail(reason or 'job_restricted') end
    local identifier = Framework.GetIdentifier(src)
    if not identifier then return DJWS.Fail('player_offline') end

    local result, err = Security.WithStore(storeId, function()
        local stockRow = DB.single('SELECT count, price FROM dj_ws_stock WHERE store_id = ? AND catalog_id = ?', { storeId, catalogId })
        local unit = Stock.UnitPrice(entry, stockRow)
        local recipeRow = DB.single('SELECT data, enabled FROM dj_ws_recipes WHERE store_id = ? AND catalog_id = ?', { storeId, catalogId })
        local recipe = Recipes.For(entry, recipeRow)
        if qty % recipe.output ~= 0 then return false, 'bad_quantity' end
        local subtotal = unit * qty
        local tax = math.floor(subtotal * settings.taxPercent / 100)
        local commission = math.floor(subtotal * settings.commissionPercent / 100)
        local total = subtotal + tax
        local have = stockRow and tonumber(stockRow.count) or 0
        local direct = false
        local consumed = nil
        if have >= qty then
            if not Stock.Reserve(storeId, catalogId, qty) then return false, 'out_of_stock' end
        else
            if not (Config.Payments.allowDirectManufacturingSales and settings.directSales and recipe.enabled) then
                return false, 'out_of_stock'
            end
            local batches = qty / recipe.output
            consumed = Materials.Scale(recipe.materials, batches)
            if not Materials.Consume(storeId, consumed) then return false, 'out_of_stock' end
            direct = true
        end
        if not Framework.RemoveMoney(src, account, total, 'dj-weaponstore-purchase') then
            if direct then Materials.Refund(storeId, consumed) else Stock.Release(storeId, catalogId, qty) end
            return false, 'cannot_afford'
        end
        local given, giveErr = Crafting.Give(src, entry, qty, recipe.quality.max or 100, settings.label)
        if not given then
            if giveErr ~= 'partial_grant' then
                Framework.AddMoney(src, account, total, 'dj-weaponstore-refund')
                if direct then Materials.Refund(storeId, consumed) else Stock.Release(storeId, catalogId, qty) end
            else
                Logs.Audit(storeId, identifier, 'partial_grant', { catalogId = catalogId, quantity = qty })
            end
            return false, giveErr or 'add_failed'
        end
        local gain = subtotal - commission
        if Config.Payments.taxToBusiness then gain = gain + tax end
        if gain > 0 then
            local credited = Business.AddBalance(storeId, gain, identifier, 'sale', entry.label)
            if not credited then
                Logs.Audit(storeId, identifier, 'business_credit_failed', { amount = gain, catalogId = catalogId })
            end
        end
        payCommission(storeId, row, commission)
        DB.update('UPDATE dj_ws_stores SET sold = sold + ? WHERE id = ?', { qty, storeId })
        DB.insert([[INSERT INTO dj_ws_sales
            (store_id, catalog_id, buyer_identifier, buyer_name, seller_identifier, quantity, unit_price, tax, commission, total, payment, direct_sale)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            storeId, catalogId, identifier, Framework.GetName(src), row.owner_identifier, qty, unit, tax, commission, total, account, direct and 1 or 0,
        })
        return true, { total = total, unit = unit, tax = tax, commission = commission, direct = direct }
    end)

    if not result then return DJWS.Fail(err or 'payment_failed') end
    Logs.Audit(storeId, identifier, 'purchase', { catalogId = catalogId, quantity = qty, total = err.total })
    Logs.Webhook('purchase', 'Weapon sale', {
        { name = 'Store', value = storeId },
        { name = 'Item', value = entry.label },
        { name = 'Qty', value = tostring(qty) },
        { name = 'Total', value = tostring(err.total) },
        { name = 'Buyer', value = Framework.GetName(src) },
    })
    Framework.Notify(src, L('purchased'), 'success')
    return DJWS.Ok({ message = L('purchased'), total = err.total, unit = err.unit, tax = err.tax })
end

function Sales.Deposit(src, payload)
    if not DB.ready() then return DJWS.Fail('database_unavailable') end
    local storeId = Security.Text(payload.storeId, 64)
    local cfg = storeId and Business.Config(storeId)
    if not cfg then return DJWS.Fail('invalid_store') end
    if not Business.Has(src, storeId, 'deposit') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'depositAccount') then return DJWS.Fail('too_far') end
    local amount = Security.Int(payload.amount, 1, Config.Security.maxTransaction or 1000000)
    local account = payload.account == 'bank' and 'bank' or 'cash'
    if not amount then return DJWS.Fail('bad_quantity') end
    local identifier = Framework.GetIdentifier(src)
    if not Framework.RemoveMoney(src, account, amount, 'dj-weaponstore-deposit') then return DJWS.Fail('cannot_afford') end
    local ok, balance = Business.AddBalance(storeId, amount, identifier, 'deposit', 'business deposit')
    if not ok then
        Framework.AddMoney(src, account, amount, 'dj-weaponstore-deposit-refund')
        return DJWS.Fail('internal')
    end
    Logs.Audit(storeId, identifier, 'deposit', { amount = amount, account = account })
    Logs.Webhook('deposit', 'Business deposit', { { name = 'Store', value = storeId }, { name = 'Amount', value = tostring(amount) } })
    return DJWS.Ok({ message = L('deposited'), balance = balance })
end

function Sales.Withdraw(src, payload)
    if not DB.ready() then return DJWS.Fail('database_unavailable') end
    local storeId = Security.Text(payload.storeId, 64)
    local cfg = storeId and Business.Config(storeId)
    if not cfg then return DJWS.Fail('invalid_store') end
    if not Business.Has(src, storeId, 'withdraw') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'withdrawAccount') then return DJWS.Fail('too_far') end
    local amount = Security.Int(payload.amount, 1, Config.Security.maxTransaction or 1000000)
    local account = payload.account == 'bank' and 'bank' or 'cash'
    if not amount then return DJWS.Fail('bad_quantity') end
    local identifier = Framework.GetIdentifier(src)
    local ok, balanceOrErr = Business.AddBalance(storeId, -amount, identifier, 'withdraw', 'business withdraw')
    if not ok then return DJWS.Fail(balanceOrErr or 'insufficient_funds') end
    if not Framework.AddMoney(src, account, amount, 'dj-weaponstore-withdraw') then
        Business.AddBalance(storeId, amount, identifier, 'withdraw_refund', 'withdraw refund')
        return DJWS.Fail('payment_failed')
    end
    Logs.Audit(storeId, identifier, 'withdraw', { amount = amount, account = account })
    Logs.Webhook('withdraw', 'Business withdrawal', { { name = 'Store', value = storeId }, { name = 'Amount', value = tostring(amount) } })
    return DJWS.Ok({ message = L('withdrawn'), balance = Business.Row(storeId) and tonumber(Business.Row(storeId).balance) or 0 })
end

function Sales.Collect(src, payload)
    if not DB.ready() then return DJWS.Fail('database_unavailable') end
    local storeId = Security.Text(payload.storeId, 64)
    local cfg = storeId and Business.Config(storeId)
    local row = cfg and Business.Row(storeId)
    if not row then return DJWS.Fail('invalid_store') end
    if not Security.Gate(src, cfg, 'collectCommission') then return DJWS.Fail('too_far') end
    local identifier = Framework.GetIdentifier(src)
    if not Framework.IsAdmin(src) and not Business.IsOwner(identifier, row) then return DJWS.Fail('no_permission') end
    local owed = tonumber(row.commission_owed) or 0
    if owed < 1 then return DJWS.Fail('collect_empty') end
    local affected = DB.affected(DB.update('UPDATE dj_ws_stores SET commission_owed = 0 WHERE id = ? AND commission_owed = ?', { storeId, owed }))
    if affected < 1 then return DJWS.Fail('busy') end
    if not Framework.AddMoney(src, 'cash', owed, 'dj-weaponstore-commission') then
        DB.update('UPDATE dj_ws_stores SET commission_owed = commission_owed + ? WHERE id = ?', { owed, storeId })
        return DJWS.Fail('payment_failed')
    end
    Logs.Audit(storeId, identifier, 'commission', { amount = owed })
    return DJWS.Ok({ message = L('collected'), balance = tonumber(Business.Row(storeId).balance) or 0, commissionOwed = 0 })
end
