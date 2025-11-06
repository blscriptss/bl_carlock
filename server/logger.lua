local LogConfig = {
    DiscordWebhook = "",  -- add your Discord webhook here
    FiveMerrWebhook = "", -- add your FiveMerr webhook here
    FiveManageWebhook = "" -- add your FiveManage webhook here
}

local function sendToDiscord(title, description, color)
    if not LogConfig.DiscordWebhook or LogConfig.DiscordWebhook == "" then return end
    local embed = {{
        ["title"] = title or "Car Lock",
        ["description"] = description,
        ["color"] = color or 16776960,
        ["footer"] = {{
            ["text"] = "Carlock | " .. os.date("%Y-%m-%d %H:%M:%S")
        }}
    }}
    PerformHttpRequest(LogConfig.DiscordWebhook, function() end, 'POST', json.encode({
        username = "Car Lock Logs",
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

local function sendToFiveMerr(title, description)
    if not LogConfig.FiveMerrWebhook or LogConfig.FiveMerrWebhook == "" then return end
    PerformHttpRequest(LogConfig.FiveMerrWebhook, function() end, 'POST', json.encode({
        title = title or "Car Lock",
        message = description
    }), { ['Content-Type'] = 'application/json' })
end

local function sendToFiveManage(title, description)
    if not LogConfig.FiveManageWebhook or LogConfig.FiveManageWebhook == "" then return end
    PerformHttpRequest(LogConfig.FiveManageWebhook, function() end, 'POST', json.encode({
        service = "Car Lock",
        title = title or "Notification",
        message = description
    }), { ['Content-Type'] = 'application/json' })
end

local function sendToAllLoggers(title, description, color)
    sendToDiscord(title, description, color)
    sendToFiveMerr(title, description)
    sendToFiveManage(title, description)
end

return sendToAllLoggers
