local function createBlips()
    for i = 1, #Config.Stores do
        local store = Config.Stores[i]
        if store.enabled ~= false and store.blip and store.blip.enabled ~= false then
            local blip = AddBlipForCoord(store.coords.x, store.coords.y, store.coords.z)
            SetBlipSprite(blip, store.blip.sprite or 110)
            SetBlipColour(blip, store.blip.color or 1)
            SetBlipScale(blip, store.blip.scale or 0.75)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(store.blip.label or store.label or 'DJ Weapon Store')
            EndTextCommandSetBlipName(blip)
        end
    end
end

local function requestIpls()
    if not Config.MLO or not Config.MLO.enabled then return end
    for _, interior in pairs(Config.MLO.interiors or {}) do
        if type(interior) == 'table' and interior.enabled and type(interior.ipl) == 'string' and interior.ipl ~= '' then
            RequestIpl(interior.ipl)
        end
    end
end

CreateThread(function()
    requestIpls()
    createBlips()
    DJWSClient.RebuildPoints()
    DJWSClient.StartBenches()
    Interact.Start()
    Wait(1500)
    Callback.Trigger('getBenches', {}, function(result)
        if result and result.ok and type(result.benches) == 'table' then
            DJWSClient.ApplyBenches(result.benches)
        end
    end)
end)

RegisterCommand(Config.Commands.place or 'djws_place', function()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for i = 1, #Config.Stores do
        local store = Config.Stores[i]
        if store.enabled ~= false then
            local dist = DJWS.Distance(pos, store.coords)
            local limit = (store.radius or 12.0) + (Config.Security.placementDistance or 8.0)
            if dist <= limit and (not bestDist or dist < bestDist) then
                best = store
                bestDist = dist
            end
        end
    end
    if not best then
        Notify.Show(L('too_far'), 'error')
        return
    end
    Callback.Trigger('getState', { storeId = best.id }, function(state)
        if not state or not state.ok then
            Notify.Show((state and (state.message or state.error)) or L('too_far'), 'error')
            return
        end
        local allowed = state.admin or state.owner or (state.perms and state.perms.benches)
        if not allowed then
            Notify.Show(L('no_permission'), 'error')
            return
        end
        Placement.Start({
            storeId = best.id,
            label = (best.label or 'Store') .. ' Bench',
            benchType = 'general',
            model = Config.Benches.defaults.general,
            output = 'stock',
            jobs = '',
            minGrade = 0,
            publicCraft = false,
            invisible = false,
        })
    end)
end, false)

RegisterCommand(Config.Commands.open or 'djws', function()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for i = 1, #Config.Stores do
        local store = Config.Stores[i]
        if store.enabled ~= false then
            local dist = DJWS.Distance(pos, store.coords)
            if dist <= (store.radius or 12.0) and (not bestDist or dist < bestDist) then
                best = store
                bestDist = dist
            end
        end
    end
    for i = 1, #DJWSClient.Benches do
        local bench = DJWSClient.Benches[i]
        local dist = DJWS.Distance(pos, bench.coords)
        if dist <= (Config.Security.benchDistance or 2.4) + 1.0 and (not bestDist or dist < bestDist) then
            DJWSClient.Open(bench.storeId, 'bench', bench.id)
            return
        end
    end
    if not best then
        Notify.Show(L('too_far'), 'error')
        return
    end
    DJWSClient.Open(best.id, 'catalog', nil)
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Placement.active = false
    for id, entity in pairs(DJWSClient.Entities) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
        DJWSClient.Entities[id] = nil
    end
    if Target and Target.Clear then Target.Clear() end
    if NUI and NUI.Close then NUI.Close() end
end)
