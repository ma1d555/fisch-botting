-- (Progression build) this run's session: loops and event handlers stop when it ends
local NOVA_SESSION = getgenv().NovaSession
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local autoSellRunning = false
local autoSellStorageRunning = false
local _shadyFailCount = 0
local _isCloning = false

local _cachedMarcNpc = nil
local _cachedMarcIdle = nil
local _cachedShadyNpc = nil
local _cachedShadyIdle = nil

local SHADY_MUTATIONS = {
    "Shady",
    "Sludge"
}

local _cachedDataController = nil
local function getCachedDataController()
    if _cachedDataController then return _cachedDataController end
    pcall(function()
        _cachedDataController = require(ReplicatedStorage:WaitForChild("client"):WaitForChild("legacyControllers"):WaitForChild("DataController"))
    end)
    return _cachedDataController
end

local function getInventory()
    local dc = getCachedDataController()
    if not dc then return nil end
    local inv = nil
    pcall(function()
        if dc.InventoryReplicator then
            inv = dc.InventoryReplicator:Index({"Inventory"})
        else
            inv = dc.fetch("Inventory")
        end
    end)
    return inv
end

local function isSellable(itemName)
    if not itemName then return false end
    local lowerName = itemName:lower()
    local nonSellableKeywords = {
        "geode", "relic", "key", "crate", "totem", "potion", "bait", "rod",
        "coin", "wood", "stone", "fragment", "essence", "gps", "glider",
        "whistle", "compass", "anchor", "bag", "chest", "barrel", "conch",
        "amulet", "flipper", "glove", "plushie", "waders", "suit", "gear",
        "matrix", "nuke", "nuklir", "tool", "card", "present", "gift", "ticket",
        "bucket", "flashlight", "hat", "mask"
    }
    if string.find(lowerName, "wood", 1, true) and not string.find(lowerName, "driftwood", 1, true) then
        return false
    end
    for _, keyword in ipairs(nonSellableKeywords) do
        if string.find(lowerName, keyword, 1, true) then
            return false
        end
    end
    return true
end

local function isShadyOrSludge(itemName, mutation, itemData)
    local targets = {"shady", "sludge"}
    local function checkStr(val)
        if not val then return false end
        local s = tostring(val):lower()
        for _, t in ipairs(targets) do
            if s:find(t, 1, true) then
                return true
            end
        end
        return false
    end

    if checkStr(itemName) then return true end
    if checkStr(mutation) then return true end
    if type(itemData) == "table" then
        if checkStr(itemData.name) or checkStr(itemData.Name) then return true end
        local sub = itemData.sub or itemData
        if type(sub) == "table" then
            if checkStr(sub.Mutation) or checkStr(sub.mutation) or checkStr(sub.Name) or checkStr(sub.Variant) or checkStr(sub.Tier) then
                return true
            end
            if type(sub.Mutation) == "table" then
                for k, v in pairs(sub.Mutation) do
                    if checkStr(k) or checkStr(v) then return true end
                end
            end
        end
    end
    return false
end

local function analyzeInventory()
    local hasShady = false
    local normalSellCount = 0
    local inventory = getInventory()
    if inventory then
        for _, itemData in pairs(inventory) do
            if itemData and itemData.sub and not itemData.sub.Favourited then
                if (itemData.sub.Weight or itemData.sub.weight) and isSellable(itemData.name) then
                    local mut = itemData.sub.Mutation or itemData.sub.mutation
                    if isShadyOrSludge(itemData.name, mut, itemData) then
                        hasShady = true
                    else
                        normalSellCount = normalSellCount + 1
                    end
                end
            end
        end
    end
    return hasShady, normalSellCount
end

local function isShadyLocked()
    if _G.ShadyInInventory then
        return true
    end
    if _G.LastShadyStartReelTime and (tick() - _G.LastShadyStartReelTime < 20) then
        return true
    end
    local hasShady, _ = analyzeInventory()
    if hasShady then
        _G.ShadyInInventory = true
        return true
    end
    return false
end

local function ensureStorage()
    local storage = ReplicatedStorage:FindFirstChild("NovaNPCStorage")
    if not storage then
        storage = Instance.new("Folder")
        storage.Name = "NovaNPCStorage"
        storage.Parent = ReplicatedStorage
    end
    return storage
end

local function cloneAndStoreNpc(realNpc, name)
    if not realNpc then return nil, nil end
    local storage = ensureStorage()
    local existing = storage:FindFirstChild(name)
    if existing then
        local desc = existing:FindFirstChild("description")
        local idle = desc and desc:FindFirstChild("idle")
        if idle then return existing, idle end
    end
    local clone = nil
    pcall(function()
        realNpc.Archivable = true
        clone = realNpc:Clone()
        if clone then
            clone.Name = name
            clone.Parent = storage
        end
    end)
    if clone then
        local desc = clone:FindFirstChild("description")
        local idle = desc and desc:FindFirstChild("idle")
        if idle then return clone, idle end
    end
    return nil, nil
end

local function getFallbackNpc(npcName)
    local storage = ensureStorage()
    local existing = storage:FindFirstChild(npcName) or workspace:FindFirstChild(npcName)
    if existing then
        local desc = existing:FindFirstChild("description")
        local idle = desc and desc:FindFirstChild("idle")
        if idle then return existing, idle end
    end
    local model = Instance.new("Model")
    model.Name = npcName
    local desc = Instance.new("Folder")
    desc.Name = "description"
    desc.Parent = model
    local idle = Instance.new("Animation")
    idle.Name = "idle"
    idle.Parent = desc
    model.Parent = storage
    return model, idle
end

local function initMerchantsOnce()
    if _isCloning then return end
    if _cachedMarcNpc and _cachedMarcIdle and _cachedShadyNpc and _cachedShadyIdle then return end
    _isCloning = true

    task.spawn(function()
        local storage = ensureStorage()

        -- 1. Check if already cached in persistent storage
        if not (_cachedMarcNpc and _cachedMarcIdle) then
            local stored = storage:FindFirstChild("Marc Merchant")
            if stored and stored:FindFirstChild("description") and stored.description:FindFirstChild("idle") then
                _cachedMarcNpc = stored
                _cachedMarcIdle = stored.description.idle
            end
        end
        if not (_cachedShadyNpc and _cachedShadyIdle) then
            local stored = storage:FindFirstChild("Shady Merchant")
            if stored and stored:FindFirstChild("description") and stored.description:FindFirstChild("idle") then
                _cachedShadyNpc = stored
                _cachedShadyIdle = stored.description.idle
            end
        end

        -- 2. Check if present in workspace without teleporting
        local npcs = workspace:FindFirstChild("world") and workspace.world:FindFirstChild("npcs")
        if not (_cachedMarcNpc and _cachedMarcIdle) and npcs then
            local marc = npcs:FindFirstChild("Marc Merchant")
            if marc then
                _cachedMarcNpc, _cachedMarcIdle = cloneAndStoreNpc(marc, "Marc Merchant")
            end
        end
        if not (_cachedShadyNpc and _cachedShadyIdle) and npcs then
            local shady = npcs:FindFirstChild("Shady Merchant")
            if shady then
                _cachedShadyNpc, _cachedShadyIdle = cloneAndStoreNpc(shady, "Shady Merchant")
            end
        end

        -- 3. If still not found (player is on a distant island), perform EXACTLY ONE 1-time fetch in background
        if not (_cachedMarcNpc and _cachedMarcIdle) or not (_cachedShadyNpc and _cachedShadyIdle) then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local prevAutoCast = _G.Config and _G.Config.AutoCast
                    if _G.Config then _G.Config.AutoCast = false end
                    local savedCF = hrp.CFrame

                    if not (_cachedMarcNpc and _cachedMarcIdle) then
                        hrp.CFrame = CFrame.new(466, 151, 229)
                        task.wait(1.5)
                        local wNpcs = workspace:FindFirstChild("world") and workspace.world:FindFirstChild("npcs")
                        local marc = wNpcs and wNpcs:FindFirstChild("Marc Merchant")
                        if marc then
                            _cachedMarcNpc, _cachedMarcIdle = cloneAndStoreNpc(marc, "Marc Merchant")
                        end
                    end

                    if not (_cachedShadyNpc and _cachedShadyIdle) then
                        hrp.CFrame = CFrame.new(-2997, -1023, 6067)
                        task.wait(1.5)
                        local wNpcs = workspace:FindFirstChild("world") and workspace.world:FindFirstChild("npcs")
                        local shady = wNpcs and wNpcs:FindFirstChild("Shady Merchant")
                        if shady then
                            _cachedShadyNpc, _cachedShadyIdle = cloneAndStoreNpc(shady, "Shady Merchant")
                        end
                    end

                    hrp.CFrame = savedCF
                    task.wait(0.3)
                    if prevAutoCast ~= nil and _G.Config then
                        _G.Config.AutoCast = prevAutoCast
                    end
                end
            end)
        end

        -- 4. Fallback if cloning failed
        if not (_cachedMarcNpc and _cachedMarcIdle) then
            _cachedMarcNpc, _cachedMarcIdle = getFallbackNpc("Marc Merchant")
        end
        if not (_cachedShadyNpc and _cachedShadyIdle) then
            _cachedShadyNpc, _cachedShadyIdle = getFallbackNpc("Shady Merchant")
        end

        _isCloning = false
    end)
end

-- Initialize merchant cloning immediately on script execution
task.spawn(initMerchantsOnce)

local function getOrFetchMarcNpc()
    if _cachedMarcNpc and _cachedMarcNpc.Parent and _cachedMarcIdle and _cachedMarcIdle.Parent then
        return _cachedMarcNpc, _cachedMarcIdle
    end
    local storage = ensureStorage()
    local stored = storage:FindFirstChild("Marc Merchant")
    if stored and stored:FindFirstChild("description") and stored.description:FindFirstChild("idle") then
        _cachedMarcNpc = stored
        _cachedMarcIdle = stored.description.idle
        return _cachedMarcNpc, _cachedMarcIdle
    end
    _cachedMarcNpc, _cachedMarcIdle = getFallbackNpc("Marc Merchant")
    return _cachedMarcNpc, _cachedMarcIdle
end

local function getOrFetchShadyNpc()
    if _cachedShadyNpc and _cachedShadyNpc.Parent and _cachedShadyIdle and _cachedShadyIdle.Parent then
        return _cachedShadyNpc, _cachedShadyIdle
    end
    local storage = ensureStorage()
    local stored = storage:FindFirstChild("Shady Merchant")
    if stored and stored:FindFirstChild("description") and stored.description:FindFirstChild("idle") then
        _cachedShadyNpc = stored
        _cachedShadyIdle = stored.description.idle
        return _cachedShadyNpc, _cachedShadyIdle
    end
    _cachedShadyNpc, _cachedShadyIdle = getFallbackNpc("Shady Merchant")
    return _cachedShadyNpc, _cachedShadyIdle
end

local _cachedSellEvents = nil
local function getCachedSellEvents()
    if not _cachedSellEvents then
        pcall(function()
            _cachedSellEvents = ReplicatedStorage:WaitForChild("events", 5)
        end)
    end
    return _cachedSellEvents
end

local function clickYesPopup()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pGui then return end
        local targetGuis = {
            pGui:FindFirstChild("dialogue"),
            pGui:FindFirstChild("Dialogue"),
            pGui:FindFirstChild("merchant"),
            pGui:FindFirstChild("Merchant"),
            pGui:FindFirstChild("confirm"),
            pGui:FindFirstChild("Confirm")
        }
        for _, gui in ipairs(targetGuis) do
            if gui and gui.Enabled then
                for _, obj in ipairs(gui:GetDescendants()) do
                    if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                        local t = tostring(obj.Text or ""):lower()
                        local n = tostring(obj.Name):lower()
                        if t:find("yes") or t:find("ya") or t:find("confirm") or t:find("sell") or n:find("yes") or n:find("confirm") then
                            local mockInput = { UserInputType = Enum.UserInputType.MouseButton1 }
                            if firesignal then
                                pcall(function() firesignal(obj.Activated, mockInput) end)
                            end
                            if getconnections then
                                for _, c in ipairs(getconnections(obj.MouseButton1Click)) do
                                    pcall(function() c:Fire() end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function sellShadyInventory()
    pcall(function()
        local shadyNpc, idle = getOrFetchShadyNpc()
        local events = getCachedSellEvents()
        if events and shadyNpc and idle then
            local args = {
                {
                    voice = 12,
                    uid = "Shady Merchant",
                    npc = shadyNpc,
                    idle = idle
                }
            }
            if events:FindFirstChild("ShadySellAll") then
                events.ShadySellAll:InvokeServer(unpack(args))
            end
            task.wait(0.2)
            clickYesPopup()
        end
    end)
    _G.ShadyInInventory = false
    _shadyFailCount = 0
end

local function performSellAll()
    pcall(function()
        local marc, idle = getOrFetchMarcNpc()
        local events = getCachedSellEvents()
        if events and marc and idle then
            local args = {
                {
                    voice = 12,
                    uid = "merchant_moosewood",
                    npc = marc,
                    idle = idle
                }
            }
            if events:FindFirstChild("SellAll") then
                events.SellAll:InvokeServer(unpack(args))
            end
            pcall(function()
                local net = ReplicatedStorage:FindFirstChild("packages") and ReplicatedStorage.packages:FindFirstChild("Net")
                if net and net:FindFirstChild("RF/SellAllItems") then
                    net["RF/SellAllItems"]:InvokeServer()
                end
            end)
            task.wait(0.2)
            clickYesPopup()
        end
    end)
end

local function executeSellCycle()
    -- 1. Pertama: Jual ikan Shady / Sludge dulu
    pcall(sellShadyInventory)
    task.wait(0.8)
    
    -- 2. Kedua: Langsung jual semua ikan biasa (CS / Marc Merchant)
    pcall(performSellAll)
end

local function AutoSell()
    if autoSellRunning then return end
    autoSellRunning = true
    task.spawn(function()
        initMerchantsOnce()
        
        -- Initial sell pass immediately on toggle ON (Shady lalu CS)
        pcall(executeSellCycle)
        
        while getgenv().NovaSession == NOVA_SESSION and _G.Config and _G.Config.AutoSell do
            local intervalMinutes = tonumber(_G.Config and _G.Config.AutoSellInterval) or 3
            if intervalMinutes < 1 then intervalMinutes = 1 end
            local intervalSeconds = intervalMinutes * 60
            
            local elapsed = 0
            while elapsed < intervalSeconds do
                if not (_G.Config and _G.Config.AutoSell) then break end
                task.wait(1)
                elapsed = elapsed + 1
            end
            
            if not (_G.Config and _G.Config.AutoSell) then break end
            
            -- Jalankan siklus penjualan 2-tahap (Shady dulu baru CS)
            pcall(executeSellCycle)
        end
        autoSellRunning = false
    end)
end

local function AutoSellStorage()
    if autoSellStorageRunning then return end
    autoSellStorageRunning = true
    task.spawn(function()
        local useNpc, idle = getOrFetchMarcNpc()
        if not (useNpc and idle) then
            autoSellStorageRunning = false
            return
        end
        local args = {{voice = 12, uid = "merchant_moosewood", npc = useNpc, idle = idle}}
        while getgenv().NovaSession == NOVA_SESSION and _G.Config and _G.Config.AutoSellStorage do
            pcall(function()
                local events = game:GetService("ReplicatedStorage"):WaitForChild("events", 5)
                local sellAllStorage = events and events:FindFirstChild("SellAllStorage")
                if sellAllStorage then
                    task.spawn(function()
                        pcall(function() sellAllStorage:InvokeServer(unpack(args)) end)
                    end)
                    task.wait(0.5)
                    clickYesPopup()
                end
            end)
            task.wait(5)
        end
        autoSellStorageRunning = false
    end)
end

local M = {
    AutoSell = AutoSell,
    AutoSellStorage = AutoSellStorage,
    sellShadyInventory = sellShadyInventory,
    performSellAll = performSellAll,
    InitMerchants = initMerchantsOnce,
}

setmetatable(M, {
    __call = function(self, value)
        _G.Config.AutoSell = value
        if value then
            AutoSell()
        end
    end
})

task.spawn(function()
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local events = RS:WaitForChild("events", 10)
        local annoCatch = events and (events:FindFirstChild("anno_catch") or events:WaitForChild("anno_catch", 5))
        if annoCatch then
            annoCatch.OnClientEvent:Connect(function(fishData)
                if getgenv().NovaSession ~= NOVA_SESSION then return end
                if not fishData then return end
                local mutStr = tostring(fishData.Mutation or ""):lower()
                local fishName = tostring(fishData.Name or ""):lower()
                if mutStr:find("shady", 1, true) or mutStr:find("sludge", 1, true) or fishName:find("shady", 1, true) or fishName:find("sludge", 1, true) then
                    _G.ShadyInInventory = true
                    _G.LastShadyStartReelTime = tick()
                end
            end)
        end
    end)
end)

return M