Benches = { Cache = {} }

local function project(row)
    return {
        id = tonumber(row.id),
        storeId = row.store_id,
        label = row.label,
        benchType = row.bench_type,
        model = row.model,
        coords = { x = tonumber(row.x) or 0.0, y = tonumber(row.y) or 0.0, z = tonumber(row.z) or 0.0 },
        heading = tonumber(row.heading) or 0.0,
        zOffset = tonumber(row.z_offset) or 0.0,
        output = row.output_mode or 'stock',
        jobs = row.jobs or '',
        minGrade = tonumber(row.min_grade) or 0,
        invisible = row.invisible == 1 or row.invisible == true,
        publicCraft = row.public_craft == 1 or row.public_craft == true,
    }
end

function Benches.Reload()
    local rows = DB.query('SELECT * FROM dj_ws_benches', {}) or {}
    local list = {}
    for i = 1, #rows do
        list[#list + 1] = project(rows[i])
    end
    Benches.Cache = list
    TriggerClientEvent(DJWS.Events.benches, -1, list)
    return list
end

function Benches.ForStore(storeId)
    local list = {}
    for i = 1, #Benches.Cache do
        if Benches.Cache[i].storeId == storeId then
            list[#list + 1] = Benches.Cache[i]
        end
    end
    return list
end

function Benches.Get(id)
    id = tonumber(id)
    if not id then return nil end
    for i = 1, #Benches.Cache do
        if Benches.Cache[i].id == id then return Benches.Cache[i] end
    end
    return nil
end

function Benches.JobOk(src, bench)
    if not bench.jobs or bench.jobs == '' then return true end
    local job = Framework.GetJob(src)
    for name in string.gmatch(bench.jobs, '([^,]+)') do
        local trimmed = name:gsub('%s+', '')
        if trimmed ~= '' and trimmed == job.name and (job.grade or 0) >= (bench.minGrade or 0) then
            return true
        end
    end
    return false
end

local function validPayload(src, payload, existing)
    local storeId = existing and existing.storeId or Security.Text(payload.storeId, 64)
    local cfg = storeId and Business.Config(storeId)
    if not cfg then return nil, 'invalid_store' end
    if not Business.Has(src, storeId, 'benches') then return nil, 'no_permission' end
    if not (Config.Admin.allowOwnerPlacement or Framework.IsAdmin(src) or Business.Has(src, storeId, 'benches')) then
        return nil, 'no_permission'
    end
    local benchType = Security.Text(payload.benchType, 32) or (existing and existing.benchType)
    local model = Security.Text(payload.model, 80) or (existing and existing.model)
    if not benchType or not Config.Benches.types[benchType] then return nil, 'invalid_bench' end
    if not model or not Config.Benches.models[model] then return nil, 'bad_model' end
    local x = tonumber(payload.x)
    local y = tonumber(payload.y)
    local z = tonumber(payload.z)
    if not x or not y or not z then return nil, 'too_far' end
    local coords = { x = x, y = y, z = z }
    local maxDist = Config.Security.placementDistance or 8.0
    if Framework.IsAdmin(src) then maxDist = maxDist + 40.0 end
    if not Security.NearCoords(src, coords, maxDist) then return nil, 'too_far' end
    local heading = tonumber(payload.heading) or 0.0
    local zOffset = tonumber(payload.zOffset) or 0.0
    heading = heading % 360.0
    zOffset = DJWS.Clamp(zOffset, -2.0, 3.0)
    local output = payload.output == 'player' and 'player' or 'stock'
    local publicCraft = payload.publicCraft == true and output == 'player'
    local jobs = ''
    if type(payload.jobs) == 'string' then
        jobs = payload.jobs:gsub('[^%w_,]', ''):sub(1, 200)
    end
    local minGrade = Security.Int(payload.minGrade, 0, 20) or 0
    local label = Security.Text(payload.label, 80) or (existing and existing.label) or (cfg.label .. ' Bench')
    return {
        storeId = storeId,
        label = label,
        benchType = benchType,
        model = model,
        x = x, y = y, z = z,
        heading = heading,
        zOffset = zOffset,
        output = output,
        jobs = jobs,
        minGrade = minGrade,
        invisible = payload.invisible == true,
        publicCraft = publicCraft,
    }
end

function Benches.Save(src, payload)
    if not DB.ready() then return DJWS.Fail('database_unavailable') end
    local existing = payload.id and Benches.Get(payload.id) or nil
    local data, err = validPayload(src, payload, existing)
    if not data then return DJWS.Fail(err or 'invalid_bench') end
    local identifier = Framework.GetIdentifier(src)
    if existing then
        DB.update([[UPDATE dj_ws_benches SET label = ?, bench_type = ?, model = ?, x = ?, y = ?, z = ?, heading = ?, z_offset = ?,
            output_mode = ?, jobs = ?, min_grade = ?, invisible = ?, public_craft = ? WHERE id = ? AND store_id = ?]], {
            data.label, data.benchType, data.model, data.x, data.y, data.z, data.heading, data.zOffset,
            data.output, data.jobs, data.minGrade, data.invisible and 1 or 0, data.publicCraft and 1 or 0,
            existing.id, data.storeId,
        })
    else
        DB.insert([[INSERT INTO dj_ws_benches
            (store_id, label, bench_type, model, x, y, z, heading, z_offset, output_mode, jobs, min_grade, invisible, public_craft, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            data.storeId, data.label, data.benchType, data.model, data.x, data.y, data.z, data.heading, data.zOffset,
            data.output, data.jobs, data.minGrade, data.invisible and 1 or 0, data.publicCraft and 1 or 0, identifier,
        })
    end
    Benches.Reload()
    Logs.Audit(data.storeId, identifier, 'bench_save', data)
    Logs.Webhook('bench', 'Bench saved', {
        { name = 'Store', value = data.storeId },
        { name = 'Type', value = data.benchType },
        { name = 'By', value = identifier or tostring(src) },
    })
    return DJWS.Ok({ message = L('bench_saved'), benches = Benches.ForStore(data.storeId) })
end

function Benches.Delete(src, payload)
    if not DB.ready() then return DJWS.Fail('database_unavailable') end
    local bench = Benches.Get(payload.id)
    if not bench then return DJWS.Fail('invalid_bench') end
    if not Business.Has(src, bench.storeId, 'benches') then return DJWS.Fail('no_permission') end
    local cfg = Business.Config(bench.storeId)
    if not cfg or not Security.Gate(src, cfg, 'deleteBench') then return DJWS.Fail('too_far') end
    DB.update('DELETE FROM dj_ws_benches WHERE id = ?', { bench.id })
    Benches.Reload()
    Logs.Audit(bench.storeId, Framework.GetIdentifier(src), 'bench_delete', { id = bench.id })
    Logs.Webhook('bench', 'Bench removed', { { name = 'Store', value = bench.storeId }, { name = 'Bench', value = bench.label } })
    return DJWS.Ok({ message = L('bench_removed'), benches = Benches.ForStore(bench.storeId) })
end
