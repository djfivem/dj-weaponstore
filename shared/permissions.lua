DJWS = DJWS or {}

DJWS.Permissions = {
    'dashboard',
    'manufacture',
    'recipes',
    'materials',
    'stock',
    'prices',
    'hire',
    'fire',
    'permissions',
    'withdraw',
    'benches',
    'reports',
    'settings',
    'deposit',
}

DJWS.PermissionSet = {}
for i = 1, #DJWS.Permissions do
    DJWS.PermissionSet[DJWS.Permissions[i]] = true
end

function DJWS.FilterPermissions(list)
    local out = {}
    local seen = {}
    if type(list) ~= 'table' then return out end
    for i = 1, #list do
        local name = list[i]
        if type(name) == 'string' and DJWS.PermissionSet[name] and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    return out
end

function DJWS.PermissionMap(list)
    local map = {}
    local filtered = DJWS.FilterPermissions(list)
    for i = 1, #filtered do
        map[filtered[i]] = true
    end
    return map
end
