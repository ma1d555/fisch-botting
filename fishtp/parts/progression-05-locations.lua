	-- [Progression part 05-locations: saved spots and teleporting to them. The loader joins the parts in order into one scope.]
	-- ---- locations -------------------------------------------------------------------

	local DEFAULT_SPOTS = {
		["Fortune Rod shop"] = { -1510, 141, 750 },
		["Enchant altar"] = { 1310, -802, -84 },
		["Merlin"] = { -951, 222, -986 },
		["Driftwood spot"] = { 357, 134, 237 }, -- Moosewood
		["Bait crate shop"] = { 372, 139, 282 },
		["Sundial Totem shop"] = { -1149, 134, -1074 },
		["Castaways peak"] = { 630, 327, -2055 }, -- the Songstress up at the peak of Castaway Cliffs
		["Cloud"] = { 1495.1, 2593.5, -1758.0 }, -- above the clouds: where the Heavenly Harmonic Dove is fished
		["Mysterious Songstress"] = { 2070, -640, 2472 }, -- in the music venue
		["DJ Spinopus spot"] = { 1376, -603, 2337 },
		["Chaotic relic spot"] = { 1376, -598, 2388 }, -- where the Chaotic relic goes in
		["Heaven's Rod shop"] = { 20026, -469, 7142 }, -- in the cave the pedestals open
		-- Where to stand to put each Energy Crystal in (the user's coordinates; "orange" is the Yellow one).
		["Yellow pedestal"] = { 19966.7, 1138.1, 5361.1 },
		["Red pedestal"] = { 19952.1, 1138.1, 5351.2 },
		["Blue pedestal"] = { 19962.0, 1138.1, 5336.1 },
		["Green pedestal"] = { 19976.8, 1138.1, 5346.0 },
		["C$ farm spot"] = { 1104.9, -738.9, 1448.9 }, -- the AFK spot: where the plan fishes when it needs money
		["XP spot"] = { -1263.1, -231.7, -2949.4 }, -- where the plan fishes for levels
		["Meteor Totem shop"] = { -1945, 275, 230 },
		["Pickaxe shop"] = { 19782, 418, 5391 },
		["Hiker #12"] = { 19922, 1137, 5356 },
		["Crafting station"] = { -3161, -741, 1678 },
		["Blue crystal"] = { 20123, 208, 5444 },
		["Shadowy figure"] = { 19873, 448, 5556 },
		["Yellow crystal"] = { 19498, 335, 5553 },
		["Avalanche Totem shop"] = { 19711, 468, 6059 },
		["RoRed"] = { -1921, 263, 117 },
		["Button 1 (Moosewood)"] = { 400, 135, 265 },
		["Button 2"] = { 5506, 147, -315 },
		["Button 3"] = { 2930, 281, 2594 },
		["Button 4"] = { -1715, 149, 737 },
		["Button 5"] = { -2566, 181, 1353 },
	}
	-- Places the plan needs that aren't known yet; save them once from the Locations section.
	local SPOT_NAMES = {
		"Fortune Rod shop", "Crafting station", "Enchant altar", "Merlin", "Driftwood spot", "Bait crate shop", "Sundial Totem shop", "Meteor Totem shop", "Pickaxe shop",
		"C$ farm spot", "XP spot", "Hiker #12", "Yellow pedestal", "Red pedestal", "Blue pedestal", "Green pedestal", "Heaven's Rod shop",
		"Mysterious Songstress", "Chaotic relic spot", "DJ Spinopus spot", "Castaways peak", "Cloud",
		"Blue crystal", "Shadowy figure", "Yellow crystal", "Avalanche Totem shop", "RoRed",
		"Button 1 (Moosewood)", "Button 2", "Button 3", "Button 4", "Button 5",
	}

	local function spots()
		local saved = readJson(SPOTS_FILE)
		return type(saved) == "table" and saved or {}
	end

	function G.spot(name)
		local p = spots()[name] or DEFAULT_SPOTS[name]
		return p and Vector3.new(p[1], p[2], p[3]) or nil
	end

	local function saveSpot(name)
		local hrp = G.hrp()
		if not hrp then return false end
		local all = spots()
		local p = hrp.Position
		all[name] = { math.floor(p.X), math.floor(p.Y), math.floor(p.Z) }
		writeJson(SPOTS_FILE, all)
		log("saved location " .. name .. " at " .. table.concat(all[name], ", "))
		return true
	end

	-- Which way to face at some spots (user), turned from the way a teleport leaves you facing: degrees to the left.
	-- The cast goes where you face, so this points it at the water.
	local SPOT_TURN = { ["C$ farm spot"] = 180, ["XP spot"] = 90, ["Driftwood spot"] = 90 }
	local function faceSpot(name)
		local turn, hrp = SPOT_TURN[name], G.hrp()
		if turn and hrp then hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(turn), 0) end
	end

	-- Teleports to a named location, waiting for the user to save it if it isn't known yet.
	local function goTo(name)
		local pos = G.spot(name)
		if not pos then
			setStatus("Location needed", ("Stand at \"%s\" and save it in the Locations section"):format(name))
			waitFor(function() return G.spot(name) ~= nil end, math.huge, 2)
			pos = G.spot(name)
		end
		G.teleport(pos)
		faceSpot(name)
		return pos
	end

