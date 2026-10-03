	-- [Progression part 12-tools: codes, explore, snapshot. The loader joins the parts in order into one scope.]
	-- ---- codes ------------------------------------------------------------------------------

	-- Codes listed as working in late September 2026 by Game8, Beebom and Pocket Gamer (they disagree, so both
	-- spellings are tried where they differ). Add more, one per line, to workspace/amethyst/progression/codes.txt.
	local CODES = {
		"VroomVroom", "PeaceLoveUnityRespect", "LittleBudlingUpdate", "MarianaIsGoingCrazy", "scarlet", "SCARLET",
		"TemporarySubmarine", "SUBMARINE", "CARBON", "CARBONBOBBER", "SkycrestIsInTheSky", "SkycrestNextWeek",
		"ShootingStars", "CollectMyPufferfish", "TheDeepIsVeryDeep", "TheDeepAwaitsForYou", "HarpoonGunsAreAwesome",
		"HarpoonGunsNextWeek", "RoamingFishAndWaterPark", "OllieAndFinWhale", "DrylandsIsFire", "KingCrabstle",
		"Fischfest2026", "AquariumCustomization", "Shady", "HumpbackAndMegamouth", "Sovereign", "VenueTakeover",
		"nickandsnothegoat", "Companions",
	}
	-- The settings menu's code box (Settings/.../codes/coderunner) sends events.runcode:FireServer(code) and the game
	-- answers with its own notification, so there's no result to read back here: every code is just sent once.
	local redeeming = false
	function Progression.redeemCodes()
		if redeeming then return end
		redeeming = true
		local codes, seen = {}, {}
		local function add(code)
			code = code and code:gsub("^%s+", ""):gsub("%s+$", "")
			if code and code ~= "" and not seen[code] then
				seen[code] = true
				codes[#codes + 1] = code
			end
		end
		for _, code in ipairs(CODES) do add(code) end
		pcall(function()
			if isfile(DIR .. "/codes.txt") then
				for line in readfile(DIR .. "/codes.txt"):gmatch("[^\r\n,]+") do add(line) end
			end
		end)
		local remote = G.event("runcode")
		if not remote then
			setStatus("Codes", "the game's code remote (events.runcode) wasn't found")
			redeeming = false
			return
		end
		for i, code in ipairs(codes) do
			setStatus("Redeeming codes", ("%d/%d: %s"):format(i, #codes, code))
			pcall(remote.FireServer, remote, code)
			task.wait(1.5)
		end
		setStatus("Codes sent", ("%d codes; the game's popups say which worked"):format(#codes))
		redeeming = false
	end

	-- ---- explore ------------------------------------------------------------------------------

	-- The hub's TP tab is built by the obfuscated AreaTP module, so its island positions can't be read directly.
	-- captureTP wraps a TP section before AreaTP fills it and keeps each dropdown's options: choosing an option
	-- teleports (with the hub's ground snap), which is exactly what Explore needs.
	local tpMenus = {}
	function Progression.captureTP(section, label)
		if type(section) ~= "table" or type(section.AddDropdown) ~= "function" then return end
		local original = section.AddDropdown
		section.AddDropdown = function(self, opts, ...)
			if type(opts) == "table" then
				tpMenus[#tpMenus + 1] = { section = label, opts = opts }
			end
			return original(self, opts, ...)
		end
	end

	-- Discovering a location pays C$ and XP once (library.locations). The server decides which zone you're in and
	-- writes it to character.zone (ZoneController reads that), so each spot is held until that changes (or 2.5s),
	-- not for a single frame. Spots come from the TP menu; zone parts are the fallback.
	local exploring = false

	local function exploreTargets()
		local targets = {}
		for _, menu in ipairs(tpMenus) do
			local title = tostring(menu.opts.Title or ""):lower()
			local options = menu.opts.Options or menu.opts.Values or menu.opts.List
			-- Island/area pickers only: NPC lists and saved positions aren't places to discover.
			if menu.section == "Main" and type(options) == "table" and not title:find("npc") and not title:find("save") then
				for _, option in ipairs(options) do
					if type(option) == "string" and option ~= "None" and option ~= "" then
						targets[#targets + 1] = {
							name = option,
							menu = menu,
							-- Returns whether it moved us; some UI libraries pass the choice wrapped in a table.
							go = function()
								local hrp = G.hrp()
								local start = hrp and hrp.Position
								pcall(menu.opts.Callback, option)
								task.wait(0.3)
								local now = G.hrp()
								if start and now and (now.Position - start).Magnitude > 20 then return true end
								pcall(menu.opts.Callback, { option })
								task.wait(0.3)
								now = G.hrp()
								return start ~= nil and now ~= nil and (now.Position - start).Magnitude > 20
							end,
						}
					end
				end
			end
		end
		if #targets > 0 then return targets, "TP menu" end
		local zones = workspace:FindFirstChild("zones")
		local folder = zones and zones:FindFirstChild("player")
		local seen = {}
		for _, zone in ipairs(folder and folder:GetChildren() or {}) do
			local label = zone:FindFirstChild("zonename")
			local name = label and label.Value or zone.Name
			local pos = positionOf(zone)
			if pos and not seen[name] then
				seen[name] = true
				targets[#targets + 1] = { name = name, go = function() G.teleport(pos) end }
			end
		end
		return targets, "zone parts"
	end
	function Progression.exploreAreas()
		if exploring then
			exploring = false -- pressing again stops it
			return
		end
		if state.running then
			setStatus("Explore", "turn Auto progression off first (both move you around)")
			return
		end
		local hrp = G.hrp()
		local zoneValue = LP.Character and LP.Character:FindFirstChild("zone")
		if not (hrp and zoneValue) then
			setStatus("Explore", "couldn't find your character's zone")
			return
		end
		local targets, source = exploreTargets()
		if #targets == 0 then
			setStatus("Explore", "no TP menu locations or zones found")
			return
		end
		exploring = true
		log(("explore: %d spots from the %s"):format(#targets, source))
		local home = hrp.CFrame
		-- The hub's "Auto Fishing Teleport" would keep pulling us back to its zone.
		local hubZoneTeleport = _G.Config.selectedZoneADS
		_G.Config.selectedZoneADS = false
		local zonesSeen, newZones = {}, 0
		local current = zoneValue.Value
		if current then zonesSeen[current] = true end
		local misses = {} -- menu -> options that didn't move us; a menu whose first two don't isn't a teleport list
		local ok, err = pcall(function()
			for i, target in ipairs(targets) do
				if not exploring then break end
				local skip = target.menu and (misses[target.menu] or 0) >= 2
				local moved = false
				local before = zoneValue.Value
				if not skip then
					setStatus("Exploring", ("%d/%d: %s (press again to stop)"):format(i, #targets, target.name))
					moved = target.go() ~= false
					if not moved then
						misses[target.menu] = (misses[target.menu] or 0) + 1
						log(("explore %s: didn't move"):format(target.name))
					end
				end
				if moved then
					-- Hold still until the server moves us into the new zone, then a moment for the discovery to pay out.
					local deadline = os.clock() + 2.5
					repeat task.wait(0.1) until zoneValue.Value ~= before or os.clock() > deadline or not exploring
					local now = zoneValue.Value
					if now ~= before then
						task.wait(0.4)
						if now and not zonesSeen[now] then
							zonesSeen[now] = true
							newZones = newZones + 1
						end
					end
					log(("explore %s: zone %s"):format(target.name, now and now.Name or "Ocean"))
				end
			end
		end)
		hrp = G.hrp()
		if hrp then
			hrp.CFrame = home
			pcall(snapToGround, hrp)
		end
		_G.Config.selectedZoneADS = hubZoneTeleport
		if not ok then log("explore stopped by an error: " .. tostring(err)) end
		setStatus("Explore done", ("%d spots, entered %d different zones"):format(#targets, newZones))
		exploring = false
	end

	-- ---- snapshot ----------------------------------------------------------------------------

	-- F7 (or the Extras button): writes what's on screen and nearby to progression/ui-<time>.txt, which is how the
	-- script learns a shop or menu it doesn't know yet. Reads only; nothing is pressed.
	function Progression.snapshot()
		local lines = {}
		local hrp = G.hrp()
		local pos = hrp and hrp.Position
		lines[#lines + 1] = "position: " .. (pos and ("%d, %d, %d"):format(math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z)) or "?")
		lines[#lines + 1] = "equipped rod: " .. tostring(G.equippedRod()) .. ", bait: " .. tostring(G.equippedBait())
		lines[#lines + 1] = "-- prompts within 60 studs"
		for _, prompt in ipairs(pos and G.promptsNear(pos, 60) or {}) do
			lines[#lines + 1] = ("%s | action \"%s\" | object \"%s\""):format(prompt:GetFullName(), prompt.ActionText, prompt.ObjectText)
		end
		-- The tool in hand: what's inside it and its scripts' source (how it's used, e.g. opening a crate).
		local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
		if tool then
			lines[#lines + 1] = "-- held tool: " .. tool.Name
			for _, d in ipairs(tool:GetDescendants()) do
				lines[#lines + 1] = ("%s [%s]"):format(d:GetFullName(), d.ClassName)
			end
			for _, d in ipairs(tool:GetDescendants()) do
				if (d:IsA("LocalScript") or d:IsA("ModuleScript")) and decompile then
					local ok, source = pcall(decompile, d)
					if ok and type(source) == "string" then
						lines[#lines + 1] = "-- source of " .. d:GetFullName()
						lines[#lines + 1] = source:sub(1, 20000)
					end
				end
			end
		end
		lines[#lines + 1] = "-- on screen: buttons, text boxes, text"
		for _, d in ipairs(LP.PlayerGui:GetDescendants()) do
			if #lines > 4000 then break end
			local isText = d:IsA("TextLabel") and d.Text ~= ""
			if (d:IsA("GuiButton") or d:IsA("TextBox") or isText) and shown(d) then
				local text = d:IsA("GuiButton") and buttonWords(d) or d.Text
				lines[#lines + 1] = ("%s [%s] \"%s\""):format(d:GetFullName(), d.ClassName, tostring(text):gsub("\n", " "):sub(1, 100))
			end
		end
		local file = DIR .. "/ui-" .. os.time() .. ".txt"
		pcall(writefile, file, table.concat(lines, "\n"))
		setStatus("Snapshot saved", file)
	end


	-- ---- meteors and cosmic craters (user: Fishing tab buttons) ------------------------------------------------------
	-- A landing is sent to everyone wherever they are (Meteor/Spawn: position, land time, colour; MeteorController). It
	-- leaves a crater (tag MeteorCrater) with the thing to take in it (tag MeteorItem, attribute ID); whoever claims it
	-- makes it vanish for everyone (Meteor/Claim). Landings heard since the script started are gone to, plus any meteor
	-- already loaded. Cosmic ones (Starfall, Cosmic Relics) are told apart by "cosmic" in the item's name, attributes or
	-- parts, and each item is logged, so that can be checked.
	G.sky = { landings = {} }
	pcall(function()
		local spawn = G.net("RE/Meteor/Spawn")
		if not spawn then return end
		spawn.OnClientEvent:Connect(function(pos, landAt, color)
			if not alive() or typeof(pos) ~= "Vector3" then return end
			local list = G.sky.landings
			list[#list + 1] = { pos = pos, at = tonumber(landAt) or workspace:GetServerTimeNow(), color = color }
			while #list > 20 do table.remove(list, 1) end
			log(("a meteor is landing at %d, %d, %d%s"):format(math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z),
				typeof(color) == "Color3" and (" (colour %d,%d,%d)"):format(math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)) or ""))
		end)
	end)
	function G.sky.describe(item)
		local attrs = {}
		for k, v in pairs(item:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
		local kids = {}
		for i, d in ipairs(item:GetDescendants()) do
			if i > 12 then break end
			kids[#kids + 1] = d.Name .. "[" .. d.ClassName .. "]"
		end
		return ("%s [%s] %s | %s"):format(item.Name, item.ClassName, table.concat(attrs, ";"), table.concat(kids, ", "))
	end
	function G.sky.kind(item)
		local text = G.sky.describe(item):lower()
		return text:find("cosmic", 1, true) and "cosmic" or "meteor"
	end
	function G.sky.near(pos, radius)
		local best, bestDistance
		for _, item in ipairs(CollectionService:GetTagged("MeteorItem")) do
			local p = item:IsDescendantOf(workspace) and positionOf(item)
			if p and (p - pos).Magnitude <= radius and (not best or (p - pos).Magnitude < bestDistance) then
				best, bestDistance = item, (p - pos).Magnitude
			end
		end
		return best
	end
	local function collectSky(kind)
		local label = kind == "cosmic" and "Cosmic craters" or "Meteors"
		local hrp = G.hrp()
		if not hrp then return end
		local home = hrp.Position
		local spots = {}
		local function add(p)
			for _, s in ipairs(spots) do
				if (s - p).Magnitude < 60 then return end
			end
			spots[#spots + 1] = p
		end
		for _, item in ipairs(CollectionService:GetTagged("MeteorItem")) do
			local p = item:IsDescendantOf(workspace) and positionOf(item)
			if p then add(p) end
		end
		local now = workspace:GetServerTimeNow()
		for _, l in ipairs(G.sky.landings) do
			if now >= l.at and now - l.at < 900 then add(l.pos) end
		end
		if #spots == 0 then
			setStatus(label, "none landed since the script started (it hears every landing from now on)")
			return
		end
		setStatus(label, ("looking at %d landing spot(s)"):format(#spots))
		local got = 0
		for _, pos in ipairs(spots) do
			checkStop()
			G.teleport(pos)
			local item
			waitFor(function()
				item = G.sky.near(pos, 80)
				return item ~= nil
			end, 4, 0.2)
			if not item then
				log(("%s: nothing left at %d, %d"):format(label, math.floor(pos.X), math.floor(pos.Z)))
			elseif G.sky.kind(item) ~= kind then
				log(("%s: not this kind, left it: %s"):format(label, G.sky.describe(item)))
			else
				log(("%s: taking %s"):format(label, G.sky.describe(item)))
				local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt then
					G.pressPrompt(prompt, "hold")
					if item.Parent then G.firePrompt(prompt) end
				else
					-- No prompt: touching it (each of its parts against you).
					for _, part in ipairs(item:GetDescendants()) do
						if part:IsA("BasePart") and G.hrp() then
							pcall(function()
								firetouchinterest(G.hrp(), part, 0)
								firetouchinterest(G.hrp(), part, 1)
							end)
						end
					end
				end
				if waitFor(function() return item.Parent == nil end, 6, 0.2) then
					got = got + 1
					log(label .. ": collected")
				else
					log(label .. ": it didn't go (see what it's made of above)")
				end
			end
		end
		G.teleport(home)
		setStatus(label, ("collected %d"):format(got))
	end
	function Progression.collectSky(kind)
		withProgressionPaused(collectSky, kind)
	end

	-- ---- cosmic craters (user) ----------------------------------------------------------------------------------------
	-- Star craters (Workspace.StarCrater, seen holding a Starfall Totem, Rock and Basalt, each with a "Collect" prompt)
	-- land on one of 47 spots on the islands (user, from the wiki), never in water, and nothing announces them. So the
	-- spots are flown over one by one, held in the air like the Megalodon search, and every crater that loads in is
	-- emptied. What they hold (wiki): Rock 30%, Basalt 35%, Cosmic Relic 20%, Lunar Thread 10%, Starfall Totem 5%.
	-- Where star craters can land (user, from the wiki: 47 spots, all on islands). Stops are the ones above Y 100 (user).
	G.sky.islands = {
		-- Northern Expedition
		{ 19608, 172, 5340 }, { 20312, 220, 5226 }, { 19287, 398, 6133 }, { 19611, 399, 5474 }, { 19256, 416, 5780 },
		{ 19896, 460, 4989 }, { 19616, 470, 6036 }, { 20142, 656, 5830 }, { 20326, 722, 5719 }, { 20057, 1045, 5755 },
		{ 19829, 1050, 5486 }, { 20007, 1138, 5379 },
		-- Snowcap Island
		{ 2662, 171, 2540 }, { 3376, 132, 2877 }, { 2944, 151, 2469 },
		-- Ancient Isle
		{ 6251, 145, 926 }, { 5689, 164, 687 }, { 6061, 203, 376 }, { 5469, 142, -332 }, { 5960, 262, 223 },
		{ 6127, 386, 597 }, { 5683, 184, -182 }, { 6157, 273, 347 },
		-- Moosewood
		{ 614, 167, 221 }, { 447, 142, 306 },
		-- Forsaken Shores
		{ -2899, 231, 1275 }, { -2674, 168, 1787 }, { -2821, 272, 2544 }, { -2694, 133, 1586 },
		-- Castaway Cliffs
		{ 362, 203, -1817 }, { 449, 307, -2077 },
		-- Sunstone Island
		{ -852, 137, -1166 }, { -1132, 222, -1084 },
		-- Statue of Sovereignty
		{ -131, 153, -1157 },
		-- Terrapin Island
		{ 78, 217, 2082 }, { -56, 154, 1961 },
		-- Grand Reef
		{ -3689, 143, 735 },
		-- Mushgrove Swamp
		{ 2664, 134, -856 }, { 2542, 166, -1000 },
		-- Birch Cay, Earmark Island, The Arch, Haddock Rock
		{ 1775, 142, -2481 }, { 1218, 154, 455 }, { 1008, 133, -1290 }, { 1899, 184, -1156 },
		-- Unnamed rocks
		{ 1897, 183, -1155 }, { 2145, 186, 898 }, { -1572, 128, 2235 },
	}

	function G.sky.craters()
		local out = {}
		for _, c in ipairs(workspace:GetChildren()) do
			if c.Name:find("StarCrater", 1, true) then
				for _, d in ipairs(c:GetDescendants()) do
					if d:IsA("ProximityPrompt") and d.Enabled then
						out[#out + 1] = c
						break
					end
				end
			end
		end
		return out
	end
	function G.sky.islandStops()
		local stops = {}
		for _, i in ipairs(G.sky.islands) do
			if i[2] > 100 then
				local p = Vector3.new(i[1], i[2], i[3])
				local near = false
				for _, s in ipairs(stops) do
					if (s - p).Magnitude < 60 then near = true end
				end
				if not near then stops[#stops + 1] = p end
			end
		end
		-- Nearest first, then onwards from each.
		local hrp = G.hrp()
		local from = hrp and hrp.Position or Vector3.zero
		local ordered = {}
		while #stops > 0 do
			local best, bestDistance = 1, math.huge
			for i, s in ipairs(stops) do
				local d = (Vector3.new(s.X, 0, s.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
				if d < bestDistance then best, bestDistance = i, d end
			end
			from = table.remove(stops, best)
			ordered[#ordered + 1] = from
		end
		return ordered
	end
	-- Empties a crater: each of its Collect prompts, pressed standing next to it, until it goes.
	function G.sky.empty(crater)
		local got = 0
		for _, prompt in ipairs(crater:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") and prompt.Enabled and prompt.Parent then
				log(("Cosmic craters: collecting %s (%s)"):format(prompt.ObjectText ~= "" and prompt.ObjectText or prompt.Parent.Name, prompt.ActionText))
				G.pressPrompt(prompt, "hold", true)
				if prompt.Parent and prompt.Enabled then G.firePrompt(prompt) end
				if waitFor(function() return not (prompt.Parent and prompt.Enabled and prompt:IsDescendantOf(workspace)) end, 4, 0.2) then
					got = got + 1
				else
					log("Cosmic craters: it didn't go")
				end
			end
		end
		return got
	end
	local function collectStarCraters()
		local hrp = G.hrp()
		if not hrp then return end
		local home = hrp.Position
		local RunService = game:GetService("RunService")
		local done, got, found = {}, 0, 0
		local function emptyLoaded()
			for _, crater in ipairs(G.sky.craters()) do
				if not done[crater] then
					done[crater] = true
					found = found + 1
					local p = positionOf(crater)
					log(("Cosmic craters: a crater at %s"):format(p and ("%d, %d, %d"):format(math.floor(p.X), math.floor(p.Y), math.floor(p.Z)) or "?"))
					got = got + G.sky.empty(crater)
				end
			end
		end
		-- One already loaded near you first.
		emptyLoaded()
		local stops = G.sky.islandStops()
		setStatus("Cosmic craters", ("checking %d crater spots"):format(#stops))
		local target
		local function hover(on)
			if G.sky.hover then G.sky.hover:Disconnect() end
			G.sky.hover = nil
			if on then
				G.sky.hover = RunService.Heartbeat:Connect(function()
					if not alive() then
						G.sky.hover:Disconnect()
						return
					end
					local root = G.hrp()
					if root and target then
						root.CFrame = target
						root.AssemblyLinearVelocity = Vector3.zero
					end
				end)
			end
		end
		local lastArrival = 0
		-- The world streaming in around you (anything added), to know when an island has loaded.
		local arrivals = workspace.DescendantAdded:Connect(function() lastArrival = os.clock() end)
		local ok, err = pcall(function()
			for i, stop in ipairs(stops) do
				checkStop()
				target = CFrame.new(stop + Vector3.new(0, 40, 0))
				hover(true)
				-- Checked every frame; on once the area has come in and gone quiet, 1.5 s at most (islands load more).
				local arrived = os.clock()
				while true do
					RunService.Heartbeat:Wait()
					local now = os.clock()
					if #G.sky.craters() > 0 or now - arrived > 1.5 or (lastArrival > arrived and now - lastArrival > 0.25) then break end
				end
				if #G.sky.craters() > 0 then
					hover(false)
					emptyLoaded()
				end
				if i % 10 == 0 then log(("Cosmic craters: %d of %d spots"):format(i, #stops)) end
			end
		end)
		hover(false)
		arrivals:Disconnect()
		G.teleport(home)
		if not ok then error(err, 0) end
		setStatus("Cosmic craters", ("%d crater(s) found, %d thing(s) collected"):format(found, got))
	end
	function Progression.collectStarCraters()
		withProgressionPaused(collectStarCraters)
	end
