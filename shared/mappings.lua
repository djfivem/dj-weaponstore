--[[
    Inventory item names are resolved here.

    The generated catalog `item` field is the ox_inventory name from the
    weapon source. Other inventories use that same name unless you set an
    override below, keyed by internal catalog id.

    Example:
    DJWS.ItemMappings['qb-inventory']['ws_weapon_pistol'] = 'weapon_pistol'

    Material keys follow the same rule. Set Config.Materials[key].item if a
    single inventory uses a different material item name, or set
    DJWS.MaterialMappings[inventoryName][materialKey].
]]

DJWS = DJWS or {}

DJWS.ItemMappings = {
    ox_inventory = {},
    ['qb-inventory'] = {},
    ['ps-inventory'] = {},
    ['lj-inventory'] = {},
    ['qs-inventory'] = {},
    core_inventory = {},
    ['codem-inventory'] = {},
    ['tgiann-inventory'] = {},
    standalone = {},
    custom = {},
}

DJWS.MaterialMappings = {
    ox_inventory = {},
    ['qb-inventory'] = {},
    ['ps-inventory'] = {},
    ['lj-inventory'] = {},
    ['qs-inventory'] = {},
    core_inventory = {},
    ['codem-inventory'] = {},
    ['tgiann-inventory'] = {},
    standalone = {},
    custom = {},
}

function DJWS.ResolveItem(catalogId, inventoryName)
    local entry = DJWS.ById[catalogId]
    if not entry then return nil end
    local map = DJWS.ItemMappings[inventoryName or 'ox_inventory']
    if map and type(map[catalogId]) == 'string' and map[catalogId] ~= '' then
        return map[catalogId]
    end
    return entry.item
end

function DJWS.MaterialItem(materialKey, inventoryName)
    local map = DJWS.MaterialMappings[inventoryName or 'ox_inventory']
    if map and type(map[materialKey]) == 'string' and map[materialKey] ~= '' then
        return map[materialKey]
    end
    local def = Config.Materials and Config.Materials[materialKey]
    if def and type(def.item) == 'string' and def.item ~= '' then
        return def.item
    end
    return materialKey
end

function DJWS.Image(entry, inventoryName)
    if not entry then return nil end
    if entry.image and entry.image ~= '' and not entry.image:find('%%s') then
        local template = Config.Images and Config.Images.template
        if template and entry.image:find('%.png$') and not entry.image:find('://') and not entry.image:find('^nui:') then
            return template:format(entry.image:gsub('%.png$', ''))
        end
    end
    local item = DJWS.ResolveItem(entry.id, inventoryName or 'ox_inventory')
    local template = Config.Images and Config.Images.template
    if not template or not item then return nil end
    return template:format(item)
end
