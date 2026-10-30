DJWSClient = DJWSClient or {}
DJWSClient.Benches = DJWSClient.Benches or {}
DJWSClient.Focused = false
DJWSClient.Entities = {}
DJWSClient.Points = {}

function DJWSClient.Hash(model)
    if type(model) == 'number' then return model end
    if joaat then return joaat(model) end
    return GetHashKey(model)
end
