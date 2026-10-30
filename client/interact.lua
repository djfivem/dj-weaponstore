Interact = {}

local function nearest()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for i = 1, #DJWSClient.Points do
        local point = DJWSClient.Points[i]
        local dist = DJWS.Distance(pos, point.coords)
        if dist <= (point.distance or 2.5) and (not bestDist or dist < bestDist) then
            best = point
            bestDist = dist
        end
    end
    return best
end

function Interact.Start()
    CreateThread(function()
        while true do
            local sleep = 1000
            if not Target.UsingTarget() and not DJWSClient.Focused and not Placement.active then
                local point = nearest()
                if point then
                    sleep = 0
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(('Press ~INPUT_CONTEXT~ — %s'):format(point.label or 'DJ Weapon Store'))
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) then
                        if point.kind == 'bench' then
                            DJWSClient.Open(point.storeId, 'bench', point.id)
                        else
                            DJWSClient.Open(point.id, 'catalog', nil)
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)
end
