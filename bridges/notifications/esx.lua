DJWS.NotifyProviders.esx = {
    Show = function(message)
        if GetResourceState('es_extended') ~= 'started' then return false end
        TriggerEvent('esx:showNotification', message)
        return true
    end,
}
