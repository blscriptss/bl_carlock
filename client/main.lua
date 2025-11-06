local lastToggle = 0
local toggleCooldown = 2000 -- milliseconds

Config = Config or {}
Config.LockCommand = Config.LockCommand or 'lock'
Config.Keybind = Config.Keybind or 'U'
Config.MaxVehicleDistance = Config.MaxVehicleDistance or 4.0
if Config.PlayLockAnimation == nil then Config.PlayLockAnimation = true end
if Config.FlashLights == nil then Config.FlashLights = true end
if Config.PlaySound == nil then Config.PlaySound = true end
Config.Notify = Config.Notify or 'qb' -- 'qb' | 'okok' | 'mythic' | 'ox' | 'print'

Locales = Locales or {
    ['no_vehicle_nearby'] = 'No vehicle nearby.',
    ['vehicle_locked'] = 'Vehicle locked.',
    ['vehicle_unlocked'] = 'Vehicle unlocked.',
    ['no_keys'] = "You don't have the keys."
}

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
    local names = { 'es_extended', 'esx_framework' }
    for _, name in ipairs(names) do
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
        return
    end

    Framework.ESX = tryGetESX()
    if Framework.ESX then
        Framework.type = 'esx'
        return
    end

    Framework.type = 'standalone'
end)

local function Notify(msg, type_)
    local t = type_ or 'inform'
    if Config.Notify == 'qb' then
        TriggerEvent('QBCore:Notify', msg, t)
    elseif Config.Notify == 'okok' then
        TriggerEvent('okokNotify:Alert', 'Car Lock', msg, 5000, t)
    elseif Config.Notify == 'mythic' then
        TriggerEvent('mythic_notify:client:SendAlert', { type = t, text = msg })
    elseif Config.Notify == 'ox' then
        if lib and lib.notify then
            lib.notify({ description = msg, type = t })
        else
            print('[Notify][' .. t .. ']: ' .. msg)
        end
    elseif Config.Notify == 'bl_notify' then
        TriggerEvent('bl_notify:Alert', 'Car Lock', msg, 5000, t)
    else
        print('[Notify][' .. t .. ']: ' .. msg)
    end
end

RegisterCommand(Config.LockCommand, function()
    TryToggleLock()
end, false)

RegisterKeyMapping(Config.LockCommand, 'Toggle Vehicle Lock', 'keyboard', Config.Keybind)

local pending = {}

RegisterNetEvent('bl_carlock:client:hasVehicleKeyResp', function(token, hasKey)
    local p = pending[token]
    if p then
        p.result = hasKey and true or false
        p.done = true
    end
end)

local function serverHasKey_fallback(vehicle, timeoutMs)
    local token = tostring(math.random(100000, 999999)) .. tostring(GetGameTimer())
    pending[token] = { done = false, result = false }
    TriggerServerEvent('bl_carlock:server:hasVehicleKeyReq', token, GetVehicleNumberPlateText(vehicle))
    local start = GetGameTimer()
    local timeout = timeoutMs or 3000
    while not pending[token].done do
        if GetGameTimer() - start > timeout then
            break
        end
        Wait(0)
    end
    local res = pending[token].result
    pending[token] = nil
    return res
end

local function serverHasKey_qb(cb)
    Framework.QBCore.Functions.TriggerCallback('bl_carlock:server:hasVehicleKey', function(hasKey)
        cb(hasKey and true or false)
    end)
end

function TryToggleLock()
    local now = GetGameTimer()
    if now - lastToggle < toggleCooldown then return end
    lastToggle = now
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        local coords = GetEntityCoords(ped)
        local vehicles = GetGamePool('CVehicle')
        local bestVeh = 0
        local bestDist = Config.MaxVehicleDistance + 0.01
        for _, v in pairs(vehicles) do
            if DoesEntityExist(v) and not IsPedAPlayer(GetPedInVehicleSeat(v, -1)) then
                local d = #(coords - GetEntityCoords(v))
                if d < bestDist then
                    bestDist = d
                    bestVeh = v
                end
            end
        end
        vehicle = bestVeh
    end

    if vehicle == 0 then
        Notify('There is no vehicle nearby to lock or unlock.', 'inform')
        return
    end

    local vehicleNet = VehToNet(vehicle)
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    local newLock = (lockStatus == 1)

    local function proceed(hasKey)
        if hasKey then
            TriggerServerEvent('bl_carlock:server:toggleLock', GetVehicleNumberPlateText(vehicle), vehicleNet, newLock)
        else
            Notify('You don\'t have keys for this vehicle.', 'inform')
        end
    end

    if Framework.type == 'qb' and Framework.QBCore then
        serverHasKey_qb(proceed)
    else
        local has = serverHasKey_fallback(vehicle, 3000)
        proceed(has)
    end
end

RegisterNetEvent('bl_carlock:client:setLockState', function(isLocked, vehicleNet)
    local veh = NetToVeh(vehicleNet)
    if not DoesEntityExist(veh) then
        return
    end

    SetVehicleDoorsLocked(veh, isLocked and 2 or 1)

    if Config.FlashLights then
        SetVehicleLights(veh, 2)
        Wait(150)
        SetVehicleLights(veh, 0)
    end

    if Config.PlayLockAnimation then
        RequestAnimDict('anim@mp_player_intmenu@key_fob@')
        while not HasAnimDictLoaded('anim@mp_player_intmenu@key_fob@') do
            Wait(10)
        end
        TaskPlayAnim(PlayerPedId(), 'anim@mp_player_intmenu@key_fob@', 'fob_click', 8.0, -8.0, 500, 48, 0.0, false, false, false)
    end

    if Config.PlaySound then
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'lock', 0.5)
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'unlock', 0.5)
    end

    Notify(isLocked and Locales['vehicle_locked'] or Locales['vehicle_unlocked'], isLocked and 'error' or 'success')
end)

RegisterNetEvent('bl_carlock:client:noKeys', function()
    Notify("You don't have keys for this vehicle.", 'inform')
end)
