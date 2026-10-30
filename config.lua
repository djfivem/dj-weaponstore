--[[
    DJ Weapon Store
    Developed by Diesel Dev Shack

    Owners edit behavior here. Weapon rows live in shared/data and are
    addressed by internal catalog id. Inventory item names are resolved
    through shared/mappings.lua — do not hardcode item names in gameplay.
]]

Config = {}

Config.Debug = false
Config.Locale = 'en'
Config.ResourceName = 'DJ Weapon Store'
Config.Brand = 'Diesel Dev Shack'

-- auto | qbcore | qbox | esx | esx_legacy | standalone | custom
Config.Framework = 'auto'

-- auto | ox_inventory | qb-inventory | ps-inventory | lj-inventory | qs-inventory | core_inventory | codem-inventory | tgiann-inventory | standalone | custom
Config.Inventory = 'auto'

-- auto | ox_target | qb-target | custom | fallback
Config.Target = 'auto'

-- auto | ox_lib | qb | esx | custom | native
Config.Notify = 'auto'

Config.Admin = {
    ace = 'dj_weaponstore.admin',
    -- Also treat qb/qbox admin+god and ESX admin/superadmin as admins.
    useFrameworkAdmin = true,
    -- Ace permission "command" (server operators). Disable if that is too broad.
    allowCommandAce = true,
    -- Admins may open management away from the shop. Purchases, crafting, and
    -- physical material transfers still require distance.
    remoteManagement = true,
    allowOwnerPlacement = true,
}

Config.Security = {
    shopRadius = 12.0,
    registerDistance = 3.5,
    benchDistance = 2.4,
    placementDistance = 8.0,
    rateLimits = {
        default = 350,
        getState = 400,
        startCraft = 1200,
        submitSkill = 600,
        purchase = 700,
        saveBench = 800,
        depositAccount = 600,
        withdrawAccount = 600,
    },
    maxCraftQty = 5,
    maxPurchaseQty = 10,
    maxStockAdjust = 100,
    maxMaterialMove = 500,
    maxTransaction = 1000000,
    -- When false, a skill-check success cannot force the craft to succeed.
    -- A reported failure can only fail the craft. See README.
    trustClientSkillCheck = false,
    failRefundPercent = 100,
    cancelLockoutSeconds = 5,
}

Config.Payments = {
    taxPercent = 8,
    maxTax = 25,
    commissionPercent = 5,
    maxCommission = 30,
    -- Commission is paid to the store owner (or held as commission owed).
    taxToBusiness = false,
    allowCash = true,
    allowBank = true,
    -- Global gate. A store setting can still disable it.
    allowDirectManufacturingSales = false,
    license = {
        enabled = false,
        -- qb/qbox metadata key, or esx_license type.
        type = 'weapon',
        -- Optional inventory item that also satisfies the check.
        item = nil,
    },
    -- Empty means the public can buy. Names are framework job names.
    jobRestrictions = {},
}

Config.Stock = {
    maxPerItem = 250,
    maxPrice = 5000000,
}

Config.Ammo = {
    -- One manufacturing batch produces this many rounds.
    batch = 30,
}

Config.Crafting = {
    allowCancel = true,
    preferScenario = false,
    skillCheck = {
        enabled = false,
        -- Client calls exports.ox_lib:skillCheck when this resource is started.
        -- If the export is missing, the craft continues on the server roll.
        resource = 'ox_lib',
    },
}

Config.Animations = {
    pistol = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flag = 1 },
    rifle = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flag = 1 },
    melee = { dict = 'amb@world_human_hammering@male@base', anim = 'base', flag = 1 },
    assembly = { dict = 'mini@repair', anim = 'fixing_a_player', flag = 1 },
    general = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flag = 49 },
}

Config.Scenarios = {
    general = 'WORLD_HUMAN_WELDING',
}

Config.Benches = {
    types = {
        pistol = true,
        rifle = true,
        melee = true,
        assembly = true,
        general = true,
    },
    models = {
        ['gr_prop_gr_bench_01a'] = true,
        ['gr_prop_gr_bench_02a'] = true,
        ['gr_prop_gr_bench_03a'] = true,
        ['gr_prop_gr_bench_04b'] = true,
        ['prop_tool_bench02'] = true,
        ['prop_tool_bench02_ld'] = true,
    },
    defaults = {
        pistol = 'gr_prop_gr_bench_02a',
        rifle = 'gr_prop_gr_bench_01a',
        melee = 'prop_tool_bench02',
        assembly = 'gr_prop_gr_bench_04b',
        general = 'gr_prop_gr_bench_03a',
    },
    fallbackModel = 'prop_tool_bench02',
    spawnDistance = 80.0,
    despawnDistance = 100.0,
}

-- Which weapon families a bench type is allowed to produce.
Config.BenchCategories = {
    pistol = { pistols = true, heavy_pistols = true },
    rifle = { smgs = true, shotguns = true, rifles = true, assault_rifles = true, snipers = true },
    melee = { melee = true },
    assembly = { custom = true, attachments = true, ammunition = true, variants = true },
    general = {
        pistols = true, heavy_pistols = true, smgs = true, shotguns = true, rifles = true,
        assault_rifles = true, snipers = true, melee = true, custom = true, variants = true,
        attachments = true, ammunition = true,
    },
}

Config.Images = {
    -- %s is the inventory item name. Point this at whatever inventory image pack you use.
    template = 'nui://ox_inventory/web/images/%s.png',
}

Config.Catalog = {
    -- World/environmental damage types stay in the data files but are hidden in the UI.
    showUncraftable = false,
}

-- Prices, craft time (seconds), XP, difficulty 1-5, and quality range.
-- Variant weapons use their family stats and the price multiplier below.
Config.Pricing = {
    variantMultiplier = 1.15,
    pistols = { price = 7500, min = 3500, max = 22000, time = 35, xp = 15, difficulty = 2, quality = { min = 72, max = 98 } },
    heavy_pistols = { price = 14500, min = 7000, max = 42000, time = 50, xp = 26, difficulty = 2, quality = { min = 70, max = 96 } },
    smgs = { price = 18500, min = 9000, max = 52000, time = 60, xp = 32, difficulty = 3, quality = { min = 68, max = 96 } },
    shotguns = { price = 16000, min = 8000, max = 48000, time = 55, xp = 30, difficulty = 3, quality = { min = 68, max = 96 } },
    rifles = { price = 24000, min = 12000, max = 70000, time = 75, xp = 40, difficulty = 3, quality = { min = 64, max = 95 } },
    assault_rifles = { price = 27500, min = 14000, max = 80000, time = 80, xp = 44, difficulty = 4, quality = { min = 62, max = 94 } },
    snipers = { price = 42000, min = 22000, max = 120000, time = 110, xp = 60, difficulty = 4, quality = { min = 58, max = 92 } },
    melee = { price = 2500, min = 500, max = 12000, time = 20, xp = 8, difficulty = 1, quality = { min = 80, max = 100 } },
    custom = { price = 20000, min = 5000, max = 90000, time = 70, xp = 36, difficulty = 3, quality = { min = 65, max = 95 } },
    attachments = { price = 1500, min = 250, max = 8000, time = 15, xp = 6, difficulty = 1, quality = { min = 90, max = 100 } },
    ammunition = { price = 150, min = 25, max = 800, time = 8, xp = 2, difficulty = 1, quality = { min = 100, max = 100 } },
}

-- Optional per-catalog-id overrides. Key is the internal id (ws_...), never a raw guess from the client.
Config.PriceOverrides = {
    -- ['ws_weapon_pistol'] = { price = 5000, min = 2500, max = 15000 },
}

-- Optional full recipe overrides. Same internal ids. Materials must exist in Config.Materials.
Config.RecipeOverrides = {
    -- ['ws_weapon_pistol'] = { time = 40, xp = 20, difficulty = 2, unlockXp = 0, materials = { { item = 'steel', count = 4 } } },
}

-- Extra weapons added later. Same shape as generated entries (id, item, label, category, family, kind, bench, craftable, purchasable).
Config.ExtraCatalog = {
    -- { id = 'ws_weapon_example', item = 'WEAPON_EXAMPLE', label = 'Example', category = 'custom', family = 'custom', kind = 'weapon', bench = 'assembly', craftable = true, purchasable = true, weight = 1000, description = 'Added by the server owner.' },
}

Config.Materials = {
    steel = { label = 'Steel', weight = 150, category = 'metal', price = 40 },
    iron = { label = 'Iron', weight = 180, category = 'metal', price = 28 },
    aluminum = { label = 'Aluminum', weight = 80, category = 'metal', price = 34 },
    copper = { label = 'Copper', weight = 90, category = 'metal', price = 30 },
    plastic = { label = 'Plastic', weight = 40, category = 'polymer', price = 12 },
    rubber = { label = 'Rubber', weight = 50, category = 'polymer', price = 14 },
    gunpowder = { label = 'Gunpowder', weight = 20, category = 'chemical', price = 55 },
    components = { label = 'Components', weight = 60, category = 'mechanical', price = 75 },
    springs = { label = 'Springs', weight = 25, category = 'mechanical', price = 22 },
    barrels = { label = 'Barrels', weight = 300, category = 'mechanical', price = 120 },
    frames = { label = 'Frames', weight = 250, category = 'mechanical', price = 140 },
    parts = { label = 'Parts', weight = 40, category = 'mechanical', price = 18 },
}

Config.Suppliers = {
    { id = 'foundry', label = 'Foundry Contract', categories = { metal = true, polymer = true } },
    { id = 'machine', label = 'Machine Shop', categories = { mechanical = true, chemical = true } },
}

Config.RecipeSets = {
    pistols = {
        { item = 'steel', count = 6 },
        { item = 'springs', count = 2 },
        { item = 'frames', count = 1 },
        { item = 'plastic', count = 2 },
        { item = 'gunpowder', count = 1 },
    },
    heavy_pistols = {
        { item = 'steel', count = 10 },
        { item = 'iron', count = 4 },
        { item = 'springs', count = 3 },
        { item = 'frames', count = 1 },
        { item = 'barrels', count = 1 },
        { item = 'gunpowder', count = 2 },
    },
    smgs = {
        { item = 'steel', count = 12 },
        { item = 'aluminum', count = 4 },
        { item = 'springs', count = 4 },
        { item = 'frames', count = 1 },
        { item = 'barrels', count = 1 },
        { item = 'parts', count = 3 },
    },
    shotguns = {
        { item = 'steel', count = 14 },
        { item = 'iron', count = 6 },
        { item = 'barrels', count = 2 },
        { item = 'frames', count = 1 },
        { item = 'parts', count = 2 },
    },
    rifles = {
        { item = 'steel', count = 16 },
        { item = 'aluminum', count = 6 },
        { item = 'barrels', count = 2 },
        { item = 'frames', count = 1 },
        { item = 'springs', count = 3 },
        { item = 'parts', count = 4 },
    },
    assault_rifles = {
        { item = 'steel', count = 18 },
        { item = 'aluminum', count = 8 },
        { item = 'barrels', count = 2 },
        { item = 'frames', count = 1 },
        { item = 'springs', count = 4 },
        { item = 'parts', count = 5 },
        { item = 'components', count = 2 },
    },
    snipers = {
        { item = 'steel', count = 22 },
        { item = 'aluminum', count = 6 },
        { item = 'barrels', count = 3 },
        { item = 'frames', count = 1 },
        { item = 'components', count = 4 },
        { item = 'parts', count = 4 },
    },
    melee = {
        { item = 'steel', count = 4 },
        { item = 'iron', count = 2 },
        { item = 'rubber', count = 1 },
    },
    custom = {
        { item = 'steel', count = 10 },
        { item = 'parts', count = 4 },
        { item = 'components', count = 2 },
        { item = 'frames', count = 1 },
    },
    attachments = {
        { item = 'steel', count = 2 },
        { item = 'aluminum', count = 1 },
        { item = 'springs', count = 1 },
    },
    ammunition = {
        { item = 'gunpowder', count = 2 },
        { item = 'copper', count = 1 },
        { item = 'parts', count = 1 },
    },
}

Config.Grades = {
    [0] = 'Trainee',
    [1] = 'Maker',
    [2] = 'Armorer',
    [3] = 'Manager',
}

-- Applied only when hiring or when a manager explicitly applies the template.
-- Withdraw, fire, permissions, and settings are intentionally absent at every grade.
Config.GradeTemplates = {
    [0] = { 'dashboard', 'manufacture' },
    [1] = { 'dashboard', 'manufacture', 'materials' },
    [2] = { 'dashboard', 'manufacture', 'materials', 'stock', 'recipes', 'reports' },
    [3] = { 'dashboard', 'manufacture', 'materials', 'stock', 'prices', 'recipes', 'reports', 'benches', 'deposit' },
}

Config.Business = {
    hireDistance = 8.0,
    maxGrade = 3,
}

Config.Standalone = {
    startingCash = 5000,
    startingBank = 25000,
    maxWeight = 120000,
    maxSlots = 100,
}

Config.InventoryOptions = {
    -- Treat a nil return from AddItem as success. Leave false unless you have
    -- confirmed that inventory returns nil when the item really was added.
    -- Turning this on without that confirmation can duplicate items.
    nilAddIsSuccess = {},
    core_inventory = {
        -- source | identifier | content | primary
        -- Not live-verified. Confirm against your core_inventory version.
        idMode = 'source',
    },
}

Config.CustomFramework = {
    resource = '',
    exports = {
        getIdentifier = 'GetIdentifier',
        getName = 'GetName',
        getJob = 'GetJob',
        getMoney = 'GetMoney',
        addMoney = 'AddMoney',
        removeMoney = 'RemoveMoney',
        isAdmin = 'IsAdmin',
        hasLicense = 'HasLicense',
    },
}

Config.CustomInventory = {
    resource = '',
    exports = {
        canCarry = 'CanCarry',
        addItem = 'AddItem',
        removeItem = 'RemoveItem',
        getCount = 'GetCount',
        setMetadata = 'SetMetadata',
    },
}

Config.CustomTarget = {
    resource = '',
    exports = {
        addEntity = 'AddEntity',
        removeEntity = 'RemoveEntity',
        addZone = 'AddZone',
        removeZone = 'RemoveZone',
    },
}

Config.CustomNotify = {
    resource = '',
    exports = {
        notify = 'Notify',
    },
}

Config.Webhooks = {
    url = '',
    name = 'DJ Weapon Store',
    events = {
        purchase = true,
        craft = true,
        deposit = true,
        withdraw = true,
        hire = true,
        fire = true,
        bench = true,
        stock = true,
        recipe = true,
        settings = true,
        security = false,
    },
}

Config.TargetOptions = {
    icon = 'fa-solid fa-gun',
    storeLabel = 'DJ Weapon Store',
    benchLabel = 'Crafting Bench',
}

Config.Commands = {
    open = 'djws',
    place = 'djws_place',
    owner = 'djws_owner',
    fund = 'djws_fund',
    materials = 'djws_materials',
}
