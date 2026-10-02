-- Fishing + TP + Progression build.
-- Progression tab: works through the Fortune, Wisdom, Heaven's, Pinion's Aria and Tryhard rods by itself.
-- Fishing tab: fishing controls from the FishOnly build.
-- TP tab: built by the same AreaTP module the full Main_RS uses.
-- Right Shift toggles UI.

if getgenv().FishTPUnload then
    pcall(getgenv().FishTPUnload)
elseif getgenv().__FishTP_Loaded then
    warn("[FishTP] an older version is still running and can't be unloaded: rejoin once")
    return
end
getgenv().__FishTP_Loaded = true
local FISHTP_SESSION = {}
getgenv().FishTPSession = FISHTP_SESSION
local unloadSteps = {}
getgenv().FishTPOnUnload = function(step) table.insert(unloadSteps, step) end
getgenv().FishTPUnload = function()
    if getgenv().FishTPSession ~= FISHTP_SESSION then return end
    getgenv().FishTPSession = nil
    getgenv().FishTPUnload = nil
    getgenv().FishTPOnUnload = nil
    for i = #unloadSteps, 1, -1 do pcall(unloadSteps[i]) end
    local roots = {}
    pcall(function() roots[#roots + 1] = game:GetService("CoreGui") end)
    pcall(function() if gethui then roots[#roots + 1] = gethui() end end)
    for _, root in ipairs(roots) do
        for _, gui in ipairs(root:GetChildren()) do
            if gui.Name == "FishTP_UI" then pcall(function() gui:Destroy() end) end
        end
    end
    if getgenv().FishTPUI then pcall(getgenv().FishTPUI.Destroy) end
    getgenv().FishTPUI = nil
    _G.ShieldScriptActive = nil
    getgenv().__FishTP_Loaded = nil
    print("[FishTP] unloaded")
end
print("[FishTP] booting")

-- ============================================================
-- kill client chat / system spam
-- ============================================================
task.spawn(function()
    pcall(function()
        local chat = game:GetService("ReplicatedStorage"):FindFirstChild("events")
            and game.ReplicatedStorage.events:FindFirstChild("chat")
        if chat and getconnections then
            for _, conn in ipairs(getconnections(chat.OnClientEvent)) do
                pcall(function() conn:Disable() end)
                pcall(function() conn:Disconnect() end)
            end
        end
    end)
    pcall(function()
        local setRemote = game:GetService("ReplicatedStorage"):FindFirstChild("packages")
            and game.ReplicatedStorage.packages:FindFirstChild("Replion")
            and game.ReplicatedStorage.packages.Replion:FindFirstChild("Remotes")
            and game.ReplicatedStorage.packages.Replion.Remotes:FindFirstChild("Set")
        if setRemote and getconnections then
            for _, conn in ipairs(getconnections(setRemote.OnClientEvent)) do
                pcall(function() conn:Disable() end)
                pcall(function() conn:Disconnect() end)
            end
        end
    end)
end)

-- ============================================================
-- network + module loader
-- ============================================================
local BaseURL         = "https://raw.githubusercontent.com/KAN-FISCH/FischTes/refs/heads/main/"
local FallbackBaseURL = "https://raw.githubusercontent.com/KAN-FISCH/Fisch/refs/heads/main/"

local function httpGet(url, timeout)
    local done, ok, res = false, false, nil
    local co = coroutine.running()
    task.spawn(function()
        local s, r = pcall(game.HttpGet, game, url)
        if not done then
            done = true
            ok = s
            res = r
            task.spawn(co)
        end
    end)
    task.delay(timeout or 8, function()
        if not done then
            done = true
            ok = false
            res = "timeout"
            task.spawn(co)
        end
    end)
    coroutine.yield()
    return ok, res
end

-- full list from Main_RS so modules that call _G.getMod internally can resolve any name
local ModulePaths = {
    Config         = "Config.lua",
    Utils          = "Modules/Utils.lua",
    InstantBobber  = "Modules/InstantBobber.lua",
    AutoCast       = "Modules/AutoCast.lua",
    AutoReel       = "Modules/AutoReel.lua",
    PerfectCatch   = "Modules/PerfectCatch.lua",
    AutoShake      = "Modules/AutoShake.lua",
    AutoBuyBait    = "Modules/AutoBuyBait.lua",
    AutoBuyRod     = "Modules/AutoBuyRod.lua",
    AutoSell       = "Modules/AutoSell.lua",
    TeleportArea   = "Modules/TeleportArea.lua",
    TeleportNPC    = "Modules/TeleportNPC.lua",
    TeleportZone   = "Modules/TeleportZone.lua",
    ESP            = "Modules/ESP.lua",
    AutoMine       = "Modules/AutoMine.lua",
    AutoQuest      = "Modules/AutoQuest.lua",
    WalkSpeed      = "Modules/WalkSpeed.lua",
    MiscFishing    = "Modules/MiscFishing.lua",
    DisableOxygen  = "Modules/DisableOxygen.lua",
    AutoCosmic     = "Modules/AutoCosmic.lua",
    AutoMinigames  = "Modules/AutoMinigames.lua",
    AutoHop        = "Modules/AutoHop.lua",
    AutoPotion     = "Modules/AutoPotion.lua",
    AutoConfig     = "Modules/AutoConfig.lua",
    AutoStorage    = "Modules/AutoStorage.lua",
    MiscFeatures   = "Modules/MiscFeatures.lua",
    Exclusive      = "Modules/Exclusive.lua",
    Autos          = "Modules/Autos.lua",
    AntiAFK        = "Modules/AntiAFK.lua",
    Shop           = "Modules/Shop.lua",
    AutoQuestShady = "Modules/AutoQuestShady.lua",
    AreaTP         = "Modules/AreaTP.lua",
}

local ModuleCache = {}

-- The hub's modules are readable copies in the executor's workspace, fishtp/modules (added by the Progression build).
local function readLocal(file)
    local ok, text = pcall(readfile, "fishtp/" .. file)
    return ok and type(text) == "string" and text or nil
end

local function looksLikeStub(src)
    if not src or #src < 200 then return true end
    if src:sub(1, 20):lower():match("<") then return true end
    if src:find("CharacterAdded", 1, true) and #src < 4000 then return true end
    return false
end

local function getMod(name)
    if ModuleCache[name] then return ModuleCache[name] end
    local path = ModulePaths[name]
    if not path then return nil end

    local localSource = readLocal("modules/" .. name .. ".lua")
    if localSource then
        local fn, err = loadstring(localSource, "=" .. name)
        local runOk, out = false, err
        if fn then runOk, out = pcall(fn) end
        if runOk then
            ModuleCache[name] = out
            print("[FishTP] loaded (local):", name)
            return out
        end
        warn("[FishTP] local module failed, downloading it instead:", name, out)
    end

    local attempt, ok, res = 0, false, nil
    while attempt < 3 do
        attempt = attempt + 1
        local url = (attempt % 2 == 1) and (BaseURL .. path) or (FallbackBaseURL .. path)
        ok, res = httpGet(url, 8)
        if ok and res and not looksLikeStub(res) then break end
        ok = false
        task.wait(1)
    end
    if not ok or not res then
        warn("[FishTP] fetch fail:", name)
        return nil
    end

    local fn, err = loadstring(res)
    if not fn then warn("[FishTP] compile fail:", name, err) return nil end
    local runOk, out = pcall(fn)
    if not runOk then warn("[FishTP] runtime fail:", name, out) return nil end
    ModuleCache[name] = out
    print("[FishTP] loaded:", name)
    return out
end

_G.getMod = getMod

-- ============================================================
-- stop AutoSell's merchant-finding trips to Moosewood and the Shady Bazaar (added by the Progression build)
-- ============================================================
pcall(function()
    local RS = game:GetService("ReplicatedStorage")
    local storage = RS:FindFirstChild("ShieldNPCStorage") or Instance.new("Folder")
    storage.Name = "ShieldNPCStorage"
    storage.Parent = RS
    for _, name in ipairs({ "Marc Merchant", "Shady Merchant" }) do
        if not storage:FindFirstChild(name) then
            local model = Instance.new("Model")
            model.Name = name
            local description = Instance.new("Folder")
            description.Name = "description"
            description.Parent = model
            local idle = Instance.new("Animation")
            idle.Name = "idle"
            idle.Parent = description
            model.Parent = storage
        end
    end
end)

-- ============================================================
-- pull modules
-- ============================================================
local Config       = getMod("Config")
local Utils        = getMod("Utils")
local AutoCast     = getMod("AutoCast")
local AutoReel     = getMod("AutoReel")
local AutoShake    = getMod("AutoShake")
local AutoSell     = getMod("AutoSell")
local MiscFishing  = getMod("MiscFishing")
local TeleportArea = getMod("TeleportArea")
getMod("TeleportNPC")
getMod("TeleportZone")

local executorName = (Utils and Utils.DetectExecutor and Utils.DetectExecutor()) or "Unknown"

if not _G.Config then
    _G.Config = {
        AutoCast = false, InstantCast = false, AutoReel = false,
        InstantReel = true, ReelMode = "Super Instant", AutoShake = false,
        isEquipRpd = false, AutoSell = false, AutoSellInterval = 3,
        AutoBuyBait = false, AutoBuyRod = false,
        perfectCatchEnabled = 100, PerfectCatchChance = 100, perfectCastEnabled = 100,
        selectedZone = "None", selectedZoneADS = false,
        SavedPosition = nil, AutoTeleportOnLoad = true,
    }
end
_G.__var = _G.__var or {}
getgenv().__var = _G.__var

-- ============================================================
-- GUI library
-- ============================================================
local FishUI
do
    local source = readLocal("modules/FishUI.lua")
    local fn, err = loadstring(source or "", "=FishUI")
    local runOk, lib = false, err
    if fn then runOk, lib = pcall(fn) end
    if not runOk or type(lib) ~= "table" then
        warn("[FishTP] can't load fishtp/modules/FishUI.lua:", lib)
        return
    end
    FishUI = lib
end
getgenv().FishTPUI = FishUI

-- loaded after the GUI lib, same order as Main_RS
local AreaTP = getMod("AreaTP")

-- ============================================================
-- globals Main_RS sets up before AreaTP runs (save position / config)
-- ============================================================
local uiRefs = {}
getgenv().__uiRefs = uiRefs
getgenv().regUIElement = function(ref, configKey, cb)
    if ref then uiRefs[#uiRefs + 1] = { ref = ref, key = configKey, cb = cb } end
end

getgenv().configFolder      = "ExclusiveConfigs/"
getgenv().currentConfigFile = "Default"
getgenv().savedConfigsList  = {}
getgenv().lastSaveTime      = os.time()
getgenv().totalSaves        = 0

getgenv().teleportToSavedPosition = function(position)
    if not position or not position.X or not position.Y or not position.Z then
        return false
    end
    task.spawn(function()
        local player = game.Players.LocalPlayer
        local char = player.Character or player.CharacterAdded:Wait()
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = CFrame.new(position.X, position.Y, position.Z)
            task.wait(0.5)
        end
    end)
    return true
end

getgenv().deepCopy = function(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for key, value in pairs(original) do
        local typeKey = type(key)
        local typeVal = type(value)
        if typeKey == "string" or typeKey == "number" then
            if not (typeKey == "string" and key:match("^<Function>")) then
                if typeVal == "table" then
                    copy[key] = getgenv().deepCopy(value)
                elseif typeVal == "string" or typeVal == "number" or typeVal == "boolean" then
                    copy[key] = value
                end
            end
        end
    end
    return copy
end

getgenv().loadConfig = function(configName, autoTeleport)
    configName = configName or getgenv().currentConfigFile
    if autoTeleport == nil then
        autoTeleport = _G.Config.AutoTeleportOnLoad
    end
    local filePath = getgenv().configFolder .. configName .. ".json"
    if readfile and isfile and isfile(filePath) then
        local HttpService = game:GetService("HttpService")
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(filePath))
        end)
        if success and result then
            local loadedConfig = result.Config or result
            local loadedVar = result.Var or {}
            for key, value in pairs(loadedConfig) do
                if key == "SavedPosition" then
                    if type(value) == "table" and value.x then
                        _G.Config[key] = CFrame.new(value.x, value.y, value.z)
                    else
                        _G.Config[key] = nil
                    end
                else
                    _G.Config[key] = value
                end
            end
            for key, value in pairs(loadedVar) do
                if key ~= "reelConnection" and key ~= "isReeling" then
                    getgenv().__var[key] = value
                end
            end
            getgenv().currentConfigFile = configName
            getgenv().lastSaveTime = os.time()
            task.defer(function()
                for _, entry in ipairs(uiRefs) do
                    local val = _G.Config[entry.key]
                    if val ~= nil then
                        pcall(function()
                            if entry.ref.Set then
                                entry.ref:Set(val)
                            elseif entry.ref.SetValue then
                                entry.ref:SetValue(val)
                            end
                        end)
                        pcall(entry.cb, val)
                    end
                end
            end)
            if autoTeleport and _G.Config.SavedPosition then
                getgenv().teleportToSavedPosition(_G.Config.SavedPosition)
            end
            return true
        end
    end
    warn("[Config] Load failed: " .. configName)
    return false
end

getgenv().saveConfig = function(configName)
    configName = configName or getgenv().currentConfigFile
    if not isfolder(getgenv().configFolder) then
        makefolder(getgenv().configFolder)
    end
    local configCopy = getgenv().deepCopy(_G.Config)
    local savedPosCF = _G.Config.SavedPosition
    if savedPosCF then
        if typeof(savedPosCF) == "CFrame" then
            configCopy.SavedPosition = { x = savedPosCF.X, y = savedPosCF.Y, z = savedPosCF.Z }
        elseif type(savedPosCF) == "table" and (savedPosCF.x or savedPosCF.X) then
            configCopy.SavedPosition = {
                x = savedPosCF.x or savedPosCF.X,
                y = savedPosCF.y or savedPosCF.Y,
                z = savedPosCF.z or savedPosCF.Z
            }
        else
            configCopy.SavedPosition = nil
        end
    else
        configCopy.SavedPosition = nil
    end
    local data = { Config = configCopy, Var = {} }
    for k, v in pairs(getgenv().__var) do
        if k ~= "reelConnection" and k ~= "isReeling" then
            data.Var[k] = v
        end
    end
    local HttpService = game:GetService("HttpService")
    local success, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if success and writefile then
        writefile(getgenv().configFolder .. configName .. ".json", result)
        print("[Config] Saved config successfully to " .. configName)
        return true
    end
    return false
end

-- restore the first saved config before the UI is built, so toggles show the loaded values
pcall(function()
    if isfolder and isfolder(getgenv().configFolder) and listfiles then
        local found = {}
        for _, file in pairs(listfiles(getgenv().configFolder)) do
            if type(file) == "string" and file:match("%.json$") then
                local fileName = file:match("([^/\\]+)%.json$")
                if fileName then table.insert(found, fileName) end
            end
        end
        table.sort(found)
        if #found > 0 then
            getgenv().loadConfig(found[1], true)
        end
    end
end)

-- adds methods AreaTP may call that this UI lib doesn't have
local function patchUI(obj)
    if type(obj) ~= "table" then return obj end
    if not obj.AddSeperator then
        obj.AddSeperator = function() end
    end
    if not obj.AddSeparator then
        obj.AddSeparator = function() end
    end
    if obj.AddSection then
        local oldAddSection = obj.AddSection
        obj.AddSection = function(self, ...)
            local newSec = oldAddSection(self, ...)
            if newSec then patchUI(newSec) end
            return newSec
        end
    end
    if obj.AddParagraph then
        local oldAddPara = obj.AddParagraph
        obj.AddParagraph = function(self, ...)
            local para = oldAddPara(self, ...)
            if para and not para.SetDesc then
                para.SetDesc = function(s, text)
                    if s.Set then pcall(function() s:Set({Content = text}) end) end
                end
            end
            return para
        end
    end
    return obj
end

-- ============================================================
-- ground snap: AreaTP's island/NPC destinations sit too high, so after
-- one of its buttons moves you, drop you straight onto what's below
-- ============================================================
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local snapWrapped = 0

local function getHRP()
    local char = Players.LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function snapToGround(hrp)
    local char = hrp.Parent
    local target = hrp.Position
    hrp.Anchored = true
    pcall(function()
        -- destination may not be streamed in yet right after a long teleport
        Players.LocalPlayer:RequestStreamAroundAsync(target, 3)
    end)
    pcall(function()
        local ignore = { char }
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = false
        for _ = 1, 20 do
            params.FilterDescendantsInstances = ignore
            local hit = workspace:Raycast(target, Vector3.new(0, -3000, 0), params)
            if not hit then return end
            local part = hit.Instance
            -- skip invisible zone/trigger parts so you land on real ground
            if part == workspace.Terrain or (part.CanCollide and part.Transparency < 1) then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local lift = 3.5
                if hum and hum.RigType == Enum.HumanoidRigType.R15 then
                    lift = hum.HipHeight + hrp.Size.Y / 2 + 0.5
                end
                hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, lift, 0)) * hrp.CFrame.Rotation
                return
            end
            table.insert(ignore, part)
        end
    end)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.Anchored = false
end

local function snapAfterTeleport(startPos)
    task.spawn(function()
        local deadline = os.clock() + 2
        while os.clock() < deadline do
            RunService.Heartbeat:Wait()
            local hrp = getHRP()
            if hrp and (hrp.Position - startPos).Magnitude > 30 then
                snapToGround(hrp)
                return
            end
        end
    end)
end

local function withGroundSnap(section)
    if type(section) ~= "table" then return end
    for _, method in ipairs({ "AddButton", "AddDropdown" }) do
        local original = section[method]
        if type(original) == "function" then
            section[method] = function(self, opts, ...)
                if type(opts) == "table" and type(opts.Callback) == "function" then
                    local cb = opts.Callback
                    opts.Callback = function(...)
                        local hrp = getHRP()
                        local startPos = hrp and hrp.Position
                        cb(...)
                        if startPos then snapAfterTeleport(startPos) end
                    end
                    snapWrapped = snapWrapped + 1
                end
                return original(self, opts, ...)
            end
        end
    end
end

local FISHING_ZONES = {
    "None", "Moosewood Village", "Roslit Hamlet", "Sunstone Island",
    "Terrapin Island", "The Depths", "Ancient Isles", "Forsaken Shores",
    "Crimson Cavern", "Luminescent Cavern", "Lost Jungle", "Crystal Cove",
}

