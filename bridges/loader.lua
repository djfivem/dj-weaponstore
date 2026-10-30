DJWS = DJWS or {}
DJWS.Bridge = DJWS.Bridge or {}
DJWS.FrameworkProviders = DJWS.FrameworkProviders or {}
DJWS.InventoryProviders = DJWS.InventoryProviders or {}
DJWS.NotifyProviders = DJWS.NotifyProviders or {}
DJWS.TargetProviders = DJWS.TargetProviders or {}

local announced = {}

local function started(name)
    return GetResourceState(name) == 'started'
end

local function announce(kind, value)
    local key = kind .. ':' .. tostring(value)
    if announced[key] then return end
    announced[key] = true
    print(('[DJ Weapon Store] %s: %s'):format(kind, value))
end

function DJWS.DetectFramework()
    local configured = (Config and Config.Framework) or 'auto'
    if configured ~= 'auto' then return configured end
    if started('qbx_core') then return 'qbox' end
    if started('qb-core') then return 'qbcore' end
    if started('es_extended') then return 'esx_legacy' end
    return 'standalone'
end

function DJWS.DetectInventory()
    local configured = (Config and Config.Inventory) or 'auto'
    if configured ~= 'auto' then return configured end
    local order = {
        'ox_inventory',
        'qb-inventory',
        'ps-inventory',
        'lj-inventory',
        'qs-inventory',
        'core_inventory',
        'codem-inventory',
        'tgiann-inventory',
    }
    for i = 1, #order do
        if started(order[i]) then return order[i] end
    end
    return 'standalone'
end

function DJWS.DetectTarget()
    local configured = (Config and Config.Target) or 'auto'
    if configured ~= 'auto' then return configured end
    if started('ox_target') then return 'ox_target' end
    if started('qb-target') then return 'qb-target' end
    return 'fallback'
end

function DJWS.DetectNotify()
    local configured = (Config and Config.Notify) or 'auto'
    if configured ~= 'auto' then return configured end
    if started('ox_lib') then return 'ox_lib' end
    if started('qbx_core') or started('qb-core') then return 'qb' end
    if started('es_extended') then return 'esx' end
    return 'native'
end

function DJWS.RefreshBridges()
    local framework = DJWS.DetectFramework()
    local inventory = DJWS.DetectInventory()
    local notify = DJWS.DetectNotify()
    if DJWS.Bridge.framework ~= framework then
        DJWS.Bridge.framework = framework
        announce('framework', framework)
    end
    if IsDuplicityVersion() and DJWS.Bridge.inventory ~= inventory then
        DJWS.Bridge.inventory = inventory
        announce('inventory', inventory)
    end
    if not IsDuplicityVersion() then
        local target = DJWS.DetectTarget()
        if DJWS.Bridge.target ~= target then
            DJWS.Bridge.target = target
            announce('target', target)
        end
    end
    if DJWS.Bridge.notify ~= notify then
        DJWS.Bridge.notify = notify
        announce('notify', notify)
    end
end

DJWS.RefreshBridges()
