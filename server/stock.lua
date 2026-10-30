Stock = {}

function Stock.Rows(storeId)
    return DB.query('SELECT catalog_id, count, price, manufactured, sold FROM dj_ws_stock WHERE store_id = ?', { storeId }) or {}
end

function Stock.Map(storeId)
    local map = {}
    local rows = Stock.Rows(storeId)
    for i = 1, #rows do
        map[rows[i].catalog_id] = rows[i]
    end
    return map
end

function Stock.UnitPrice(entry, row)
    local spec = Pricing.For(entry)
    local price = spec.price
    if row and row.price ~= nil then
        local override = math.floor(tonumber(row.price) or price)
        price = override
    end
    return DJWS.Clamp(price, spec.min, spec.max), spec
end

function Stock.Reserve(storeId, catalogId, qty)
    return DB.affected(DB.update(
        'UPDATE dj_ws_stock SET count = count - ?, sold = sold + ? WHERE store_id = ? AND catalog_id = ? AND count >= ?',
        { qty, qty, storeId, catalogId, qty }
    )) >= 1
end

function Stock.Release(storeId, catalogId, qty)
    DB.update(
        'UPDATE dj_ws_stock SET count = count + ?, sold = GREATEST(sold - ?, 0) WHERE store_id = ? AND catalog_id = ?',
        { qty, qty, storeId, catalogId }
    )
end

function Stock.AddProduced(storeId, catalogId, qty)
    local row = DB.single('SELECT count FROM dj_ws_stock WHERE store_id = ? AND catalog_id = ?', { storeId, catalogId })
    local have = row and tonumber(row.count) or 0
    if have + qty > (Config.Stock.maxPerItem or 250) then return false end
    if not row then
        local id = DB.insert('INSERT INTO dj_ws_stock (store_id, catalog_id, count, manufactured, sold) VALUES (?, ?, ?, ?, 0)', {
            storeId, catalogId, qty, qty,
        })
        return type(id) == 'number' and id > 0
    end
    return DB.affected(DB.update(
        'UPDATE dj_ws_stock SET count = count + ?, manufactured = manufactured + ? WHERE store_id = ? AND catalog_id = ? AND count + ? <= ?',
        { qty, qty, storeId, catalogId, qty, Config.Stock.maxPerItem or 250 }
    )) >= 1
end

function Stock.SetPrice(src, storeId, payload)
    local cfg = Business.Config(storeId)
    if not cfg or not DB.ready() then return DJWS.Fail('database_unavailable') end
    if not Business.Has(src, storeId, 'prices') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'setPrice') then return DJWS.Fail('too_far') end
    local catalogId = Security.CatalogId(payload.catalogId)
    local entry = catalogId and DJWS.Get(catalogId)
    if not entry or entry.purchasable == false then return DJWS.Fail('invalid_item') end
    local spec = Pricing.For(entry)
    local price = Security.Int(payload.price, spec.min, math.min(spec.max, Config.Stock.maxPrice or spec.max))
    if not price then return DJWS.Fail('bad_price') end
    local existing = DB.scalar('SELECT id FROM dj_ws_stock WHERE store_id = ? AND catalog_id = ?', { storeId, catalogId })
    if existing then
        DB.update('UPDATE dj_ws_stock SET price = ? WHERE store_id = ? AND catalog_id = ?', { price, storeId, catalogId })
    else
        DB.insert('INSERT INTO dj_ws_stock (store_id, catalog_id, count, price, manufactured, sold) VALUES (?, ?, 0, ?, 0, 0)', {
            storeId, catalogId, price,
        })
    end
    Logs.Audit(storeId, Framework.GetIdentifier(src), 'price', { catalogId = catalogId, price = price })
    return DJWS.Ok({ message = L('price_updated') })
end

function Stock.Adjust(src, storeId, payload)
    local cfg = Business.Config(storeId)
    if not cfg or not DB.ready() then return DJWS.Fail('database_unavailable') end
    if not Business.Has(src, storeId, 'stock') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'adjustStock') then return DJWS.Fail('too_far') end
    local catalogId = Security.CatalogId(payload.catalogId)
    local entry = catalogId and DJWS.Get(catalogId)
    if not entry then return DJWS.Fail('invalid_item') end
    local delta = Security.Int(payload.delta, -(Config.Security.maxStockAdjust or 100), Config.Security.maxStockAdjust or 100)
    if not delta or delta == 0 then return DJWS.Fail('bad_quantity') end
    local ok, err = Security.WithStore(storeId, function()
        local row = DB.single('SELECT count FROM dj_ws_stock WHERE store_id = ? AND catalog_id = ?', { storeId, catalogId })
        local have = row and tonumber(row.count) or 0
        local nextCount = have + delta
        if nextCount < 0 or nextCount > (Config.Stock.maxPerItem or 250) then return false, 'capacity' end
        if not row then
            local id = DB.insert('INSERT INTO dj_ws_stock (store_id, catalog_id, count, manufactured, sold) VALUES (?, ?, ?, 0, 0)', {
                storeId, catalogId, nextCount,
            })
            return type(id) == 'number'
        end
        local affected = DB.affected(DB.update('UPDATE dj_ws_stock SET count = ? WHERE store_id = ? AND catalog_id = ?', {
            nextCount, storeId, catalogId,
        }))
        return affected >= 1
    end)
    if not ok then return DJWS.Fail(err or 'internal') end
    Logs.Audit(storeId, Framework.GetIdentifier(src), 'stock_adjust', { catalogId = catalogId, delta = delta })
    Logs.Webhook('stock', 'Stock adjusted', {
        { name = 'Store', value = storeId },
        { name = 'Catalog', value = catalogId },
        { name = 'Delta', value = tostring(delta) },
    })
    return DJWS.Ok({ message = L('stock_updated') })
end
