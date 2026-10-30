DJWS = DJWS or {}

function DJWS.Debug(message)
    if Config and Config.Debug then
        print('[DJ Weapon Store] ' .. tostring(message))
    end
end

function DJWS.Error(message)
    print('[DJ Weapon Store] ' .. tostring(message))
end

function DJWS.CopyList(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for i = 1, #list do
        local row = list[i]
        if type(row) == 'table' then
            out[#out + 1] = {
                item = row.item,
                count = tonumber(row.count) or 0,
            }
        end
    end
    return out
end

function DJWS.Serial()
    local charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    local chars = { 'D', 'J' }
    for _ = 1, 8 do
        local index = math.random(1, #charset)
        chars[#chars + 1] = charset:sub(index, index)
    end
    return table.concat(chars)
end

function DJWS.Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function DJWS.Distance(a, b)
    if not a or not b then return 9999.0 end
    local ax, ay, az = a.x or a[1], a.y or a[2], a.z or a[3]
    local bx, by, bz = b.x or b[1], b.y or b[2], b.z or b[3]
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

function DJWS.CoordsTable(value)
    if not value then return nil end
    return { x = value.x + 0.0, y = value.y + 0.0, z = value.z + 0.0 }
end

function DJWS.Now()
    return os.time()
end
