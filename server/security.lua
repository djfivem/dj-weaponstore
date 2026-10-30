Security = { hits = {} }

local blockedRemote = {
    purchase = true,
    startCraft = true,
    submitSkill = true,
    cancelCraft = true,
    depositMaterial = true,
    withdrawMaterial = true,
}

function Security.Rate(src, action)
    local limits = Config.Security.rateLimits or {}
    local window = limits[action] or limits.default or 350
    local now = GetGameTimer()
    Security.hits[src] = Security.hits[src] or {}
    local previous = Security.hits[src][action] or 0
    if now - previous < window then return false end
    Security.hits[src][action] = now
    return true
end

function Security.Clear(src)
    Security.hits[src] = nil
end

function Security.Text(value, maxLen)
    if type(value) ~= 'string' then return nil end
    local cleaned = value:gsub('[%c]', ''):sub(1, maxLen or 80)
    if cleaned == '' then return nil end
    return cleaned
end

function Security.Int(value, minValue, maxValue)
    local number = tonumber(value)
    if not number then return nil end
    number = math.floor(number)
    if number < minValue or number > maxValue then return nil end
    return number
end

function Security.CatalogId(value)
    if type(value) ~= 'string' or not value:match('^ws_[%w_]+$') then return nil end
    if not DJWS.ById[value] then return nil end
    return value
end

function Security.Coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function Security.NearCoords(src, coords, maxDist)
    local pos = Security.Coords(src)
    if not pos or not coords then return false end
    return DJWS.Distance(pos, coords) <= maxDist
end

function Security.InStore(src, store)
    if not store then return false end
    return Security.NearCoords(src, store.coords, store.radius or Config.Security.shopRadius or 12.0)
end

function Security.AtRegister(src, store)
    if not store then return false end
    return Security.NearCoords(src, store.coords, store.registerDistance or Config.Security.registerDistance or 3.5)
end

function Security.Remote(src, action)
    if not Config.Admin.remoteManagement then return false end
    if blockedRemote[action] then return false end
    return Framework.IsAdmin(src)
end

function Security.CanOpen(src, store)
    if Security.InStore(src, store) then return true end
    if Security.Remote(src, 'getState') then return true end
    local benches = Benches and Benches.ForStore and Benches.ForStore(store.id) or {}
    for i = 1, #benches do
        if Security.NearCoords(src, benches[i].coords, (Config.Security.benchDistance or 2.4) + 0.8) then
            return true
        end
    end
    return false
end

function Security.Gate(src, store, action)
    if action == 'purchase' then
        return Security.AtRegister(src, store)
    end
    if Security.InStore(src, store) then return true end
    return Security.Remote(src, action)
end

local storeLocks = {}

function Security.WithStore(storeId, fn)
    if storeLocks[storeId] then return false, 'busy' end
    storeLocks[storeId] = true
    local ok, a, b = pcall(fn)
    storeLocks[storeId] = nil
    if not ok then
        DJWS.Error(tostring(a))
        return false, 'internal'
    end
    return a, b
end
