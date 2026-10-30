NUI = { open = false }

function NUI.Open(state)
    NUI.open = true
    DJWSClient.Focused = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = state })
end

function NUI.Close()
    NUI.open = false
    DJWSClient.Focused = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function DJWSClient.Open(storeId, focus, benchId)
    Callback.Trigger('getState', { storeId = storeId, focus = focus, benchId = benchId }, function(state)
        if not state or not state.ok then
            Notify.Show((state and (state.message or state.error)) or L('too_far'), 'error')
            return
        end
        NUI.Open(state)
    end)
end

local function finishSkill(result, cb)
    if not result or not result.needSkill then
        cb(result or DJWS.Fail('no_response'))
        return
    end
    SetNuiFocus(false, false)
    local passed, unavailable = CraftClient.Skill(result.difficulty)
    if NUI.open then SetNuiFocus(true, true) end
    Callback.Trigger('submitSkill', {
        token = result.token,
        passed = passed == true,
        unavailable = unavailable == true,
    }, function(finalResult)
        cb(finalResult or DJWS.Fail('no_response'))
    end)
end

RegisterNUICallback('close', function(_, cb)
    NUI.Close()
    cb({ ok = true })
end)

RegisterNUICallback('rpc', function(body, cb)
    local action = body and body.action
    local payload = body and body.payload or {}
    if action == 'close' then
        NUI.Close()
        cb({ ok = true })
        return
    end
    if action == 'placeBench' or action == 'editBench' then
        NUI.Close()
        Placement.Start(payload)
        cb({ ok = true, message = 'Placement started' })
        return
    end
    Callback.Trigger(action, payload, function(result)
        if action == 'startCraft' then
            finishSkill(result, cb)
            return
        end
        cb(result or DJWS.Fail('no_response'))
    end)
end)

CreateThread(function()
    while true do
        if DJWSClient.Focused then
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 199, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)
