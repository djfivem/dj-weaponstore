DB = { schemaReady = false }

function DB.available()
    return GetResourceState('oxmysql') == 'started'
end

function DB.ready()
    return DB.schemaReady == true
end

function DB.affected(result)
    if type(result) == 'number' then return result end
    if type(result) == 'table' then
        return tonumber(result.affectedRows or result.changedRows or 0) or 0
    end
    return 0
end

local function call(method, sql, params)
    if not DB.available() then return nil end
    local p = promise.new()
    local settled = false
    local function finish(value)
        if settled then return end
        settled = true
        p:resolve(value)
    end
    local ok, err = pcall(function()
        exports.oxmysql[method](sql, params or {}, finish)
    end)
    if not ok then
        DJWS.Error(('oxmysql %s failed: %s'):format(method, tostring(err)))
        return nil
    end
    SetTimeout(15000, function()
        if not settled then
            DJWS.Error('oxmysql ' .. method .. ' timed out')
            finish(nil)
        end
    end)
    return Citizen.Await(p)
end

function DB.query(sql, params)
    return call('query', sql, params)
end

function DB.single(sql, params)
    local result = call('single', sql, params)
    if type(result) == 'table' then return result end
    return nil
end

function DB.scalar(sql, params)
    local result = call('scalar', sql, params)
    if type(result) == 'table' then return result[1] end
    return result
end

function DB.insert(sql, params)
    local result = call('insert', sql, params)
    if type(result) == 'number' then return result end
    if type(result) == 'table' then return tonumber(result.insertId or result[1]) end
    return nil
end

function DB.update(sql, params)
    return call('update', sql, params)
end

local function statements(sql)
    local lines = {}
    for line in (sql .. '\n'):gmatch('(.-)\n') do
        if not line:match('^%s*%-%-') then
            lines[#lines + 1] = line
        end
    end
    local body = table.concat(lines, '\n')
    local out = {}
    for statement in body:gmatch('([^;]+);') do
        if statement:match('%S') then
            out[#out + 1] = statement
        end
    end
    return out
end

function DB.Install()
    if not DB.available() then return false end
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if not sql or sql == '' then
        DJWS.Error('sql/install.sql is missing. Tables were not created.')
        return false
    end
    local list = statements(sql)
    for i = 1, #list do
        local result = DB.query(list[i], {})
        if result == nil then
            DJWS.Error('Failed while creating tables. Check oxmysql and sql/install.sql.')
            return false
        end
    end
    DB.schemaReady = true
    print('[DJ Weapon Store] Database tables are ready.')
    return true
end
