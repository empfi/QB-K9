local QBCore = exports['qb-core']:GetCoreObject()

-- Handle dog selection from menu
RegisterNetEvent('qb-k9:client:selectDog')
AddEventHandler('qb-k9:client:selectDog', function(dogModel)
    TriggerServerEvent('qb-k9:server:collectK9', dogModel)
end)

-- Open dog selection menu or spawn directly
RegisterNetEvent('qb-k9:client:openDogMenu')
AddEventHandler('qb-k9:client:openDogMenu', function()
    if not Config.DogModels or #Config.DogModels == 0 then
        QBCore.Functions.Notify('No dog models configured!', 'error')
        return
    end

    if #Config.DogModels == 1 then
        -- Only one dog model, spawn directly
        TriggerServerEvent('qb-k9:server:collectK9', Config.DogModels[1])
    else
        -- Multiple dog models, open selection menu
        local menu = {
            {
                header = "Select K9",
                isMenuHeader = true
            }
        }
        for _, model in ipairs(Config.DogModels) do
            local displayName = model:gsub('^a_c_', ''):gsub('^%l', string.upper)
            table.insert(menu, {
                header = displayName,
                txt = "Select this K9 model",
                params = {
                    event = "qb-k9:client:selectDog",
                    args = model
                }
            })
        end
        if exports['qb-menu'] then
            exports['qb-menu']:openMenu(menu)
        else
            QBCore.Functions.Notify('qb-menu not detected, spawning default dog.', 'error')
            TriggerServerEvent('qb-k9:server:collectK9', Config.DogModels[1])
        end
    end
end)