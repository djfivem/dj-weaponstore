Recipes = {}

function Recipes.BenchAllows(benchType, entry)
    local allowed = Config.BenchCategories and Config.BenchCategories[benchType]
    if not allowed or not entry then return false end
    if allowed[entry.family] or allowed[entry.category] then return true end
    return false
end

function Recipes.Default(entry)
    local spec = Pricing.For(entry)
    local override = Config.RecipeOverrides and Config.RecipeOverrides[entry.id] or nil
    local materials
    if type(override) == 'table' and type(override.materials) == 'table' then
        materials = override.materials
    else
        materials = Config.RecipeSets[entry.family] or Config.RecipeSets.custom
    end

    local output = 1
    if entry.kind == 'ammo' then
        output = math.floor(tonumber(Config.Ammo and Config.Ammo.batch) or 30)
    end
    if type(override) == 'table' and override.output then
        output = math.floor(tonumber(override.output) or output)
    end
    if output < 1 then output = 1 end

    local enabled = entry.craftable ~= false
    if type(override) == 'table' and override.enabled == false then
        enabled = false
    end

    return {
        catalogId = entry.id,
        materials = DJWS.CopyList(materials),
        time = type(override) == 'table' and math.floor(tonumber(override.time) or spec.time) or spec.time,
        xp = type(override) == 'table' and math.floor(tonumber(override.xp) or spec.xp) or spec.xp,
        difficulty = type(override) == 'table' and math.floor(tonumber(override.difficulty) or spec.difficulty) or spec.difficulty,
        quality = spec.quality,
        bench = (type(override) == 'table' and override.bench) or entry.bench,
        enabled = enabled,
        output = output,
        unlockXp = type(override) == 'table' and math.floor(tonumber(override.unlockXp) or 0) or 0,
    }
end
