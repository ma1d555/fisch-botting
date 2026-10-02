-- FishTP + Progression loader. The script lives in the executor's workspace folder, fishtp/: the parts listed in
-- fishtp/parts.txt (joined in that order and run as one script) and the hub's modules in fishtp/modules.
-- Run from queue_on_teleport (after a server hop) it starts while the new server is still loading: the hub's modules
-- take Players.LocalPlayer once when they load (AutoCast errored on a nil one), so it waits for the game, the player
-- and the character first.
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
while not Players.LocalPlayer do task.wait(0.1) end
if not Players.LocalPlayer.Character then Players.LocalPlayer.CharacterAdded:Wait() end
task.wait(2)
local DIR = "fishtp/"
-- Files come from GitHub first (so a run is always the latest), the workspace copy is the fallback.
local BASE = "https://raw.githubusercontent.com/ma1d555/fisch-botting/claude/gallant-lamport-7dusyx/fishtp/"
local function fetch(path)
    local ok, text = pcall(game.HttpGet, game, BASE .. path)
    if ok and type(text) == "string" and #text > 0 and not text:sub(1, 20):lower():match("^%s*<") and text:sub(1, 4) ~= "404:" then
        return text
    end
    local okFile, fileText = pcall(readfile, DIR .. path)
    return okFile and type(fileText) == "string" and fileText or nil
end
getgenv().FishTPFetch = fetch
getgenv().FishTPQueueSource = 'loadstring(game:HttpGet("' .. BASE .. 'loader.lua"))()'
local list = fetch("parts.txt")
if not list then
    warn("[FishTP] can't get parts.txt from GitHub or the workspace fishtp/ folder")
    return
end
local chunks, index, line = {}, {}, 1
for name in list:gmatch("[^\r\n]+") do
    local text = fetch("parts/" .. name)
    if not text then
        warn("[FishTP] missing part:", name)
        return
    end
    text = text:gsub("\r\n", "\n")
    if text:sub(-1) ~= "\n" then text = text .. "\n" end
    local _, count = text:gsub("\n", "")
    chunks[#chunks + 1] = text
    index[#index + 1] = { name = name, first = line, last = line + count - 1 }
    line = line + count
end
local function where(n)
    for _, part in ipairs(index) do
        if n and n >= part.first and n <= part.last then return part.name .. ":" .. (n - part.first + 1) end
    end
    return "FishTP:" .. tostring(n)
end
getgenv().FishTPWhere = where
local function explain(err)
    return (tostring(err):gsub("FishTP:(%d+):", function(n) return where(tonumber(n)) .. ":" end))
end
local fn, err = loadstring(table.concat(chunks), "=FishTP")
if not fn then
    warn("[FishTP] doesn't compile:", explain(err))
    return
end
local ok, runErr = xpcall(fn, function(e) return explain(e) .. "\n" .. debug.traceback() end)
if not ok then warn("[FishTP] error while loading:", runErr) end
