DJWS = DJWS or {}

function DJWS.Ok(data)
    local out = data or {}
    out.ok = true
    return out
end

function DJWS.Fail(code, ...)
    return {
        ok = false,
        error = code,
        message = L(code, ...),
    }
end
