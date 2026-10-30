function Recipes.LoadMap(storeId)
    local rows = DB.query('SELECT catalog_id, data, enabled FROM dj_ws_recipes WHERE store_id = ?', { storeId }) or {}
    local map = {}
    for i = 1, #rows do
        map[rows[i].catalog_id] = rows[i]
    end
    return map
end

function Recipes.For(entry, row)
    local recipe = Recipes.Default(entry)
    if row and type(row.data) == 'string' and row.data ~= '' then
        local ok, decoded = pcall(json.decode, row.data)
        if ok and type(decoded) == 'table' then
            if type(decoded.materials) == 'table' then
                local materials = DJWS.CopyList(decoded.materials)
                if #materials > 0 then recipe.materials = materials end
            end
            if decoded.time then recipe.time = math.floor(tonumber(decoded.time) or recipe.time) end
            if decoded.xp then recipe.xp = math.floor(tonumber(decoded.xp) or recipe.xp) end
            if decoded.difficulty then recipe.difficulty = math.floor(tonumber(decoded.difficulty) or recipe.difficulty) end
            if decoded.unlockXp then recipe.unlockXp = math.floor(tonumber(decoded.unlockXp) or 0) end
            if decoded.output then recipe.output = math.floor(tonumber(decoded.output) or recipe.output) end
            if type(decoded.bench) == 'string' then recipe.bench = decoded.bench end
        end
    end
    if row and (row.enabled == 0 or row.enabled == false) then
        recipe.enabled = false
    end
    recipe.time = DJWS.Clamp(recipe.time, 1, 900)
    recipe.xp = DJWS.Clamp(recipe.xp, 0, 500)
    recipe.difficulty = DJWS.Clamp(recipe.difficulty, 1, 5)
    recipe.unlockXp = math.max(0, math.floor(tonumber(recipe.unlockXp) or 0))
    recipe.output = math.max(1, math.floor(tonumber(recipe.output) or 1))
    if entry.craftable == false then recipe.enabled = false end
    return recipe
end

function Recipes.Validate(payload, entry)
    if type(payload) ~= 'table' or type(payload.materials) ~= 'table' then return nil end
    if #payload.materials < 1 or #payload.materials > 12 then return nil end
    local materials, seen = {}, {}
    for i = 1, #payload.materials do
        local row = payload.materials[i]
        local item = type(row) == 'table' and row.item or nil
        local count = math.floor(tonumber(type(row) == 'table' and row.count or nil) or 0)
        if type(item) ~= 'string' or not Config.Materials[item] or seen[item] or count < 1 or count > 500 then
            return nil
        end
        seen[item] = true
        materials[#materials + 1] = { item = item, count = count }
    end
    local time = math.floor(tonumber(payload.time) or 0)
    local xp = math.floor(tonumber(payload.xp) or 0)
    local difficulty = math.floor(tonumber(payload.difficulty) or 0)
    local unlockXp = math.floor(tonumber(payload.unlockXp) or 0)
    local output = math.floor(tonumber(payload.output) or (entry.kind == 'ammo' and (Config.Ammo.batch or 30) or 1))
    if time < 5 or time > 900 or xp < 0 or xp > 500 or difficulty < 1 or difficulty > 5 then return nil end
    if unlockXp < 0 or unlockXp > 100000 or output < 1 or output > 500 then return nil end
    local bench = payload.bench
    if type(bench) ~= 'string' or not Config.Benches.types[bench] then return nil end
    if not Recipes.BenchAllows(bench, entry) and bench ~= 'general' then return nil end
    return {
        materials = materials,
        time = time,
        xp = xp,
        difficulty = difficulty,
        unlockXp = unlockXp,
        output = output,
        bench = bench,
        enabled = payload.enabled ~= false,
    }
end

function Recipes.Get(src, storeId, payload)
    local cfg = Business.Config(storeId)
    if not cfg or not DB.ready() then return DJWS.Fail('database_unavailable') end
    if not Business.Has(src, storeId, 'recipes') and not Business.Has(src, storeId, 'manufacture') then
        return DJWS.Fail('no_permission')
    end
    local catalogId = Security.CatalogId(payload.catalogId)
    local entry = catalogId and DJWS.Get(catalogId)
    if not entry then return DJWS.Fail('invalid_item') end
    local row = DB.single('SELECT data, enabled FROM dj_ws_recipes WHERE store_id = ? AND catalog_id = ?', { storeId, catalogId })
    local recipe = Recipes.For(entry, row)
    recipe.label = entry.label
    recipe.category = entry.category
    recipe.family = entry.family
    return DJWS.Ok({ recipe = recipe })
end

function Recipes.Save(src, storeId, payload)
    local cfg = Business.Config(storeId)
    if not cfg or not DB.ready() then return DJWS.Fail('database_unavailable') end
    if not Business.Has(src, storeId, 'recipes') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'saveRecipe') then return DJWS.Fail('too_far') end
    local catalogId = Security.CatalogId(payload.catalogId)
    local entry = catalogId and DJWS.Get(catalogId)
    if not entry or entry.craftable == false then return DJWS.Fail('invalid_item') end
    local recipe = Recipes.Validate(payload, entry)
    if not recipe then return DJWS.Fail('bad_quantity') end
    local encoded = json.encode(recipe)
    local enabled = recipe.enabled and 1 or 0
    local identifier = Framework.GetIdentifier(src)
    local existing = DB.scalar('SELECT id FROM dj_ws_recipes WHERE store_id = ? AND catalog_id = ?', { storeId, catalogId })
    if existing then
        DB.update('UPDATE dj_ws_recipes SET data = ?, enabled = ?, updated_by = ? WHERE store_id = ? AND catalog_id = ?', {
            encoded, enabled, identifier, storeId, catalogId,
        })
    else
        DB.insert('INSERT INTO dj_ws_recipes (store_id, catalog_id, data, enabled, updated_by) VALUES (?, ?, ?, ?, ?)', {
            storeId, catalogId, encoded, enabled, identifier,
        })
    end
    Logs.Audit(storeId, identifier, 'recipe', { catalogId = catalogId })
    Logs.Webhook('recipe', 'Recipe updated', {
        { name = 'Store', value = storeId },
        { name = 'Weapon', value = entry.label },
    })
    return DJWS.Ok({ message = L('saved'), recipe = recipe })
end

function Recipes.Reset(src, storeId, payload)
    local cfg = Business.Config(storeId)
    if not cfg or not DB.ready() then return DJWS.Fail('database_unavailable') end
    if not Business.Has(src, storeId, 'recipes') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'resetRecipe') then return DJWS.Fail('too_far') end
    local catalogId = Security.CatalogId(payload.catalogId)
    local entry = catalogId and DJWS.Get(catalogId)
    if not entry then return DJWS.Fail('invalid_item') end
    DB.update('DELETE FROM dj_ws_recipes WHERE store_id = ? AND catalog_id = ?', { storeId, catalogId })
    Logs.Audit(storeId, Framework.GetIdentifier(src), 'recipe_reset', { catalogId = catalogId })
    return DJWS.Ok({ message = L('saved'), recipe = Recipes.For(entry, nil) })
end
