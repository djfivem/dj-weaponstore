DJWS.NotifyProviders.qb = {
    Show = function(message, ntype)
        local map = { success = 'success', error = 'error', warning = 'error', inform = 'primary' }
        if GetResourceState('qbx_core') == 'started' then
            local ok = pcall(function()
                exports.qbx_core:Notify(message, map[ntype] or 'inform')
            end)
            if ok then return true end
        end
        if GetResourceState('qb-core') == 'started' or GetResourceState('qbx_core') == 'started' then
            TriggerEvent('QBCore:Notify', message, map[ntype] or 'primary')
            return true
        end
        return false
    end,
}
