CraftClient = { playing = false }

function CraftClient.Skill(difficulty)
    local resource = Config.Crafting.skillCheck and Config.Crafting.skillCheck.resource or 'ox_lib'
    if GetResourceState(resource) ~= 'started' then
        return nil, true
    end
    local levels = { 'easy', 'easy', 'medium', 'medium', 'hard' }
    local level = levels[DJWS.Clamp(math.floor(tonumber(difficulty) or 2), 1, 5)]
    local ok, result = pcall(function()
        return exports[resource]:skillCheck({ level }, { 'w', 'a', 's', 'd' })
    end)
    if not ok then
        DJWS.Debug('Skill check export failed: ' .. tostring(result))
        return nil, true
    end
    return result == true, false
end

function CraftClient.Stop()
    CraftClient.playing = false
    local ped = PlayerPedId()
    ClearPedTasks(ped)
end

function CraftClient.Play(payload)
    CraftClient.Stop()
    local benchType = payload and payload.benchType or 'general'
    local anim = Config.Animations[benchType] or Config.Animations.general
    local duration = 0
    if payload and payload.endsAt and payload.serverNow then
        duration = math.max(1, payload.endsAt - payload.serverNow)
    end
    CraftClient.playing = true
    CreateThread(function()
        local ped = PlayerPedId()
        if Config.Crafting.preferScenario and Config.Scenarios[benchType] then
            TaskStartScenarioInPlace(ped, Config.Scenarios[benchType], 0, true)
        elseif anim and anim.dict and anim.anim then
            RequestAnimDict(anim.dict)
            local expire = GetGameTimer() + 3000
            while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < expire do Wait(20) end
            if HasAnimDictLoaded(anim.dict) then
                TaskPlayAnim(ped, anim.dict, anim.anim, 8.0, -8.0, duration * 1000, anim.flag or 1, 0.0, false, false, false)
            end
        end
        local ends = GetGameTimer() + (duration * 1000)
        while CraftClient.playing and GetGameTimer() < ends do
            Wait(200)
        end
        if not CraftClient.playing then return end
        CraftClient.Stop()
    end)
end

RegisterNetEvent(DJWS.Events.craft, function(payload)
    if type(payload) ~= 'table' then return end
    if payload.phase == 'running' then
        CraftClient.Play(payload)
    else
        CraftClient.Stop()
        if payload.message then
            local kind = payload.phase == 'done' and 'success' or 'error'
            Notify.Show(payload.message, kind)
        end
    end
    SendNUIMessage({ action = 'craft', data = payload })
end)
