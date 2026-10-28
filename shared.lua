Honor = {}

-- Prints only when Config.Debug = true
function Honor.Debug(...)
    if Config.Debug then print('^3[pena_honor]^7', ...) end
end

function Honor.Clamp(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    return math.max(Config.MinHonor, math.min(Config.MaxHonor, value))
end

function Honor.GetTier(value)
    local found = Config.Tiers[1]
    for i = 1, #Config.Tiers do
        if value >= Config.Tiers[i].min then
            found = Config.Tiers[i]
        else
            break
        end
    end
    return found
end

-- Position of a tier in Config.Tiers (1 = lowest), or nil for an unknown id
function Honor.TierIndex(id)
    for i = 1, #Config.Tiers do
        if Config.Tiers[i].id == id then return i end
    end
end

-- True when the honor value is in the given tier or higher
function Honor.HasTier(value, id)
    local want = Honor.TierIndex(id)
    return want ~= nil and Honor.TierIndex(Honor.GetTier(value).id) >= want
end

-- Value of a Config.Benefits entry for an honor value. Only 'good' tiers ever give benefits.
function Honor.GetBenefit(name, value)
    local list = Config.Benefits and Config.Benefits[name]
    if not list then return nil end
    local tier = Honor.GetTier(value)
    if tier.mood ~= 'good' then return nil end
    return list[tier.id]
end

-- All benefits an honor value currently gives, as { name = value }
function Honor.GetBenefits(value)
    local out = {}
    for name in pairs(Config.Benefits or {}) do
        local v = Honor.GetBenefit(name, value)
        if v ~= nil then out[name] = v end
    end
    return out
end

-- Value of a Config.Penalties entry for an honor value. Only 'bad' tiers ever get penalties.
function Honor.GetPenalty(name, value)
    local list = Config.Penalties and Config.Penalties[name]
    if not list then return nil end
    local tier = Honor.GetTier(value)
    if tier.mood ~= 'bad' then return nil end
    return list[tier.id]
end

-- All penalties an honor value currently has, as { name = value }
function Honor.GetPenalties(value)
    local out = {}
    for name in pairs(Config.Penalties or {}) do
        local v = Honor.GetPenalty(name, value)
        if v ~= nil then out[name] = v end
    end
    return out
end

-- Defaults, so an older config.lua that lacks newer options keeps working
Config.HUD = Config.HUD or {}
if Config.HUD.position == nil then Config.HUD.position = 'bottom-center' end
if Config.HUD.duration == nil then Config.HUD.duration = 5000 end
if Config.HUD.showValue == nil then Config.HUD.showValue = false end
if Config.Keybind == nil then Config.Keybind = 'F7' end
Config.Radial = Config.Radial or { enabled = false }
Config.Sounds = Config.Sounds or { enabled = false }

Config.OutlawHonor = Config.OutlawHonor or -350
Config.Listeners = Config.Listeners or {}
Config.AutoDetect = Config.AutoDetect or { enabled = true }
Config.AutoDetect.ignoredPedModels = Config.AutoDetect.ignoredPedModels or {}
if Config.AutoDetect.assault == nil then Config.AutoDetect.assault = true end
if Config.AutoDetect.gangsAreHostile == nil then Config.AutoDetect.gangsAreHostile = true end
if Config.AutoDetect.threaten == nil then Config.AutoDetect.threaten = true end
if Config.AutoDetect.carjack == nil then Config.AutoDetect.carjack = true end
Config.AutoDetect.protectedAnimals = Config.AutoDetect.protectedAnimals or {}

Config.Benefits = Config.Benefits or {}
Config.Penalties = Config.Penalties or {}
Config.ShopRefusal = Config.ShopRefusal or { enabled = false }
Config.NpcFear = Config.NpcFear or { enabled = false }

Config.Notify = Config.Notify or {}
if Config.Notify.enabled == nil then Config.Notify.enabled = true end
Config.Notify.position = Config.Notify.position or 'top-right'
Config.Notify.duration = Config.Notify.duration or 4000
Config.Notify.max = Config.Notify.max or 3