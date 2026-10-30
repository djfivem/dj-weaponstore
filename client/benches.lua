local function loadModel(model)
    local hashed = DJWSClient.Hash(model)
    if not IsModelInCdimage(hashed) or not IsModelValid(hashed) then
        hashed = DJWSClient.Hash(Config.Benches.fallbackModel or 'prop_tool_bench02')
    end
    RequestModel(hashed)
    local expire = GetGameTimer() + 3000
    while not HasModelLoaded(hashed) and GetGameTimer() < expire do Wait(20) end
    if not HasModelLoaded(hashed) then return nil end
    return hashed
end

local function deleteEntity(id)
    local entity = DJWSClient.Entities[id]
    if entity and DoesEntityExist(entity) then
        Target.RemoveEntity(entity, 'djws_bench_' .. id)
        DeleteEntity(entity)
    end
    DJWSClient.Entities[id] = nil
end

local function spawnBench(bench)
    if bench.invisible then
        Target.AddZone({
            name = 'djws_bench_zone_' .. bench.id,
            coords = vector3(bench.coords.x, bench.coords.y, bench.coords.z),
            radius = 1.1,
            icon = Config.TargetOptions.icon,
            label = bench.label or Config.TargetOptions.benchLabel,
            distance = Config.Security.benchDistance,
            onSelect = function()
                DJWSClient.Open(bench.storeId, 'bench', bench.id)
            end,
        })
        return
    end
    local model = loadModel(bench.model)
    if not model then return end
    local entity = CreateObject(model, bench.coords.x, bench.coords.y, bench.coords.z + (bench.zOffset or 0.0), false, false, false)
    if not entity or entity == 0 then return end
    SetEntityHeading(entity, bench.heading or 0.0)
    FreezeEntityPosition(entity, true)
    SetEntityAsMissionEntity(entity, true, true)
    SetEntityInvincible(entity, true)
    SetModelAsNoLongerNeeded(model)
    DJWSClient.Entities[bench.id] = entity
    Target.AddEntity(entity, {
        name = 'djws_bench_' .. bench.id,
        icon = Config.TargetOptions.icon,
        label = bench.label or Config.TargetOptions.benchLabel,
        distance = Config.Security.benchDistance,
        onSelect = function()
            DJWSClient.Open(bench.storeId, 'bench', bench.id)
        end,
    })
end

function DJWSClient.ApplyBenches(list)
    DJWSClient.Benches = list or {}
    for id in pairs(DJWSClient.Entities) do
        deleteEntity(id)
    end
    Target.Clear()
    DJWSClient.RebuildPoints()
    for i = 1, #DJWSClient.Benches do
        if DJWSClient.Benches[i].invisible then
            spawnBench(DJWSClient.Benches[i])
        end
    end
end

function DJWSClient.RebuildPoints()
    DJWSClient.Points = {}
    for i = 1, #Config.Stores do
        local store = Config.Stores[i]
        if store.enabled ~= false then
            DJWSClient.Points[#DJWSClient.Points + 1] = {
                kind = 'store',
                id = store.id,
                coords = store.coords,
                distance = store.registerDistance or Config.Security.registerDistance,
                label = Config.TargetOptions.storeLabel,
            }
            Target.AddZone({
                name = 'djws_store_' .. store.id,
                coords = store.coords,
                radius = 1.2,
                icon = Config.TargetOptions.icon,
                label = Config.TargetOptions.storeLabel,
                distance = store.registerDistance or Config.Security.registerDistance,
                onSelect = function()
                    DJWSClient.Open(store.id, 'catalog', nil)
                end,
            })
        end
    end
    for i = 1, #DJWSClient.Benches do
        local bench = DJWSClient.Benches[i]
        DJWSClient.Points[#DJWSClient.Points + 1] = {
            kind = 'bench',
            id = bench.id,
            storeId = bench.storeId,
            coords = vector3(bench.coords.x, bench.coords.y, bench.coords.z),
            distance = Config.Security.benchDistance,
            label = bench.label or Config.TargetOptions.benchLabel,
        }
    end
end

function DJWSClient.StartBenches()
    CreateThread(function()
        while true do
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local spawnAt = Config.Benches.spawnDistance or 80.0
            local despawnAt = Config.Benches.despawnDistance or 100.0
            for i = 1, #DJWSClient.Benches do
                local bench = DJWSClient.Benches[i]
                local dist = DJWS.Distance(pos, bench.coords)
                if dist <= spawnAt and not DJWSClient.Entities[bench.id] and not bench.invisible then
                    spawnBench(bench)
                elseif dist > despawnAt and DJWSClient.Entities[bench.id] then
                    deleteEntity(bench.id)
                elseif dist <= spawnAt and bench.invisible then
                    -- zone is persistent; nothing to stream
                end
            end
            Wait(1000)
        end
    end)
end

RegisterNetEvent(DJWS.Events.benches, function(list)
    if type(list) ~= 'table' then return end
    DJWSClient.ApplyBenches(list)
end)
