DJWS.NotifyProviders.custom = {
    Show = function(message, ntype)
        local conf = Config.CustomNotify or {}
        local resource = conf.resource
        local exportName = conf.exports and conf.exports.notify
        if type(resource) ~= 'string' or resource == '' or type(exportName) ~= 'string' then
            return false
        end
        if GetResourceState(resource) ~= 'started' then return false end
        local ok = pcall(function()
            exports[resource][exportName](message, ntype)
        end)
        return ok
    end,
}
