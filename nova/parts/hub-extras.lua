-- ============================================================
-- Misc tab: stats, safety (anti-AFK, auto rejoin, pause when someone is near), webhook alerts, panic key
-- ============================================================
local Extras = (function()
    local M = {}
    local HttpService = game:GetService("HttpService")
    local LP = Players.LocalPlayer
    local function alive() return getgenv().NovaSession == NOVA_SESSION end

    -- the switches the panic key and the proximity pause turn off (and, for the pause, back on)
    local RUN_KEYS = {
        "Fishing/Fishing/Auto Cast", "Fishing/Fishing/Auto Reel", "Fishing/Fishing/Auto Shake",
        "Fishing/Fishing/Auto Sell", "Progression/Progression/Auto Progression",
    }
    local RODS = { "Fortune Rod", "Wisdom Rod", "Heaven's Rod", "Pinion's Aria", "Tryhard Rod" }

    local alerts -- the Webhook Alerts switch

    -- ---- webhook ------------------------------------------------------------------------------

    -- only Discord webhooks: the URL is typed in by hand, so nothing else gets posted to
    local WEBHOOK_PREFIXES = {
        "https://discord.com/api/webhooks/", "https://canary.discord.com/api/webhooks/",
        "https://ptb.discord.com/api/webhooks/", "https://discordapp.com/api/webhooks/",
    }
    local function webhookUrl()
        local url = tostring(NovaSettings.ui.webhook or ""):gsub("^%s+", ""):gsub("%s+$", "")
        for _, prefix in ipairs(WEBHOOK_PREFIXES) do
            if url:sub(1, #prefix) == prefix then return url end
        end
        return nil
    end

    -- force: send even with Webhook Alerts off (the test button, catch alerts). onResult(ok, detail) once it's done.
    local function send(text, force, onResult)
        if not force and not (alerts and alerts:Get()) then return false, "Webhook Alerts is off" end
        local url = webhookUrl()
        if not url then return false, "no Discord webhook URL" end
        local req = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
        if not req then return false, "this executor can't send web requests" end
        task.spawn(function()
            local ok, res = pcall(req, {
                Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ content = ("**%s** · %s"):format(LP.Name, text) }),
            })
            local code = ok and type(res) == "table" and tonumber(res.StatusCode) or nil
            local good = (code ~= nil and code >= 200 and code < 300) or (code == nil and ok and type(res) == "table" and res.Success == true)
            local detail = ok and ("HTTP " .. tostring(code or "?")) or tostring(res)
            if not good then warn("[Nova] webhook not sent: " .. detail) end
            if onResult then pcall(onResult, good, detail) end
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

    -- ---- catches ------------------------------------------------------------------------------

    local RARITIES = {
        "Trash", "Common", "Uncommon", "Unusual", "Rare", "Legendary", "Mythical", "Exotic", "Secret", "Relic",
        "Fragment", "Gemstone", "Extinct", "Limited", "Special", "Apex", "Divine", "Godly",
    }
    local rarityByLower = {}
    for _, r in ipairs(RARITIES) do rarityByLower[r:lower()] = r end

    -- The catch announcement's own fields first; failing that, the game's fish data (if it has a folder for it).
    local function rarityOf(name, fish)
        if type(fish) == "table" then
            for _, key in ipairs({ "Rarity", "rarity", "Tier", "tier" }) do
                if type(fish[key]) == "string" and fish[key] ~= "" then return fish[key] end
            end
            for _, value in pairs(fish) do
                if type(value) == "string" and rarityByLower[value:lower()] then return rarityByLower[value:lower()] end
            end
        end
        local found
        pcall(function()
            local entry = game:GetService("ReplicatedStorage").resources.items.fish:FindFirstChild(name)
            if not entry then return end
            found = entry:GetAttribute("Rarity") or entry:GetAttribute("rarity")
            local value = not found and (entry:FindFirstChild("Rarity") or entry:FindFirstChild("rarity"))
            if value then found = value.Value end
        end)
        return type(found) == "string" and found ~= "" and found or nil
    end

    -- "Mythical, exotic" -> { mythical = true, exotic = true }
    local function wordSet(text)
        local set = {}
        for word in tostring(text or ""):gmatch("[^,]+") do
            word = word:gsub("^%s+", ""):gsub("%s+$", ""):lower()
            if word ~= "" then set[word] = true end
        end
        return set
    end

    local function setControls(keys, value)
        local was = {}
        for _, key in ipairs(keys) do
            local ctl = NovaUI.controls[key]
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
        NovaUI.Notify("Panic", "Everything stopped", 4)
        send("Panic key pressed: everything stopped")
    end

    -- ---- tab ----------------------------------------------------------------------------------

    function M.build(tab)
        local stats = tab:AddSection("Stats", true, "Left")
        local safety = tab:AddSection("Safety", true, "Left")
        local hook = tab:AddSection("Alerts", true, "Right")

        -- stats: since the script started (or the last Reset)
        local statsPara = stats:AddParagraph({ Title = "Session", Content = "…" })
        local base, lastXp, xpGained
        local function resetStats()
            local ok, snap = pcall(Progression.stats)
            base = { t = os.clock(), catches = ok and snap.catches or 0, coins = ok and snap.coins or 0, level = ok and snap.level or 0 }
            lastXp, xpGained = ok and snap.xp or nil, 0
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
                    -- XP is per level: when it drops, a level went up and the new amount counts from zero
                    if snap.xp then
                        if lastXp then xpGained = xpGained + (snap.xp >= lastXp and snap.xp - lastXp or snap.xp) end
                        lastXp = snap.xp
                    end
                    local xpLine = snap.xp and ("XP +%s (%s/h)"):format(commas(xpGained), commas(xpGained / hours)) or "XP not found yet"
                    statsPara:SetDesc(("%s\nCatches %s (%s/h)\nC$ %s%s (%s/h)\n%s\nLevels +%d"):format(
                        clock(os.clock() - base.t), commas(caught), commas(caught / hours),
                        gained >= 0 and "+" or "", commas(gained), commas(gained / hours), xpLine, math.max(0, snap.level - base.level)))
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
            NovaUI.Notify("Disconnected", "Rejoining…", 6)
            send("Disconnected (" .. tostring(reason) .. "), rejoining")
            task.spawn(function()
                local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
                if queue then pcall(queue, getgenv().NovaQueueSource or 'loadstring(readfile("nova/loader.lua"))()') end
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
                        NovaUI.Notify("Paused", tostring(who) .. " is nearby", 4)
                        send("Paused: " .. tostring(who) .. " is nearby")
                    end
                elseif paused then
                    clearChecks = clearChecks + 1
                    if clearChecks >= 3 or not pauseNear:Get() then
                        paused, clearChecks = false, 0
                        for _, key in ipairs(pausedKeys) do
                            local ctl = NovaUI.controls[key]
                            if ctl then pcall(ctl.Set, ctl, true) end
                        end
                        if #pausedKeys > 0 then NovaUI.Notify("Resumed", "Nobody nearby", 3) end
                        pausedKeys = {}
                    end
                end
            end
        end)

        -- alerts
        local hookStatus = hook:AddParagraph({ Title = "Webhook", Content = webhookUrl() and "URL set" or "Paste a Discord webhook URL" })
        local function hookSay(text) pcall(function() hookStatus:SetDesc(text) end) end
        alerts = hook:AddToggle({ Title = "Webhook Alerts", Default = false })
        hook:AddInput({
            Title = "Webhook URL", Default = NovaSettings.ui.webhook or "", Placeholder = "Discord webhook",
            Callback = function(v)
                NovaSettings.ui.webhook = tostring(v or "")
                NovaSettings.saveUI()
                hookSay(webhookUrl() and "URL set" or "That isn't a Discord webhook URL")
            end,
        })
        hook:AddButton({
            Title = "Test Webhook",
            Callback = function()
                hookSay("Sending…")
                local queued, why = send("Test message", true, function(good, detail)
                    hookSay(good and ("Test sent (" .. detail .. ")") or ("Failed: " .. detail))
                    NovaUI.Notify("Webhook", good and "Test sent" or ("Failed: " .. detail), 4)
                end)
                if not queued then
                    hookSay("Not sent: " .. why)
                    NovaUI.Notify("Webhook", "Not sent: " .. why, 4)
                end
            end,
        })
        local toasts = hook:AddToggle({
            Title = "Toasts", Default = NovaUI.ToastsEnabled ~= false,
            Callback = function(on) NovaUI.ToastsEnabled = on end,
        })
        NovaUI.ToastsEnabled = toasts:Get()

        -- catches: a toast for each (or only the ones that match), the webhook for the ones that match
        local catchSec = tab:AddSection("Catch Alerts", true, "Right")
        local catchToasts = catchSec:AddToggle({ Title = "Catch Toasts", Default = false })
        local catchHook = catchSec:AddToggle({ Title = "Catch Webhook", Default = false })
        local rarityFilter = wordSet(NovaSettings.ui.alertRarities)
        local fishFilter = wordSet(NovaSettings.ui.alertFish)
        catchSec:AddInput({
            Title = "Rarities", Default = NovaSettings.ui.alertRarities or "", Placeholder = "Mythical, Exotic", Save = true,
            Callback = function(v)
                NovaSettings.ui.alertRarities = tostring(v or "")
                NovaSettings.saveUI()
                rarityFilter = wordSet(v)
            end,
        })
        catchSec:AddInput({
            Title = "Fish", Default = NovaSettings.ui.alertFish or "", Placeholder = "Megalodon, Moby", Save = true,
            Callback = function(v)
                NovaSettings.ui.alertFish = tostring(v or "")
                NovaSettings.saveUI()
                fishFilter = wordSet(v)
            end,
        })
        catchSec:AddParagraph({ Title = "How it matches", Content = "Comma separated, any case. Fish names must be the full name. Catch Toasts with both empty shows every catch." })
        local logged = 0
        table.insert(Progression.catchHooks, function(name, fish)
            -- the first few catches' fields go to the console, to see what the game sends
            if logged < 3 and type(fish) == "table" then
                logged = logged + 1
                local fields = {}
                for key, value in pairs(fish) do
                    if type(value) ~= "table" and type(value) ~= "userdata" then fields[#fields + 1] = tostring(key) .. "=" .. tostring(value) end
                end
                print("[Nova] catch data: " .. table.concat(fields, ", "))
            end
            local rarity = rarityOf(name, fish)
            local mutation = type(fish) == "table" and fish.Mutation and tostring(fish.Mutation) or ""
            local text = name .. (rarity and (" (" .. rarity .. ")") or "") .. (mutation ~= "" and (" · " .. mutation) or "")
            local filtering = next(rarityFilter) ~= nil or next(fishFilter) ~= nil
            local match = (rarity ~= nil and rarityFilter[rarity:lower()] == true) or fishFilter[name:lower()] == true
            if catchToasts:Get() and (match or not filtering) then NovaUI.Notify("Caught", text, 3) end
            if catchHook:Get() and match then send("Caught **" .. text .. "**", true) end
        end)

        -- progression news: stuck / done go to the webhook and pop up
        table.insert(Progression.statusHooks, function(status, detail)
            if status:find("^Stuck") or status == "Done" then
                local text = status .. (detail ~= "" and (": " .. detail) or "")
                NovaUI.Notify("Progression", text, 6)
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
                            NovaUI.Notify("New rod", rod, 8)
                            send("Got " .. rod)
                        end
                    end
                end
                owned = now
                task.wait(10)
            end
        end)

        NovaSettings.bindKey("panicKey", M.panic)
    end

    return M
end)()
