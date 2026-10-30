Callback = Callback or {}

if IsDuplicityVersion() then
    Callback.Handlers = Callback.Handlers or {}

    function Callback.Register(name, fn)
        Callback.Handlers[name] = fn
    end

    RegisterNetEvent(DJWS.Events.cb, function(id, name, payload)
        local src = source
        if type(id) ~= 'number' or type(name) ~= 'string' then return end
        if not Security or not Security.Rate(src, name) then
            TriggerClientEvent(DJWS.Events.cbRes, src, id, DJWS.Fail('rate_limited'))
            return
        end
        local handler = Callback.Handlers[name]
        if not handler then
            TriggerClientEvent(DJWS.Events.cbRes, src, id, DJWS.Fail('unknown_action'))
            return
        end
        local ok, result = pcall(handler, src, type(payload) == 'table' and payload or {})
        if not ok then
            DJWS.Error(('RPC %s failed: %s'):format(name, tostring(result)))
            result = DJWS.Fail('internal')
        end
        if type(result) ~= 'table' then
            result = DJWS.Fail('internal')
        end
        TriggerClientEvent(DJWS.Events.cbRes, src, id, result)
    end)
else
    local pending = {}
    local seq = 0

    RegisterNetEvent(DJWS.Events.cbRes, function(id, payload)
        local cb = pending[id]
        if not cb then return end
        pending[id] = nil
        cb(payload)
    end)

    function Callback.Trigger(name, payload, cb)
        seq = seq + 1
        local id = seq
        pending[id] = cb
        SetTimeout(20000, function()
            if not pending[id] then return end
            pending[id] = nil
            cb(DJWS.Fail('timeout'))
        end)
        TriggerServerEvent(DJWS.Events.cb, id, name, payload or {})
    end
end
