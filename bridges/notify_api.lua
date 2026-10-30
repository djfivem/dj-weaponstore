Notify = {}

function Notify.Show(message, ntype)
    if IsDuplicityVersion() then return end
    DJWS.RefreshBridges()
    local name = DJWS.Bridge.notify
    local impl = DJWS.NotifyProviders[name]
    if impl and impl.Show then
        local ok, shown = pcall(impl.Show, message, ntype or 'inform')
        if ok and shown ~= false then return end
    end
    if name ~= 'native' and DJWS.NotifyProviders.native then
        DJWS.NotifyProviders.native.Show(message, ntype)
    end
end

function Notify.Send(src, message, ntype)
    if not IsDuplicityVersion() then
        Notify.Show(message, ntype)
        return
    end
    TriggerClientEvent(DJWS.Events.notify, src, {
        message = message,
        ntype = ntype or 'inform',
    })
end

if not IsDuplicityVersion() then
    RegisterNetEvent(DJWS.Events.notify, function(payload)
        if type(payload) ~= 'table' then return end
        Notify.Show(payload.message, payload.ntype)
    end)
end
