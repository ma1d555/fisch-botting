-- ============================================================
-- Misc tab: stats, safety (anti-AFK, auto rejoin, pause when someone is near), webhook alerts, panic key
-- ============================================================
local Extras = (function()
    local M = {}
    local HttpService = game:GetService("HttpService")
    local LP = Players.LocalPlayer
    local function alive() return getgenv().FishTPSession == FISHTP_SESSION end

    -- the switches the panic key and the proximity pause turn off (and, for the pause, back on)
    local RUN_KEYS = {
        "Fishing/Fishing/Auto Cast", "Fishing/Fishing/Auto Reel", "Fishing/Fishing/Auto Shake",
        "Fishing/Fishing/Auto Sell", "Progression/Progression/Auto Progression",
    }
    local RODS = { "Fortune Rod", "Wisdom Rod", "Heaven's Rod", "Pinion's Aria", "Tryhard Rod" }

    local alerts -- the Webhook Alerts switch

    -- ---- webhook ------------------------------------------------------------------------------

    local function webhookUrl()
        local url = tostring(FishSettings.ui.webhook or "")
        if url:match("^https://discord%.com/api/webhooks/") or url:match("^https://discordapp%.com/api/webhooks/") then return url end
        return nil
    end

    local function send(text, force)
        if not force and not (alerts and alerts:Get()) then return false end
        local url = webhookUrl()
        local req = request or http_request or (syn and syn.request) or (http and http.request)
        if not url or not req then return false end
        task.spawn(function()
            pcall(req, {
                Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ content = ("**%s** · %s"):format(LP.Name, text) }),
            })
        end)
        return true
    end

    -- ---- helpers ------------------------------------------------------------------------------

    local function commas(n)
        local s = tostring(math.floor(n + 0.5))
        local sign = s:sub(1, 1) == "-" and "-" or ""
        s = s:gsub("^-", "")
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return sign .. s
    end

    local function clock(seconds)
        seconds = math.floor(seconds)
        return ("%02d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
    end

    local function setControls(keys, value)
        local was = {}
        for _, key in ipairs(keys) do
            local ctl = FishUI.controls[key]
            if ctl and ctl:Get() == not value then
                was[#was + 1] = key
                pcall(ctl.Set, ctl, value)
            end
        end
        return was
    end

    -- ---- panic --------------------------------------------------------------------------------

    local paused, pausedKeys = false, {}
    function M.panic()
        paused, pausedKeys = false, {}
        pcall(Progression.panic)
        setControls(RUN_KEYS, false)
        FishUI.Notify("Panic", "Everything stopped", 4)
        send("Panic key pressed: everything stopped")
    end

    -- ---- tab ----------------------------------------------------------------------------------

    function M.build(tab)
        local stats = tab:AddSection("Stats", true, "Left")
        local safety = tab:AddSection("Safety", true, "Left")
        local hook = tab:AddSection("Alerts", true, "Right")

        -- stats: since the script started (or the last Reset)
        local statsPara = stats:AddParagraph({ Title = "Session", Content = "…" })
        local base
        local function resetStats()
            local ok, snap = pcall(Progression.stats)
            base = { t = os.clock(), catches = ok and snap.catches or 0, coins = ok and snap.coins or 0, level = ok and snap.level or 0 }
        end
        resetStats()
        stats:AddButton({ Title = "Reset Stats", Callback = resetStats })
        task.spawn(function()
            while alive() do
                pcall(function()
                    local snap = Progression.stats()
                    local hours = math.max((os.clock() - base.t) / 3600, 1 / 3600)
                    local gained = snap.coins - base.coins
                    local caught = snap.catches - base.catches
                    statsPara:SetDesc(("%s\nCatches %s (%s/h)\nC$ %s%s (%s/h)\nLevels +%d"):format(
                        clock(os.clock() - base.t), commas(caught), commas(caught / hours),
                        gained >= 0 and "+" or "", commas(gained), commas(gained / hours), math.max(0, snap.level - base.level)))
                end)
                task.wait(1)
            end
        end)

        -- anti-AFK
        local afk = safety:AddToggle({ Title = "Anti AFK", Default = true })
        pcall(function()
            local VirtualUser = game:GetService("VirtualUser")
            LP.Idled:Connect(function()
                if not alive() or not afk:Get() then return end
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)

        -- auto rejoin: when the game shows its disconnect/kick message, teleport back in and re-run the script
        local rejoin = safety:AddToggle({ Title = "Auto Rejoin", Default = false })
        local rejoining = false
        local function rejoinNow(reason)
            if rejoining or not alive() or not rejoin:Get() then return end
            rejoining = true
            FishUI.Notify("Disconnected", "Rejoining…", 6)
            send("Disconnected (" .. tostring(reason) .. "), rejoining")
            task.spawn(function()
                local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
                if queue then pcall(queue, getgenv().FishTPQueueSource or 'loadstring(readfile("fishtp/loader.lua"))()') end
                local TeleportService = game:GetService("TeleportService")
                for _ = 1, 30 do
                    if not alive() then return end
                    pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
                    task.wait(8)
                end
                rejoining = false
            end)
        end
        pcall(function()
            game:GetService("GuiService").ErrorMessageChanged:Connect(function(message)
                if message and message ~= "" then rejoinNow(message) end
            end)
        end)
        pcall(function()
            local overlay = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 5):WaitForChild("promptOverlay", 5)
            overlay.ChildAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" then rejoinNow("kicked") end
            end)
        end)

        -- pause while another player is close, carry on once they've left
        local pauseNear = safety:AddToggle({ Title = "Pause Near Players", Default = false })
        local pauseDistance = safety:AddSlider({ Title = "Pause Distance", Min = 10, Max = 300, Increment = 10, Default = 60 })
        local function someoneNear()
            local mine = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not mine then return false end
            for _, other in ipairs(Players:GetPlayers()) do
                local root = other ~= LP and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - mine.Position).Magnitude <= pauseDistance:Get() then return true, other.Name end
            end
            return false
        end
        task.spawn(function()
            local clearChecks = 0
            while alive() do
                task.wait(1)
                local ok, near, who = pcall(someoneNear)
                near = ok and near and pauseNear:Get()
                if near then
                    clearChecks = 0
                    if not paused then
                        paused = true
                        pausedKeys = setControls(RUN_KEYS, false)
                        FishUI.Notify("Paused", tostring(who) .. " is nearby", 4)
                        send("Paused: " .. tostring(who) .. " is nearby")
                    end
                elseif paused then
                    clearChecks = clearChecks + 1
                    if clearChecks >= 3 or not pauseNear:Get() then
                        paused, clearChecks = false, 0
                        for _, key in ipairs(pausedKeys) do
                            local ctl = FishUI.controls[key]
                            if ctl then pcall(ctl.Set, ctl, true) end
                        end
                        if #pausedKeys > 0 then FishUI.Notify("Resumed", "Nobody nearby", 3) end
                        pausedKeys = {}
                    end
                end
            end
        end)

        -- alerts
        alerts = hook:AddToggle({ Title = "Webhook Alerts", Default = false })
        hook:AddInput({
            Title = "Webhook URL", Default = FishSettings.ui.webhook or "", Placeholder = "Discord webhook",
            Callback = function(v)
                FishSettings.ui.webhook = tostring(v or "")
                FishSettings.saveUI()
            end,
        })
        hook:AddButton({
            Title = "Test Webhook",
            Callback = function()
                if send("Test message", true) then
                    FishUI.Notify("Webhook", "Sent a test message", 3)
                else
                    FishUI.Notify("Webhook", "Needs a Discord webhook URL", 4)
                end
            end,
        })

        -- progression news: stuck / done go to the webhook and pop up
        table.insert(Progression.statusHooks, function(status, detail)
            if status:find("^Stuck") or status == "Done" then
                local text = status .. (detail ~= "" and (": " .. detail) or "")
                FishUI.Notify("Progression", text, 6)
                send(text)
            end
        end)

        -- rods: a message when one shows up in the inventory
        task.spawn(function()
            local G = Progression.G
            local owned
            while alive() do
                local now = {}
                for _, rod in ipairs(RODS) do
                    local ok, has = pcall(G.ownsRod, rod)
                    if ok then now[rod] = has == true end
                end
                if owned then
                    for _, rod in ipairs(RODS) do
                        if now[rod] and not owned[rod] then
                            FishUI.Notify("New rod", rod, 8)
                            send("Got " .. rod)
                        end
                    end
                end
                owned = now
                task.wait(10)
            end
        end)

        FishSettings.bindKey("panicKey", M.panic)
    end

    return M
end)()
