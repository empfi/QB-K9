local QBCore = exports['qb-core']:GetCoreObject()
local dogPed = nil
local isWaiting = false
local isAttacking = false
local isReturning = false
local attackTarget = nil
local attackQueue = {}
local lastDogPos = nil
local stuckTimer = 0
local lastTeleportTime = 0
local wasInVehicle = false
local isDogEnteringVehicle = false
local isReturningK9 = false
local returnCooldown = 5000
local isDogSpawned = false -- New flag to track if dog was explicitly spawned

-- Create Blip for K9 Station
Citizen.CreateThread(function()
    local blip = AddBlipForCoord(Config.K9Station.x, Config.K9Station.y, Config.K9Station.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("K9 Station")
    EndTextCommandSetBlipName(blip)
end)

-- Key press interaction for K9 station
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - Config.K9Station)

        if distance < 3.0 then
            local PlayerData = QBCore.Functions.GetPlayerData()
            local PlayerJob = PlayerData.job

            if PlayerJob and PlayerJob.name == Config.JobRequired then
                local allowedRanks = Config.K9AllowedRanks
                local playerGrade = PlayerJob.grade.level

                local function isRankAllowed(rankStr, playerGrade)
                    if rankStr:find(',') then
                        local ranksList = {}
                        for rank in rankStr:gmatch("%d+") do
                            table.insert(ranksList, tonumber(rank))
                        end
                        for _, r in ipairs(ranksList) do
                            if r == playerGrade then
                                return true
                            end
                        end
                        return false
                    elseif rankStr:find('%+') then
                        local minRank = tonumber(rankStr:sub(1, -2))
                        return playerGrade >= minRank
                    elseif rankStr:find('%-') then
                        local maxRank = tonumber(rankStr:sub(1, -2))
                        return playerGrade <= maxRank
                    else
                        local requiredRank = tonumber(rankStr)
                        return playerGrade == requiredRank
                    end
                end

                if isRankAllowed(allowedRanks, playerGrade) then
                    if not dogPed then
                        DrawText3D(Config.K9Station.x, Config.K9Station.y, Config.K9Station.z, "[E] Collect K9")
                        if IsControlJustPressed(0, 38) then
                            TriggerEvent('qb-k9:client:openDogMenu')
                        end
                    elseif dogPed then
                        DrawText3D(Config.K9Station.x, Config.K9Station.y, Config.K9Station.z, "[E] Return K9")
                        if IsControlJustPressed(0, 38) and not isReturningK9 then
                            isReturningK9 = true
                            TriggerServerEvent('qb-k9:server:returnK9')
                            Citizen.SetTimeout(returnCooldown, function()
                                isReturningK9 = false
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- Command for K9 Recall
RegisterCommand('recallK9', function()
    if dogPed then
        RecallK9()
    end
end, false)

RegisterKeyMapping('recallK9', 'Recall K9 Dog', 'keyboard', 'o')

-- Exports
exports('HasK9', function()
    return dogPed ~= nil and DoesEntityExist(dogPed) and not IsEntityDead(dogPed)
end)

exports('IsK9Waiting', function()
    return isWaiting
end)

exports('GetDogPed', function()
    return dogPed
end)

-- Spawn K9
RegisterNetEvent('qb-k9:client:collectK9')
AddEventHandler('qb-k9:client:collectK9', function(dogModel)
    if dogPed and DoesEntityExist(dogPed) then
        QBCore.Functions.Notify('You already have a K9!', 'error')
        return
    end

    if not dogModel or type(dogModel) ~= 'string' or dogModel == '' then
        QBCore.Functions.Notify('Invalid dog model provided!', 'error')
        return
    end

    local playerPed = PlayerPedId()
    local model = GetHashKey(dogModel)

    RequestModel(model)
    local loadAttempts = 0
    while not HasModelLoaded(model) and loadAttempts < 100 do
        Citizen.Wait(100)
        loadAttempts = loadAttempts + 1
    end

    if not HasModelLoaded(model) then
        QBCore.Functions.Notify('Failed to load dog model: ' .. dogModel, 'error')
        return
    end

    local spawnPos
    if Config.UseShelterLocation and Config.K9ShelterLocation then
        spawnPos = Config.K9ShelterLocation
    else
        local offset = GetOffsetFromEntityInWorldCoords(playerPed, -2.0, 0.0, 0.0)
        local _, groundZ = GetGroundZFor_3dCoord(offset.x, offset.y, offset.z + 1.0, false)
        spawnPos = vector3(offset.x, offset.y, groundZ)
    end

    dogPed = CreatePed(4, model, spawnPos.x, spawnPos.y, spawnPos.z, GetEntityHeading(playerPed), true, false)
    if not dogPed then
        QBCore.Functions.Notify('Failed to create K9 ped!', 'error')
        SetModelAsNoLongerNeeded(model)
        return
    end

    SetEntityAsMissionEntity(dogPed, true, true)
    SetPedFleeAttributes(dogPed, 0, false)
    SetPedCombatAttributes(dogPed, 46, true)
    SetPedRelationshipGroupHash(dogPed, GetHashKey('K9'))
    SetRelationshipBetweenGroups(5, GetHashKey('K9'), GetHashKey('PLAYER'))
    SetEntityMaxHealth(dogPed, Config.DogMaxHealth)
    SetEntityHealth(dogPed, Config.DogMaxHealth)
    SetEntityInvincible(dogPed, false)
    SetPedHearingRange(dogPed, 0.0)
    SetBlockingOfNonTemporaryEvents(dogPed, true)

    NetworkRegisterEntityAsNetworked(dogPed)
    local netId = NetworkGetNetworkIdFromEntity(dogPed)
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)

    if Config.UseOxTarget then
        exports['ox_target']:addGlobalPed(Config.DogTargetOx)
        exports['ox_target']:addGlobalPed(Config.EntityTargetOx)
    else
        exports['qb-target']:AddGlobalPed({
            options = Config.DogTarget.options,
            distance = 2.0
        })
        exports['qb-target']:AddGlobalPed({
            options = Config.EntityTarget.options,
            distance = 3.0
        })
    end

    QBCore.Functions.Notify('K9 collected successfully!', 'success')
    SetModelAsNoLongerNeeded(model)
    lastTeleportTime = 0
    isReturning = false
    isDogSpawned = true -- Set flag when dog is spawned

    FollowPlayer()
end)

-- Return K9
RegisterNetEvent('qb-k9:client:returnK9')
AddEventHandler('qb-k9:client:returnK9', function()
    if not dogPed or not DoesEntityExist(dogPed) then
        QBCore.Functions.Notify('No K9 to return!', 'error')
        return
    end

    RecallK9()

    if Config.UseShelterLocation and Config.K9ShelterLocation then
        isReturning = true
        ClearPedTasks(dogPed)
        TaskFollowNavMeshToCoord(dogPed, Config.K9ShelterLocation.x, Config.K9ShelterLocation.y, Config.K9ShelterLocation.z, 4.0, -1, 1.0, true, 0)
        Citizen.CreateThread(function()
            while isReturning and dogPed and DoesEntityExist(dogPed) do
                Citizen.Wait(1000)
                local dogCoords = GetEntityCoords(dogPed)
                local distance = #(dogCoords - Config.K9ShelterLocation)
                if distance < 2.0 then
                    DeleteEntity(dogPed)
                    dogPed = nil
                    isReturning = false
                    isDogSpawned = false -- Reset flag when dog is returned
                    QBCore.Functions.Notify('K9 returned to shelter!', 'success')
                    break
                end
            end
        end)
    else
        DeleteEntity(dogPed)
        dogPed = nil
        isDogSpawned = false -- Reset flag when dog is returned
        QBCore.Functions.Notify('K9 returned!', 'success')
    end
end)

-- Recall K9
function RecallK9()
    if not dogPed or not DoesEntityExist(dogPed) then return end

    isWaiting = false
    isAttacking = false
    attackTarget = nil
    attackQueue = {}
    SetEntityInvincible(dogPed, false)
    ClearPedTasks(dogPed)
    QBCore.Functions.Notify('K9 recalled!', 'success')
    FollowPlayer()
end

-- Process Attack Queue
function ProcessAttackQueue()
    if not dogPed or not DoesEntityExist(dogPed) or isWaiting or #attackQueue == 0 then
        isAttacking = false
        attackTarget = nil
        if dogPed and DoesEntityExist(dogPed) then
            ClearPedTasks(dogPed)
            FollowPlayer()
        end
        return
    end

    attackTarget = attackQueue[1]
    local playerPed = PlayerPedId()
    if not DoesEntityExist(attackTarget) or IsEntityDead(attackTarget) or attackTarget == playerPed then
        table.remove(attackQueue, 1)
        ProcessAttackQueue()
        return
    end

    isAttacking = true
    ClearPedTasks(dogPed)
    TaskCombatPed(dogPed, attackTarget, 0, 16)
    QBCore.Functions.Notify('K9 attacking target!', 'success')
end

-- Monitor Attack Target Status
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if isAttacking and attackTarget and dogPed and DoesEntityExist(dogPed) then
            if not DoesEntityExist(attackTarget) or IsEntityDead(attackTarget) then
                table.remove(attackQueue, 1)
                QBCore.Functions.Notify('Target is dead or gone, K9 moving to next target or returning.', 'success')
                ProcessAttackQueue()
            end
        end
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name == "CEventNetworkEntityDamage" then
        local victim, attacker = args[1], args[2]
        if dogPed and victim == dogPed 
           and DoesEntityExist(attacker) 
           and attacker ~= PlayerPedId() 
           and attacker ~= dogPed then
            QBCore.Functions.Notify('K9 is under attack – defending itself!', 'error')
            table.insert(attackQueue, attacker)
            if not isAttacking then
                ProcessAttackQueue()
            end
        end
    end
end)

-- Monitor Attack Target Distance
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        if isAttacking and attackTarget and dogPed and DoesEntityExist(dogPed) then
            local dogCoords = GetEntityCoords(dogPed)
            local targetCoords = GetEntityCoords(attackTarget)
            local distance = #(dogCoords - targetCoords)
            if distance > Config.MaxAttackDistance then
                table.remove(attackQueue, 1)
                QBCore.Functions.Notify('Target is too far, K9 moving to next target or returning.', 'success')
                ProcessAttackQueue()
            end
        end
    end
end)

-- Monitor Vehicle Status for K9 Vehicle Interaction
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local playerPed = PlayerPedId()
        local isInVehicle = IsPedInAnyVehicle(playerPed, false)
        local currentVehicle = GetVehiclePedIsIn(playerPed, false)
        local vehicleClass = currentVehicle and DoesEntityExist(currentVehicle) and GetVehicleClass(currentVehicle) or -1

        if isInVehicle and dogPed and DoesEntityExist(dogPed) and not isReturning and isDogSpawned then
            -- Handle vehicle entry for all vehicles (including boats and helicopters)
            if not IsPedInVehicle(dogPed, currentVehicle, false) and not isDogEnteringVehicle then
                isDogEnteringVehicle = true
                local freeSeat = GetFreeSeat(currentVehicle)
                if freeSeat ~= nil then
                    -- Verify network sync
                    local netId = NetworkGetNetworkIdFromEntity(dogPed)
                    if not NetworkDoesNetworkIdExist(netId) then
                        ClearPedTasks(dogPed)
                        DeleteEntity(dogPed)
                        dogPed = nil
                        isDogSpawned = false
                        QBCore.Functions.Notify('K9 network sync failed, K9 has been stored.', 'error')
                        isDogEnteringVehicle = false
                        goto continue
                    end
                    -- Make dog invincible during vehicle entry
                    SetEntityInvincible(dogPed, true)
                    -- Attempt to warp dog into vehicle
                    local maxAttempts = 3
                    local attempt = 1
                    local success = false
                    while attempt <= maxAttempts and not success do
                        ClearPedTasks(dogPed)
                        local vehiclePos = GetEntityCoords(currentVehicle)
                        local offset = GetOffsetFromEntityInWorldCoords(currentVehicle, -1.5, 0.0, 0.0)
                        local _, groundZ = GetGroundZFor_3dCoord(offset.x, offset.y, offset.z + 1.0, false)
                        SetEntityCoords(dogPed, offset.x, offset.y, groundZ, false, false, false, true)
                        TaskWarpPedIntoVehicle(dogPed, currentVehicle, freeSeat)
                        Citizen.Wait(300)
                        if IsPedInVehicle(dogPed, currentVehicle, false) then
                            success = true
                            QBCore.Functions.Notify('K9 has entered the vehicle.', 'success')
                        else
                            attempt = attempt + 1
                        end
                    end
                    SetEntityInvincible(dogPed, false)
                    if not success then
                        ClearPedTasks(dogPed)
                        DeleteEntity(dogPed)
                        dogPed = nil
                        isDogSpawned = false
                        QBCore.Functions.Notify('Failed to place K9 in vehicle after retries, K9 has been stored.', 'error')
                    end
                else
                    ClearPedTasks(dogPed)
                    DeleteEntity(dogPed)
                    dogPed = nil
                    isDogSpawned = false
                    QBCore.Functions.Notify('No free seats, K9 has been stored.', 'success')
                end
                isDogEnteringVehicle = false
            end
        elseif not isInVehicle and dogPed and DoesEntityExist(dogPed) and IsPedInAnyVehicle(dogPed, false) then
            -- Player exits, dog leaves vehicle
            ClearPedTasks(dogPed)
            TaskLeaveVehicle(dogPed, currentVehicle, 0)
            Citizen.Wait(1000)
            FollowPlayer()
            QBCore.Functions.Notify('K9 has exited and is following you.', 'success')
        elseif not isInVehicle and not dogPed and wasInVehicle and not isReturning and isDogSpawned then
            -- Respawn dog after exiting vehicle if despawned
            local model = GetHashKey(Config.DogModels[1])
            RequestModel(model)
            while not HasModelLoaded(model) do
                Citizen.Wait(0)
            end

            local offset = GetOffsetFromEntityInWorldCoords(playerPed, -2.0, 0.0, 0.0)
            local _, groundZ = GetGroundZFor_3dCoord(offset.x, offset.y, offset.z + 1.0, false)
            local spawnPos = vector3(offset.x, offset.y, groundZ)

            dogPed = CreatePed(4, model, spawnPos.x, spawnPos.y, spawnPos.z, GetEntityHeading(playerPed), true, false)
            SetEntityAsMissionEntity(dogPed, true, true)
            SetPedFleeAttributes(dogPed, 0, false)
            SetPedCombatAttributes(dogPed, 46, true)
            SetPedRelationshipGroupHash(dogPed, GetHashKey('K9'))
            SetRelationshipBetweenGroups(5, GetHashKey('K9'), GetHashKey('PLAYER'))
            SetEntityMaxHealth(dogPed, Config.DogMaxHealth)
            SetEntityHealth(dogPed, Config.DogMaxHealth)
            SetEntityInvincible(dogPed, false)
            SetPedHearingRange(dogPed, 0.0)
            SetBlockingOfNonTemporaryEvents(dogPed, true)

            NetworkRegisterEntityAsNetworked(dogPed)
            local netId = NetworkGetNetworkIdFromEntity(dogPed)
            SetNetworkIdCanMigrate(netId, true)
            SetNetworkIdExistsOnAllMachines(netId, true)

            QBCore.Functions.Notify('K9 has been retrieved after exiting vehicle!', 'success')
            FollowPlayer()
        end

        wasInVehicle = isInVehicle
        ::continue::
    end
end)

-- Function to find a free seat in the vehicle
function GetFreeSeat(vehicle)
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = 1, maxSeats - 1 do
        if IsVehicleSeatFree(vehicle, seat) then
            return seat
        end
    end
    if IsVehicleSeatFree(vehicle, 0) then
        return 0
    end
    return nil
end

-- Follow Player
function FollowPlayer()
    if not dogPed or not DoesEntityExist(dogPed) or isWaiting or isAttacking or isReturning then return end

    ClearPedTasks(dogPed)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    TaskFollowNavMeshToCoord(dogPed, playerCoords.x, playerCoords.y, playerCoords.z, 4.0, -1, Config.DogFollowDistance - 0.5, true, 0)

    Citizen.CreateThread(function()
        while dogPed and DoesEntityExist(dogPed) and not isWaiting and not isAttacking and not isReturning do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local dogCoords = GetEntityCoords(dogPed)
            local distance = #(playerCoords - dogCoords)
            local playerSpeed = #(GetEntityVelocity(playerPed))

            if lastDogPos and playerSpeed > Config.MinMoveSpeed and distance > Config.DogFollowDistance and #(dogCoords - lastDogPos) < 0.2 then
                local rayHandle = StartShapeTestCapsule(dogCoords.x, dogCoords.y, dogCoords.z, playerCoords.x, playerCoords.y, playerCoords.z, 0.5, 10, dogPed, 7)
                local _, hit = GetShapeTestResult(rayHandle)
                if hit == 1 then
                    stuckTimer = stuckTimer + (Config.MoveUpdateInterval / 1000)
                else
                    stuckTimer = 0
                end
            else
                stuckTimer = 0
            end
            lastDogPos = dogCoords

            local isColliding = IsEntityPositionFrozen(dogPed) or IsEntityAttached(dogPed) or IsEntityInAir(dogPed)
            if isColliding then
                stuckTimer = stuckTimer + (Config.MoveUpdateInterval / 1000)
            end

            local currentTime = GetGameTimer()
            if (distance > Config.MaxTeleportDistance or stuckTimer > Config.StuckTimeThreshold) and (currentTime - lastTeleportTime > 3000) then
                if not IsPedInAnyVehicle(playerPed, false) and not isAttacking then
                    SetEntityInvincible(dogPed, true)
                    ClearPedTasks(dogPed)
                    local offset = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, -2.0, 0.0)
                    local _, groundZ = GetGroundZFor_3dCoord(offset.x, offset.y, offset.z + 1.0, false)
                    SetEntityCoords(dogPed, offset.x, offset.y, groundZ, false, false, false, true)
                    SetEntityInvincible(dogPed, false)
                    QBCore.Functions.Notify('K9 teleported to you!', 'success')
                    lastTeleportTime = currentTime
                    stuckTimer = 0
                    TaskFollowNavMeshToCoord(dogPed, playerCoords.x, playerCoords.y, playerCoords.z, 4.0, -1, Config.DogFollowDistance - 0.5, true, 0)
                end
            end

            local moveSpeed = playerSpeed > 2.0 and 4.0 or 2.0
            if distance > Config.DogFollowDistance then
                TaskFollowNavMeshToCoord(dogPed, playerCoords.x, playerCoords.y, playerCoords.z, moveSpeed, -1, Config.DogFollowDistance - 0.5, true, 0)
            end

            Citizen.Wait(Config.MoveUpdateInterval)
        end
    end)
end

-- Toggle Wait
RegisterNetEvent('qb-k9:client:toggleWait')
AddEventHandler('qb-k9:client:toggleWait', function()
    if not dogPed or not DoesEntityExist(dogPed) then return end

    isWaiting = not isWaiting
    if isWaiting then
        ClearPedTasks(dogPed)
        SetEntityInvincible(dogPed, true)
        RequestAnimDict('creatures@rottweiler@amb@world_dog_sitting@idle_a')
        while not HasAnimDictLoaded('creatures@rottweiler@amb@world_dog_sitting@idle_a') do
            Citizen.Wait(0)
        end
        TaskPlayAnim(dogPed, 'creatures@rottweiler@amb@world_dog_sitting@idle_a', 'idle_a', 8.0, -8.0, -1, 1, 0, false, false, false)
        QBCore.Functions.Notify('K9 is waiting and sitting (Godmode).', 'success')
    else
        SetEntityInvincible(dogPed, false)
        ClearPedTasks(dogPed)
        QBCore.Functions.Notify('K9 is following.', 'success')
        FollowPlayer()
    end
end)

-- Bark
RegisterNetEvent('qb-k9:client:bark')
AddEventHandler('qb-k9:client:bark', function()
    if not dogPed or not DoesEntityExist(dogPed) then return end

    RequestAnimDict('creatures@rottweiler@amb@world_dog_barking@idle_a')
    while not HasAnimDictLoaded('creatures@rottweiler@amb@world_dog_barking@idle_a') do
        Citizen.Wait(0)
    end
    TaskPlayAnim(dogPed, 'creatures@rottweiler@amb@world_dog_barking@idle_a', 'idle_a', 8.0, -8.0, -1, 0, 0, false, false, false)
    QBCore.Functions.Notify('K9 is barking!', 'success')
    Citizen.Wait(3000)
    ClearPedTasks(dogPed)
    if not isWaiting then
        FollowPlayer()
    end
end)

-- Toggle Attack
RegisterNetEvent('qb-k9:client:toggleAttack')
AddEventHandler('qb-k9:client:toggleAttack', function(data)
    if not dogPed or not DoesEntityExist(dogPed) then return end

    local targetPed = data.entity
    local playerPed = PlayerPedId()
    if not targetPed or not DoesEntityExist(targetPed) or targetPed == playerPed or targetPed == dogPed then
        QBCore.Functions.Notify('Invalid target!', 'error')
        return
    end

    if not HasEntityClearLosToEntity(dogPed, targetPed, 17) then
        QBCore.Functions.Notify('K9 cannot see the target!', 'error')
        return
    end

    for i, queuedTarget in ipairs(attackQueue) do
        if queuedTarget == targetPed then
            table.remove(attackQueue, i)
            if attackTarget == targetPed then
                ProcessAttackQueue()
            end
            QBCore.Functions.Notify('K9 stopped attacking target.', 'success')
            return
        end
    end

    table.insert(attackQueue, targetPed)
    QBCore.Functions.Notify('K9 added target to attack queue!', 'success')
    if not isAttacking then
        ProcessAttackQueue()
    end
end)

-- Utility Functions
function TaskStayInPlace(ped)
    ClearPedTasks(ped)
    TaskStartScenarioInPlace(ped, 'WORLD_DOG_SIT', 0, true)
end

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end

-- Health Regen
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        if dogPed and DoesEntityExist(dogPed) then
            local hp = GetEntityHealth(dogPed)
            if hp > 0 and hp < Config.DogMaxHealth and not isAttacking then
                local newHp = math.min(hp + Config.DogRegenRate * 2, Config.DogMaxHealth)
                SetEntityHealth(dogPed, newHp)
            end
        end
    end
end)

-- K9 Death Check
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if dogPed and DoesEntityExist(dogPed) then
            local hp = GetEntityHealth(dogPed)
            if hp <= Config.DeathHealthThreshold or IsEntityDead(dogPed) then
                Citizen.Wait(2000)
                hp = GetEntityHealth(dogPed)
                if hp <= Config.DeathHealthThreshold or IsEntityDead(dogPed) then
                    QBCore.Functions.Notify('Your K9 has died or been critically injured. You need to get a new one.', 'error')
                    if DoesEntityExist(dogPed) then
                        SetEntityHealth(dogPed, 0)
                        Citizen.Wait(1000)
                        DeleteEntity(dogPed)
                    end
                    dogPed = nil
                    isDogSpawned = false
                    isWaiting = false
                    isAttacking = false
                    isReturning = false
                    attackTarget = nil
                    attackQueue = {}
                    lastDogPos = nil
                    stuckTimer = 0
                end
            end
        else
            dogPed = nil
            isDogSpawned = false
            isWaiting = false
            isAttacking = false
            isReturning = false
            attackTarget = nil
            attackQueue = {}
            lastDogPos = nil
            stuckTimer = 0
        end
    end
end)