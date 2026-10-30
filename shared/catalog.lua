DJWS = DJWS or {}

DJWS.Categories = {
    { id = 'pistols', label = 'Pistols' },
    { id = 'heavy_pistols', label = 'Heavy Pistols' },
    { id = 'smgs', label = 'SMGs' },
    { id = 'shotguns', label = 'Shotguns' },
    { id = 'rifles', label = 'Rifles' },
    { id = 'assault_rifles', label = 'Assault Rifles' },
    { id = 'snipers', label = 'Snipers' },
    { id = 'melee', label = 'Melee' },
    { id = 'custom', label = 'Custom' },
    { id = 'variants', label = 'Variants' },
    { id = 'attachments', label = 'Attachments' },
    { id = 'ammunition', label = 'Ammunition' },
}

DJWS.List = {}
DJWS.ById = {}
DJWS.ByItem = {}

local function add(entry)
    if type(entry) ~= 'table' or type(entry.id) ~= 'string' or type(entry.item) ~= 'string' then
        DJWS.Error('Skipped an invalid catalog entry.')
        return
    end
    if DJWS.ById[entry.id] then
        DJWS.Error('Duplicate catalog id ' .. entry.id)
        return
    end
    DJWS.ById[entry.id] = entry
    DJWS.List[#DJWS.List + 1] = entry
    if not DJWS.ByItem[entry.item] then
        DJWS.ByItem[entry.item] = entry.id
    end
end

local function addAll(list)
    if type(list) ~= 'table' then return end
    for i = 1, #list do
        add(list[i])
    end
end

addAll(DJWS.WeaponEntries)
addAll(DJWS.ComponentEntries)
addAll(DJWS.AmmoEntries)
addAll(Config.ExtraCatalog)

local weapons, attachments, ammo = 0, 0, 0
for i = 1, #DJWS.List do
    local kind = DJWS.List[i].kind
    if kind == 'weapon' then weapons = weapons + 1
    elseif kind == 'attachment' then attachments = attachments + 1
    elseif kind == 'ammo' then ammo = ammo + 1 end
end

DJWS.Counts = { weapons = weapons, attachments = attachments, ammo = ammo }

if DJWS.WeaponSourceCount and weapons ~= DJWS.WeaponSourceCount then
    DJWS.Error(('Weapon catalog count mismatch. Loaded %s, source %s.'):format(weapons, DJWS.WeaponSourceCount))
end

print(('[DJ Weapon Store] Catalog ready. Weapons %s, attachments %s, ammunition %s.'):format(weapons, attachments, ammo))

function DJWS.Get(catalogId)
    return DJWS.ById[catalogId]
end
