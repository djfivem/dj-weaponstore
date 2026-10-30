local function projectEntry(entry, stockRow, recipe, staff, inventoryName)
    local price, spec = Stock.UnitPrice(entry, stockRow)
    local row = {
        id = entry.id,
        item = entry.item,
        label = entry.label,
        description = entry.description,
        category = entry.category,
        family = entry.family,
        kind = entry.kind,
        ammo = entry.ammo,
        bench = entry.bench,
        craftable = entry.craftable == true,
        purchasable = entry.purchasable == true,
        requiredJob = entry.requiredJob,
        image = DJWS.Image(entry, inventoryName),
        stock = stockRow and tonumber(stockRow.count) or 0,
        price = price,
    }
    if recipe then
        row.time = recipe.time
        row.xp = recipe.xp
        row.difficulty = recipe.difficulty
        row.output = recipe.output
        row.enabled = recipe.enabled
        row.unlockXp = recipe.unlockXp
        row.materials = recipe.materials
        row.recipeBench = recipe.bench
    end
    if not staff then return row end
    row.minPrice = spec.min
    row.maxPrice = spec.max
    row.weight = entry.weight
    row.degrade = entry.degrade
    row.attachType = entry.attachType
    row.componentCount = entry.components and #entry.components or 0
    row.throwable = entry.throwable == true
    row.locked = entry.locked == true
    if stockRow then
        row.manufactured = tonumber(stockRow.manufactured) or 0
        row.sold = tonumber(stockRow.sold) or 0
        row.priceOverride = stockRow.price ~= nil and tonumber(stockRow.price) or nil
    end
    return row
end

local function buildState(src, payload)
    if not DB.ready() then
        return DJWS.Ok({
            database = false,
            message = L('database_banner'),
            brand = Config.Brand,
            resource = Config.ResourceName,
            categories = DJWS.Categories,
            catalog = {},
            mode = 'customer',
            perms = {},
        })
    end
    local storeId = Security.Text(payload.storeId, 64)
    local cfg = storeId and Business.Config(storeId)
    if not cfg then return DJWS.Fail('invalid_store') end
    if not Security.CanOpen(src, cfg) then return DJWS.Fail('too_far') end
    local row = Business.Row(storeId)
    if not row then return DJWS.Fail('database_unavailable') end
    local identifier = Framework.GetIdentifier(src)
    local admin = Framework.IsAdmin(src)
    local owner = Business.IsOwner(identifier, row)
    local perms = {}
    if admin or owner then
        for i = 1, #DJWS.Permissions do perms[DJWS.Permissions[i]] = true end
    elseif identifier then
        perms = Business.PermissionMap(storeId, identifier, row)
    end
    local staff = admin or owner or next(perms) ~= nil
    local settings = Business.Settings(row, cfg)
    local stockMap = Stock.Map(storeId)
    local focusBench = nil
    if payload.benchId then
        local bench = Benches.Get(payload.benchId)
        if bench and bench.storeId == storeId and Security.NearCoords(src, bench.coords, (Config.Security.benchDistance or 2.4) + 0.8) then
            focusBench = bench
        end
    end
    local publicBench = focusBench and focusBench.publicCraft == true
    local recipeMap = (staff or publicBench or settings.directSales) and Recipes.LoadMap(storeId) or {}
    local inventoryName = Inventory.Name()
    local catalog = {}
    for i = 1, #DJWS.List do
        local entry = DJWS.List[i]
        local stockRow = stockMap[entry.id]
        local visible = true
        if entry.craftable == false and not Config.Catalog.showUncraftable then
            visible = false
        end
        local benchCraft = visible and publicBench and entry.craftable ~= false and Recipes.BenchAllows(focusBench.benchType, entry)
        if visible and not staff and not benchCraft then
            local count = stockRow and tonumber(stockRow.count) or 0
            local onShelf = entry.purchasable ~= false and count > 0
            local canDirect = settings.directSales and entry.purchasable ~= false and entry.craftable ~= false
            if not onShelf and not canDirect then visible = false end
        end
        if visible then
            local recipe = nil
            if staff or benchCraft then
                recipe = Recipes.For(entry, recipeMap[entry.id])
            elseif settings.directSales and entry.craftable ~= false and entry.purchasable ~= false then
                local full = Recipes.For(entry, recipeMap[entry.id])
                recipe = {
                    time = full.time,
                    xp = full.xp,
                    difficulty = full.difficulty,
                    output = full.output,
                    enabled = full.enabled,
                    unlockXp = full.unlockXp,
                }
            end
            catalog[#catalog + 1] = projectEntry(entry, stockRow, recipe, staff, inventoryName)
        end
    end
    local storeList = {}
    for i = 1, #Config.Stores do
        local store = Config.Stores[i]
        if store.enabled ~= false and Security.CanOpen(src, store) then
            storeList[#storeList + 1] = { id = store.id, label = store.label }
        end
    end
    local response = {
        database = true,
        brand = Config.Brand,
        resource = Config.ResourceName,
        serverNow = os.time(),
        store = {
            id = cfg.id,
            label = settings.label,
            balance = (staff and (perms.dashboard or perms.withdraw or perms.deposit or owner or admin)) and (tonumber(row.balance) or 0) or nil,
            remote = not Security.InStore(src, cfg),
        },
        stores = storeList,
        mode = staff and 'staff' or 'customer',
        admin = admin,
        owner = owner,
        perms = perms,
        permissions = DJWS.Permissions,
        grades = Config.Grades,
        categories = DJWS.Categories,
        catalog = catalog,
        focus = payload.focus or (focusBench and 'bench' or 'catalog'),
        bench = focusBench,
        publicCraft = focusBench and focusBench.publicCraft or false,
        benches = staff and (perms.benches or perms.manufacture or admin or owner) and Benches.ForStore(storeId) or (focusBench and { focusBench } or {}),
        craft = Crafting.Current(src),
        payments = {
            cash = Config.Payments.allowCash ~= false,
            bank = Config.Payments.allowBank ~= false,
            tax = settings.taxPercent,
            commission = settings.commissionPercent,
            direct = settings.directSales,
            license = settings.licenseRequired,
        },
        limits = {
            craft = Config.Security.maxCraftQty,
            purchase = Config.Security.maxPurchaseQty,
            material = Config.Security.maxMaterialMove,
            transaction = Config.Security.maxTransaction,
            stock = Config.Stock.maxPerItem,
        },
        models = Config.Benches.defaults,
        modelList = {},
    }
    for model in pairs(Config.Benches.models) do
        response.modelList[#response.modelList + 1] = model
    end
    table.sort(response.modelList)
    if staff and (perms.materials or perms.manufacture or owner or admin) then
        response.materials = Materials.List(storeId)
        response.suppliers = {}
        for i = 1, #Config.Suppliers do
            local supplier = Config.Suppliers[i]
            local categories = {}
            for name in pairs(supplier.categories or {}) do categories[#categories + 1] = name end
            response.suppliers[#response.suppliers + 1] = { id = supplier.id, label = supplier.label, categories = categories }
        end
        response.materialCapacity = cfg.materialCapacity
    end
    if staff and (perms.dashboard or owner or admin) then
        response.dashboard = Business.Dashboard(storeId, cfg, row)
    end
    if staff and (perms.hire or perms.fire or perms.permissions or owner or admin) then
        response.employees = Employees.List(storeId)
    end
    if staff and (perms.settings or perms.benches or owner or admin) then
        response.settings = settings
    end
    if staff and (perms.recipes or perms.manufacture or owner or admin) then
        response.recipeSets = Config.RecipeSets
        response.materialCatalog = {}
        for key, def in pairs(Config.Materials) do
            response.materialCatalog[#response.materialCatalog + 1] = { item = key, label = def.label }
        end
        table.sort(response.materialCatalog, function(a, b) return a.label < b.label end)
    end
    return DJWS.Ok(response)
end

local function like(value)
    local text = Security.Text(value, 40)
    if not text then return nil end
    text = text:gsub('\\', '\\\\'):gsub('%%', '\\%%'):gsub('_', '\\_')
    return '%' .. text .. '%'
end

local function history(src, payload)
    if not DB.ready() then return DJWS.Fail('database_unavailable') end
    local storeId = Security.Text(payload.storeId, 64)
    local cfg = storeId and Business.Config(storeId)
    if not cfg then return DJWS.Fail('invalid_store') end
    if not Security.Gate(src, cfg, 'getHistory') then return DJWS.Fail('too_far') end
    local kind = payload.kind
        local page = Security.Int(payload.page, 0, 40) or 0
        local offset = math.floor(page * 25)
    local query = like(payload.query)
    if kind == 'sales' then
        if not Business.Has(src, storeId, 'reports') then return DJWS.Fail('no_permission') end
        local rows
        if query then
            rows = DB.query([[SELECT id, catalog_id, buyer_name, quantity, unit_price, tax, commission, total, payment, direct_sale, created_at
                FROM dj_ws_sales WHERE store_id = ? AND (catalog_id LIKE ? OR buyer_name LIKE ?)
                ORDER BY id DESC LIMIT 25 OFFSET ]] .. offset, { storeId, query, query })
        else
            rows = DB.query([[SELECT id, catalog_id, buyer_name, quantity, unit_price, tax, commission, total, payment, direct_sale, created_at
                FROM dj_ws_sales WHERE store_id = ? ORDER BY id DESC LIMIT 25 OFFSET ]] .. offset, { storeId })
        end
        rows = rows or {}
        for i = 1, #rows do
            local entry = DJWS.Get(rows[i].catalog_id)
            rows[i].label = entry and entry.label or rows[i].catalog_id
        end
        return DJWS.Ok({ rows = rows })
    end
    if kind == 'manufacturing' then
        if not Business.Has(src, storeId, 'reports') then return DJWS.Fail('no_permission') end
        local rows = DB.query([[SELECT id, catalog_id, name, quantity, quality, duration, success, output_mode, created_at
            FROM dj_ws_manufacturing WHERE store_id = ? ORDER BY id DESC LIMIT 25 OFFSET ]] .. offset, { storeId }) or {}
        for i = 1, #rows do
            local entry = DJWS.Get(rows[i].catalog_id)
            rows[i].label = entry and entry.label or rows[i].catalog_id
            rows[i].success = rows[i].success == 1 or rows[i].success == true
        end
        return DJWS.Ok({ rows = rows })
    end
    if kind == 'transactions' then
        if not Business.Has(src, storeId, 'withdraw') and not Business.Has(src, storeId, 'deposit') and not Business.Has(src, storeId, 'dashboard') and not Business.Has(src, storeId, 'reports') then
            return DJWS.Fail('no_permission')
        end
        local rows = DB.query('SELECT id, kind, amount, balance_after, reason, created_at FROM dj_ws_transactions WHERE store_id = ? ORDER BY id DESC LIMIT 25 OFFSET ' .. offset, { storeId }) or {}
        return DJWS.Ok({ rows = rows })
    end
    if kind == 'materials' then
        if not Business.Has(src, storeId, 'materials') then return DJWS.Fail('no_permission') end
        local rows = DB.query('SELECT id, item, delta, reason, created_at FROM dj_ws_material_log WHERE store_id = ? ORDER BY id DESC LIMIT 25 OFFSET ' .. offset, { storeId }) or {}
        return DJWS.Ok({ rows = rows })
    end
    return DJWS.Fail('unknown_action')
end

Callback.Register('getState', function(src, payload)
    return buildState(src, payload or {})
end)

Callback.Register('getBenches', function()
    return DJWS.Ok({ benches = Benches.Cache or {} })
end)

Callback.Register('purchase', function(src, payload)
    return Sales.Purchase(src, payload)
end)

Callback.Register('startCraft', function(src, payload)
    return Crafting.Start(src, payload)
end)

Callback.Register('submitSkill', function(src, payload)
    return Crafting.SubmitSkill(src, payload)
end)

Callback.Register('cancelCraft', function(src, payload)
    return Crafting.Cancel(src, payload)
end)

Callback.Register('depositMaterial', function(src, payload)
    return Materials.Deposit(src, payload.storeId, payload)
end)

Callback.Register('withdrawMaterial', function(src, payload)
    return Materials.Withdraw(src, payload.storeId, payload)
end)

Callback.Register('buySupply', function(src, payload)
    return Materials.BuySupply(src, payload.storeId, payload)
end)

Callback.Register('setPrice', function(src, payload)
    return Stock.SetPrice(src, payload.storeId, payload)
end)

Callback.Register('adjustStock', function(src, payload)
    return Stock.Adjust(src, payload.storeId, payload)
end)

Callback.Register('hire', function(src, payload)
    return Employees.Hire(src, payload.storeId, payload)
end)

Callback.Register('fire', function(src, payload)
    return Employees.Fire(src, payload.storeId, payload)
end)

Callback.Register('setGrade', function(src, payload)
    return Employees.SetGrade(src, payload.storeId, payload)
end)

Callback.Register('setPermissions', function(src, payload)
    return Employees.SetPermissions(src, payload.storeId, payload)
end)

Callback.Register('getRecipe', function(src, payload)
    return Recipes.Get(src, payload.storeId, payload)
end)

Callback.Register('saveRecipe', function(src, payload)
    return Recipes.Save(src, payload.storeId, payload)
end)

Callback.Register('resetRecipe', function(src, payload)
    return Recipes.Reset(src, payload.storeId, payload)
end)

Callback.Register('depositAccount', function(src, payload)
    return Sales.Deposit(src, payload)
end)

Callback.Register('withdrawAccount', function(src, payload)
    return Sales.Withdraw(src, payload)
end)

Callback.Register('collectCommission', function(src, payload)
    return Sales.Collect(src, payload)
end)

Callback.Register('saveSettings', function(src, payload)
    return Business.SaveSettings(src, payload.storeId, payload)
end)

Callback.Register('saveBench', function(src, payload)
    return Benches.Save(src, payload)
end)

Callback.Register('deleteBench', function(src, payload)
    return Benches.Delete(src, payload)
end)

Callback.Register('getHistory', function(src, payload)
    return history(src, payload)
end)
