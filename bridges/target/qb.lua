DJWS.TargetProviders['qb-target'] = {
    AddEntity = function(entity, option)
        exports['qb-target']:AddTargetEntity(entity, {
            options = {
                {
                    icon = option.icon,
                    label = option.label,
                    action = option.onSelect,
                },
            },
            distance = option.distance,
        })
    end,
    RemoveEntity = function(entity)
        exports['qb-target']:RemoveTargetEntity(entity)
    end,
    AddZone = function(option)
        exports['qb-target']:AddCircleZone(option.name, option.coords, option.radius or 1.2, {
            name = option.name,
            debugPoly = Config.Debug == true,
            useZ = true,
        }, {
            options = {
                {
                    icon = option.icon,
                    label = option.label,
                    action = option.onSelect,
                },
            },
            distance = option.distance,
        })
        return option.name
    end,
    RemoveZone = function(name)
        exports['qb-target']:RemoveZone(name)
    end,
}
