Bridge = {}

local framework, core

local function resolve()
    if framework then return end

    local fw = Config.Framework
    if fw == 'auto' then
        if GetResourceState('qbx_core') == 'started' then fw = 'qbox'
        elseif GetResourceState('qb-core') == 'started' then fw = 'qb'
        elseif GetResourceState('es_extended') == 'started' then fw = 'esx'
        else fw = 'standalone' end
    end

    if fw == 'qb' then
        core = exports['qb-core']:GetCoreObject()
    elseif fw == 'esx' then
        core = exports['es_extended']:getSharedObject()
    end

    framework = fw
end

function Bridge.GetIdentifier(src)
    resolve()

    if framework == 'qbox' then
        local player = exports.qbx_core:GetPlayer(src)
        return player and player.PlayerData.citizenid
    elseif framework == 'qb' then
        local player = core.Functions.GetPlayer(src)
        return player and player.PlayerData.citizenid
    elseif framework == 'esx' then
        local player = core.GetPlayerFromId(src)
        return player and player.identifier
    end

    return GetPlayerIdentifierByType(src, 'license')
end
