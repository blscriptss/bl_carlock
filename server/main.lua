local sendToAllLoggers = require 'server.logger'


local lockCooldown = {}

local function isOnCooldown(src)
    local now = os.time()
    if lockCooldown[src] and (now - lockCooldown[src]) < 2 then  -- 2 seconds cooldown
        return true
    end
    lockCooldown[src] = now
    return false
end



Config = Config or {}
Config.RequireKeyItem = Config.RequireKeyItem ~= nil and Config.RequireKeyItem or false
Config.KeyItemName = Config.KeyItemName or 'vehiclekey'
Config.Inventory = Config.Inventory or 'qb' -- 'qb' | 'ox' | 'qs'
Config.Debug = Config.Debug or false

local function dbg(msg)
    if Config.Debug then
        print(('[bl_carlock][DEBUG] %s'):format(msg))
    end
end

local Framework = { type = 'standalone', QBCore = nil, ESX = nil }

local function tryGetQBCore()
    local state_qb = GetResourceState('qb-core')
    local state_qbx = GetResourceState('qbx-core')
    if state_qb == 'started' or state_qbx == 'started' then
        local ok, obj = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and obj then
            return obj
        end
    end
    return nil
end

local function tryGetESX()
    local esxNames = { 'es_extended', 'esx_framework' }
    for _, name in ipairs(esxNames) do
        if GetResourceState(name) == 'started' then
            local ok, obj = pcall(function()
                return exports[name]:getSharedObject()
            end)
            if ok and obj then
                return obj
            end
        end
    end
    return nil
end

CreateThread(function()
    Framework.QBCore = tryGetQBCore()
    if Framework.QBCore then
        Framework.type = 'qb'
        dbg('Detected QBCore')
        return
    end

    Framework.ESX = tryGetESX()
    if Framework.ESX then
        Framework.type = 'esx'
        dbg('Detected ESX')
        return
    end

    Framework.type = 'standalone'
    dbg('Running in Standalone mode')
end)

function isPlayerVehicle(src, plate)
    if Framework.QBCore then
        local player = Framework.QBCore.Functions.GetPlayer(src)
        if not player then return false end
        local citizenid = player.PlayerData.citizenid
        local result = MySQL.Sync.fetchScalar([[
            SELECT COUNT(*) FROM player_vehicles WHERE plate = @plate AND citizenid = @citizenid
        ]], {
            ['@plate'] = plate,
            ['@citizenid'] = citizenid
        })
        return result and result > 0
    elseif Framework.ESX then
        local xPlayer = Framework.ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        local identifier = xPlayer.getIdentifier and xPlayer:getIdentifier() or xPlayer.identifier
        local result = MySQL.Sync.fetchScalar([[
            SELECT COUNT(*) FROM owned_vehicles WHERE plate = @plate AND owner = @identifier
        ]], {
            ['@plate'] = plate,
            ['@identifier'] = identifier
        })
        return result and result > 0
    end

    return false
end


local function hasKeyItem_qb(src)
    if not Framework.QBCore then
        return false
    end
    local Player = Framework.QBCore.Functions.GetPlayer(src)
    if not Player then
        return false
    end
    if Config.Inventory == 'ox' then
        local count = exports.ox_inventory:Search(src, 'count', Config.KeyItemName)
        return (count or 0) > 0
    elseif Config.Inventory == 'qb' then
        local item = Player.Functions.GetItemByName(Config.KeyItemName)
        return item ~= nil
    elseif Config.Inventory == 'qs' then
        local qs = exports['qs-inventory']
        if qs and qs.GetItemCount then
            local count = qs:GetItemCount(src, Config.KeyItemName)
            return (count or 0) > 0
        end
        return false
    end
    return false
end

local function hasKeyItem_esx(src)
    if not Framework.ESX then
        return false
    end
    local xPlayer = Framework.ESX.GetPlayerFromId(src)
    if not xPlayer then
        return false
    end
    -- ESX inventory item
    local item = xPlayer.getInventoryItem and xPlayer:getInventoryItem(Config.KeyItemName) or nil
    if item and item.count and item.count > 0 then
        return true
    end
    return false
end


local function checkHasVehicleKey(src)
    if not Config.RequireKeyItem then
        return true
    end

    if Framework.type == 'qb' then
        return hasKeyItem_qb(src)
    elseif Framework.type == 'esx' then
        return hasKeyItem_esx(src)
    else
        return false
    end
end

local function registerQBCoreCallback()
    if Framework.QBCore and Framework.QBCore.Functions and Framework.QBCore.Functions.CreateCallback then
        Framework.QBCore.Functions.CreateCallback('bl_carlock:server:hasVehicleKey', function(source, cb)
            local hasKey = checkHasVehicleKey(source)
            cb(hasKey)
        end)
        dbg('Registered QBCore callback bl_carlock:server:hasVehicleKey')
    end
end

CreateThread(function()
    Wait(500)
    registerQBCoreCallback()
end)

    RegisterNetEvent('bl_carlock:server:hasVehicleKeyReq', function(token)
    local src = source
    if isOnCooldown(src) then
        print(('[bl_carlock] Player %s is spamming lock/unlock'):format(src))
        return
    end

    local hasKey = checkHasVehicleKey(src)
    TriggerClientEvent('bl_carlock:client:hasVehicleKeyResp', src, token, hasKey)
end)

RegisterNetEvent('bl_carlock:server:toggleLock', function(plate, vehicleNet, newLockState)
    local src = source
    if isOnCooldown(src) then
        print(('[bl_carlock] Player %s is spamming lock/unlock'):format(src))
        return
    end
    local playerName = GetPlayerName(src) or "unknown"
    local action = newLockState and "Unlocked" or "Locked"

    if type(vehicleNet) ~= "number" or vehicleNet < 0 or vehicleNet > 65535 then
        print(("[bl_carlock] Rejected toggleLock from %s: invalid vehicleNetId %s"):format(src, tostring(vehicleNet)))
        return
    end

    local veh = NetworkGetEntityFromNetworkId(vehicleNet)
    if not DoesEntityExist(veh) then
        print(("[bl_carlock] Rejected toggleLock from %s: vehicle entity doesn't exist"):format(src))
        return
    end

    local ped = GetPlayerPed(src)
    local dist = #(GetEntityCoords(ped) - GetEntityCoords(veh))
    if dist > 8.0 then
        print(("[bl_carlock] Rejected toggleLock from %s: too far from vehicle (%.2f m)"):format(src, dist))
        return
    end

    local hasKey = false
    if hasVehicleKeyDB then
        hasKey = hasVehicleKeyDB(src, plate)
    else
        hasKey = true
    end

    if not isPlayerVehicle(src, plate) then
        TriggerClientEvent('bl_carlock:client:noKeys', src)
        return
    end

    local itemOk = not Config.RequireKeyItem or checkHasVehicleKey(src)
    if itemOk then
        TriggerClientEvent('bl_carlock:client:setLockState', -1, newLockState, vehicleNet)
        sendToAllLoggers(
            "Vehicle Lock Toggled",
            ("[%s] %s (%s) %s vehicle"):format(plate, playerName, src, action),
            newLockState and 65280 or 16711680
)
    else
        print(("[bl_carlock] Player %s tried to toggleLock without key for %s"):format(src, plate))
        TriggerClientEvent('bl_carlock:client:noKeys', src)
    end
end)

RegisterNetEvent('bl_carlock:server:giveKey', function(playerId, plate)
    -- If you wire persistence later, insert a row here based on your DB and inventory
    dbg(('Key assigned (stub) plate=%s player=%s'):format(tostring(plate), tostring(playerId)))
end)

RegisterNetEvent('qb-vehicleshop:server:sellVehicle', function(vehicleData, playerId)
    if vehicleData and vehicleData.plate and playerId then
        TriggerEvent('bl_carlock:server:giveKey', playerId, vehicleData.plate)
    end
end)

RegisterNetEvent('esx_vehicleshop:buyVehicle', function(vehicleData)
    local playerId = source
    if vehicleData and vehicleData.plate then
        TriggerEvent('bl_carlock:server:giveKey', playerId, vehicleData.plate)
    end
end)

RegisterNetEvent('jg_dealerships:vehiclePurchased', function(playerId, vehicleData)
    if vehicleData and vehicleData.plate and playerId then
        TriggerEvent('bl_carlock:server:giveKey', playerId, vehicleData.plate)
    end
end)

RegisterNetEvent('qbx_vehicleshop:server:vehicleSold', function(playerData, vehicleData)
    if playerData and playerData.source and vehicleData and vehicleData.plate then
        TriggerEvent('bl_carlock:server:giveKey', playerData.source, vehicleData.plate)
    end
end)

RegisterNetEvent('jg_dealerships:server:vehicleSold', function(playerData, vehicleData)
    if playerData and playerData.source and vehicleData and vehicleData.plate then
        TriggerEvent('bl_carlock:server:giveKey', playerData.source, vehicleData.plate)
    end
end)

RegisterNetEvent('bl_carlock:server:hasVehicleKeyReq', function(token)
    local src = source
    local hasKey = false

    if Config.RequireKeyItem then
        if Config.Inventory == 'ox' then
            local count = exports.ox_inventory:Search(src, 'count', Config.KeyItemName)
            hasKey = count and count > 0
        elseif Config.Inventory == 'qb' then
            local Player = Framework and Framework.QBCore and Framework.QBCore.Functions.GetPlayer(src)
            if Player then
                for _, item in pairs(Player.Functions.GetItems() or {}) do
                    if item.name == Config.KeyItemName then
                        hasKey = true
                        break
                    end
                end
            end
        elseif Config.Inventory == 'qs' then
            local qs = exports['qs-inventory']
            if qs and qs.GetItemCount then
                local count = qs:GetItemCount(src, Config.KeyItemName)
                hasKey = count and count > 0
            end
        elseif Config.Framework == 'esx' then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                local item = xPlayer.getInventoryItem(Config.KeyItemName)
                hasKey = item and item.count > 0
            end
        end
    else
        hasKey = true
    end

    TriggerClientEvent('bl_carlock:client:hasVehicleKeyResp', src, token, hasKey)
end)
