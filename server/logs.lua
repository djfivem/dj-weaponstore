Logs = {}

function Logs.Audit(storeId, identifier, action, detail)
    local payload = nil
    if detail ~= nil then
        local ok, encoded = pcall(json.encode, detail)
        if ok then payload = encoded end
    end
    if not DB.ready() then
        DJWS.Debug(('%s %s'):format(action, payload or ''))
        return
    end
    DB.insert('INSERT INTO dj_ws_audit (store_id, identifier, action, detail) VALUES (?, ?, ?, ?)', {
        storeId, identifier, tostring(action):sub(1, 64), payload,
    })
end

function Logs.Webhook(eventName, title, fields)
    local conf = Config.Webhooks or {}
    if type(conf.url) ~= 'string' or conf.url:sub(1, 8) ~= 'https://' then return end
    if conf.events and conf.events[eventName] == false then return end
    local embedFields = {}
    if type(fields) == 'table' then
        for i = 1, #fields do
            local row = fields[i]
            if type(row) == 'table' then
                embedFields[#embedFields + 1] = {
                    name = tostring(row.name or 'Detail'):sub(1, 80),
                    value = tostring(row.value or '-'):sub(1, 900),
                    inline = true,
                }
            end
        end
    end
    local ok, body = pcall(json.encode, {
        username = conf.name or 'DJ Weapon Store',
        embeds = {
            {
                title = tostring(title or 'DJ Weapon Store'):sub(1, 200),
                color = 12925105,
                fields = embedFields,
            },
        },
    })
    if not ok then return end
    PerformHttpRequest(conf.url, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
end
