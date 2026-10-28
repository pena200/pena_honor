local cache, pending, lastAuto, hourly, lastApplied = {}, {}, {}, {}, {}
local dbReady = false

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `pena_honor` (
            `identifier` VARCHAR(80) NOT NULL,
            `honor` INT NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`)
        )
    ]])
    dbReady = true
end)

local function save(entry, wait)
    if not entry or not entry.dirty then return end
    entry.dirty = false
    local query = 'INSERT INTO pena_honor (identifier, honor) VALUES (?, ?) ON DUPLICATE KEY UPDATE honor = VALUES(honor)'
    if wait then
        MySQL.insert.await(query, { entry.id, entry.honor })
    else
        MySQL.insert(query, { entry.id, entry.honor })
    end
end

local function publish(src, value)
    local player = Player(src)
    if not player then return end
    player.state:set('honor', value, true)
    player.state:set('honorTier', Honor.GetTier(value).id, true)
    player.state:set('honorPenalties', Honor.GetPenalties(value), true)
    player.state:set('honorBenefits', Honor.GetBenefits(value), true)
end

local function loadEntry(src)
    while not dbReady do Wait(100) end

    local id = Bridge.GetIdentifier(src)
    if not id then return nil end

    local entry = cache[src]
    if entry and entry.id == id then return entry end
    if entry then save(entry) end

    local row = MySQL.single.await('SELECT honor FROM pena_honor WHERE identifier = ?', { id })
    entry = { id = id, honor = Honor.Clamp(row and row.honor or Config.StartHonor), dirty = false }
    cache[src] = entry
    publish(src, entry.honor)
    return entry
end

local function log(src, delta, value, reason)
    if not Config.Webhook.enabled or Config.Webhook.url == '' then return end
    PerformHttpRequest(Config.Webhook.url, function() end, 'POST', json.encode({
        username = 'Honor Log',
        embeds = {{
            title = delta > 0 and 'Honor gained' or 'Honor lost',
            color = delta > 0 and 0x89CFF0 or 0xFF2E97,
            fields = {
                { name = 'Player', value = ('%s (%s)'):format(GetPlayerName(src) or 'unknown', src), inline = true },
                { name = 'Change', value = ('%+d -> %d'):format(delta, value), inline = true },
                { name = 'Reason', value = reason or 'n/a', inline = false },
            },
        }},
    }), { ['Content-Type'] = 'application/json' })
end

local function applyChange(src, amount, reason)
    local entry = loadEntry(src)
    if not entry then return Honor.Debug('no honor entry for', src, '(character not loaded yet?)') or false end

    local old = entry.honor
    local new = Honor.Clamp(old + amount)
    local oldTier = Honor.GetTier(old)
    local delta = new - old
    if delta == 0 then
        Honor.Debug(('no change for %s: honor is already %d (limit %d to %d)'):format(src, old, Config.MinHonor, Config.MaxHonor))
        return false
    end
    Honor.Debug(('honor change for %s: %d -> %d (%s)'):format(src, old, new, tostring(reason)))

    entry.honor, entry.dirty = new, true
    publish(src, new)

    TriggerClientEvent('pena_honor:client:changed', src, new, delta, reason)
    TriggerEvent(delta > 0 and 'pena_honor:honorAdded' or 'pena_honor:honorRemoved', src, delta, new, reason)
    log(src, delta, new, reason)

    local newTier = Honor.GetTier(new)
    if newTier.id ~= oldTier.id then
        TriggerEvent('pena_honor:tierChanged', src, newTier.id, oldTier.id, new)
        TriggerClientEvent('pena_honor:client:tierChanged', src, newTier.id, oldTier.id, new)
    end
    return true
end

local function AddHonor(src, amount, reason)
    src, amount = tonumber(src), tonumber(amount)
    if not src or not amount or amount == 0 or not GetPlayerName(src) then return false end

    if not Config.Pool.enabled then
        return applyChange(src, amount, reason)
    end

    local p = pending[src]
    if not p then
        p = { amount = 0, reasons = {}, seen = {} }
        pending[src] = p
    end
    p.amount = p.amount + amount
    if reason and not p.seen[reason] then
        p.seen[reason] = true
        p.reasons[#p.reasons + 1] = reason
    end
    return true
end

local function RemoveHonor(src, amount, reason)
    return AddHonor(src, -math.abs(tonumber(amount) or 0), reason)
end

local function GetHonor(src)
    local entry = loadEntry(tonumber(src))
    return entry and entry.honor or nil
end

local function SetHonor(src, value, reason)
    src = tonumber(src)
    local entry = src and loadEntry(src)
    if not entry then return false end
    return applyChange(src, Honor.Clamp(value) - entry.honor, reason or 'Set by admin')
end

local function ApplyAction(src, key)
    src = tonumber(src)
    local action = Config.Actions[key]
    if not src or not action or action.enabled == false then return false end

    local cooldownMs = action.cooldown and action.cooldown * 1000
    if cooldownMs then
        local last = lastApplied[src] and lastApplied[src][key]
        if last and GetGameTimer() - last < cooldownMs then return false end
    end

    if action.maxPerHour then
        local now = os.time()
        hourly[src] = hourly[src] or {}
        local h = hourly[src][key]
        if not h or now - h.start >= 3600 then
            h = { start = now, total = 0 }
            hourly[src][key] = h
        end
        local cost = math.abs(action.amount)
        if h.total + cost > action.maxPerHour then return false end
        h.total = h.total + cost
    end

    if cooldownMs then
        lastApplied[src] = lastApplied[src] or {}
        lastApplied[src][key] = GetGameTimer()
    end

    return AddHonor(src, action.amount, action.label)
end

exports('AddHonor', AddHonor)
exports('RemoveHonor', RemoveHonor)
exports('GetHonor', GetHonor)
exports('SetHonor', SetHonor)
exports('ApplyAction', ApplyAction)

local registeredBy = {}

exports('RegisterAction', function(key, def)
    local resource = GetInvokingResource() or GetCurrentResourceName()
    if type(key) ~= 'string' or key == '' or type(def) ~= 'table' then return false end

    local amount = tonumber(def.amount)
    if not amount or amount == 0 then return false end
    if Config.Actions[key] and registeredBy[key] ~= resource then return false end -- never overwrite config.lua actions

    Config.Actions[key] = {
        label      = tostring(def.label or key),
        amount     = amount,
        maxPerHour = tonumber(def.maxPerHour),
        cooldown   = tonumber(def.cooldown),
    }
    registeredBy[key] = resource
    return true
end)

exports('GetActions', function()
    local copy = {}
    for key, action in pairs(Config.Actions) do
        copy[key] = { label = action.label, amount = action.amount, maxPerHour = action.maxPerHour, cooldown = action.cooldown, enabled = action.enabled ~= false }
    end
    return copy
end)

AddEventHandler('onResourceStop', function(resource)
    for key, owner in pairs(registeredBy) do
        if owner == resource then
            Config.Actions[key], registeredBy[key] = nil, nil
        end
    end
end)
exports('GetTier', function(src)
    local value = GetHonor(src)
    return value and Honor.GetTier(value) or nil
end)


CreateThread(function()
    while true do
        Wait(Config.Pool.interval)
        for src, p in pairs(pending) do
            pending[src] = nil
            if GetPlayerName(src) then
                applyChange(src, p.amount, table.concat(p.reasons, ', '))
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        for _, entry in pairs(cache) do save(entry) end
    end
end)


RegisterNetEvent('pena_honor:server:sync', function()
    local src = source
    local entry = loadEntry(src)
    if entry then TriggerClientEvent('pena_honor:client:sync', src, entry.honor) end
end)

RegisterNetEvent('pena_honor:server:auto', function(key, victimId)
    local src = source
    local action = type(key) == 'string' and Config.Actions[key]
    Honor.Debug('server received', src, key, victimId or '')
    if not action or not action.auto then return Honor.Debug('rejected: unknown or non-auto action', key) end

    local now = GetGameTimer()
    lastAuto[src] = lastAuto[src] or {}
    if lastAuto[src][key] and now - lastAuto[src][key] < Config.AutoCooldown then return Honor.Debug('rejected: cooldown', key) end
    lastAuto[src][key] = now

    if key == 'kill_player' then
        victimId = tonumber(victimId)
        if not victimId or victimId == src or not GetPlayerName(victimId) then return end

        local a, b = GetEntityCoords(GetPlayerPed(src)), GetEntityCoords(GetPlayerPed(victimId))
        if #(a - b) > 300.0 then return end

        local victim = cache[victimId]
        if victim and victim.honor <= Config.OutlawHonor then key = 'kill_outlaw' end
    end

    Honor.Debug('applied', key, ApplyAction(src, key))
end)

for _, l in ipairs(Config.Listeners) do
    if l.event and l.action and Config.Actions[l.action] then
        AddEventHandler(l.event, function(...)
            local target = l.useSource and source or select(l.arg or 1, ...)
            ApplyAction(target, l.action)
        end)
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    save(cache[src])
    cache[src], pending[src], lastAuto[src], hourly[src], lastApplied[src] = nil, nil, nil, nil, nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, entry in pairs(cache) do save(entry, true) end
end)

local function reply(src, msg)
    if src == 0 then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'Honor', msg } }) end
end

local function adminCommand(name, handler)
    RegisterCommand(name, function(src, args)
        if src ~= 0 and not IsPlayerAceAllowed(src, 'pena_honor.admin') then return end
        local target, value = tonumber(args[1]), tonumber(args[2])
        if not target or not value or not GetPlayerName(target) then
            return reply(src, ('Usage: /%s [id] [amount]'):format(name))
        end
        handler(target, value)
        if Config.AdminChatFeedback then
            reply(src, ('%s now has %s honor.'):format(GetPlayerName(target), tostring(GetHonor(target))))
        end
    end, false)
end

adminCommand('sethonor', function(target, value) SetHonor(target, value) end)
adminCommand('addhonor', function(target, value) applyChange(target, value, 'Added by admin') end)
RegisterCommand('honoraction', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'pena_honor.admin') then return end
    local target, key = tonumber(args[1]), args[2]
    if not target or not key or not GetPlayerName(target) or not Config.Actions[key] then
        return reply(src, 'Usage: /honoraction [id] [action]')
    end
    ApplyAction(target, key)
end, false)