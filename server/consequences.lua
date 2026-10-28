local refusedUntil = {}

local function honorOf(src)
    local player = Player(src)
    return player and player.state.honor or 0
end

local function shouldRefuse(src, key, silent)
    src = tonumber(src)
    local cfg = Config.ShopRefusal
    if not src or not GetPlayerName(src) or not cfg or not cfg.enabled then return false end

    local chance = tonumber(Honor.GetPenalty('refuse_service', honorOf(src)))
    if not chance or chance <= 0 then return false end

    key = tostring(key or 'shop')
    local now = os.time()
    local memory = refusedUntil[src] and refusedUntil[src][key]
    local refuse = (memory and memory > now) or math.random(100) <= chance
    if not refuse then return false end

    refusedUntil[src] = refusedUntil[src] or {}
    refusedUntil[src][key] = now + (tonumber(cfg.memory) or 60)

    if not silent then
        TriggerClientEvent('pena_honor:client:refused', src)
        if cfg.notify ~= false and GetResourceState('ox_lib') == 'started' then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Honor',
                description = cfg.message or 'They refuse to serve you.',
                type = 'error',
            })
        end
    end
    return true
end

exports('ShouldRefuseService', shouldRefuse)

AddEventHandler('playerDropped', function()
    refusedUntil[source] = nil
end)

local registered = false

local function register()
    local cfg = Config.ShopRefusal
    if registered or not cfg or not cfg.enabled or GetResourceState('ox_inventory') ~= 'started' then return end

    local ok = pcall(function()
        exports.ox_inventory:registerHook('openShop', function(payload)
            if type(payload) ~= 'table' then return end
            if payload.shopType and cfg.excludeShops and cfg.excludeShops[payload.shopType] then return end

            local key = ('%s:%s'):format(payload.shopType or 'shop', payload.shopId or 1)
            if shouldRefuse(payload.source, key) then return false end
        end, {})
    end)

    registered = ok
end

AddEventHandler('onResourceStop', function(resource)
    if resource == 'ox_inventory' then registered = false end
end)

CreateThread(function()
    while true do
        if not registered then register() end
        Wait(5000)
    end
end)