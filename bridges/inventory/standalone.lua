local function weightOf(item)
    local catalogId = DJWS.ByItem[item]
    local entry = catalogId and DJWS.ById[catalogId]
    if entry and tonumber(entry.weight) then return tonumber(entry.weight) end
    local material = Config.Materials[item]
    if material and tonumber(material.weight) then return tonumber(material.weight) end
    return 0
end

local function rows(identifier, item)
    return DB.query('SELECT id, count, metadata FROM dj_ws_player_items WHERE identifier = ? AND item = ?', { identifier, item }) or {}
end

local function used(identifier)
    local list = DB.query('SELECT item, count FROM dj_ws_player_items WHERE identifier = ?', { identifier }) or {}
    local weight, slots = 0, 0
    for i = 1, #list do
        local count = tonumber(list[i].count) or 0
        weight = weight + (weightOf(list[i].item) * count)
        slots = slots + 1
    end
    return weight, slots
end

DJWS.InventoryProviders.standalone = {
    supports = { metadata = true, durability = true, weight = true },
    notes = 'Built-in item table used only when no external inventory is selected. It is not a full player inventory UI.',
    CanCarry = function(src, item, count, metadata)
        if not DB or not DB.ready or not DB.ready() then return false, 'database_unavailable' end
        local identifier = Framework.GetIdentifier(src)
        if not identifier then return false, 'inventory_unavailable' end
        local weight, slots = used(identifier)
        local addWeight = weightOf(item) * count
        if weight + addWeight > (Config.Standalone.maxWeight or 120000) then
            return false, 'inventory_full'
        end
        local existing = rows(identifier, item)
        local stacks = metadata == nil
        if not stacks and #existing >= (Config.Standalone.maxSlots or 100) then
            return false, 'inventory_full'
        end
        if slots >= (Config.Standalone.maxSlots or 100) and #existing == 0 then
            return false, 'inventory_full'
        end
        return true
    end,
    Add = function(src, item, count, metadata)
        if not DB or not DB.ready or not DB.ready() then return false, 'database_unavailable' end
        local identifier = Framework.GetIdentifier(src)
        if not identifier then return false, 'inventory_unavailable' end
        if metadata == nil then
            local current = rows(identifier, item)
            for i = 1, #current do
                if current[i].metadata == nil or current[i].metadata == '' then
                    local affected = DB.affected(DB.update('UPDATE dj_ws_player_items SET count = count + ? WHERE id = ?', { count, current[i].id }))
                    return affected >= 1
                end
            end
        end
        local encoded = metadata and json.encode(metadata) or nil
        local id = DB.insert('INSERT INTO dj_ws_player_items (identifier, item, count, metadata) VALUES (?, ?, ?, ?)', {
            identifier, item, count, encoded,
        })
        return type(id) == 'number' and id > 0
    end,
    Remove = function(src, item, count)
        if not DB or not DB.ready or not DB.ready() then return false, 'database_unavailable' end
        local identifier = Framework.GetIdentifier(src)
        if not identifier then return false, 'inventory_unavailable' end
        local current = rows(identifier, item)
        local left = count
        for i = 1, #current do
            if left <= 0 then break end
            local have = tonumber(current[i].count) or 0
            if have > 0 then
                local take = math.min(have, left)
                if have == take then
                    DB.update('DELETE FROM dj_ws_player_items WHERE id = ?', { current[i].id })
                else
                    DB.update('UPDATE dj_ws_player_items SET count = count - ? WHERE id = ? AND count >= ?', { take, current[i].id, take })
                end
                left = left - take
            end
        end
        return left == 0
    end,
    Count = function(src, item)
        if not DB or not DB.ready or not DB.ready() then return 0 end
        local identifier = Framework.GetIdentifier(src)
        if not identifier then return 0 end
        local total = DB.scalar('SELECT COALESCE(SUM(count), 0) FROM dj_ws_player_items WHERE identifier = ? AND item = ?', { identifier, item })
        return tonumber(total) or 0
    end,
}
