--[[
    Shared result handling for inventory exports.

    An add/remove is successful only when the call does not throw and the
    export returns a truthy value. nil and false are failures. Inventories
    that return nil on success can be opted in per resource via
    Config.InventoryOptions.nilAddIsSuccess, after you have confirmed the
    item was actually created. Leaving that off avoids duplicate grants.
]]

DJWS = DJWS or {}

local warned = {}

local function warnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    DJWS.Error(message)
end

function DJWS.InterpretAdd(resource, ok, result)
    if not ok then
        warnOnce(resource .. ':add', ('%s AddItem failed: %s'):format(resource, tostring(result)))
        return false, 'export_error'
    end
    if result == false or result == nil then
        if result == nil and Config.InventoryOptions and Config.InventoryOptions.nilAddIsSuccess and Config.InventoryOptions.nilAddIsSuccess[resource] then
            return true, nil
        end
        return false, 'add_failed'
    end
    return true, result
end

function DJWS.InterpretRemove(resource, ok, result)
    if not ok then
        warnOnce(resource .. ':remove', ('%s RemoveItem failed: %s'):format(resource, tostring(result)))
        return false, 'export_error'
    end
    if result == false or result == nil then
        return false, 'remove_failed'
    end
    return true
end

function DJWS.InterpretCount(ok, result)
    if not ok then return 0 end
    if type(result) == 'number' then return result end
    if type(result) == 'table' then
        return tonumber(result.amount or result.count or result.qty) or 0
    end
    return 0
end

function DJWS.InterpretCarry(resource, ok, result)
    if not ok then
        warnOnce(resource .. ':carry', ('%s carry check is unavailable (%s). Crafting into this inventory is blocked until the export succeeds or you set a verified carry export.'):format(resource, tostring(result)))
        return false, 'carry_check_unverified'
    end
    if result == true then return true end
    if type(result) == 'number' and result > 0 then return true end
    if result == false or result == nil then return false, 'inventory_full' end
    return false, 'inventory_full'
end
