Materials = {}

function Materials.Scale(list, qty)
    local out = {}
    qty = math.floor(qty)
    for i = 1, #list do
        out[#out + 1] = { item = list[i].item, count = list[i].count * qty }
    end
    return out
end

function Materials.List(storeId)
    local rows = DB.query('SELECT item, count FROM dj_ws_materials WHERE store_id = ?', { storeId }) or {}
    local map = {}
    for i = 1, #rows do
        map[rows[i].item] = tonumber(rows[i].count) or 0
    end
    local list = {}
    for key, def in pairs(Config.Materials) do
        list[#list + 1] = {
            item = key,
            label = def.label,
            category = def.category,
            price = def.price,
            weight = def.weight,
            count = map[key] or 0,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

function Materials.Total(storeId)
    return tonumber(DB.scalar('SELECT COALESCE(SUM(count), 0) FROM dj_ws_materials WHERE store_id = ?', { storeId })) or 0
end

function Materials.Log(storeId, identifier, item, delta, reason)
    DB.insert('INSERT INTO dj_ws_material_log (store_id, identifier, item, delta, reason) VALUES (?, ?, ?, ?, ?)', {
        storeId, identifier, item, delta, reason,
    })
end

function Materials.Refund(storeId, list)
    for i = 1, #(list or {}) do
        local row = list[i]
        if row and row.item and row.count and row.count > 0 and Config.Materials[row.item] then
            DB.update([[INSERT INTO dj_ws_materials (store_id, item, count) VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE count = count + VALUES(count)]], { storeId, row.item, row.count })
        end
    end
end

function Materials.Consume(storeId, list)
    local removed = {}
    for i = 1, #list do
        local row = list[i]
        if not Config.Materials[row.item] or row.count < 1 then
            Materials.Refund(storeId, removed)
            return false
        end
        local affected = DB.affected(DB.update(
            'UPDATE dj_ws_materials SET count = count - ? WHERE store_id = ? AND item = ? AND count >= ?',
            { row.count, storeId, row.item, row.count }
        ))
        if affected < 1 then
            Materials.Refund(storeId, removed)
            return false
        end
        removed[#removed + 1] = { item = row.item, count = row.count }
    end
    return true, removed
end

function Materials.Add(storeId, item, count, capacity)
    if not Config.Materials[item] or count < 1 then return false end
    local total = Materials.Total(storeId)
    if total + count > capacity then return false end
    local affected = DB.affected(DB.update([[INSERT INTO dj_ws_materials (store_id, item, count) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE count = count + VALUES(count)]], { storeId, item, count }))
    return affected >= 1
end

function Materials.ConsumePlayer(src, list)
    local inventory = Inventory.Name()
    for i = 1, #list do
        local item = DJWS.MaterialItem(list[i].item, inventory)
        if Inventory.GetCount(src, item) < list[i].count then
            return false
        end
    end
    local removed = {}
    for i = 1, #list do
        local item = DJWS.MaterialItem(list[i].item, inventory)
        local ok = Inventory.Remove(src, item, list[i].count)
        if not ok then
            for j = 1, #removed do
                Inventory.Add(src, DJWS.MaterialItem(removed[j].item, inventory), removed[j].count, nil)
            end
            return false
        end
        removed[#removed + 1] = list[i]
    end
    return true
end

function Materials.RefundPlayer(src, list)
    if not src or not GetPlayerName(src) then return false end
    local inventory = Inventory.Name()
    for i = 1, #(list or {}) do
        local item = DJWS.MaterialItem(list[i].item, inventory)
        local added = Inventory.Add(src, item, list[i].count, nil)
        if not added then return false end
    end
    return true
end

local function move(src, storeId, payload, direction)
    local cfg = Business.Config(storeId)
    if not cfg or not DB.ready() then return DJWS.Fail('database_unavailable') end
    if not Business.Has(src, storeId, 'materials') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, direction == 'deposit' and 'depositMaterial' or 'withdrawMaterial') then
        return DJWS.Fail('too_far')
    end
    local item = payload.item
    if type(item) ~= 'string' or not Config.Materials[item] then return DJWS.Fail('invalid_item') end
    local count = Security.Int(payload.count, 1, Config.Security.maxMaterialMove or 500)
    if not count then return DJWS.Fail('bad_quantity') end
    local ok, err = Security.WithStore(storeId, function()
        local identifier = Framework.GetIdentifier(src)
        local inventory = Inventory.Name()
        local mapped = DJWS.MaterialItem(item, inventory)
        if direction == 'deposit' then
            if Inventory.GetCount(src, mapped) < count then return false, 'missing_materials' end
            if Materials.Total(storeId) + count > (cfg.materialCapacity or 5000) then return false, 'capacity' end
            if not Inventory.Remove(src, mapped, count) then return false, 'remove_failed' end
            if not Materials.Add(storeId, item, count, cfg.materialCapacity or 5000) then
                Inventory.Add(src, mapped, count, nil)
                return false, 'capacity'
            end
            Materials.Log(storeId, identifier, item, count, 'deposit')
            return true
        end
        local have = tonumber(DB.scalar('SELECT count FROM dj_ws_materials WHERE store_id = ? AND item = ?', { storeId, item })) or 0
        if have < count then return false, 'missing_materials' end
        local canCarry = Inventory.CanCarry(src, mapped, count, nil)
        if not canCarry then return false, 'inventory_full' end
        local affected = DB.affected(DB.update(
            'UPDATE dj_ws_materials SET count = count - ? WHERE store_id = ? AND item = ? AND count >= ?',
            { count, storeId, item, count }
        ))
        if affected < 1 then return false, 'missing_materials' end
        if not Inventory.Add(src, mapped, count, nil) then
            Materials.Add(storeId, item, count, cfg.materialCapacity or 999999)
            return false, 'add_failed'
        end
        Materials.Log(storeId, identifier, item, -count, 'withdraw')
        return true
    end)
    if not ok then return DJWS.Fail(err or 'internal') end
    return DJWS.Ok({
        message = direction == 'deposit' and L('deposited') or L('withdrawn'),
        materials = Materials.List(storeId),
    })
end

function Materials.Deposit(src, storeId, payload)
    return move(src, storeId, payload, 'deposit')
end

function Materials.Withdraw(src, storeId, payload)
    return move(src, storeId, payload, 'withdraw')
end

function Materials.BuySupply(src, storeId, payload)
    local cfg = Business.Config(storeId)
    if not cfg or not DB.ready() then return DJWS.Fail('database_unavailable') end
    if not Business.Has(src, storeId, 'materials') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'buySupply') then return DJWS.Fail('too_far') end
    local supplierId = Security.Text(payload.supplier, 40)
    local item = payload.item
    local count = Security.Int(payload.count, 1, Config.Security.maxMaterialMove or 500)
    if not supplierId or type(item) ~= 'string' or not Config.Materials[item] or not count then
        return DJWS.Fail('invalid_item')
    end
    local supplier
    for i = 1, #Config.Suppliers do
        if Config.Suppliers[i].id == supplierId then supplier = Config.Suppliers[i] end
    end
    if not supplier then return DJWS.Fail('invalid_item') end
    local category = Config.Materials[item].category
    if not supplier.categories or not supplier.categories[category] then return DJWS.Fail('invalid_item') end
    local cost = math.floor((tonumber(Config.Materials[item].price) or 0) * count)
    if cost < 1 then return DJWS.Fail('bad_price') end
    local ok, err = Security.WithStore(storeId, function()
        local paid, reason = Business.AddBalance(storeId, -cost, Framework.GetIdentifier(src), 'supply', supplier.label)
        if not paid then return false, reason or 'insufficient_funds' end
        if not Materials.Add(storeId, item, count, cfg.materialCapacity or 5000) then
            Business.AddBalance(storeId, cost, Framework.GetIdentifier(src), 'supply_refund', 'capacity refund')
            return false, 'capacity'
        end
        Materials.Log(storeId, Framework.GetIdentifier(src), item, count, 'supply')
        return true
    end)
    if not ok then return DJWS.Fail(err or 'internal') end
    local row = Business.Row(storeId)
    Logs.Webhook('stock', 'Supplier restock', {
        { name = 'Store', value = storeId },
        { name = 'Item', value = item },
        { name = 'Count', value = tostring(count) },
        { name = 'Cost', value = tostring(cost) },
    })
    return DJWS.Ok({
        message = L('supplied'),
        materials = Materials.List(storeId),
        balance = row and tonumber(row.balance) or 0,
    })
end
