--[[
    Store coordinates, default benches, and optional MLO hints.
    The resource runs on these coordinates with no MLO installed.
    Move them to match your map. Disabled stores are ignored.
]]

Config.MLO = {
    enabled = false,
    interiors = {
        sandy = { enabled = false, ipl = nil },
        city = { enabled = false, ipl = nil },
        hawick = { enabled = false, ipl = nil },
        custom = { enabled = false, ipl = nil },
    },
}

Config.Stores = {
    {
        id = 'sandy',
        enabled = true,
        label = 'Sandy Shores Armory',
        mlo = 'sandy',
        coords = vector3(1692.62, 3759.41, 34.71),
        heading = 227.0,
        radius = 14.0,
        registerDistance = 3.6,
        materialCapacity = 8000,
        blip = { enabled = true, sprite = 110, color = 1, scale = 0.75, label = 'DJ Weapon Store' },
    },
    {
        id = 'city',
        enabled = true,
        label = 'Pillbox Gunworks',
        mlo = 'city',
        coords = vector3(22.64, -1105.56, 29.80),
        heading = 160.0,
        radius = 14.0,
        registerDistance = 3.6,
        materialCapacity = 8000,
        blip = { enabled = true, sprite = 110, color = 1, scale = 0.75, label = 'DJ Weapon Store' },
    },
    {
        id = 'hawick',
        enabled = true,
        label = 'Hawick Gunworks',
        mlo = 'hawick',
        coords = vector3(253.89, -50.47, 69.94),
        heading = 70.0,
        radius = 14.0,
        registerDistance = 3.6,
        materialCapacity = 8000,
        blip = { enabled = true, sprite = 110, color = 1, scale = 0.75, label = 'DJ Weapon Store' },
    },
    {
        id = 'custom',
        enabled = false,
        label = 'Custom Weapon Store',
        mlo = 'custom',
        coords = vector3(0.0, 0.0, 72.0),
        heading = 0.0,
        radius = 12.0,
        registerDistance = 3.5,
        materialCapacity = 5000,
        blip = { enabled = true, sprite = 110, color = 1, scale = 0.75, label = 'DJ Weapon Store' },
    },
}

Config.DefaultBenches = {
    {
        store = 'sandy',
        label = 'Sandy Pistol Bench',
        benchType = 'pistol',
        model = 'gr_prop_gr_bench_02a',
        coords = vector3(1694.35, 3757.55, 34.71),
        heading = 227.0,
        output = 'stock',
        jobs = '',
        minGrade = 0,
        invisible = false,
    },
    {
        store = 'sandy',
        label = 'Sandy Rifle Bench',
        benchType = 'rifle',
        model = 'gr_prop_gr_bench_01a',
        coords = vector3(1690.15, 3761.35, 34.71),
        heading = 47.0,
        output = 'stock',
        jobs = '',
        minGrade = 0,
        invisible = false,
    },
    {
        store = 'city',
        label = 'Pillbox Assembly Bench',
        benchType = 'general',
        model = 'gr_prop_gr_bench_03a',
        coords = vector3(20.15, -1106.85, 29.80),
        heading = 160.0,
        output = 'stock',
        jobs = '',
        minGrade = 0,
        invisible = false,
    },
    {
        store = 'hawick',
        label = 'Hawick General Bench',
        benchType = 'general',
        model = 'prop_tool_bench02',
        coords = vector3(255.55, -48.65, 69.94),
        heading = 70.0,
        output = 'stock',
        jobs = '',
        minGrade = 0,
        invisible = false,
    },
}
