DJWS.NotifyProviders.ox_lib = {
    Show = function(message, ntype)
        if GetResourceState('ox_lib') ~= 'started' then return false end
        local map = { success = 'success', error = 'error', warning = 'warning', inform = 'inform' }
        TriggerEvent('ox_lib:notify', {
            title = 'DJ Weapon Store',
            description = message,
            type = map[ntype] or 'inform',
        })
        return true
    end,
}
