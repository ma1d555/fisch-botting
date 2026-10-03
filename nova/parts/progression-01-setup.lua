-- ============================================================
-- Progression: works through the rod questlines by itself.
--   Fortune Rod -> Wisdom Rod -> Heaven's Rod -> Pinion's Aria -> Tryhard Rod
--
-- Every game action lives in the G table and copies what the game's own client scripts do (read from their
-- decompiled source). Nothing hooks the game: the anti-cheat kicks for that. Alts share what they need and what
-- they can spare through files in workspace/amethyst/progression and trade when they're in the same server.
-- Everything it does is logged to workspace/amethyst/progression/<UserId>-log.txt.
-- ============================================================

local Progression = {}
Progression.statusHooks = {} -- functions(status, detail) the hub adds (webhook alerts)
Progression.catchHooks = {} -- functions(name, fish) called on every catch (catch alerts and toasts)
do
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")
	local HttpService = game:GetService("HttpService")
	local VirtualInputManager = game:GetService("VirtualInputManager")
	local LP = Players.LocalPlayer

	-- This run of the script (the hub's session; see Unload): loops and event handlers stop once it's over.
	local function alive() return getgenv().NovaSession == NOVA_SESSION end

	local DIR = "amethyst/progression"
	pcall(function()
		if not isfolder("amethyst") then makefolder("amethyst") end
		if not isfolder(DIR) then makefolder(DIR) end
	end)
	local LOG_FILE = DIR .. "/" .. LP.UserId .. "-log.txt"
	local SETTINGS_FILE = DIR .. "/" .. LP.UserId .. "-settings.json"
	local SPOTS_FILE = DIR .. "/locations.json"

	local STOP = setmetatable({}, { __tostring = function() return "stopped" end })

	local ROD_ORDER = { "Fortune Rod", "Wisdom Rod", "Heaven's Rod", "Pinion's Aria", "Tryhard Rod" }

	local state = {
		running = false,
		stop = false,
		status = "Idle",
		detail = "",
		settings = {
			version = 4,
			rods = { ["Fortune Rod"] = true, ["Wisdom Rod"] = true, ["Heaven's Rod"] = true, ["Pinion's Aria"] = true, ["Tryhard Rod"] = true },
			shareWithAlts = true,
			grindZone = "XP spot",
			teleportToGrind = false, -- off: grind where you stood when Auto progression was turned on
			autoBait = true, -- put on the bait you have most of when none is on
			buyBaitCrates = true, -- out of bait: buy 100 bait crates at Moosewood and open them
			useSundial = true, -- enchanting in the day: a Sundial Totem makes it night (bought if there's none)
			placedCrystals = {}, -- Energy Crystals already put in their pedestals (the game doesn't say), by colour
			aria = {}, -- Pinion's Aria steps already done (the game doesn't say)
			useChaoticRod = false, -- the Chaotic relic: fish with chaoticRod instead of the fastest-luring rod
			chaoticRod = nil,
		},
		home = nil, -- that spot
		needs = {}, -- item -> { qty, filter } this account is asking alts for
		protected = {}, -- item names AutoSell must not get rid of
		catches = 0,
		caught = {}, -- fish name -> times caught since the script started
	}
	local listeners = {}

	-- ---- basics ------------------------------------------------------------------

	local function readJson(file)
		local ok, value = pcall(function()
			if isfile(file) then return HttpService:JSONDecode(readfile(file)) end
		end)
		return ok and value or nil
	end

	local function writeJson(file, value)
		pcall(function() writefile(file, HttpService:JSONEncode(value)) end)
	end

	local function log(msg)
		local line = os.date("%H:%M:%S") .. "  " .. msg
		print("[Progression] " .. msg)
		pcall(function()
			if appendfile and isfile(LOG_FILE) then
				appendfile(LOG_FILE, line .. "\n")
			else
				writefile(LOG_FILE, (isfile(LOG_FILE) and readfile(LOG_FILE) or "") .. line .. "\n")
			end
		end)
	end

	local function notify()
		for _, fn in ipairs(listeners) do pcall(fn) end
	end

	local function setStatus(status, detail)
		state.status = status
		state.detail = detail or ""
		log(status .. (detail and detail ~= "" and (" - " .. detail) or ""))
		for _, hook in ipairs(Progression.statusHooks) do pcall(hook, status, state.detail) end
		notify()
	end

	local function checkStop()
		if state.stop then error(STOP, 0) end
	end

	local function sleep(seconds)
		local untilAt = os.clock() + seconds
		repeat
			task.wait(math.min(0.25, seconds))
			checkStop()
		until os.clock() >= untilAt
	end

	-- Polls cond() until it's true (returns true) or timeout seconds pass (returns false).
	local function waitFor(cond, timeout, interval)
		local deadline = os.clock() + (timeout or 10)
		while os.clock() < deadline do
			local ok, result = pcall(cond)
			if ok and result then return true end
			sleep(interval or 0.5)
		end
		return false
	end

	do
		local saved = readJson(SETTINGS_FILE)
		if type(saved) == "table" then
			for key, value in pairs(saved) do state.settings[key] = value end
		end
		-- Earlier versions left the grind zone on "None" (fish wherever you stand), or on the Moosewood spot, which is
		-- gone (user): grind at the XP spot instead.
		if state.settings.grindZone == "None" or state.settings.grindZone == nil or state.settings.grindZone == "Moosewood spot" then
			state.settings.grindZone = "XP spot"
		end
		state.settings.version = 4
		state.settings.legitCast = nil -- now the Fishing tab's Legit Cast
	end
	local function saveSettings()
		writeJson(SETTINGS_FILE, state.settings)
	end

