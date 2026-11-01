local QBCore = exports['qb-core']:GetCoreObject()
local Weapons = {}
local Loaded = true
local realWeapons = Config.RealWeapons
local handgunFlag = 'backhandgun'
local rifleFlag = 'assault'
local offsetCoords = nil
local weaponCategoryOffsets = {}
local showPistol = true
local showKnife = true
local holstered  = true
local blocked = false
local PlayerData = {}
local switched = false
holsterBusy = false

local function _U(key)
    local locales = Config.Locales or {}
    local lang = locales[Config.Locale] or locales['en'] or {}
    local fallback = locales['en'] or {}
    return lang[key] or fallback[key] or key
end

function GetOwnedWeaponSet()
    local owned = {}
    local ok, items = pcall(function()
        return exports.ox_inventory:GetPlayerItems()
    end)

    if ok and items then
        for _, item in pairs(items) do
            if item and item.name then
                owned[item.name:lower()] = true
            end
        end
    end

    return owned
end

function OwnsWeapon(weaponName, owned)
    if HasPedGotWeapon(PlayerPedId(), GetHashKey(weaponName), false) then
        return true
    end

    owned = owned or GetOwnedWeaponSet()
    return owned[weaponName:lower()] == true
end

RegisterCommand("hide", function(source)
    local ped = PlayerPedId()
    if showPistol and showKnife then
        local _canHide = true
        for i, realweapon in pairs(realWeapons) do
            if HasPedGotWeapon(ped, GetHashKey(realWeapons[i].name), false) then
                if(not realWeapons[i].canHide) then
                    _canHide = false
                end
            end
        end
        if _canHide then
            SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
            SetPedCanSwitchWeapon(ped, false)
            showPistol = false
            showKnife = false 
            RemoveGears()
            lib.notify({description = _U('notify_hidden')})
            ExecuteCommand('do ' .. _U('do_hidden'))
        else
            lib.notify({description = _U('notify_cannot_hide')})
        end
    else
        showPistol = true
        showKnife = true
        SetGears()
        SetPedCanSwitchWeapon(ped, true)
        lib.notify({description = _U('notify_shown')})
        ExecuteCommand('do ' .. _U('do_shown'))
    end
end, false)

Citizen.CreateThread(function()
    local playerPed = PlayerPedId()
    SetPedCanSwitchWeapon(playerPed, true)
    realWeapons = Config.RealWeapons
    weaponCategoryOffsets = Config.WeaponCategoryOffsets
    local owned = {}

    while true do
        Citizen.Wait(1500)
        if holsterBusy then goto continue end

        playerPed = PlayerPedId()
        owned = GetOwnedWeaponSet()

        for i=1, #realWeapons, 1 do
            local weaponHash = GetHashKey(realWeapons[i].name)
            local onPlayer = false

            if showPistol and OwnsWeapon(realWeapons[i].name, owned) then
                for weaponName, entity in pairs(Weapons) do
                    if weaponName == realWeapons[i].name and DoesEntityExist(entity) then
                        onPlayer = true
                        break
                    end
                end

                if not onPlayer and weaponHash ~= GetSelectedPedWeapon(playerPed) then
                    if realWeapons[i].model ~= nil then
                        SetGear(realWeapons[i].name)
                    end
                end
            end
        end

        ::continue::
    end
end)


RegisterNetEvent('qb_weaponmaster:restoreLoadout')
AddEventHandler('qb_weaponmaster:restoreLoadout', function()
    RemoveGears()
    Loaded = true
end)



function GetWeaponNameByHash(hash)
    for _, v in pairs(Config.RealWeapons) do
        if GetHashKey(v.name) == hash then
            return v.name
        end
    end
    return nil
end

function GetWeaponCategoryByHash(hash)
    for _, v in pairs(Config.RealWeapons) do
        if GetHashKey(v.name) == hash then
            return v.category
        end
    end
    return nil
end

function PlayHolsterAnim(ped, category, action)
    local dict, anim = nil, nil

    -- Si es una pistola (según categoría definida en config)
    local isHandgun = false
    if category == 'handguns' or category == 'revolver' or category == 'bighandgun' or category == 'utilityhandgun' then
        isHandgun = true
    end

    if isHandgun then
        if action == "draw" then
            if handgunFlag == 'backhandgun' then dict,anim = "reaction@intimidation@1h","intro"
            elseif handgunFlag == 'boxers' then dict,anim = "combat@combat_reactions@pistol_1h_gang","0"
            elseif handgunFlag == 'chesthandgun' then dict,anim = "combat@combat_reactions@pistol_1h_gang","0"
            elseif handgunFlag == 'leghandgun' then dict,anim = "reaction@male_stand@big_variations@d","react_big_variations_m"
            else dict,anim = "rcmjosh4","josh_leadout_cop2" end
        else -- holster
            if handgunFlag == 'backhandgun' then dict,anim = "reaction@intimidation@1h","outro"
            elseif handgunFlag == 'boxers' then dict,anim = "combat@combat_reactions@pistol_1h_gang","0"
            elseif handgunFlag == 'chesthandgun' then dict,anim = "combat@combat_reactions@pistol_1h_gang","0"
            elseif handgunFlag == 'leghandgun' then dict,anim = "reaction@male_stand@big_variations@d","react_big_variations_m"
            else dict,anim = "reaction@intimidation@cop@unarmed","outro" end
        end
    else
        if action == "draw" then
            if rifleFlag == 'tacticalrifle' then dict,anim = "combat@combat_reactions@pistol_1h_hillbilly","0"
            else dict,anim = "reaction@intimidation@1h","intro" end
        else
            if rifleFlag == 'tacticalrifle' then dict,anim = "combat@combat_reactions@pistol_1h_gang","0"
            else dict,anim = "reaction@intimidation@1h","outro" end
        end
    end

    if dict and anim then
        loadAnimDict(dict)
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 1000, 48, 0, false, false, false)
    end
end

function RemoveGear(weaponName)
    local entity = Weapons[weaponName]
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
    Weapons[weaponName] = nil
end


function RemoveGears()
    for weaponName, entity in pairs(Weapons) do
        DeleteEntity(entity)
    end
    Weapons = {}
end

function GetCoords(cat)
    for i=1, #weaponCategoryOffsets, 1 do
        if weaponCategoryOffsets[i].category == cat then
            return weaponCategoryOffsets[i].bone, weaponCategoryOffsets[i].x, weaponCategoryOffsets[i].y, weaponCategoryOffsets[i].z, weaponCategoryOffsets[i].xRot, weaponCategoryOffsets[i].yRot, weaponCategoryOffsets[i].zRot
        end
    end
end

function SetGear(weapon)
    if not weapon then return end

    if not showPistol then return end

    if Weapons[weapon] and DoesEntityExist(Weapons[weapon]) then
        return
    end

    local playerPed = PlayerPedId()
    local model = nil
    local bone, boneX, boneY, boneZ, boneXRot, boneYRot, boneZRot

    for i=1, #realWeapons, 1 do
        if realWeapons[i].name == weapon then
            if realWeapons[i].category == 'handguns' or realWeapons[i].category == 'revolver' then
                if PlayerData and PlayerData.job and PlayerData.job.name == 'police' and not switched then
                    offsetCoords = "handguns"
                    handgunFlag = "handguns"
                else
                    offsetCoords = handgunFlag
                end
            elseif realWeapons[i].category == 'machine' or realWeapons[i].category == 'assault' or realWeapons[i].category == 'shotgun' or realWeapons[i].category == 'sniper' or realWeapons[i].category == 'heavy' then
                offsetCoords = rifleFlag
            else
                offsetCoords = realWeapons[i].category
            end

            bone, boneX, boneY, boneZ, boneXRot, boneYRot, boneZRot = GetCoords(offsetCoords)
            model = realWeapons[i].model
            break
        end
    end

    if not model or not bone then return end

    local modelHash = GetHashKey(model)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 1000 do
        Citizen.Wait(10)
        timeout = timeout + 1
    end

    local x,y,z = table.unpack(GetEntityCoords(playerPed))
    local object = CreateObject(modelHash, x, y, z, true, true, false)
    if DoesEntityExist(object) then
        local boneIndex = GetPedBoneIndex(playerPed, bone)
        AttachEntityToEntity(object, playerPed, boneIndex, boneX, boneY, boneZ, boneXRot, boneYRot, boneZRot, false, false, false, false, 2, true)
        Weapons[weapon] = object
    end
    SetModelAsNoLongerNeeded(modelHash)
end

function SetGears()
    local playerPed  = PlayerPedId()
    
    local owned = GetOwnedWeaponSet()

    for j=1, #realWeapons, 1 do
        if OwnsWeapon(realWeapons[j].name, owned) then		
            SetGear(realWeapons[j].name)
        end
    end
end

local function RefreshGears()
    local ped = PlayerPedId()

    local owned = GetOwnedWeaponSet()
    local selectedWeapon = GetSelectedPedWeapon(ped)

    for i = 1, #realWeapons, 1 do
        local wep = realWeapons[i]
        local weaponName = wep.name
        local weaponHash = GetHashKey(weaponName)

        if showPistol and weaponHash ~= selectedWeapon and OwnsWeapon(weaponName, owned) then
            local offset
            if wep.category == 'handguns' or wep.category == 'revolver' then
                if PlayerData and PlayerData.job and PlayerData.job.name == 'police' and not switched then
                    offset = "handguns"
                    handgunFlag = "handguns"
                else
                    offset = handgunFlag
                end
            elseif wep.category == 'machine' or wep.category == 'assault' or wep.category == 'shotgun' or wep.category == 'sniper' or wep.category == 'heavy' then
                offset = rifleFlag
            else
                offset = wep.category
            end

            local bone, boneX, boneY, boneZ, boneXRot, boneYRot, boneZRot = GetCoords(offset)

            if not bone then
                if Weapons[weaponName] and DoesEntityExist(Weapons[weaponName]) then
                    RemoveGear(weaponName)
                end
                SetGear(weaponName)
            else
                if Weapons[weaponName] and DoesEntityExist(Weapons[weaponName]) then
                    local ent = Weapons[weaponName]
                    -- Detach y reattach para forzar nueva posición
                    DetachEntity(ent, true, true)
                    local boneIndex = GetPedBoneIndex(ped, bone)
                    -- pequeño wait para evitar condiciones de carrera en algunos clientes
                    Citizen.Wait(30)
                    AttachEntityToEntity(ent, ped, boneIndex, boneX, boneY, boneZ, boneXRot, boneYRot, boneZRot, false, false, false, false, 2, true)
                else
                    SetGear(weaponName)
                end
            end

        else
            if Weapons[weaponName] and DoesEntityExist(Weapons[weaponName]) then
                RemoveGear(weaponName)
            end
        end
    end
end


RegisterCommand('holster', function(source, args)
    if args[1] == nil then
        OpenHolsterMenu()
        return
    end

    local ped = PlayerPedId()
    local newHandgunFlag = handgunFlag
    local newRifleFlag = rifleFlag

    if args[1] == 'handguns' or args[1] == 'waisthandgun' then
        newHandgunFlag = args[1]
        lib.notify({description = _U('pos_hip')})
    elseif args[1] == 'backhandgun' then 
        newHandgunFlag = args[1]
        lib.notify({description = _U('pos_back')})
    elseif args[1] == 'leghandgun' or args[1] == 'hiphandgun' or args[1] == 'handguns2' then
        newHandgunFlag = args[1]
        lib.notify({description = _U('pos_leg')})
    elseif args[1] == 'chesthandgun' then
        newHandgunFlag = args[1]
        lib.notify({description = _U('pos_chest')})
    elseif args[1] == 'boxers' then
        newHandgunFlag = args[1]
        lib.notify({description = _U('pos_front')})
    elseif args[1] == 'assault' then
        newRifleFlag = args[1]
        lib.notify({description = _U('pos_rifle_back')})
    elseif args[1] == 'tacticalrifle' then
        newRifleFlag = args[1]
        lib.notify({description = _U('pos_rifle_front')})
    end

    -- Aplicar flags
    handgunFlag = newHandgunFlag
    rifleFlag = newRifleFlag
    switched = true

    RefreshGears()

    Citizen.Wait(250)
    SetGears()
    Citizen.Wait(250)
    RefreshGears()

    if not holstered then
        ClearPedTasks(ped)
    end

end)



function OpenHolsterMenu()
    lib.registerContext({
        id = 'holster_menu',
        title = _U('menu_main_title'),
        options = {
            {
                title = _U('menu_pistols_title'),
                description = _U('menu_pistols_desc'),
                onSelect = function()
                    OpenPistolsMenu()
                end,
            },
            {
                title = _U('menu_rifles_title'),
                description = _U('menu_rifles_desc'),
                onSelect = function()
                    OpenRiflesMenu()
                end,
            },
            {
                title = _U('menu_hide_title'),
                description = _U('menu_hide_desc'),
                onSelect = function()
                    ExecuteCommand('hide')
                end,
            },
        }
    })
    lib.showContext('holster_menu')
end

function OpenPistolsMenu()
    lib.registerContext({
        id = 'pistols_menu',
        title = _U('menu_pistols_sub_title'),
        menu = 'holster_menu',
        options = {
            {
                title = _U('opt_front_title'),
                description = _U('opt_front_desc'),
                onSelect = function()
                    ExecuteCommand('holster boxers')
                end,
            },
            {
                title = _U('opt_back_title'),
                description = _U('opt_back_desc'),
                onSelect = function()
                    ExecuteCommand('holster backhandgun')
                end,
            },
            {
                title = _U('opt_waist_title'),
                description = _U('opt_waist_desc'),
                onSelect = function()
                    ExecuteCommand('holster waisthandgun')
                end,
            },
            {
                title = _U('opt_hip_title'),
                description = _U('opt_hip_desc'),
                onSelect = function()
                    ExecuteCommand('holster handguns')
                end,
            },
            {
                title = _U('opt_chest_title'),
                description = _U('opt_chest_desc'),
                onSelect = function()
                    ExecuteCommand('holster chesthandgun')
                end,
            },
            {
                title = _U('opt_thigh_title'),
                description = _U('opt_thigh_desc'),
                onSelect = function()
                    ExecuteCommand('holster hiphandgun')
                end,
            },
            {
                title = _U('opt_leg_title'),
                description = _U('opt_leg_desc'),
                onSelect = function()
                    ExecuteCommand('holster leghandgun')
                end,
            },
            {
                title = _U('opt_leg2_title'),
                description = _U('opt_leg2_desc'),
                onSelect = function()
                    ExecuteCommand('holster handguns2')
                end,
            },
        }
    })
    lib.showContext('pistols_menu')
end

function OpenRiflesMenu()
    lib.registerContext({
        id = 'rifles_menu',
        title = _U('menu_rifles_sub_title'),
        menu = 'holster_menu',
        options = {
            {
                title = _U('opt_rifle_chest_title'),
                description = _U('opt_rifle_chest_desc'),
                onSelect = function()
                    ExecuteCommand('holster tacticalrifle')
                end,
            },
            {
                title = _U('opt_rifle_back_title'),
                description = _U('opt_rifle_back_desc'),
                onSelect = function()
                    ExecuteCommand('holster assault')
                end,
            },
        }
    })
    lib.showContext('rifles_menu')
end

function loadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Citizen.Wait(100)
    end
end

function CheckWeapon(ped, newWeap)
    if IsEntityDead(ped) then
        blocked = false
            return false
        else
            for i = 1, #realWeapons do
                if GetHashKey(realWeapons[i].name) == GetSelectedPedWeapon(ped) then
                    return true
                end
            end
        return false
    end
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job

    if job and job.name == 'police' then
        handgunFlag = 'handguns'
        lib.notify({
            title = _U('police_title'),
            description = _U('police_desc'),
            type = 'inform'
        })
    end

    RemoveGears()
    Wait(1000)
    SetGears()
end)

function loadAnimDict2(dict)
    while ( not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Citizen.Wait(0)
    end
end

function GetWeaponNameByHash(hash)
    for _, v in pairs(Config.RealWeapons) do
        if GetHashKey(v.name) == hash then
            return v.name
        end
    end
    return nil
end

Citizen.CreateThread(function()
    loadAnimDict("rcmjosh4")
    loadAnimDict("reaction@intimidation@cop@unarmed")
    loadAnimDict("reaction@intimidation@1h")
    loadAnimDict2("combat@combat_reactions@pistol_1h_gang")
    loadAnimDict2("combat@combat_reactions@pistol_1h_hillbilly")
    loadAnimDict2("reaction@male_stand@big_variations@d")

    local rot = 0
    local wepCat
    local lastWep
    local ped = PlayerPedId()
    PlayerData = QBCore.Functions.GetPlayerData()

    while true do
        Citizen.Wait(100)
        ped = PlayerPedId()
        rot = GetEntityHeading(ped)

        if not IsPedInAnyVehicle(ped, true) then
            if (GetPedParachuteState(ped) == -1 or GetPedParachuteState(ped) == 0) and not IsPedInParachuteFreeFall(ped) then
                wepCat = GetWeapontypeGroup(GetSelectedPedWeapon(ped))

                if CheckWeapon(ped) then
                    local currentWep = GetSelectedPedWeapon(ped)
                    local weapName = GetWeaponNameByHash(currentWep)

                    if (wepCat == 416676503 or wepCat == 690389602) then
                        if holstered then
                            holsterBusy = true
                            blocked = true

                            if handgunFlag == 'backhandgun' then
                                TaskPlayAnimAdvanced(ped, "reaction@intimidation@1h", "intro", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.325, 0, 0)
                            elseif handgunFlag == 'boxers' then
                                TaskPlayAnimAdvanced(ped, "combat@combat_reactions@pistol_1h_gang", "0", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.325, 0, 0)
                            elseif handgunFlag == 'chesthandgun' then
                                TaskPlayAnimAdvanced(ped, "combat@combat_reactions@pistol_1h_gang", "0", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.325, 0, 0)
                            elseif handgunFlag == 'leghandgun' then
                                TaskPlayAnimAdvanced(ped, "reaction@male_stand@big_variations@d", "react_big_variations_m", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.325, 0, 0)
                            else
                                TaskPlayAnim(ped, "rcmjosh4", "josh_leadout_cop2", 8.0, 2.0, -1, 48, 10, 0, 0, 0)
                            end

                            Citizen.Wait(700)
                            ClearPedTasks(ped)
                            holstered = false
                            lastWep = currentWep

                            if weapName then RemoveGear(weapName) end
                            holsterBusy = false
                        end
                    else
                        -- Rifles
                        if holstered then
                            holsterBusy = true
                            blocked = true

                            if rifleFlag == 'tacticalrifle' then
                                TaskPlayAnimAdvanced(ped, "combat@combat_reactions@pistol_1h_hillbilly", "0", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.325, 0, 0)
                            else
                                TaskPlayAnimAdvanced(ped, "reaction@intimidation@1h", "intro", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.325, 0, 0)
                            end

                            Citizen.Wait(700)
                            ClearPedTasks(ped)
                            holstered = false
                            lastWep = currentWep

                            if weapName then RemoveGear(weapName) end
                            holsterBusy = false
                        end
                    end

                else
                    if lastWep ~= nil and not holstered then
                        holsterBusy = true
                        local weapName = GetWeaponNameByHash(lastWep)

                        if weapName then SetGear(weapName) end

                        if (GetWeapontypeGroup(lastWep) == 416676503 or GetWeapontypeGroup(lastWep) == 690389602) then
                            -- Pistolas
                            if handgunFlag == 'backhandgun' then
                                TaskPlayAnimAdvanced(ped, "reaction@intimidation@1h", "outro", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.125, 0, 0)
                            elseif handgunFlag == 'boxers' then
                                TaskPlayAnimAdvanced(ped, "combat@combat_reactions@pistol_1h_gang", "0", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.125, 0, 0)
                            elseif handgunFlag == 'leghandgun' then
                                TaskPlayAnimAdvanced(ped, "reaction@male_stand@big_variations@d", "react_big_variations_m", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.125, 0, 0)
                            elseif handgunFlag == 'chesthandgun' then
                                TaskPlayAnimAdvanced(ped, "combat@combat_reactions@pistol_1h_gang", "0", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.125, 0, 0)
                            else
                                TaskPlayAnimAdvanced(ped, "reaction@intimidation@cop@unarmed", "outro", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.125, 0, 0)
                            end
                        else
                            -- Rifles
                            if rifleFlag == 'tacticalrifle' then
                                TaskPlayAnimAdvanced(ped, "combat@combat_reactions@pistol_1h_gang", "0", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.125, 0, 0)
                            else
                                TaskPlayAnimAdvanced(ped, "reaction@intimidation@1h", "outro", GetEntityCoords(ped, true), 0, 0, rot, 8.0, 3.0, -1, 50, 0.125, 0, 0)
                            end
                        end

                        Citizen.Wait(700)
                        ClearPedTasks(ped)
                        holstered = true
                        holsterBusy = false
                    end
                end
            elseif (GetVehiclePedIsTryingToEnter(ped) == 0) then
                holstered = false
            else
                SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
            end
        else
            holstered = true
        end
    end
end)

Citizen.CreateThread(function()
    Wait(2000)
    PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData.job and PlayerData.job.name == 'police' then
        handgunFlag = 'handguns'
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end

    local ped = PlayerPedId()
    RemoveGears()
    SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData.job and PlayerData.job.name == 'police' then
        handgunFlag = 'handguns'
    end
end)


local lastItems = {}

local function getInventorySnapshot()
    local snapshot = {}
    local items = exports.ox_inventory:GetPlayerItems() or {}
    for _, item in pairs(items) do
        if item.name then
            snapshot[item.name] = (snapshot[item.name] or 0) + (item.count or item.amount or 1)
        end
    end
    return snapshot
end

local function getRealWeapon(itemName)
    itemName = itemName:lower()

    for _, realWep in pairs(Config.RealWeapons) do
        local wepName = realWep.name:lower()
        local wepItem = (realWep.item and realWep.item:lower()) or wepName:gsub('weapon_', '')
        local simpleItem = itemName:gsub('weapon_', '')

        if itemName == wepName or itemName == wepItem or simpleItem == wepItem then
            return realWep.name
        end
    end
end

CreateThread(function()
    Wait(2000)
    lastItems = getInventorySnapshot()

    while true do
        Wait(1000)
        local currentItems = getInventorySnapshot()
        local ped = PlayerPedId()

        for name, count in pairs(currentItems) do
            local prev = lastItems[name] or 0
            if count > prev then
                local weaponName = getRealWeapon(name)
                if weaponName then
                    local weaponHash = GetHashKey(weaponName)
                    if GetSelectedPedWeapon(ped) ~= weaponHash then
                        SetGear(weaponName)
                    end
                end
            elseif count < prev then
                local weaponName = getRealWeapon(name)
                if weaponName then
                    RemoveGear(weaponName)
                end
            end
        end

        for name, prevCount in pairs(lastItems) do
            if not currentItems[name] then
                local weaponName = getRealWeapon(name)
                if weaponName then
                    RemoveGear(weaponName)
                end
            end
        end

        lastItems = currentItems
    end
end)

AddEventHandler('playerSpawned', function()
    Citizen.CreateThread(function()
        Wait(4000)

        local ped = PlayerPedId()
        while not ped or ped == 0 or not DoesEntityExist(ped) do
            Wait(500)
            ped = PlayerPedId()
        end

        if SetGears then
            SetGears(true)
            Wait(1000)
            RefreshGears()
        end
    end)
end)