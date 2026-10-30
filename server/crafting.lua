Crafting = {
    Active = {},
    ByPlayer = {},
    ByBench = {},
}

local function chanceFor(difficulty)
    local level = DJWS.Clamp(math.floor(tonumber(difficulty) or 1), 1, 5)
    return 100 - ((level - 1) * 12)
end

local function metadataFor(entry, quality, storeLabel)
    local supports = Inventory.Supports()
    if not supports.metadata then return nil end
    local data = {
        durability = quality,
        quality = quality,
        serial = DJWS.Serial(),
        crafted = storeLabel,
    }
    if entry.kind == 'weapon' then
        data.ammo = 0
        data.components = {}
        if entry.ammo then data.ammoName = entry.ammo end
        if entry.degrade then data.degrade = entry.degrade end
        if entry.model then data.model = entry.model end
        if entry.throwable then data.throwable = true end
    elseif entry.kind == 'attachment' then
        data.attachType = entry.attachType
        data.components = entry.components or {}
        if entry.usetime then data.usetime = entry.usetime end
    end
    return data
end

function Crafting.Give(src, entry, count, quality, storeLabel)
    local item = Inventory.Item(entry.id)
    if not item or count < 1 then return false, 'invalid_item' end
    if entry.kind == 'ammo' then
        if not Inventory.CanCarry(src, item, count, nil) then return false, 'inventory_full' end
        if not Inventory.Add(src, item, count, nil) then return false, 'add_failed' end
        return true
    end
    local sample = metadataFor(entry, quality, storeLabel)
    if not Inventory.CanCarry(src, item, count, sample) then return false, 'inventory_full' end
    local granted = 0
    for _ = 1, count do
        local added = Inventory.Add(src, item, 1, metadataFor(entry, quality, storeLabel))
        if not added then
            local removed = 0
            for _index = 1, granted do
                if Inventory.Remove(src, item, 1) then removed = removed + 1 end
            end
            if removed ~= granted then
                return false, 'partial_grant'
            end
            return false, 'add_failed'
        end
        granted = granted + 1
    end
    return true
end

local function persist(craft)
    local encoded = json.encode(craft.materials or {})
    local existing = DB.scalar('SELECT token FROM dj_ws_active_crafts WHERE token = ?', { craft.token })
    if existing then
        DB.update([[UPDATE dj_ws_active_crafts SET paid = ?, started_at = ?, ends_at = ?, status = ?, quality = ? WHERE token = ?]], {
            craft.paid and 1 or 0, craft.startedAt or 0, craft.endsAt or 0, craft.status, craft.quality or 0, craft.token,
        })
        return true
    end
    local id = DB.insert([[INSERT INTO dj_ws_active_crafts
        (token, store_id, bench_id, identifier, catalog_id, quantity, materials, output_mode, quality, paid, started_at, ends_at, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        craft.token, craft.storeId, craft.benchId, craft.identifier, craft.catalogId, craft.quantity, encoded,
        craft.output, craft.quality or 0, craft.paid and 1 or 0, craft.startedAt or 0, craft.endsAt or 0, craft.status,
    })
    return type(id) == 'string' or type(id) == 'number'
end

function Crafting.Clear(token)
    local craft = Crafting.Active[token]
    if not craft then return end
    Crafting.Active[token] = nil
    if craft.src and Crafting.ByPlayer[craft.src] == token then Crafting.ByPlayer[craft.src] = nil end
    if craft.benchId and Crafting.ByBench[craft.benchId] == token then Crafting.ByBench[craft.benchId] = nil end
    if DB.ready() then
        DB.update('DELETE FROM dj_ws_active_crafts WHERE token = ?', { token })
    end
end

function Crafting.Refund(craft, percent)
    percent = percent or 100
    local list = {}
    for i = 1, #(craft.materials or {}) do
        local count = math.floor((craft.materials[i].count * percent) / 100)
        if count > 0 then
            list[#list + 1] = { item = craft.materials[i].item, count = count }
        end
    end
    if #list == 0 then return true end
    if craft.output == 'stock' then
        Materials.Refund(craft.storeId, list)
        return true
    end
    if craft.src and GetPlayerName(craft.src) and Materials.RefundPlayer(craft.src, list) then
        return true
    end
    Logs.Audit(craft.storeId, craft.identifier, 'refund_pending', { token = craft.token, materials = list })
    Logs.Webhook('craft', 'Material refund needs a manual return', {
        { name = 'Store', value = craft.storeId },
        { name = 'Player', value = craft.identifier or '?' },
        { name = 'Token', value = craft.token },
    })
    return false
end

local function payloadFor(craft, phase, message)
    return {
        token = craft.token,
        phase = phase,
        label = craft.label,
        endsAt = craft.endsAt,
        serverNow = os.time(),
        message = message,
        quantity = craft.quantity,
        benchType = craft.benchType,
    }
end

local function beginRun(craft, skipRoll)
    local paidOk, payErr = Security.WithStore(craft.storeId, function()
        if craft.output == 'stock' then
            local consumed = Materials.Consume(craft.storeId, craft.materials)
            if not consumed then return false, 'missing_materials' end
            return true
        end
        if not Materials.ConsumePlayer(craft.src, craft.materials) then return false, 'missing_materials' end
        return true
    end)
    if not paidOk then
        Crafting.Clear(craft.token)
        return DJWS.Fail(payErr or 'missing_materials')
    end
    craft.paid = true
    craft.skipRoll = skipRoll == true
    craft.status = 'running'
    craft.startedAt = os.time()
    craft.endsAt = craft.startedAt + craft.duration
    persist(craft)
    TriggerClientEvent(DJWS.Events.craft, craft.src, payloadFor(craft, 'running', L('craft_started')))
    Framework.Notify(craft.src, L('craft_started'), 'inform')
    return DJWS.Ok({ message = L('craft_started'), craft = payloadFor(craft, 'running') })
end

function Crafting.Start(src, payload)
    if not DB.ready() then return DJWS.Fail('database_unavailable') end
    if Crafting.ByPlayer[src] then return DJWS.Fail('already_crafting') end
    local storeId = Security.Text(payload.storeId, 64)
    local cfg = storeId and Business.Config(storeId)
    if not cfg then return DJWS.Fail('invalid_store') end
    local bench = Benches.Get(payload.benchId)
    if not bench or bench.storeId ~= storeId then return DJWS.Fail('invalid_bench') end
    if not Security.NearCoords(src, bench.coords, Config.Security.benchDistance or 2.4) then return DJWS.Fail('too_far') end
    if not Benches.JobOk(src, bench) then return DJWS.Fail('job_restricted') end
    if Crafting.ByBench[bench.id] then return DJWS.Fail('bench_busy') end
    local catalogId = Security.CatalogId(payload.catalogId)
    local entry = catalogId and DJWS.Get(catalogId)
    if not entry or entry.craftable == false then return DJWS.Fail('invalid_item') end
    if entry.requiredJob then
        local job = Framework.GetJob(src)
        if job.name ~= entry.requiredJob then return DJWS.Fail('job_restricted') end
    end
    local staff = Business.Has(src, storeId, 'manufacture')
    if bench.output == 'stock' then
        if not staff then return DJWS.Fail('no_permission') end
    elseif not bench.publicCraft and not staff then
        return DJWS.Fail('no_permission')
    end
    if not Recipes.BenchAllows(bench.benchType, entry) then return DJWS.Fail('invalid_bench') end
    local qty = Security.Int(payload.quantity, 1, Config.Security.maxCraftQty or 5)
    if not qty then return DJWS.Fail('bad_quantity') end
    local row = DB.single('SELECT data, enabled FROM dj_ws_recipes WHERE store_id = ? AND catalog_id = ?', { storeId, catalogId })
    local recipe = Recipes.For(entry, row)
    if not recipe.enabled then return DJWS.Fail('recipe_disabled') end
    local identifier = Framework.GetIdentifier(src)
    if not identifier then return DJWS.Fail('player_offline') end
    if recipe.unlockXp > 0 and Business.GetXp(identifier) < recipe.unlockXp then return DJWS.Fail('locked') end
    local produced = recipe.output * qty
    if bench.output == 'stock' then
        local have = tonumber(DB.scalar('SELECT count FROM dj_ws_stock WHERE store_id = ? AND catalog_id = ?', { storeId, catalogId })) or 0
        if have + produced > (Config.Stock.maxPerItem or 250) then return DJWS.Fail('capacity') end
    end
    local token = ('%s-%s-%s'):format(src, os.time(), math.random(100000, 999999))
    Crafting.ByPlayer[src] = token
    Crafting.ByBench[bench.id] = token
    local quality = math.random(recipe.quality.min or 70, recipe.quality.max or 100)
    local craft = {
        token = token,
        src = src,
        identifier = identifier,
        name = Framework.GetName(src),
        storeId = storeId,
        benchId = bench.id,
        catalogId = catalogId,
        label = entry.label,
        quantity = qty,
        produced = produced,
        materials = Materials.Scale(recipe.materials, qty),
        output = bench.output,
        recipe = recipe,
        quality = quality,
        duration = recipe.time * qty,
        benchType = bench.benchType,
        status = 'reserved',
        paid = false,
        expires = os.time() + 30,
        storeLabel = cfg.label,
    }
    Crafting.Active[token] = craft
    if not persist(craft) then
        Crafting.Clear(token)
        return DJWS.Fail('database_unavailable')
    end
    if Config.Crafting.skillCheck and Config.Crafting.skillCheck.enabled then
        return DJWS.Ok({
            needSkill = true,
            token = token,
            difficulty = recipe.difficulty,
            message = L('craft_started'),
        })
    end
    return beginRun(craft, false)
end

function Crafting.SubmitSkill(src, payload)
    local token = Security.Text(payload.token, 64)
    local craft = token and Crafting.Active[token]
    if not craft or craft.src ~= src or craft.status ~= 'reserved' then return DJWS.Fail('invalid_item') end
    if payload.passed == false and payload.unavailable ~= true then
        Crafting.Clear(token)
        return DJWS.Fail('skill_failed')
    end
    local trust = Config.Security.trustClientSkillCheck == true and payload.passed == true and payload.unavailable ~= true
    return beginRun(craft, trust)
end

function Crafting.Cancel(src, payload)
    if not Config.Crafting.allowCancel then return DJWS.Fail('cancel_locked') end
    local token = Security.Text(payload and payload.token, 64) or Crafting.ByPlayer[src]
    local craft = token and Crafting.Active[token]
    if not craft or craft.src ~= src or craft.finished then return DJWS.Fail('invalid_item') end
    if craft.status ~= 'reserved' then
        local lockout = Config.Security.cancelLockoutSeconds or 5
        if craft.endsAt and (craft.endsAt - os.time()) <= lockout then
            return DJWS.Fail('cancel_locked')
        end
    end
    craft.finished = true
    if craft.status == 'reserved' then
        Crafting.Clear(token)
        return DJWS.Ok({ message = L('craft_cancelled') })
    end
    if craft.paid then Crafting.Refund(craft, 100) end
    Logs.Audit(craft.storeId, craft.identifier, 'craft_cancel', { catalogId = craft.catalogId, token = token })
    Crafting.Clear(token)
    TriggerClientEvent(DJWS.Events.craft, src, { phase = 'cancelled', message = L('craft_cancelled') })
    return DJWS.Ok({ message = L('craft_cancelled') })
end

local function history(craft, success)
    DB.insert([[INSERT INTO dj_ws_manufacturing
        (store_id, bench_id, catalog_id, identifier, name, quantity, quality, duration, success, output_mode, materials)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        craft.storeId, craft.benchId, craft.catalogId, craft.identifier, craft.name, craft.produced,
        success and craft.quality or 0, craft.duration, success and 1 or 0, craft.output, json.encode(craft.materials or {}),
    })
end

function Crafting.Complete(token)
    local craft = Crafting.Active[token]
    if not craft or craft.finished or craft.status ~= 'running' then return end
    craft.finished = true
    local entry = DJWS.Get(craft.catalogId)
    if not entry then
        if craft.paid then Crafting.Refund(craft, 100) end
        Crafting.Clear(token)
        return
    end
    local roll = craft.skipRoll or (math.random(1, 100) <= chanceFor(craft.recipe.difficulty))
    if not roll then
        local percent = Config.Security.failRefundPercent or 100
        if craft.paid then Crafting.Refund(craft, percent) end
        history(craft, false)
        Logs.Audit(craft.storeId, craft.identifier, 'craft_failed', { catalogId = craft.catalogId })
        Logs.Webhook('craft', 'Manufacturing failed', {
            { name = 'Store', value = craft.storeId },
            { name = 'Item', value = craft.label },
            { name = 'Player', value = craft.name or craft.identifier },
        })
        if craft.src and GetPlayerName(craft.src) then
            TriggerClientEvent(DJWS.Events.craft, craft.src, { phase = 'failed', message = L('craft_failed') })
            Framework.Notify(craft.src, L('craft_failed'), 'error')
        end
        Crafting.Clear(token)
        return
    end
    local ok, err = Security.WithStore(craft.storeId, function()
        if craft.output == 'stock' then
            if not Stock.AddProduced(craft.storeId, craft.catalogId, craft.produced) then
                return false, 'capacity'
            end
            return true
        end
        if not craft.src or not GetPlayerName(craft.src) then return false, 'player_offline' end
        local given, giveErr = Crafting.Give(craft.src, entry, craft.produced, craft.quality, craft.storeLabel)
        if not given then return false, giveErr or 'add_failed' end
        return true
    end)
    if not ok then
        if craft.paid and err ~= 'partial_grant' then Crafting.Refund(craft, 100) end
        history(craft, false)
        Logs.Audit(craft.storeId, craft.identifier, 'craft_failed', { catalogId = craft.catalogId, error = err })
        if craft.src and GetPlayerName(craft.src) then
            Framework.Notify(craft.src, L(err or 'craft_failed'), 'error')
            TriggerClientEvent(DJWS.Events.craft, craft.src, { phase = 'failed', message = L(err or 'craft_failed') })
        end
        Crafting.Clear(token)
        return
    end
    DB.update('UPDATE dj_ws_stores SET manufactured = manufactured + ? WHERE id = ?', { craft.produced, craft.storeId })
    Business.AddXp(craft.identifier, (craft.recipe.xp or 0) * craft.quantity)
    history(craft, true)
    for i = 1, #craft.materials do
        Materials.Log(craft.storeId, craft.identifier, craft.materials[i].item, -craft.materials[i].count, 'craft')
    end
    Logs.Audit(craft.storeId, craft.identifier, 'craft_success', { catalogId = craft.catalogId, quantity = craft.produced, quality = craft.quality })
    Logs.Webhook('craft', 'Manufacturing complete', {
        { name = 'Store', value = craft.storeId },
        { name = 'Item', value = craft.label },
        { name = 'Qty', value = tostring(craft.produced) },
        { name = 'Quality', value = tostring(craft.quality) },
    })
    if craft.src and GetPlayerName(craft.src) then
        Framework.Notify(craft.src, L('craft_success'), 'success')
        TriggerClientEvent(DJWS.Events.craft, craft.src, { phase = 'done', message = L('craft_success'), catalogId = craft.catalogId })
    end
    Crafting.Clear(token)
end

function Crafting.OnDrop(src)
    local token = Crafting.ByPlayer[src]
    if not token then return end
    local craft = Crafting.Active[token]
    if craft and craft.paid and not craft.finished then
        Crafting.Refund(craft, 100)
        Logs.Audit(craft.storeId, craft.identifier, 'craft_drop', { token = token })
    end
    Crafting.Clear(token)
end

function Crafting.Recover()
    local rows = DB.query('SELECT * FROM dj_ws_active_crafts', {}) or {}
    for i = 1, #rows do
        local row = rows[i]
        if tonumber(row.paid) == 1 then
            local mats = {}
            local decodedOk, decoded = pcall(json.decode, row.materials or '[]')
            if decodedOk and type(decoded) == 'table' then mats = decoded end
            local craft = {
                token = row.token,
                storeId = row.store_id,
                identifier = row.identifier,
                output = row.output_mode,
                materials = mats,
                src = nil,
            }
            Crafting.Refund(craft, 100)
        end
        DB.update('DELETE FROM dj_ws_active_crafts WHERE token = ?', { row.token })
    end
end

function Crafting.StartScheduler()
    CreateThread(function()
        while true do
            local any = false
            local now = os.time()
            local due = {}
            for token, craft in pairs(Crafting.Active) do
                any = true
                if craft.status == 'reserved' and craft.expires and now >= craft.expires then
                    due[#due + 1] = { token = token, kind = 'expire' }
                elseif craft.status == 'running' and craft.endsAt and now >= craft.endsAt then
                    due[#due + 1] = { token = token, kind = 'complete' }
                end
            end
            for i = 1, #due do
                if due[i].kind == 'expire' then
                    local craft = Crafting.Active[due[i].token]
                    if craft and craft.status == 'reserved' then
                        Crafting.Clear(due[i].token)
                    end
                else
                    Crafting.Complete(due[i].token)
                end
            end
            Wait(any and 500 or 1000)
        end
    end)
end

function Crafting.Current(src)
    local token = Crafting.ByPlayer[src]
    local craft = token and Crafting.Active[token]
    if not craft or craft.status ~= 'running' then return nil end
    return payloadFor(craft, 'running')
end
