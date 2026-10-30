local function boot()
    CreateThread(function()
        local tries = 0
        while not DB.available() and tries < 20 do
            tries = tries + 1
            Wait(500)
        end
        if not DB.available() then
            DJWS.Error('oxmysql is not started. DJ Weapon Store will show the catalog only. Manufacturing, stock, and money will not persist.')
            return
        end
        if not DB.Install() then return end
        Business.Seed()
        Benches.Reload()
        Crafting.Recover()
        print('[DJ Weapon Store] Diesel Dev Shack — ready.')
    end)
    Crafting.StartScheduler()
end

local function adminCommand(src)
    if src == 0 then return true end
    if Framework.IsAdmin(src) then return true end
    Framework.Notify(src, L('not_admin'), 'error')
    return false
end

RegisterCommand(Config.Commands.owner or 'djws_owner', function(src, args)
    if not adminCommand(src) then return end
    if not DB.ready() then
        if src ~= 0 then Framework.Notify(src, L('database_unavailable'), 'error') end
        return
    end
    local storeId = args[1]
    if not Business.Config(storeId) then
        if src ~= 0 then Framework.Notify(src, L('invalid_store'), 'error') end
        return
    end
    local target = tonumber(args[2]) or src
    if target == 0 then
        print('[DJ Weapon Store] Pass a player id from the server console.')
        return
    end
    local identifier = Framework.GetIdentifier(target)
    if not identifier then
        if src ~= 0 then Framework.Notify(src, L('player_offline'), 'error') end
        return
    end
    DB.update('UPDATE dj_ws_stores SET owner_identifier = ? WHERE id = ?', { identifier, storeId })
    Logs.Audit(storeId, identifier, 'set_owner', { by = src })
    if src ~= 0 then Framework.Notify(src, L('owner_set'), 'success') end
    print(('[DJ Weapon Store] %s owner set to %s'):format(storeId, identifier))
end, true)

RegisterCommand(Config.Commands.fund or 'djws_fund', function(src, args)
    if not adminCommand(src) then return end
    if not DB.ready() then return end
    local storeId = args[1]
    local amount = math.floor(tonumber(args[2]) or 0)
    if not Business.Config(storeId) or amount == 0 or math.abs(amount) > 10000000 then
        if src ~= 0 then Framework.Notify(src, L('bad_quantity'), 'error') end
        return
    end
    local ok = Business.AddBalance(storeId, amount, src == 0 and 'console' or Framework.GetIdentifier(src), 'admin_fund', 'admin fund')
    if src ~= 0 then Framework.Notify(src, ok and L('funded') or L('insufficient_funds'), ok and 'success' or 'error') end
end, true)

RegisterCommand(Config.Commands.materials or 'djws_materials', function(src, args)
    if not adminCommand(src) then return end
    if not DB.ready() then return end
    local storeId, item, count = args[1], args[2], math.floor(tonumber(args[3]) or 0)
    local cfg = storeId and Business.Config(storeId)
    if not cfg or not Config.Materials[item] or count == 0 or math.abs(count) > 10000 then
        if src ~= 0 then Framework.Notify(src, L('bad_quantity'), 'error') end
        return
    end
    if count > 0 then
        DB.update([[INSERT INTO dj_ws_materials (store_id, item, count) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE count = count + VALUES(count)]], { storeId, item, count })
    else
        DB.update('UPDATE dj_ws_materials SET count = GREATEST(count + ?, 0) WHERE store_id = ? AND item = ?', { count, storeId, item })
    end
    Materials.Log(storeId, src == 0 and 'console' or Framework.GetIdentifier(src), item, count, 'admin')
    Logs.Audit(storeId, src == 0 and 'console' or Framework.GetIdentifier(src), 'admin_materials', { item = item, count = count })
    if src ~= 0 then Framework.Notify(src, L('materials_added'), 'success') end
end, true)

AddEventHandler('playerDropped', function()
    local src = source
    if Crafting and Crafting.OnDrop then Crafting.OnDrop(src) end
    if Security and Security.Clear then Security.Clear(src) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for token, craft in pairs(Crafting.Active or {}) do
        if craft.paid and not craft.finished then
            Crafting.Refund(craft, 100)
        end
        Crafting.Clear(token)
    end
end)

exports('GetCatalogId', function(itemName)
    return DJWS.ByItem[itemName]
end)

exports('GetItemName', function(catalogId, inventoryName)
    return DJWS.ResolveItem(catalogId, inventoryName or Inventory.Name())
end)

boot()
