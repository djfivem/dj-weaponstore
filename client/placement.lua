Placement = { active = false }

local function cameraDirection()
    local rot = GetGameplayCamRot(2)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function raycast()
    local cam = GetGameplayCamCoord()
    local dir = cameraDirection()
    local dest = cam + (dir * 10.0)
    local handle = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1 + 16, PlayerPedId(), 0)
    local _, hit, coords = GetShapeTestResult(handle)
    if hit == 1 then return coords end
    return dest
end

local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function Placement.Start(payload)
    if Placement.active then return end
    if type(payload) ~= 'table' then return end
    Placement.active = true
    local modelName = payload.model or (Config.Benches.defaults and Config.Benches.defaults[payload.benchType]) or Config.Benches.fallbackModel
    local hashed = DJWSClient.Hash(modelName)
    if not IsModelInCdimage(hashed) then
        modelName = Config.Benches.fallbackModel
        hashed = DJWSClient.Hash(modelName)
    end
    RequestModel(hashed)
    local expire = GetGameTimer() + 3000
    while not HasModelLoaded(hashed) and GetGameTimer() < expire do Wait(20) end
    if not HasModelLoaded(hashed) then
        Placement.active = false
        Notify.Show(L('bad_model'), 'error')
        return
    end
    local start = GetEntityCoords(PlayerPedId())
    if payload.coords then
        start = vector3(payload.coords.x, payload.coords.y, payload.coords.z)
    end
    local preview = CreateObject(hashed, start.x, start.y, start.z, false, false, false)
    SetEntityAlpha(preview, 180, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)
    local heading = tonumber(payload.heading) or GetEntityHeading(PlayerPedId())
    local zOffset = tonumber(payload.zOffset) or 0.0
    CreateThread(function()
        while Placement.active do
            local hit = raycast()
            SetEntityCoordsNoOffset(preview, hit.x, hit.y, hit.z + zOffset, false, false, false)
            SetEntityHeading(preview, heading)
            help('Scroll rotate  |  Arrows height  |  Enter save  |  Backspace cancel')
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            if IsControlJustPressed(0, 14) then heading = (heading + 5.0) % 360.0 end
            if IsControlJustPressed(0, 15) then heading = (heading - 5.0) % 360.0 end
            if IsControlPressed(0, 172) then zOffset = zOffset + 0.01 end
            if IsControlPressed(0, 173) then zOffset = zOffset - 0.01 end
            if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) then
                local coords = GetEntityCoords(preview)
                Placement.active = false
                DeleteEntity(preview)
                Callback.Trigger('saveBench', {
                    id = payload.id,
                    storeId = payload.storeId,
                    label = payload.label,
                    benchType = payload.benchType,
                    model = modelName,
                    x = coords.x,
                    y = coords.y,
                    z = coords.z - zOffset,
                    heading = heading,
                    zOffset = zOffset,
                    output = payload.output,
                    jobs = payload.jobs,
                    minGrade = payload.minGrade,
                    invisible = payload.invisible,
                    publicCraft = payload.publicCraft,
                }, function(result)
                    Notify.Show((result and (result.message or result.error)) or L('bench_saved'), result and result.ok and 'success' or 'error')
                end)
            elseif IsControlJustPressed(0, 194) or IsControlJustPressed(0, 202) then
                Placement.active = false
                DeleteEntity(preview)
                Notify.Show(L('placement_cancelled'), 'error')
            end
            Wait(0)
        end
        if DoesEntityExist(preview) then DeleteEntity(preview) end
        SetModelAsNoLongerNeeded(hashed)
    end)
end
