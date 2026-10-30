DJWS.TargetProviders.ox_target = {
    AddEntity = function(entity, option)
        exports.ox_target:addLocalEntity(entity, {
            {
                name = option.name,
                icon = option.icon,
                label = option.label,
                distance = option.distance,
                onSelect = option.onSelect,
            },
        })
    end,
    RemoveEntity = function(entity, optionName)
        exports.ox_target:removeLocalEntity(entity, optionName)
    end,
    AddZone = function(option)
        return exports.ox_target:addSphereZone({
            coords = option.coords,
            radius = option.radius or 1.2,
            debug = Config.Debug == true,
            options = {
                {
                    name = option.name,
                    icon = option.icon,
                    label = option.label,
                    distance = option.distance,
                    onSelect = option.onSelect,
                },
            },
        })
    end,
    RemoveZone = function(zoneId)
        exports.ox_target:removeZone(zoneId)
    end,
}
