Pricing = {}

local function copyQuality(quality)
    if type(quality) ~= 'table' then
        return { min = 70, max = 100 }
    end
    local minQ = math.floor(tonumber(quality.min) or 70)
    local maxQ = math.floor(tonumber(quality.max) or 100)
    if maxQ < minQ then maxQ = minQ end
    return { min = DJWS.Clamp(minQ, 1, 100), max = DJWS.Clamp(maxQ, 1, 100) }
end

function Pricing.For(entry)
    local family = entry.family or entry.category or 'custom'
    local base = Config.Pricing[family] or Config.Pricing.custom
    local price = math.floor(tonumber(base.price) or 0)
    local minPrice = math.floor(tonumber(base.min) or 0)
    local maxPrice = math.floor(tonumber(base.max) or price)
    local time = math.floor(tonumber(base.time) or 30)
    local xp = math.floor(tonumber(base.xp) or 0)
    local difficulty = math.floor(tonumber(base.difficulty) or 1)
    local quality = copyQuality(base.quality)

    if entry.category == 'variants' then
        local multiplier = tonumber(Config.Pricing.variantMultiplier) or 1.0
        price = math.floor(price * multiplier)
        minPrice = math.floor(minPrice * multiplier)
        maxPrice = math.floor(maxPrice * multiplier)
    end

    local override = Config.PriceOverrides and Config.PriceOverrides[entry.id]
    if type(override) == 'table' then
        price = math.floor(tonumber(override.price) or price)
        minPrice = math.floor(tonumber(override.min) or minPrice)
        maxPrice = math.floor(tonumber(override.max) or maxPrice)
        time = math.floor(tonumber(override.time) or time)
        xp = math.floor(tonumber(override.xp) or xp)
        difficulty = math.floor(tonumber(override.difficulty) or difficulty)
        if override.quality then quality = copyQuality(override.quality) end
    end

    if minPrice > maxPrice then minPrice = maxPrice end
    price = DJWS.Clamp(price, minPrice, maxPrice)
    difficulty = DJWS.Clamp(difficulty, 1, 5)
    if time < 1 then time = 1 end

    return {
        price = price,
        min = minPrice,
        max = maxPrice,
        time = time,
        xp = xp,
        difficulty = difficulty,
        quality = quality,
    }
end
