local scared = {}
local ignored = {}
for _, model in ipairs(Config.AutoDetect.ignoredPedModels or {}) do
    ignored[joaat(model)] = true
end

CreateThread(function()
    while true do
        local cfg = Config.NpcFear
        Wait((cfg and tonumber(cfg.interval)) or 2000)

        local radius = cfg and cfg.enabled and tonumber(Honor.GetPenalty('npc_fear', LocalPlayer.state.honor or 0))
        local now = GetGameTimer()

        for ped, time in pairs(scared) do
            if now - time > 30000 then scared[ped] = nil end
        end

        if radius and radius > 0 then
            local me = PlayerPedId()
            local coords = GetEntityCoords(me)
            local limit, count = radius * radius, 0

            for _, ped in ipairs(GetGamePool('CPed')) do
                if count >= (cfg.maxPerTick or 5) then break end

                if ped ~= me and not scared[ped] and IsPedHuman(ped) and not IsPedAPlayer(ped)
                    and not IsPedDeadOrDying(ped, true) and not IsPedInAnyVehicle(ped, false)
                    and not IsPedFleeing(ped) and not ignored[GetEntityModel(ped)] then
                    local t = GetPedType(ped)
                    local copOrGang = t == 6 or t == 27 or (t >= 7 and t <= 16)

                    if not copOrGang and not IsPedInCombat(ped, me) and NetworkHasControlOfEntity(ped) then
                        local delta = GetEntityCoords(ped) - coords
                        if (delta.x * delta.x + delta.y * delta.y + delta.z * delta.z) <= limit then
                            scared[ped] = now
                            count = count + 1
                            TaskReactAndFleePed(ped, me)
                        end
                    end
                end
            end
        end
    end
end)