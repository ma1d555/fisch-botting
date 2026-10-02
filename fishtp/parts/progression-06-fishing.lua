	-- [Progression part 06-fishing: fishing through the hub, legit cast, earning C$. The loader joins the parts in order into one scope.]
	-- ---- fishing (drives the hub's own modules) -------------------------------------------

	local Fish = { active = false, saved = nil, zone = nil, opts = nil, spot = nil }

	-- Grind zones that are saved locations rather than the hub's zone list.
	local SPOT_ZONES = {
		["Driftwood spot"] = "Driftwood spot", ["C$ farm spot"] = "C$ farm spot",
		["DJ Spinopus spot"] = "DJ Spinopus spot", ["Cloud"] = "Cloud", ["XP spot"] = "XP spot",
	}

	local function hubCall(fn, ...)
		if fn then pcall(fn, ...) end
	end

	-- Anything in `protected` must not be sold (AutoSell sells Driftwood, Ruby, crystals and so on). Those items are
	-- favourited, which Sell All skips, so selling can stay on; if favouriting isn't possible, selling pauses.
	local function sellingIsSafe()
		for name, filter in pairs(state.protected) do
			local f = filter ~= true and filter or nil
			if G.count(name, f, true) > 0 and not G.favourite(name, f) then return false end
		end
		return true
	end

	-- Legit cast (user): casting the way a player does. The left mouse button is held, the power bar the game shows
	-- over your character (HumanoidRootPart.power.powerbar.bar) fills, and the button is let go when it's full, so the
	-- rod's own script makes the throw. Returns whether the bobber went out.
	local RunService = game:GetService("RunService")
	function G.legitCast()
		local character, hrp, rodName = LP.Character, G.hrp(), G.equippedRod()
		if not (character and hrp and rodName) then return false end
		local rod = character:FindFirstChild(rodName)
		if not rod then
			-- While the progression fishes, the rod is put back in hand; otherwise what you hold is up to you.
			if Fish.active then G.hold(rodName) end
			return false
		end
		if _G.IsReeling or rod:FindFirstChild("bobber") or character:FindFirstChild("dialoglink")
			or LP.PlayerGui:FindFirstChild("shakeui") or LP.PlayerGui:FindFirstChild("reel") then
			return false
		end
		G.mouse(true)
		local bar, full
		local deadline = os.clock() + 4
		while os.clock() < deadline do
			RunService.Heartbeat:Wait()
			local power = hrp:FindFirstChild("power")
			local powerbar = power and power:FindFirstChild("powerbar")
			bar = powerbar and powerbar:FindFirstChild("bar")
			if bar and bar.Size.X.Scale >= 0.97 and bar.Size.Y.Scale >= 0.97 then
				full = true
				break
			end
		end
		G.mouse(false)
		if not bar then
			log("legit cast: the power bar didn't show up")
			return false
		end
		local out = waitFor(function() return rod:FindFirstChild("bobber") ~= nil end, 3, 0.1)
		if not out then log(("legit cast: no bobber after letting go (bar %s)"):format(full and "full" or "not full")) end
		return out
	end

	-- Legit Cast (the Fishing tab's toggle, _G.Config.LegitCast): while it and Auto Cast are both on, the hub's AutoCast
	-- stands down (the build patches it to) and this casts like a player instead. Auto shake and reel carry on as usual.
	task.spawn(function()
		while alive() do
			local config = _G.Config
			if config and config.LegitCast and config.AutoCast then
				local ok, err = pcall(G.legitCast)
				if not ok then log("legit cast failed: " .. tostring(err)) end
				task.wait(0.4)
			else
				task.wait(0.5)
			end
		end
	end)

	function Fish.start(zone, opts)
		opts = opts or {}
		Fish.zone, Fish.opts = zone, opts
		if not Fish.saved then
			Fish.saved = {
				PerfectCatchChance = _G.Config.PerfectCatchChance,
				perfectCatchEnabled = _G.Config.perfectCatchEnabled,
				perfectCastEnabled = _G.Config.perfectCastEnabled,
				LegitCast = _G.Config.LegitCast == true,
				-- The reel settings opts.minigame changes (nil ones as their defaults, so they're put back too).
				ReelMode = _G.Config.ReelMode or "Super Instant",
				InstantReel = _G.Config.InstantReel == true,
				BarSizePercent = _G.Config.BarSizePercent or 0,
				ReelProgressSpeed = _G.Config.ReelProgressSpeed or 1,
				FreezeReelProgress = _G.Config.FreezeReelProgress == true,
				FreezeFish = _G.Config.FreezeFish == true,
			}
		end
		if opts.perfect then
			_G.Config.perfectCatchEnabled = 100
			_G.Config.PerfectCatchChance = 100
			_G.Config.perfectCastEnabled = 100
		end
		-- The reel minigame played out instead of Super Instant finishing it (user: the 42 catches for Pinion's Aria
		-- didn't count with Super Instant): the bar fills the whole reel, so the fish never leaves it, and progress goes
		-- at its normal speed (user: 100%). "Legit" keeps Auto Reel on without finishing the reel itself.
		if opts.minigame then
			_G.Config.ReelMode = "Legit"
			_G.Config.InstantReel = false
			_G.Config.BarSizePercent = 100
			_G.Config.ReelProgressSpeed = 1
			_G.Config.FreezeReelProgress = false
			_G.Config.FreezeFish = false
		end
		-- Legit Cast: the Fishing tab's setting, and always at the Cloud (user: for the Heavenly Harmonic Dove). Fish.stop
		-- puts the setting back as it was, so it's only on afterwards if you had it on.
		local legit = zone == "Cloud" or Fish.saved.LegitCast
		_G.Config.LegitCast = legit
		_G.Config.AutoCast = true
		_G.Config.InstantCast = not legit
		_G.Config.AutoReel = true
		_G.Config.AutoShake = true
		-- The hub's Auto Equip Rod keeps re-equipping in a loop. Nothing here unequips the rod except holding a
		-- totem or relic, so it's put in hand once, and again only when something else took its place.
		_G.Config.isEquipRpd = false
		if MiscFishing and MiscFishing.AutoEquipRod then hubCall(MiscFishing.AutoEquipRod, false) end
		local rod = G.equippedRod()
		if rod and not (LP.Character and LP.Character:FindFirstChild(rod)) then G.hold(rod) end
		local sell = opts.sell and sellingIsSafe()
		_G.Config.AutoSell = sell
		hubCall(AutoCast, true)
		hubCall(AutoReel, true)
		hubCall(AutoShake, true)
		if sell then hubCall(AutoSell, true) end
		-- Progression decides where to fish. A step that needs a zone names it. Otherwise it's the grind zone when
		-- "Teleport to the grind zone" is on, or the spot you stood on when you turned Auto progression on.
		-- A saved spot (like the XP spot) is teleported to directly; a hub zone uses the hub's zone teleport;
		-- "None" means right here. Any zone left in the hub's Fishing tab (it survives re-running the script in the
		-- same client) is cleared rather than teleported to.
		if zone == nil and not state.settings.teleportToGrind then
			zone = "None"
			Fish.spot = state.home
		else
			zone = zone or state.settings.grindZone or "None"
			local spotName = SPOT_ZONES[zone]
			Fish.spot = spotName and G.spot(spotName) or nil
		end
		local hubZone = SPOT_ZONES[zone] and "None" or zone
		_G.Config.selectedZone = hubZone
		_G.Config.selectedZoneADS = hubZone ~= "None"
		-- The hub's zone teleport is only used for a hub zone; for "None" it's left alone, so turning the
		-- progression on or off never moves you.
		Fish.hubZone = hubZone
		if hubZone ~= "None" and TeleportArea and TeleportArea.TeleportToZone then hubCall(TeleportArea.TeleportToZone, hubZone) end
		if Fish.spot and not G.near(Fish.spot, 40) then
			G.teleport(Fish.spot)
			faceSpot(SPOT_ZONES[zone])
		end
		Fish.active = true
		if legit then log("legit cast on") end
	end

	function Fish.stop()
		if not Fish.active then return end
		Fish.active = false
		Fish.spot = nil
		_G.Config.AutoCast = false
		_G.Config.InstantCast = false
		_G.Config.AutoShake = false
		_G.Config.AutoSell = false
		hubCall(AutoCast, false)
		hubCall(AutoShake, false)
		_G.Config.selectedZone = "None"
		_G.Config.selectedZoneADS = false
		if Fish.hubZone and Fish.hubZone ~= "None" and TeleportArea and TeleportArea.TeleportToZone then
			hubCall(TeleportArea.TeleportToZone, "None")
		end
		Fish.hubZone = nil
		-- Puts the hub's perfect catch/cast and Legit Cast back as they were. Its zone teleport stays off.
		if Fish.saved then
			for key, value in pairs(Fish.saved) do _G.Config[key] = value end
			Fish.saved = nil
		end
		task.wait(0.5)
	end

	local restockBait -- buys and opens bait crates; set in the bait crate section below

	-- Fishes until cond() is true. opts: zone, rod, bait, perfect, sell, minigame (the reel played out, see Fish.start),
	-- label for the status line.
	local function fishUntil(label, cond, opts)
		if cond() then return end
		opts = opts or {}
		-- A step that needs a particular rod says so; everything else fishes with the best rod owned.
		G.equipRod(opts.rod or state.stageRod or G.bestRod())
		-- A step's own bait (Magnet, Shark Head...), else (Auto bait) the bait you have most of when none is on;
		-- out of bait, Buy bait crates restocks first.
		local function restockWhileFishing(force)
			local wasFishing = Fish.active
			if wasFishing then Fish.stop() end
			local ok = restockBait(force)
			if wasFishing then Fish.start(opts.zone, opts) end
			return ok
		end
		local function baitUp()
			-- A step that takes any of a few baits (Magnet or Garbage for Driftwood): keep one of them on, and if
			-- none are left, restock from bait crates (at most every 15 minutes).
			if opts.baits then
				local current = G.equippedBait()
				for _, name in ipairs(opts.baits) do
					if current == name and G.baitCount(name) > 0 then return end
				end
				for pass = 1, 2 do
					for _, name in ipairs(opts.baits) do
						if G.baitCount(name) > 0 then
							G.equipBait(name)
							return
						end
					end
					if pass == 2 or not (state.settings.buyBaitCrates and restockBait) or not restockWhileFishing(false) then break end
				end
				return
			end
			if opts.bait or not state.settings.autoBait then return end
			if not G.autoBait() and state.settings.buyBaitCrates and restockBait then
				if restockWhileFishing(false) then G.autoBait() end
			end
		end
		if opts.bait then G.equipBait(opts.bait) else baitUp() end
		setStatus("Fishing", label)
		Fish.start(opts.zone, opts)
		local lastLog, lastBait = os.clock(), os.clock()
		while not cond() do
			sleep(4)
			if os.clock() - lastBait > 60 then
				lastBait = os.clock()
				baitUp()
			end
			-- The progression comes last: if you move somewhere else, it fishes there instead of pulling you back.
			if Fish.spot and not G.near(Fish.spot, 120) then
				local hrp = G.hrp()
				if hrp then
					local p = hrp.Position
					log(("moved to %d, %d, %d; fishing here from now on"):format(math.floor(p.X), math.floor(p.Y), math.floor(p.Z)))
					if Fish.spot == state.home then state.home = p end
					Fish.spot = p
				end
			end
			if opts.sell and _G.Config.AutoSell and not sellingIsSafe() then
				_G.Config.AutoSell = false
				log("AutoSell paused: holding items the plan needs")
			end
			if os.clock() - lastLog > 120 then
				lastLog = os.clock()
				log(("still fishing for %s (level %d, %d C$, %d catches)"):format(label, G.level(), G.coins(), state.catches))
			end
		end
		Fish.stop()
	end

	local function fishCatches(label, count, opts)
		local target = state.catches + count
		fishUntil(label, function()
			state.detail = ("%s (%d/%d)"):format(label, count - math.max(0, target - state.catches), count)
			notify()
			return state.catches >= target
		end, opts)
	end

	-- Money (user): the best rod owned, at the C$ farm spot.
	local function earn(amount, why)
		fishUntil(("%s C$ for %s"):format(tostring(amount), why), function() return G.coins() >= amount end,
			{ sell = true, rod = G.bestRod(), zone = "C$ farm spot" })
	end

