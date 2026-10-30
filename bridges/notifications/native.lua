DJWS.NotifyProviders.native = {
    Show = function(message)
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(tostring(message or ''))
        EndTextCommandThefeedPostTicker(false, false)
        return true
    end,
}
