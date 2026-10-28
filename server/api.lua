local function honorOf(src)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return nil end
    local player = Player(src)
    return player and player.state.honor
end

-- exports.pena_honor:GetBenefit(src, 'your_benefit') -> value from Config.Benefits, or nil
exports('GetBenefit', function(src, name)
    local value = honorOf(src)
    return value and Honor.GetBenefit(name, value) or nil
end)

-- exports.pena_honor:GetBenefits(src) -> { name = value, ... } for everything the player currently qualifies for
exports('GetBenefits', function(src)
    local value = honorOf(src)
    return value and Honor.GetBenefits(value) or {}
end)

-- exports.pena_honor:GetPenalty(src, 'refuse_service') -> value from Config.Penalties, or nil (only bad honor has penalties)
exports('GetPenalty', function(src, name)
    local value = honorOf(src)
    return value and Honor.GetPenalty(name, value) or nil
end)

-- exports.pena_honor:GetPenalties(src) -> { name = value, ... }
exports('GetPenalties', function(src)
    local value = honorOf(src)
    return value and Honor.GetPenalties(value) or {}
end)

-- exports.pena_honor:HasTier(src, 'honorable') -> true when the player is in that tier or higher
exports('HasTier', function(src, id)
    local value = honorOf(src)
    return value ~= nil and Honor.HasTier(value, id)
end)

-- exports.pena_honor:HasMinHonor(src, 350) -> true when the player's honor is at least that value
exports('HasMinHonor', function(src, minimum)
    local value = honorOf(src)
    return value ~= nil and value >= (tonumber(minimum) or 0)
end)