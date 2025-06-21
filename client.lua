local isOnDuty = false
local department = ""
local playerName = ""
local callsign = ""
local dutyBlips = {} -- Store blips for other players on duty

RegisterCommand("duty", function()
    SetNuiFocus(true, true)
    SendNUIMessage({ 
        type = "openDutyMenu",
        currentDuty = isOnDuty
    })
end)

RegisterNUICallback("setDuty", function(data, cb)
    isOnDuty = data.onDuty
    department = data.department
    playerName = data.playerName
    callsign = data.callsign
    
    TriggerServerEvent("duty:updateStatus", isOnDuty, department, playerName, callsign)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("closeMenu", function(_, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

-- Optional: Add a command to check current duty status
RegisterCommand("dutystatus", function()
    if isOnDuty then
        TriggerEvent('chat:addMessage', {
            color = {0, 255, 0},
            multiline = true,
            args = {"Duty Status", string.format("You are ON DUTY as %s (%s) in %s", 
                playerName, callsign, department)}
        })
    else
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"Duty Status", "You are OFF DUTY"}
        })
    end
end)

-- Event to receive duty time when going off duty
RegisterNetEvent("duty:showDutyTime")
AddEventHandler("duty:showDutyTime", function(dutyTime)
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 255},
        multiline = true,
        args = {"Duty System", string.format("You were on duty for: %s", dutyTime)}
    })
end)

-- Event to update blips for all players on duty
RegisterNetEvent("duty:updateBlips")
AddEventHandler("duty:updateBlips", function(playersOnDuty)
    -- Remove all existing duty blips
    for playerId, blipData in pairs(dutyBlips) do
        if DoesBlipExist(blipData.blip) then
            RemoveBlip(blipData.blip)
        end
    end
    dutyBlips = {}
    
    -- Create new blips for players on duty
    for playerId, playerData in pairs(playersOnDuty) do
        local targetPlayer = GetPlayerFromServerId(playerId)
        if targetPlayer ~= -1 and targetPlayer ~= PlayerId() then -- Don't create blip for self
            local targetPed = GetPlayerPed(targetPlayer)
            if DoesEntityExist(targetPed) then
                local blip = AddBlipForEntity(targetPed)
                
                -- Set blip properties based on department
                local blipColor = GetDepartmentBlipColor(playerData.department)
                local blipSprite = GetDepartmentBlipSprite(playerData.department)
                
                SetBlipSprite(blip, blipSprite)
                SetBlipColour(blip, blipColor)
                SetBlipScale(blip, 0.8)
                SetBlipAsShortRange(blip, true)
                
                -- Set blip name
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(string.format("%s - %s (%s)", 
                    playerData.department, playerData.playerName, playerData.callsign))
                EndTextCommandSetBlipName(blip)
                
                dutyBlips[playerId] = {
                    blip = blip,
                    data = playerData
                }
            end
        end
    end
end)

-- Function to get blip color based on department
function GetDepartmentBlipColor(dept)
    local colors = {
        SASP = 5,   -- Yellow
        BCSO = 17,  -- Orange  
        LSPD = 3    -- Blue
    }
    return colors[dept] or 1 -- Default white
end

-- Function to get blip sprite based on department
function GetDepartmentBlipSprite(dept)
    local sprites = {
        SASP = 56,  -- Police car
        BCSO = 56,  -- Police car
        LSPD = 56   -- Police car
    }
    return sprites[dept] or 1 -- Default dot
end

-- Update blips periodically to track player movement
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- Update every 5 seconds
        
        -- Update blip positions for players on duty
        for playerId, blipData in pairs(dutyBlips) do
            local targetPlayer = GetPlayerFromServerId(playerId)
            if targetPlayer ~= -1 then
                local targetPed = GetPlayerPed(targetPlayer)
                if DoesEntityExist(targetPed) and DoesBlipExist(blipData.blip) then
                    -- Blip automatically follows the entity, no need to update position
                else
                    -- Player no longer exists, remove blip
                    if DoesBlipExist(blipData.blip) then
                        RemoveBlip(blipData.blip)
                    end
                    dutyBlips[playerId] = nil
                end
            else
                -- Player disconnected, remove blip
                if DoesBlipExist(blipData.blip) then
                    RemoveBlip(blipData.blip)
                end
                dutyBlips[playerId] = nil
            end
        end
    end
end)

-- Clean up blips when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for playerId, blipData in pairs(dutyBlips) do
            if DoesBlipExist(blipData.blip) then
                RemoveBlip(blipData.blip)
            end
        end
        dutyBlips = {}
    end
end)