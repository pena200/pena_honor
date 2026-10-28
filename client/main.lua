local currentHonor = nil
local sendConfig
local openToken = 0

local function playSound(key)
    local sounds = Config.Sounds
    if not sounds or not sounds.enabled then return end
    local sound = sounds[key]
    if type(sound) ~= 'table' or not sound[1] then return end
    PlaySoundFrontend(-1, sound[1], sound[2] or 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

local function titleFor(value)
    local tier = Honor.GetTier(value)
    return IsPedMale(PlayerPedId()) and tier.male or tier.female
end

local function display(to, from, delta, reason, toast)
    openToken = openToken + 1
    sendConfig()
    local tier, fromTier = Honor.GetTier(to), Honor.GetTier(from or to)
    SendNUIMessage({
        action   = 'show',
        from     = from or to,
        to       = to,
        delta    = delta,
        reason   = reason,
        toast    = toast,
        title    = titleFor(to),
        mood     = tier.mood,
        fromMood = fromTier.mood,
        fromTitle = titleFor(from or to),
        duration = Config.HUD.duration,
    })
end

function sendConfig()
    SendNUIMessage({
        action    = 'config',
        position  = Config.HUD.position,
        colors    = Config.Colors,
        min       = Config.MinHonor,
        max       = Config.MaxHonor,
        showValue = Config.HUD.showValue,
        notify    = Config.Notify,
    })
end

local function requestSync()
    TriggerServerEvent('pena_honor:server:sync')
end


RegisterNetEvent('pena_honor:client:sync', function(value)
    currentHonor = value
end)

RegisterNetEvent('pena_honor:client:changed', function(value, delta, reason)
    currentHonor = value
    playSound(delta > 0 and 'gain' or 'loss')
    display(value, value - delta, delta, reason, true)
end)

-- Reaching a better or worse tier
RegisterNetEvent('pena_honor:client:tierChanged', function(newTier, oldTier)
    local up = (Honor.TierIndex(newTier) or 0) > (Honor.TierIndex(oldTier) or 0)
    SetTimeout((Config.Sounds and Config.Sounds.tierDelay) or 700, function()
        playSound(up and 'tierUp' or 'tierDown')
    end)
end)

RegisterNetEvent('pena_honor:client:refused', function()
    playSound('refused')
end)

CreateThread(function()
    sendConfig()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(2000)
    requestSync()
end)

RegisterNetEvent('esx:playerLoaded', requestSync)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', requestSync)
AddEventHandler('playerSpawned', requestSync)


RegisterCommand('honor', function()
    local value = LocalPlayer.state.honor or currentHonor
    if not value then return requestSync() end
    display(value, value, 0, nil, false)
    playSound('open')

    local token = openToken
    SetTimeout(Config.HUD.duration, function()
        if token == openToken then playSound('close') end
    end)
end, false)

if Config.Keybind then
    RegisterKeyMapping('honor', 'Show honor', 'keyboard', Config.Keybind)
end

local function addRadial()
    local radial = Config.Radial
    if not radial or not radial.enabled or GetResourceState('ox_lib') ~= 'started' then return end
    pcall(function()
        exports.ox_lib:addRadialItem({
            id       = 'pena_honor',
            label    = radial.label or 'Honor',
            icon     = radial.icon or 'bolt',
            onSelect = function() ExecuteCommand('honor') end,
        })
    end)
end

addRadial()
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'ox_lib' then Wait(500) addRadial() end -- ox_lib started after us, or restarted
end)

exports('GetHonor', function()
    return LocalPlayer.state.honor or currentHonor or 0
end)

exports('GetBenefit', function(name)
    return Honor.GetBenefit(name, LocalPlayer.state.honor or currentHonor or 0)
end)

exports('GetPenalty', function(name)
    return Honor.GetPenalty(name, LocalPlayer.state.honor or currentHonor or 0)
end)

exports('HasTier', function(id)
    return Honor.HasTier(LocalPlayer.state.honor or currentHonor or 0, id)
end)

exports('ShowHonor', function()
    ExecuteCommand('honor')
end)

RegisterNUICallback('ready', function(_, cb)
    sendConfig()
    cb('ok')
end)

local ignored, handled, hitHandled, protectedAnimals = {}, {}, {}, {}
for _, model in ipairs(Config.AutoDetect.ignoredPedModels) do
    ignored[joaat(model)] = true
end
for _, model in ipairs(Config.AutoDetect.protectedAnimals) do
    protectedAnimals[joaat(model)] = true
end

local function isCop(ped)
    local t = GetPedType(ped)
    return t == 6 or t == 27 -- cop, swat
end

local function isHostile(victim, me)
    if IsPedInCombat(victim, me) then return true end
    if Config.AutoDetect.gangsAreHostile then
        local t = GetPedType(victim)
        if t >= 7 and t <= 16 then return true end -- gang peds
    end
    return false
end

local function report(key, victimId)
    Honor.Debug('client reports', key, victimId or '')
    TriggerServerEvent('pena_honor:server:auto', key, victimId)
end

AddEventHandler('gameEventTriggered', function(name, args)
    if not Config.AutoDetect.enabled or name ~= 'CEventNetworkEntityDamage' then return end

    local victim, attacker = args[1], args[2]
    local me = PlayerPedId()
    if victim == me then return end

    if attacker ~= me then
        if not (DoesEntityExist(attacker) and IsEntityAVehicle(attacker) and GetPedInVehicleSeat(attacker, -1) == me) then return end
    end

    if not DoesEntityExist(victim) or not IsEntityAPed(victim) then return end
    if ignored[GetEntityModel(victim)] then return end


    local fatal = args[4] == 1 or args[4] == true or args[6] == 1 or args[6] == true or IsPedDeadOrDying(victim, true)

    local isPlayer = IsPedAPlayer(victim)
    local now = GetGameTimer()
    Honor.Debug('you damaged ped', victim, 'fatal', fatal, 'player', isPlayer, 'human', IsPedHuman(victim), 'type', GetPedType(victim))

    if not isPlayer and not IsPedHuman(victim) then
        if fatal and protectedAnimals[GetEntityModel(victim)] then
            if handled[victim] and now - handled[victim] < 120000 then return end
            handled[victim] = now
            report('kill_animal')
        end
        return
    end

    if fatal then
        if handled[victim] and now - handled[victim] < 120000 then return end
        handled[victim] = now

        if isPlayer then
            local index = NetworkGetPlayerIndexFromPed(victim)
            local id = index ~= -1 and GetPlayerServerId(index) or nil
            if id and id > 0 then report('kill_player', id) end
        elseif isHostile(victim, me) then
            Honor.Debug('victim counted as hostile')
            if not isCop(victim) then report('kill_hostile') end
        elseif isCop(victim) then
            report('kill_cop')
        else
            report('kill_civilian')
        end
    elseif Config.AutoDetect.assault and not isPlayer then
        if hitHandled[victim] and now - hitHandled[victim] < 60000 then return end
        if isHostile(victim, me) then return end
        hitHandled[victim] = now
        report('hit_civilian')
    end
end)

CreateThread(function()
    local target, since, done, count = nil, 0, {}, 0
    while true do
        if Config.AutoDetect.enabled and Config.AutoDetect.threaten and IsPlayerFreeAiming(PlayerId()) then
            Wait(250)
            local ok, ent = GetEntityPlayerIsFreeAimingAt(PlayerId())
            local me = PlayerPedId()
            if ok and ent and DoesEntityExist(ent) and IsEntityAPed(ent) and not IsPedAPlayer(ent) and IsPedHuman(ent)
                and not IsPedDeadOrDying(ent, true) and not ignored[GetEntityModel(ent)] and not isHostile(ent, me) then
                local now = GetGameTimer()
                if ent ~= target then
                    target, since = ent, now
                elseif now - since >= 3000 and (not done[ent] or now - done[ent] > 60000) then
                    done[ent] = now
                    count = count + 1
                    if count > 200 then done, count = { [ent] = now }, 1 end
                    report('threaten_civilian')
                end
            else
                target = nil
            end
        else
            target = nil
            Wait(500)
        end
    end
end)

CreateThread(function()
    local jacked = {}
    while true do
        local me = PlayerPedId()
        if Config.AutoDetect.enabled and Config.AutoDetect.carjack and IsPedGettingIntoAVehicle(me) then
            local veh = GetVehiclePedIsEntering(me)
            if veh ~= 0 and GetSeatPedIsTryingToEnter(me) == -1 then
                local driver = GetPedInVehicleSeat(veh, -1)
                if driver ~= 0 and driver ~= me and not IsPedAPlayer(driver) and not IsPedDeadOrDying(driver, true)
                    and not ignored[GetEntityModel(driver)] then
                    local now = GetGameTimer()
                    if not jacked[veh] or now - jacked[veh] > 60000 then
                        jacked[veh] = now
                        report('carjack')
                    end
                end
            end
            Wait(200)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(120000)
        local now = GetGameTimer()
        for handle, time in pairs(handled) do
            if now - time > 120000 then handled[handle] = nil end
        end
        for handle, time in pairs(hitHandled) do
            if now - time > 60000 then hitHandled[handle] = nil end
        end
    end
end)