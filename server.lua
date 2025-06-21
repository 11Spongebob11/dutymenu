-- server.lua
-- Discord Bot Configuration
local DISCORD_BOT_TOKEN = "DISCORD_BOT_TOKEN" -- Replace with your bot token
local GUILD_ID = "GUILD_ID" -- Replace with your Discord server ID

-- Role IDs for each department (replace with your actual role IDs)
local DEPARTMENT_ROLES = {
    SASP = "SASP_ROLE",
    BCSO = "BCSO_ROLE", 
    LSPD = "LSPD_ROLE"
}

-- Store players currently on duty with their start times
local playersOnDuty = {}

-- Function to get Discord ID for a player
function GetDiscordId(src)
    local identifiers = GetPlayerIdentifiers(src)
    for _, identifier in ipairs(identifiers) do
        if string.match(identifier, "discord:") then
            return string.gsub(identifier, "discord:", "")
        end
    end
    return nil
end

-- Function to check if user has department role
function UserHasRole(discordId, roleId, callback)
    local url = ("https://discord.com/api/v10/guilds/%s/members/%s"):format(GUILD_ID, discordId)

    PerformHttpRequest(url, function(code, data, headers)
        if code == 200 then
            local user = json.decode(data)
            local roles = user.roles or {}
            for _, role in ipairs(roles) do
                if role == roleId then
                    callback(true)
                    return
                end
            end
        end
        callback(false)
    end, "GET", "", {
        ["Authorization"] = "Bot " .. DISCORD_BOT_TOKEN,
        ["Content-Type"] = "application/json"
    })
end

-- Function to format duty time
function FormatDutyTime(startTime)
    local currentTime = os.time()
    local dutyDuration = currentTime - startTime
    
    local hours = math.floor(dutyDuration / 3600)
    local minutes = math.floor((dutyDuration % 3600) / 60)
    local seconds = dutyDuration % 60
    
    if hours > 0 then
        return string.format("%d hours, %d minutes, %d seconds", hours, minutes, seconds)
    elseif minutes > 0 then
        return string.format("%d minutes, %d seconds", minutes, seconds)
    else
        return string.format("%d seconds", seconds)
    end
end

-- Function to broadcast duty blips to all clients
function BroadcastDutyBlips()
    TriggerClientEvent("duty:updateBlips", -1, playersOnDuty)
end

-- Main event handler
RegisterServerEvent("duty:updateStatus")
AddEventHandler("duty:updateStatus", function(onDuty, department, playerName, callsign)
    local src = source
    local discordId = GetDiscordId(src)
    local status = onDuty and "On Duty" or "Off Duty"
    local displayName = playerName or GetPlayerName(src)
    local currentTime = os.date("%A, %B %d, %Y %I:%M %p")
    local departmentRole = DEPARTMENT_ROLES[department]

    if not discordId then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 255, 0},
            multiline = true,
            args = {"Duty System", "⚠️ You do not have a linked Discord account."}
        })
        return
    end

    if onDuty then
        -- Check if user has the correct department role
        UserHasRole(discordId, departmentRole, function(hasRole)
            if not hasRole then
                TriggerClientEvent('chat:addMessage', src, {
                    color = {255, 0, 0},
                    multiline = true,
                    args = {"Duty System", "❌ You do not have the required Discord role to go on duty as " .. department}
                })
                return
            end

            -- Add player to duty list with start time
            playersOnDuty[src] = {
                playerName = displayName,
                callsign = callsign,
                department = department,
                startTime = os.time(),
                discordId = discordId
            }

            -- Log to console and send embed since they passed role check
            print(string.format("Player %s (%s) went on duty as %s - %s", displayName, discordId, department, callsign))
            SendDutyLogWebhook(displayName, callsign, department, onDuty, discordId, nil)
            
            -- Broadcast updated blips to all clients
            BroadcastDutyBlips()
        end)
    else
        -- Off duty - calculate duty time if player was on duty
        local dutyTime = nil
        if playersOnDuty[src] then
            dutyTime = FormatDutyTime(playersOnDuty[src].startTime)
            -- Send duty time to the player going off duty
            TriggerClientEvent("duty:showDutyTime", src, dutyTime)
            -- Remove from duty list
            playersOnDuty[src] = nil
        end

        print(string.format("Player %s (%s) went off duty", displayName, discordId))
        SendDutyLogWebhook(displayName, callsign, department, onDuty, discordId, dutyTime)
        
        -- Broadcast updated blips to all clients
        BroadcastDutyBlips()
    end
end)

-- Send embed to Discord webhook
function SendDutyLogWebhook(displayName, callsign, department, onDuty, discordId, dutyTime)
    local currentTime = os.date("%A, %B %d, %Y %I:%M %p")
    local status = onDuty and "On Duty" or "Off Duty"
    local departmentLogos = {
        SASP = "https://i.imgur.com/qwjPGhj.png",
        BCSO = "https://i.imgur.com/MWL8fOL.png",
        LSPD = "https://i.imgur.com/PCRR7pN.png",
    }

    local fields = {
        { name = "Name", value = displayName, inline = true },
        { name = "Callsign", value = callsign, inline = true },
        { name = "Department", value = department, inline = true },
        { name = "Time On Duty", value = onDuty and currentTime or "N/A", inline = true },
        { name = "Time Off Duty", value = not onDuty and currentTime or "N/A", inline = true },
        { name = "Status", value = status, inline = true },
        { name = "Discord Check", value = discordId and "✅ Role Verified" or "⚠️ No Discord Linked", inline = true }
    }

    -- Add duty duration field if going off duty
    if not onDuty and dutyTime then
        table.insert(fields, { name = "Duty Duration", value = dutyTime, inline = true })
    end

    local embed = {
        color = onDuty and 3066993 or 15158332,
        title = "Duty Log",
        description = string.format("**%s** (Callsign: %s) from **%s** is now **%s**", 
            displayName, callsign, department, status),
        thumbnail = { url = departmentLogos[department] or "https://i.imgur.com/default-badge.png" },
        fields = fields,
        footer = {
            text = "SpongeBobs Duty System • " .. currentTime
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    PerformHttpRequest("DISCORD_WEBHOOK_LINK", 
        function() end, 
        "POST", 
        json.encode({
            username = "SpongeBobs Duty System",
            avatar_url = "https://i.imgur.com/4HWBNiv.png",
            embeds = { embed }
        }), 
        { ["Content-Type"] = "application/json" }
    )
end

-- Handle player disconnection
AddEventHandler('playerDropped', function(reason)
    local src = source
    if playersOnDuty[src] then
        local playerData = playersOnDuty[src]
        local dutyTime = FormatDutyTime(playerData.startTime)
        
        -- Log disconnection with duty time
        print(string.format("Player %s disconnected while on duty. Duration: %s", 
            playerData.playerName, dutyTime))
        
        -- Remove from duty list
        playersOnDuty[src] = nil
        
        -- Broadcast updated blips
        BroadcastDutyBlips()
    end
end)

-- Command to see all players on duty (admin/debug)
RegisterCommand("dutylist", function(source, args, rawCommand)
    local src = source
    if src == 0 then -- Server console
        print("=== Players Currently On Duty ===")
        for playerId, data in pairs(playersOnDuty) do
            local dutyTime = FormatDutyTime(data.startTime)
            print(string.format("ID: %s | %s (%s) - %s | Duration: %s", 
                playerId, data.playerName, data.callsign, data.department, dutyTime))
        end
        if next(playersOnDuty) == nil then
            print("No players currently on duty.")
        end
    end
end, true)

-- Send initial blip data when player joins
RegisterServerEvent("duty:requestBlips")
AddEventHandler("duty:requestBlips", function()
    local src = source
    TriggerClientEvent("duty:updateBlips", src, playersOnDuty)
end)