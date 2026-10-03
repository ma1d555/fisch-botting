-- ============================================================
-- Settings tab: themes (left) and configs (right), both saved as JSON in the workspace folder
-- ============================================================
local NovaSettings = (function()
    local M = {}
    local HttpService = game:GetService("HttpService")
    local CONFIG_DIR, THEME_DIR, AUTO_FILE = "nova/configs/", "nova/themes/", "nova/autoload.json"
    local BUILTIN_THEMES = {
        Default = { Accent = { 145, 80, 255 }, Background = { 38, 38, 42 }, Text = { 255, 255, 255 }, Rainbow = false },
        Crimson = { Accent = { 230, 60, 70 }, Background = { 30, 28, 30 }, Text = { 255, 255, 255 }, Rainbow = false },
        Ocean   = { Accent = { 50, 160, 255 }, Background = { 24, 32, 44 }, Text = { 235, 245, 255 }, Rainbow = false },
        Mint    = { Accent = { 70, 220, 160 }, Background = { 28, 36, 34 }, Text = { 240, 255, 248 }, Rainbow = false },
        Rainbow = { Accent = { 145, 80, 255 }, Background = { 38, 38, 42 }, Text = { 255, 255, 255 }, Rainbow = true },
    }
    local BUILTIN_ORDER = { "Default", "Crimson", "Ocean", "Mint", "Rainbow" }

    local canFiles = type(writefile) == "function" and type(readfile) == "function" and type(isfolder) == "function"
        and type(makefolder) == "function" and type(listfiles) == "function"

    local function ensureDir(dir)
        if not canFiles then return end
        pcall(function()
            if not isfolder("nova") then makefolder("nova") end
            if not isfolder(dir:sub(1, -2)) then makefolder(dir:sub(1, -2)) end
        end)
    end

    -- One-time move of what the previous build saved (configs, themes, keys, webhook) from its old folder.
    pcall(function()
        if not canFiles or isfolder("nova") or not isfolder("fishtp") then return end
        makefolder("nova")
        for _, sub in ipairs({ "", "configs", "themes" }) do
            local from = sub == "" and "fishtp" or ("fishtp/" .. sub)
            if isfolder(from) then
                if sub ~= "" and not isfolder("nova/" .. sub) then makefolder("nova/" .. sub) end
                for _, file in ipairs(listfiles(from)) do
                    local name = tostring(file):match("([^/\\]+%.json)$")
                    if name then writefile("nova/" .. (sub == "" and "" or (sub .. "/")) .. name, readfile(file)) end
                end
            end
        end
    end)

    local function cleanName(text)
        text = tostring(text or ""):gsub("[^%w _%-]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        return text ~= "" and text or nil
    end

    local function readJson(path)
        if not canFiles then return nil end
        local ok, data = pcall(function()
            if isfile and not isfile(path) then return nil end
            return HttpService:JSONDecode(readfile(path))
        end)
        return ok and type(data) == "table" and data or nil
    end

    local function writeJson(path, data)
        if not canFiles then return false end
        local ok = pcall(function() writefile(path, HttpService:JSONEncode(data)) end)
        return ok
    end

    local function listNames(dir)
        local names = {}
        if not canFiles then return names end
        ensureDir(dir)
        pcall(function()
            for _, file in ipairs(listfiles(dir:sub(1, -2))) do
                local name = tostring(file):match("([^/\\]+)%.json$")
                if name then names[#names + 1] = name end
            end
        end)
        table.sort(names)
        return names
    end

    local function autoload()
        return readJson(AUTO_FILE) or {}
    end
    local function setAutoload(key, name)
        local data = autoload()
        data[key] = name
        return writeJson(AUTO_FILE, data)
    end

    -- ---- interface prefs (keys, window layout, webhook): not part of configs ------------------------

    local UI_FILE = "nova/ui.json"
    M.ui = { toggleKey = "RightShift", panicKey = "End", webhook = "", layout = nil }
    for key, value in pairs(readJson(UI_FILE) or {}) do M.ui[key] = value end
    function M.saveUI()
        ensureDir("nova/")
        writeJson(UI_FILE, M.ui)
    end

    -- Calls fn when the key named by M.ui[field] goes down. The key event and a poll both watch it (some executors
    -- miss UIS events); presses within 0.3s count once. Ignored while a keybind button is waiting for a key.
    function M.bindKey(field, fn)
        local UIS = game:GetService("UserInputService")
        local last = 0
        local function fire()
            if os.clock() - last < 0.3 or NovaUI.listening > 0 then return end
            last = os.clock()
            fn()
        end
        local function code()
            local ok, keyCode = pcall(function() return Enum.KeyCode[M.ui[field]] end)
            return ok and keyCode or nil
        end
        pcall(function()
            UIS.InputBegan:Connect(function(input, typing)
                if getgenv().NovaSession ~= NOVA_SESSION or typing then return end
                if input.KeyCode == code() then fire() end
            end)
        end)
        task.spawn(function()
            local was = false
            while getgenv().NovaSession == NOVA_SESSION do
                task.wait(0.05)
                local c = code()
                local down = c ~= nil and UIS:IsKeyDown(c)
                if down and not was and not UIS:GetFocusedTextBox() then fire() end
                was = down
            end
        end)
    end

    -- ---- config values ------------------------------------------------------------------------

    local function snapshotConfig()
        local values = {}
        for key, ctl in pairs(NovaUI.controls) do
            if ctl.Get then
                local v = ctl:Get()
                if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then values[key] = v end
            end
        end
        local data = { controls = values }
        pcall(function() data.spots = Progression.getSpots() end)
        pcall(function() data.positions = getgenv().NovaPositions and getgenv().NovaPositions.get() end)
        return data
    end

    local function applyConfig(data)
        local count = 0
        -- saved locations and TP positions are merged in (kept ones stay, same names are overwritten)
        pcall(function()
            if type(data.spots) == "table" then
                local all = Progression.getSpots()
                for name, pos in pairs(data.spots) do all[name] = pos end
                Progression.setSpots(all)
            end
            local positions = getgenv().NovaPositions
            if positions and type(data.positions) == "table" then
                local all = positions.get()
                local merged = {}
                for name, pos in pairs(all) do merged[name] = pos end
                for name, pos in pairs(data.positions) do merged[name] = pos end
                positions.set(merged)
            end
        end)
        for key, value in pairs(data.controls or {}) do
            local ctl = NovaUI.controls[key]
            if ctl and ctl.Set then
                if pcall(ctl.Set, ctl, value) then count = count + 1 end
            end
        end
        return count
    end

    -- Runs once the hub is up: the config marked autoload is applied.
    function M.autoloadConfig()
        local name = autoload().config
        local data = name and readJson(CONFIG_DIR .. name .. ".json")
        if data then
            local n = applyConfig(data)
            print("[Nova] autoloaded config '" .. name .. "' (" .. n .. " settings)")
            NovaUI.Notify("Config loaded", name .. " (" .. n .. " settings)")
        end
    end

    -- Runs before the window is built so it never shows the wrong colours.
    function M.autoloadTheme()
        local name = autoload().theme
        local data = name and (readJson(THEME_DIR .. name .. ".json") or BUILTIN_THEMES[name])
        if data then NovaUI.SetTheme(data) end
    end

    -- ---- UI -----------------------------------------------------------------------------------

    function M.build(tab)
        local themeSec = tab:AddSection("Theme", true, "Left")
        local savedThemes = tab:AddSection("Themes", true, "Left")
        local cfgSec = tab:AddSection("Configs", true, "Right")

        -- RGB sliders for the three colours; they follow the theme when one is loaded
        local sliders = {}
        local current = NovaUI.GetTheme()
        local function pushTheme()
            local t = {}
            for _, part in ipairs({ "Accent", "Background", "Text" }) do
                t[part] = { sliders[part][1]:Get(), sliders[part][2]:Get(), sliders[part][3]:Get() }
            end
            NovaUI.SetTheme(t)
        end
        local rainbowToggle
        for _, part in ipairs({ "Accent", "Background", "Text" }) do
            sliders[part] = {}
            for i, channel in ipairs({ "R", "G", "B" }) do
                sliders[part][i] = themeSec:AddSlider({
                    Title = part .. " " .. channel, Min = 0, Max = 255, Default = current[part][i],
                    Callback = pushTheme,
                })
            end
        end
        rainbowToggle = themeSec:AddToggle({
            Title = "Rainbow accent", Default = current.Rainbow,
            Callback = function(on)
                NovaUI.SetTheme({ Rainbow = on })
                if not on then
                    local t = NovaUI.GetTheme()
                    for i = 1, 3 do sliders.Accent[i]:Set(t.Accent[i], true) end
                end
            end,
        })
        local function showTheme(t)
            for _, part in ipairs({ "Accent", "Background", "Text" }) do
                for i = 1, 3 do sliders[part][i]:Set(t[part][i], true) end
            end
            rainbowToggle:Set(t.Rainbow == true, true)
        end

        local themeStatus = savedThemes:AddParagraph({ Title = "Themes", Content = canFiles and "Pick one or save the current colours." or "Saving needs an executor with file access." })
        local themeName = ""
        local selectedTheme = "Default"
        local themeDropdown
        local function themeNames()
            local names = {}
            for _, n in ipairs(BUILTIN_ORDER) do names[#names + 1] = n end
            for _, n in ipairs(listNames(THEME_DIR)) do
                if not BUILTIN_THEMES[n] then names[#names + 1] = n end
            end
            return names
        end
        local function say(para, text)
            pcall(function() para:SetDesc(text) end)
            NovaUI.Notify(para == themeStatus and "Themes" or "Configs", text, 3)
        end
        local function refreshThemes() themeDropdown:SetOptions(themeNames()) end
        themeDropdown = savedThemes:AddDropdown({
            Title = "Theme", Options = themeNames(), Default = "Default", Save = false,
            Callback = function(v) selectedTheme = v end,
        })
        savedThemes:AddInput({ Title = "Name", Default = "", Callback = function(v) themeName = v end })
        savedThemes:AddButton({
            Title = "Create",
            Callback = function()
                local name = cleanName(themeName)
                if not name or BUILTIN_THEMES[name] then return say(themeStatus, "Type a new name first.") end
                ensureDir(THEME_DIR)
                if writeJson(THEME_DIR .. name .. ".json", NovaUI.GetTheme()) then
                    refreshThemes()
                    themeDropdown:Set(name, true)
                    selectedTheme = name
                    say(themeStatus, "Created " .. name)
                else
                    say(themeStatus, "Couldn't write the file.")
                end
            end,
        })
        savedThemes:AddButton({
            Title = "Save",
            Callback = function()
                if BUILTIN_THEMES[selectedTheme] then return say(themeStatus, "Built-in themes can't be overwritten. Use Create.") end
                ensureDir(THEME_DIR)
                say(themeStatus, writeJson(THEME_DIR .. selectedTheme .. ".json", NovaUI.GetTheme()) and ("Saved " .. selectedTheme) or "Couldn't write the file.")
            end,
        })
        savedThemes:AddButton({
            Title = "Load",
            Callback = function()
                local data = BUILTIN_THEMES[selectedTheme] or readJson(THEME_DIR .. selectedTheme .. ".json")
                if not data then return say(themeStatus, "Can't read " .. tostring(selectedTheme)) end
                NovaUI.SetTheme(data)
                showTheme(NovaUI.GetTheme())
                say(themeStatus, "Loaded " .. selectedTheme)
            end,
        })
        savedThemes:AddButton({
            Title = "Delete",
            Callback = function()
                if BUILTIN_THEMES[selectedTheme] then return say(themeStatus, "Built-in themes can't be deleted.") end
                pcall(function() delfile(THEME_DIR .. selectedTheme .. ".json") end)
                say(themeStatus, "Deleted " .. selectedTheme)
                if autoload().theme == selectedTheme then setAutoload("theme", nil) end
                refreshThemes()
                themeDropdown:Set("Default", true)
                selectedTheme = "Default"
            end,
        })
        savedThemes:AddButton({
            Title = "Autoload",
            Callback = function()
                say(themeStatus, setAutoload("theme", selectedTheme) and ("Autoloading " .. selectedTheme) or "Couldn't write the file.")
            end,
        })
        savedThemes:AddButton({
            Title = "Refresh",
            Callback = refreshThemes,
        })

        -- configs: every toggle, slider and dropdown on the Fishing and Progression tabs
        local cfgStatus = cfgSec:AddParagraph({ Title = "Configs", Content = canFiles and "Saves the Fishing and Progression settings." or "Saving needs an executor with file access." })
        local cfgName = ""
        local selectedCfg = "None"
        local cfgDropdown
        local function cfgNames()
            local names = listNames(CONFIG_DIR)
            if #names == 0 then names[1] = "None" end
            return names
        end
        local function refreshCfgs() cfgDropdown:SetOptions(cfgNames()) end
        local function autoloadText()
            local name = autoload().config
            return name and ("Autoload: " .. name) or "Autoload: off"
        end
        cfgDropdown = cfgSec:AddDropdown({
            Title = "Config", Options = cfgNames(), Default = cfgNames()[1], Save = false,
            Callback = function(v) selectedCfg = v end,
        })
        selectedCfg = cfgNames()[1]
        cfgSec:AddInput({ Title = "Name", Default = "", Callback = function(v) cfgName = v end })
        cfgSec:AddButton({
            Title = "Create",
            Callback = function()
                local name = cleanName(cfgName)
                if not name then return say(cfgStatus, "Type a name first.") end
                ensureDir(CONFIG_DIR)
                if writeJson(CONFIG_DIR .. name .. ".json", snapshotConfig()) then
                    refreshCfgs()
                    cfgDropdown:Set(name, true)
                    selectedCfg = name
                    say(cfgStatus, "Created " .. name .. "\n" .. autoloadText())
                else
                    say(cfgStatus, "Couldn't write the file.")
                end
            end,
        })
        cfgSec:AddButton({
            Title = "Save",
            Callback = function()
                if selectedCfg == "None" then return say(cfgStatus, "Pick a config or use Create.") end
                ensureDir(CONFIG_DIR)
                say(cfgStatus, writeJson(CONFIG_DIR .. selectedCfg .. ".json", snapshotConfig()) and ("Saved " .. selectedCfg) or "Couldn't write the file.")
            end,
        })
        cfgSec:AddButton({
            Title = "Load",
            Callback = function()
                local data = selectedCfg ~= "None" and readJson(CONFIG_DIR .. selectedCfg .. ".json")
                if not data then return say(cfgStatus, "Can't read " .. tostring(selectedCfg)) end
                say(cfgStatus, "Loaded " .. selectedCfg .. " (" .. applyConfig(data) .. " settings)")
            end,
        })
        cfgSec:AddButton({
            Title = "Delete",
            Callback = function()
                if selectedCfg == "None" then return end
                pcall(function() delfile(CONFIG_DIR .. selectedCfg .. ".json") end)
                if autoload().config == selectedCfg then setAutoload("config", nil) end
                say(cfgStatus, "Deleted " .. selectedCfg)
                refreshCfgs()
                selectedCfg = cfgNames()[1]
                cfgDropdown:Set(selectedCfg, true)
            end,
        })
        cfgSec:AddButton({
            Title = "Autoload",
            Callback = function()
                if selectedCfg == "None" then return say(cfgStatus, "Pick a config first.") end
                setAutoload("config", selectedCfg)
                say(cfgStatus, autoloadText())
            end,
        })
        cfgSec:AddButton({
            Title = "Autoload off",
            Callback = function() setAutoload("config", nil) say(cfgStatus, autoloadText()) end,
        })
        cfgSec:AddButton({ Title = "Refresh", Callback = refreshCfgs })

        -- share a config as text: Export copies it, Import applies pasted text (and saves it when Name is filled in)
        local importText = ""
        cfgSec:AddButton({
            Title = "Export",
            Callback = function()
                local ok, text = pcall(function() return HttpService:JSONEncode(snapshotConfig()) end)
                if ok and setclipboard then
                    setclipboard(text)
                    say(cfgStatus, "Copied the current settings")
                else
                    say(cfgStatus, "Can't copy here")
                end
            end,
        })
        cfgSec:AddInput({ Title = "Paste", Default = "", Callback = function(v) importText = v end })
        cfgSec:AddButton({
            Title = "Import",
            Callback = function()
                local ok, data = pcall(function() return HttpService:JSONDecode(importText) end)
                if not ok or type(data) ~= "table" or type(data.controls) ~= "table" then return say(cfgStatus, "That isn't a config") end
                local n = applyConfig(data)
                local name = cleanName(cfgName)
                if name then
                    ensureDir(CONFIG_DIR)
                    writeJson(CONFIG_DIR .. name .. ".json", data)
                    refreshCfgs()
                    cfgDropdown:Set(name, true)
                    selectedCfg = name
                end
                say(cfgStatus, "Imported " .. n .. " settings" .. (name and (" as " .. name) or ""))
            end,
        })

        -- interface: keys and window
        local ifaceSec = tab:AddSection("Interface", true, "Right")
        ifaceSec:AddKeybind({
            Title = "Toggle Key", Default = M.ui.toggleKey,
            Callback = function(key) M.ui.toggleKey = key M.saveUI() end,
        })
        ifaceSec:AddKeybind({
            Title = "Panic Key", Default = M.ui.panicKey,
            Callback = function(key) M.ui.panicKey = key M.saveUI() end,
        })
        ifaceSec:AddButton({
            Title = "Reset Window",
            Callback = function()
                local win = getgenv().NovaWindow
                if win and win.ResetLayout then win:ResetLayout() end
            end,
        })
    end

    return M
end)()
