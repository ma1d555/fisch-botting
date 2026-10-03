-- ============================================================
-- GUI
-- ============================================================
local MainWindow, FishTab, TPTab, ProgTab, MiscTab, SettingsTab

local function setupWindow()
    FishSettings.autoloadTheme()
    MainWindow = FishUI:CreateWindow({
        Title = "FishTP • " .. executorName,
        Description = "[" .. tostring(FishSettings.ui.toggleKey) .. "] toggle",
        ["Tab Width"] = 110,
        SizeUi = UDim2.fromOffset(640, 440),
        Visible = true,
        Layout = FishSettings.ui.layout,
        OnLayout = function(layout)
            FishSettings.ui.layout = layout
            FishSettings.saveUI()
        end,
    })

    local Grp = MainWindow:CreateGroup({"Main"})
    FishTab = Grp:CreateTab({ "Fishing" })
    TPTab   = Grp:CreateTab({ "TP", NoSave = true }) -- its dropdowns teleport when set, so configs skip them
    ProgTab = Grp:CreateTab({ "Progression" })
    MiscTab = Grp:CreateTab({ "Misc" })
    SettingsTab = Grp:CreateTab({ "Settings", NoSave = true })
    getgenv().FishTPWindow = MainWindow
end

local function buildFishingTab()
    local Left       = FishTab:AddSection("Fishing",         true, "Left")
    local Right       = FishTab:AddSection("Fishing Setting", true, "Right")
    local FishingZone = FishTab:AddSection("Fishing Zone",    true, "Right")

    Left:AddDropdown({
        Title = "Reel Mode",
        Options = {"Super Instant", "Legit", "Manual"},
        Default = _G.Config.ReelMode or "Super Instant",
        Callback = function(v)
            if type(v) == "table" then v = v[1] or "Super Instant" end
            _G.Config.ReelMode = v
            _G.Config.InstantReel = (v == "Super Instant")
            if AutoReel then AutoReel(v ~= "Manual") end
        end
    })

    Left:AddToggle({
        Title = "Auto Cast",
        Default = _G.Config.AutoCast or false,
        Callback = function(v)
            _G.Config.AutoCast = v
            _G.Config.InstantCast = v
            if AutoCast then AutoCast(v) end
        end
    })

    Left:AddToggle({
        Title = "Legit Cast",
        Default = _G.Config.LegitCast or false,
        Callback = function(v)
            _G.Config.LegitCast = v
        end
    })

    Left:AddToggle({
        Title = "Auto Reel",
        Default = _G.Config.AutoReel or false,
        Callback = function(v)
            _G.Config.AutoReel = v
            if AutoReel then AutoReel(v) end
        end
    })

    Left:AddToggle({
        Title = "Auto Shake",
        Default = _G.Config.AutoShake or false,
        Callback = function(v)
            _G.Config.AutoShake = v
            if AutoShake then AutoShake(v) end
        end
    })

    Left:AddToggle({
        Title = "Auto Equip Rod",
        Default = _G.Config.isEquipRpd or false,
        Callback = function(v)
            _G.Config.isEquipRpd = v
            if MiscFishing and MiscFishing.AutoEquipRod then
                MiscFishing.AutoEquipRod(v)
            end
        end
    })

    Left:AddToggle({
        Title = "Auto Sell",
        Default = _G.Config.AutoSell or false,
        Callback = function(v)
            _G.Config.AutoSell = v
            if AutoSell then AutoSell(v) end
        end
    })

    Left:AddSlider({
        Title = "Sell Interval (min)",
        Min = 2, Max = 10,
        Default = _G.Config.AutoSellInterval or 3,
        Callback = function(v) _G.Config.AutoSellInterval = v end
    })

    Left:AddButton({
        Title = "Unload",
        Callback = function()
            if getgenv().FishTPUnload then getgenv().FishTPUnload() end
        end
    })

    Left:AddButton({
        Title = "Server Hop",
        Callback = function() task.spawn(Progression.serverHop, false) end
    })

    local fishJobId = ""
    if Left.AddInput then
        Left:AddInput({
            Title = "Job ID",
            Placeholder = "Job ID",
            Default = "",
            Callback = function(v) fishJobId = tostring(v or "") end
        })
        Left:AddButton({
            Title = "Join Server",
            Callback = function() task.spawn(Progression.joinServer, fishJobId, false) end
        })
    end

    Left:AddButton({
        Title = "Collect Meteors",
        Callback = function() task.spawn(Progression.collectSky, "meteor") end
    })

    Left:AddButton({
        Title = "Collect Craters",
        Callback = function() task.spawn(Progression.collectStarCraters) end
    })

    Left:AddButton({
        Title = "Copy Job ID",
        Callback = function()
            if setclipboard then setclipboard(game.JobId) end
        end
    })

    Right:AddSlider({
        Title = "Perfect Catch %",
        Min = 0, Max = 100,
        Default = _G.Config.PerfectCatchChance or 100,
        Callback = function(v)
            _G.Config.perfectCatchEnabled = v
            _G.Config.PerfectCatchChance = v
        end
    })

    Right:AddSlider({
        Title = "Perfect Cast %",
        Min = 0, Max = 100,
        Default = _G.Config.perfectCastEnabled or 100,
        Callback = function(v) _G.Config.perfectCastEnabled = v end
    })

    Right:AddSlider({
        Title = "Reel Delay (ms)",
        Min = 0, Max = 300, Increment = 10,
        Default = _G.Config.InstantReelDelayMs or 280,
        Callback = function(v) _G.Config.InstantReelDelayMs = v end
    })

    Right:AddSlider({
        Title = "Bar Size %",
        Min = 0, Max = 100, Increment = 5,
        Default = _G.Config.BarSizePercent or 0,
        Callback = function(v) _G.Config.BarSizePercent = v end
    })

    Right:AddSlider({
        Title = "Progress Speed %",
        Min = 100, Max = 4000, Increment = 50,
        Default = math.floor((_G.Config.ReelProgressSpeed or 1) * 100),
        Callback = function(v) _G.Config.ReelProgressSpeed = v / 100 end
    })

    Right:AddToggle({
        Title = "Freeze Fish",
        Default = _G.Config.FreezeFish or false,
        Callback = function(v) _G.Config.FreezeFish = v end
    })

    Right:AddToggle({
        Title = "Freeze Progress",
        Default = _G.Config.FreezeReelProgress or false,
        Callback = function(v) _G.Config.FreezeReelProgress = v end
    })

    FishingZone:AddDropdown({
        Title = "Fishing Zone",
        Options = FISHING_ZONES,
        Default = _G.Config.selectedZone or "None",
        Callback = function(v)
            if type(v) == "table" then v = v[1] or "None" end
            _G.Config.selectedZone = v
        end
    })

    FishingZone:AddToggle({
        Title = "Auto Fishing Teleport",
        Default = _G.Config.selectedZoneADS or false,
        Callback = function(v)
            task.spawn(function()
                _G.Config.selectedZoneADS = v
                if TeleportArea and TeleportArea.TeleportToZone then
                    if v then
                        TeleportArea.TeleportToZone(_G.Config.selectedZone or "None")
                    else
                        TeleportArea.TeleportToZone("None")
                    end
                end
            end)
        end
    })
end

-- same sections + module call as Main_RS
local function buildTPTab()
    local TPMain     = TPTab:AddSection("Main",          true,  "Left")
    local TPSavePos  = TPTab:AddSection("Save Position", true,  "Right")
    local TPNPC      = TPTab:AddSection("NPC Teleport",  true,  "Left")
    local TPBalloon  = TPTab:AddSection("Balloon",       false, "Right")

    getgenv().FishingTab = patchUI(FishTab)
    getgenv().AreaTab    = patchUI(TPTab)
    patchUI(TPMain)
    patchUI(TPSavePos)
    patchUI(TPNPC)
    patchUI(TPBalloon)
    withGroundSnap(TPMain)
    withGroundSnap(TPNPC)
    Progression.captureTP(TPMain, "Main")
    Progression.captureTP(TPNPC, "NPC")

    local function tpNotice(msg)
        pcall(function()
            TPMain:AddParagraph({ Title = "Teleport not loaded", Content = msg })
        end)
    end

    if AreaTP then
        local okTP, errTP = pcall(function()
            AreaTP(TPMain, TPSavePos, TPNPC, TPBalloon)
        end)
        if not okTP then
            warn("[FishTP] AreaTP init error:", errTP)
            tpNotice("The teleport module crashed while building buttons:\n" .. tostring(errTP))
        end
        print("[FishTP] ground snap attached to " .. snapWrapped .. " TP controls")
    else
        tpNotice("The teleport module (AreaTP) failed to download from GitHub. Rejoin and run the script again.")
    end
end

-- each tab builds separately so a crash in one can't leave the other empty
local okWin, errWin = pcall(setupWindow)
if okWin then
    local okFish, errFish = pcall(buildFishingTab)
    if not okFish then warn("[FishTP] Fishing tab error:", errFish) end
    local okTP, errTP = pcall(buildTPTab)
    if not okTP then warn("[FishTP] TP tab error:", errTP) end
    local okProg, errProg = pcall(function() Progression.build(patchUI(ProgTab), FISHING_ZONES) end)
    if not okProg then warn("[FishTP] Progression tab error:", errProg) end
    local okMisc, errMisc = pcall(function() Extras.build(MiscTab) end)
    if not okMisc then warn("[FishTP] Misc tab error:", errMisc) end
    local okSet, errSet = pcall(function() FishSettings.build(SettingsTab) end)
    if not okSet then warn("[FishTP] Settings tab error:", errSet) end
    print("[FishTP] GUI built")
else
    warn("[FishTP] window setup error:", errWin)
end

-- ============================================================
-- UI toggle key (rebindable in Settings > Interface)
-- ============================================================
local visible = true

local function toggleUI()
    visible = not visible
    if not MainWindow then return end
    pcall(function() MainWindow:SetVisible(visible) end)
end

FishSettings.bindKey("toggleKey", toggleUI)

-- ============================================================
-- boot state
-- ============================================================
task.spawn(function()
    task.wait(1)
    if _G.Config.AutoCast and AutoCast then AutoCast(true) end
    if _G.Config.AutoShake and AutoShake then AutoShake(true) end
    if AutoReel and _G.Config.ReelMode ~= "Manual" then AutoReel(true) end
    if _G.Config.AutoSell and AutoSell then AutoSell(true) end
    task.wait(0.5)
    FishSettings.autoloadConfig()
end)

print("[FishTP] ready — " .. tostring(FishSettings.ui.toggleKey) .. " toggles UI, " .. tostring(FishSettings.ui.panicKey) .. " is the panic key")
