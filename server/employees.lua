Employees = {}

local function gradeName(grade)
    return Config.Grades[grade] or ('Grade ' .. tostring(grade))
end

function Employees.List(storeId)
    local rows = DB.query('SELECT identifier, name, grade, hired_by, created_at FROM dj_ws_employees WHERE store_id = ? ORDER BY grade DESC, name ASC', { storeId }) or {}
    local perms = DB.query('SELECT identifier, permission FROM dj_ws_permissions WHERE store_id = ?', { storeId }) or {}
    local byIdent = {}
    for i = 1, #perms do
        local ident = perms[i].identifier
        byIdent[ident] = byIdent[ident] or {}
        byIdent[ident][#byIdent[ident] + 1] = perms[i].permission
    end
    local list = {}
    for i = 1, #rows do
        local row = rows[i]
        list[#list + 1] = {
            identifier = row.identifier,
            name = row.name,
            grade = tonumber(row.grade) or 0,
            gradeLabel = gradeName(tonumber(row.grade) or 0),
            hiredBy = row.hired_by,
            createdAt = row.created_at,
            online = Business.SourceByIdentifier(row.identifier) ~= nil,
            permissions = byIdent[row.identifier] or {},
        }
    end
    return list
end

local function replacePermissions(storeId, identifier, list)
    DB.update('DELETE FROM dj_ws_permissions WHERE store_id = ? AND identifier = ?', { storeId, identifier })
    for i = 1, #list do
        DB.insert('INSERT IGNORE INTO dj_ws_permissions (store_id, identifier, permission) VALUES (?, ?, ?)', {
            storeId, identifier, list[i],
        })
    end
end

function Employees.Hire(src, storeId, payload)
    local cfg = Business.Config(storeId)
    if not cfg or not Business.Row(storeId) then return DJWS.Fail('invalid_store') end
    if not Business.Has(src, storeId, 'hire') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'hire') then return DJWS.Fail('too_far') end
    local target = Security.Int(payload.target, 1, 4096)
    local grade = Security.Int(payload.grade, 0, Config.Business.maxGrade or 3) or 0
    if not target or target == src or not GetPlayerName(target) then return DJWS.Fail('player_offline') end
    if Config.Business.hireDistance and not Framework.IsAdmin(src) then
        local mine = Security.Coords(src)
        local theirs = Security.Coords(target)
        if not mine or not theirs or DJWS.Distance(mine, theirs) > Config.Business.hireDistance then
            return DJWS.Fail('too_far')
        end
    end
    local identifier = Framework.GetIdentifier(target)
    if not identifier then return DJWS.Fail('player_offline') end
    local row = Business.Row(storeId)
    if row.owner_identifier == identifier then return DJWS.Fail('already_employed') end
    local exists = DB.scalar('SELECT id FROM dj_ws_employees WHERE store_id = ? AND identifier = ?', { storeId, identifier })
    if exists then return DJWS.Fail('already_employed') end
    local name = Framework.GetName(target)
    local hiredBy = Framework.GetIdentifier(src)
    DB.insert('INSERT INTO dj_ws_employees (store_id, identifier, name, grade, hired_by) VALUES (?, ?, ?, ?, ?)', {
        storeId, identifier, name, grade, hiredBy,
    })
    local template = DJWS.FilterPermissions(Config.GradeTemplates[grade] or Config.GradeTemplates[0] or {})
    local actorMap = select(1, Business.PermissionMap(storeId, hiredBy, row))
    if not Framework.IsAdmin(src) and not Business.IsOwner(hiredBy, row) then
        local filtered = {}
        for i = 1, #template do
            if actorMap[template[i]] then filtered[#filtered + 1] = template[i] end
        end
        template = filtered
    end
    replacePermissions(storeId, identifier, template)
    Logs.Audit(storeId, hiredBy, 'hire', { identifier = identifier, name = name, grade = grade })
    Logs.Webhook('hire', 'Employee hired', {
        { name = 'Store', value = storeId },
        { name = 'Employee', value = name },
        { name = 'Grade', value = gradeName(grade) },
    })
    Framework.Notify(target, L('hired'), 'success')
    return DJWS.Ok({ message = L('hired'), employees = Employees.List(storeId) })
end

function Employees.Fire(src, storeId, payload)
    local cfg = Business.Config(storeId)
    if not cfg then return DJWS.Fail('invalid_store') end
    if not Business.Has(src, storeId, 'fire') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'fire') then return DJWS.Fail('too_far') end
    local identifier = Security.Text(payload.identifier, 80)
    if not identifier then return DJWS.Fail('player_offline') end
    local row = Business.Row(storeId)
    if row and row.owner_identifier == identifier then return DJWS.Fail('cannot_fire_owner') end
    DB.update('DELETE FROM dj_ws_permissions WHERE store_id = ? AND identifier = ?', { storeId, identifier })
    local affected = DB.affected(DB.update('DELETE FROM dj_ws_employees WHERE store_id = ? AND identifier = ?', { storeId, identifier }))
    if affected < 1 then return DJWS.Fail('player_offline') end
    local actor = Framework.GetIdentifier(src)
    Logs.Audit(storeId, actor, 'fire', { identifier = identifier })
    Logs.Webhook('fire', 'Employee fired', {
        { name = 'Store', value = storeId },
        { name = 'Employee', value = identifier },
    })
    return DJWS.Ok({ message = L('fired'), employees = Employees.List(storeId) })
end

function Employees.SetGrade(src, storeId, payload)
    local cfg = Business.Config(storeId)
    if not cfg then return DJWS.Fail('invalid_store') end
    if not Business.Has(src, storeId, 'hire') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'setGrade') then return DJWS.Fail('too_far') end
    local identifier = Security.Text(payload.identifier, 80)
    local grade = Security.Int(payload.grade, 0, Config.Business.maxGrade or 3)
    if not identifier or grade == nil then return DJWS.Fail('bad_quantity') end
    local affected = DB.affected(DB.update('UPDATE dj_ws_employees SET grade = ? WHERE store_id = ? AND identifier = ?', { grade, storeId, identifier }))
    if affected < 1 then return DJWS.Fail('player_offline') end
    if payload.applyTemplate == true then
        local template = DJWS.FilterPermissions(Config.GradeTemplates[grade] or {})
        replacePermissions(storeId, identifier, template)
    end
    Logs.Audit(storeId, Framework.GetIdentifier(src), 'grade', { identifier = identifier, grade = grade })
    return DJWS.Ok({ message = L('saved'), employees = Employees.List(storeId) })
end

function Employees.SetPermissions(src, storeId, payload)
    local cfg = Business.Config(storeId)
    if not cfg then return DJWS.Fail('invalid_store') end
    if not Business.Has(src, storeId, 'permissions') then return DJWS.Fail('no_permission') end
    if not Security.Gate(src, cfg, 'setPermissions') then return DJWS.Fail('too_far') end
    local identifier = Security.Text(payload.identifier, 80)
    if not identifier then return DJWS.Fail('player_offline') end
    local row = Business.Row(storeId)
    if row and row.owner_identifier == identifier then return DJWS.Fail('no_permission') end
    local employed = DB.scalar('SELECT id FROM dj_ws_employees WHERE store_id = ? AND identifier = ?', { storeId, identifier })
    if not employed then return DJWS.Fail('player_offline') end
    local requested = DJWS.FilterPermissions(payload.permissions or {})
    local actor = Framework.GetIdentifier(src)
    if not Framework.IsAdmin(src) and not Business.IsOwner(actor, row) then
        local actorMap = Business.PermissionMap(storeId, actor, row)
        for i = 1, #requested do
            if not actorMap[requested[i]] then
                return DJWS.Fail('no_permission')
            end
        end
    end
    replacePermissions(storeId, identifier, requested)
    Logs.Audit(storeId, actor, 'permissions', { identifier = identifier, permissions = requested })
    return DJWS.Ok({ message = L('saved'), employees = Employees.List(storeId) })
end
