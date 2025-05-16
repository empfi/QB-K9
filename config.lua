Config = {}

--[[
                                   $$$$$$\  $$\       $$$$$$$\                                $$\                                                        $$\     
                                  $$  __$$\ \__|      $$  __$$\                               $$ |                                                       $$ |    
 $$$$$$\  $$$$$$\$$$$\   $$$$$$\  $$ /  \__|$$\       $$ |  $$ | $$$$$$\ $$\    $$\  $$$$$$\  $$ | $$$$$$\   $$$$$$\  $$$$$$\$$$$\   $$$$$$\  $$$$$$$\ $$$$$$\   
$$  __$$\ $$  _$$  _$$\ $$  __$$\ $$$$\     $$ |      $$ |  $$ |$$  __$$\\$$\  $$  |$$  __$$\ $$ |$$  __$$\ $$  __$$\ $$  _$$  _$$\ $$  __$$\ $$  __$$\\_$$  _|  
$$$$$$$$ |$$ / $$ / $$ |$$ /  $$ |$$  _|    $$ |      $$ |  $$ |$$$$$$$$ |\$$\$$  / $$$$$$$$ |$$ |$$ /  $$ |$$ /  $$ |$$ / $$ / $$ |$$$$$$$$ |$$ |  $$ | $$ |    
$$   ____|$$ | $$ | $$ |$$ |  $$ |$$ |      $$ |      $$ |  $$ |$$   ____| \$$$  /  $$   ____|$$ |$$ |  $$ |$$ |  $$ |$$ | $$ | $$ |$$   ____|$$ |  $$ | $$ |$$\ 
\$$$$$$$\ $$ | $$ | $$ |$$$$$$$  |$$ |      $$ |      $$$$$$$  |\$$$$$$$\   \$  /   \$$$$$$$\ $$ |\$$$$$$  |$$$$$$$  |$$ | $$ | $$ |\$$$$$$$\ $$ |  $$ | \$$$$  |
 \_______|\__| \__| \__|$$  ____/ \__|      \__|      \_______/  \_______|   \_/     \_______|\__| \______/ $$  ____/ \__| \__| \__| \_______|\__|  \__|  \____/ 
                        $$ |                                                                                $$ |                                                 
                        $$ |                                                                                $$ |                                                 
                        \__|                                                                                \__|                                                 
]]                        

-- General Settings
Config.UseOxTarget = true -- Set to true to use ox-target, false to use qb-target
Config.K9Station = vector3(441.0, -981.0, 30.7) -- Location to collect/return the K9
Config.JobRequired = 'police' -- Job required to use K9
Config.K9AllowedRanks = '3+' -- Allowed ranks (e.g., '1,2,3' for specific ranks, '3+' for 3 and above, '3-' for 3 and below, '2' for only rank 2)

-- Dog Settings
Config.DogModels = {'a_c_husky', 'a_c_shepherd', 'a_c_retriever'} -- Valid GTA V dog models
Config.DogFollowDistance = 2.0 -- Distance the dog maintains while following
Config.DogMaxHealth = 400 -- Maximum health of the dog
Config.DogRegenRate = 2 -- Health regeneration rate per interval
Config.DogRegenInterval = 1000 -- Interval for health regeneration in ms

-- Movement Settings
Config.MaxTeleportDistance = 40.0 -- Maximum distance before dog teleports to player
Config.StuckTimeThreshold = 5.0 -- Time in seconds before dog is considered stuck
Config.MoveUpdateInterval = 200 -- Interval in ms between movement updates
Config.MinMoveSpeed = 0.5 -- Minimum player speed to consider movement for stuck detection
Config.TeleportCooldown = 5000 -- Cooldown in ms between teleports

-- Attack Settings
Config.MaxAttackDistance = 60.0 -- Maximum distance to attack target before aborting

-- Death Check Settings
Config.DeathHealthThreshold = 1 -- Health level at which the dog is considered dead (in case IsEntityDead doesn't trigger)

-- Shelter Settings
Config.UseShelterLocation = true -- Set to true to make dog walk from/to shelter, false to spawn near player and despawn immediately
Config.K9ShelterLocation = vector3(451.0835, -979.5005, 29.6899) -- Shelter location where dog walks from/to (e.g., near police station)

-- ox-target Options
Config.DogTargetOx = {
    {
        name = 'qb-k9:client:toggleWait',
        event = 'qb-k9:client:toggleWait',
        icon = 'fas fa-pause',
        label = 'Toggle Wait',
        groups = Config.JobRequired,
        canInteract = function(entity)
            return exports['qb-k9']:HasK9() and entity == exports['qb-k9']:GetDogPed()
        end,
        distance = 2.0
    },
    {
        name = 'qb-k9:client:bark',
        event = 'qb-k9:client:bark',
        icon = 'fas fa-volume-up',
        label = 'K9 Bark',
        groups = Config.JobRequired,
        canInteract = function(entity)
            return exports['qb-k9']:HasK9() and entity == exports['qb-k9']:GetDogPed()
        end,
        distance = 2.0
    }
}

Config.EntityTargetOx = {
    {
        name = 'qb-k9:client:toggleAttack',
        event = 'qb-k9:client:toggleAttack',
        icon = 'fas fa-skull',
        label = 'K9 Attack',
        groups = Config.JobRequired,
        canInteract = function(entity)
            local hasK9 = exports['qb-k9']:HasK9()
            local isWaiting = exports['qb-k9']:IsK9Waiting()
            local isDog = entity == exports['qb-k9']:GetDogPed()
            local isDead = IsEntityDead(entity)
            local isOwner = entity == PlayerPedId()
            return hasK9 and not isWaiting and not isDog and not isDead and not isOwner
        end,
        distance = 3.0
    }
}

-- qb-target Options
Config.DogTarget = {
    options = {
        {
            event = 'qb-k9:client:toggleWait',
            icon = 'fas fa-pause',
            label = 'Toggle Wait',
            job = Config.JobRequired,
            canInteract = function(entity)
                return exports['qb-k9']:HasK9() and entity == exports['qb-k9']:GetDogPed()
            end
        },
        {
            event = 'qb-k9:client:bark',
            icon = 'fas fa-volume-up',
            label = 'K9 Bark',
            job = Config.JobRequired,
            canInteract = function(entity)
                return exports['qb-k9']:HasK9() and entity == exports['qb-k9']:GetDogPed()
            end
        }
    }
}

Config.EntityTarget = {
    options = {
        {
            event = 'qb-k9:client:toggleAttack',
            icon = 'fas fa-skull',
            label = 'K9 Attack',
            job = Config.JobRequired,
            canInteract = function(entity)
                local hasK9 = exports['qb-k9']:HasK9()
                local isWaiting = exports['qb-k9']:IsK9Waiting()
                local isDog = entity == exports['qb-k9']:GetDogPed()
                local isDead = IsEntityDead(entity)
                local isOwner = entity == PlayerPedId()
                return hasK9 and not isWaiting and not isDog and not isDead and not isOwner
            end
        }
    }
}

-- Thanks for using my script <3