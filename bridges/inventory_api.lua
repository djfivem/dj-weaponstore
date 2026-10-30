Inventory = {}

local function provider()
    DJWS.RefreshBridges()
    return DJWS.InventoryProviders[DJWS.Bridge.inventory]
end

function Inventory.Name()
    DJWS.RefreshBridges()
    return DJWS.Bridge.inventory
end

function Inventory.Supports()
    local impl = provider()
    return (impl and impl.supports) or {}
end

function Inventory.CanCarry(src, item, count, metadata)
    local impl = provider()
    if not impl or not impl.CanCarry then return false, 'inventory_unavailable' end
    local ok, a, b = pcall(impl.CanCarry, src, item, count, metadata)
    if not ok then
        DJWS.Error('Inventory CanCarry error: ' .. tostring(a))
        return false, 'inventory_unavailable'
    end
    if a == true then return true end
    return false, b or 'inventory_full'
end

function Inventory.Add(src, item, count, metadata)
    local impl = provider()
    if not impl or not impl.Add then return false, 'inventory_unavailable' end
    local ok, success, err = pcall(impl.Add, src, item, count, metadata)
    if not ok then
        DJWS.Error('Inventory Add error: ' .. tostring(success))
        return false, 'add_failed'
    end
    if success == true then return true end
    return false, err or 'add_failed'
end

function Inventory.Remove(src, item, count, metadata)
    local impl = provider()
    if not impl or not impl.Remove then return false, 'inventory_unavailable' end
    local ok, success, err = pcall(impl.Remove, src, item, count, metadata)
    if not ok then
        DJWS.Error('Inventory Remove error: ' .. tostring(success))
        return false, 'remove_failed'
    end
    if success == true then return true end
    return false, err or 'remove_failed'
end

function Inventory.GetCount(src, item)
    local impl = provider()
    if not impl or not impl.Count then return 0 end
    local ok, count = pcall(impl.Count, src, item)
    if not ok then return 0 end
    return tonumber(count) or 0
end

function Inventory.Item(catalogId)
    return DJWS.ResolveItem(catalogId, Inventory.Name())
end
