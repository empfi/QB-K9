local QBCore = exports['qb-core']:GetCoreObject()

-- Server-side job and rank check for K9 collection
RegisterNetEvent('qb-k9:server:collectK9')
AddEventHandler('qb-k9:server:collectK9', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local PlayerJob = Player.PlayerData.job

    if PlayerJob.name == Config.JobRequired then
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
            TriggerClientEvent('qb-k9:client:collectK9', src)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Your rank is not allowed to use K9.', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'You are not a police officer!', 'error')
    end
end)

-- Server-side job and rank check for K9 return
RegisterNetEvent('qb-k9:server:returnK9')
AddEventHandler('qb-k9:server:returnK9', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local PlayerJob = Player.PlayerData.job

    if PlayerJob.name == Config.JobRequired then
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
            TriggerClientEvent('qb-k9:client:returnK9', src)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Your rank is not allowed to use K9.', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'You are not a police officer!', 'error')
    end
end)