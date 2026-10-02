	-- [Progression part 10-quests: mining, crystals, NPC steps, Pinion's Aria, hunts. The loader joins the parts in order into one scope.]
	-- ---- mining -------------------------------------------------------------------------------------

	-- Mining a crystal (user's instructions): stand at the saved spot, swing the pickaxe until a "Collect Crystal"
	-- prompt shows up, then collect it. Facing the nearest part named like a crystal/ore/rock, in case the swing
	-- only hits what's in front.
	local MINE_WORDS = { "crystal", "ore", "rock", "boulder" }
	local function rockNear(spot, colorWord)
		local best, bestScore
		local ok, parts = pcall(function() return workspace:GetPartBoundsInRadius(spot, 25) end)
		for _, part in ipairs(ok and parts or {}) do
			if not (LP.Character and part:IsDescendantOf(LP.Character)) then
				local names = part.Name
				local node = part.Parent
				for _ = 1, 3 do
					if not node or node == workspace then break end
					names = names .. " " .. node.Name
					node = node.Parent
				end
				names = names:lower()
				local fits = false
				for _, word in ipairs(MINE_WORDS) do
					if names:find(word, 1, true) then fits = true end
				end
				if fits then
					local score = (part.Position - spot).Magnitude - ((colorWord and names:find(colorWord, 1, true)) and 25 or 0)
					if not bestScore or score < bestScore then best, bestScore = part, score end
				end
			end
		end
		return best
	end

	local function collectPrompt(spot)
		for _, prompt in ipairs(G.promptsNear(spot, 40)) do
			if (prompt.ActionText .. " " .. prompt.ObjectText):lower():find("collect", 1, true) then return prompt end
		end
		return nil
	end

	local function mine(spotName, item, colorWord)
		local spot = goTo(spotName)
		sleep(1.5) -- let the area stream in
		local rock = rockNear(spot, colorWord)
		local hrp = G.hrp()
		if rock and hrp then
			hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(rock.Position.X, hrp.Position.Y, rock.Position.Z))
			log("mining: facing " .. rock:GetFullName())
		end
		setStatus("Mining", item .. ": swinging until \"Collect Crystal\" shows up")
		local collect
		local deadline = os.clock() + 120
		while os.clock() < deadline and G.count(item) < 1 do
			collect = collectPrompt(spot)
			if collect then break end
			if G.hold("Pickaxe") then
				local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
				if tool then pcall(function() tool:Activate() end) end
			end
			sleep(0.6)
		end
		G.unhold()
		if collect and G.count(item) < 1 then
			log(("mining: %s [%s %s] is up; collecting"):format(collect:GetFullName(), collect.ActionText, collect.ObjectText))
			G.firePrompt(collect)
			-- Some prompts only take a real key press.
			if not waitFor(function() return G.count(item) > 0 end, 4, 0.5) then
				G.pressPrompt(collect)
				waitFor(function() return G.count(item) > 0 end, 6, 0.5)
			end
		end
		local got = G.count(item) > 0
		log(("mining %s: %s"):format(item, got and "collected" or (collect and "the Collect prompt didn't give it" or "no Collect Crystal prompt after 2 minutes")))
		return got
	end

	-- Yellow Energy Crystal (user's steps): an Avalanche Totem (bought at its shop if there's none) used at the
	-- yellow spot, then away at once (the avalanche kills whoever's there), and back 5 seconds later to collect the
	-- crystal it leaves. Up to 3 totems.
	local function collectNear(spot, item)
		for _, prompt in ipairs(G.promptsNear(spot, 60)) do
			local text = (prompt.ActionText .. " " .. prompt.ObjectText):lower()
			if (text:find("collect", 1, true) or text:find("crystal", 1, true)) and not text:find("talk", 1, true) then
				log(("collecting: %s [%s %s]"):format(prompt:GetFullName(), prompt.ActionText, prompt.ObjectText))
				G.firePrompt(prompt)
				if not waitFor(function() return G.count(item) > 0 end, 3, 0.5) then G.pressPrompt(prompt) end
				return true
			end
		end
		return false
	end

	local function getYellowCrystal()
		for attempt = 1, 3 do
			if G.count("Yellow Energy Crystal") > 0 then return true end
			local function haveTotem() return G.count("Avalanche Totem", nil, true) > 0 end
			if not haveTotem() then
				setStatus("Yellow crystal", "buying an Avalanche Totem")
				buyFromDisplay("Avalanche Totem", haveTotem, "Avalanche Totem shop")
				if not haveTotem() then error("couldn't buy an Avalanche Totem (see the log)", 0) end
			end
			local spot = goTo("Yellow crystal")
			setStatus("Yellow crystal", "using an Avalanche Totem, then getting clear")
			G.useItem("Avalanche Totem")
			G.unhold()
			goTo("Avalanche Totem shop")
			sleep(5)
			setStatus("Yellow crystal", "collecting it")
			goTo("Yellow crystal")
			local got = waitFor(function()
				collectNear(spot, "Yellow Energy Crystal")
				return G.count("Yellow Energy Crystal") > 0
			end, 40, 2)
			if got then
				log("yellow crystal: collected")
				return true
			end
			log(("yellow crystal: nothing to collect after the avalanche (try %d of 3)"):format(attempt))
		end
		return G.count("Yellow Energy Crystal") > 0
	end

	local function getMythicalDriftwood()
		if not G.ownsRod("Mythical Rod") then buyMythicalRod() end
		-- Hasty on the Mythical Rod before heading out (Enchant Relics at the altar, at night).
		if G.rodEnchant("Mythical Rod", "enchant") ~= "Hasty" and not enchant("Mythical Rod", { "Hasty" }, "Enchant Relic", "enchant") then
			log("couldn't get Hasty on the Mythical Rod; going without it")
		end
		-- Magnet or Garbage bait at the Driftwood spot. Bait crates have both: with neither, crates are opened or bought.
		if G.baitCount("Magnet") < 1 and G.baitCount("Garbage") < 1 then
			if state.settings.buyBaitCrates then
				restockBait(true)
			else
				log("no Magnet or Garbage bait, and buying bait crates is off")
			end
		end
		fishUntil("2 Mythical Driftwood", have("Driftwood", 2, { Mutation = "Mythical" }), { rod = "Mythical Rod", baits = { "Magnet", "Garbage" }, zone = "Driftwood spot" })
	end

	-- Finds the NPC by name/tag; if that fails or the match is far from the saved spot (names aren't always what the
	-- wiki calls them: the shadowy figure is "???"), uses whoever has the nearest "Talk" prompt at the spot.
	-- With strict, only the given answers are ever picked.
	local function talkToNpc(npc, answers, strict)
		-- Next to the NPC, not on top of it (and not at all if already close).
		local npcPos, hrp = positionOf(npc), G.hrp()
		if npcPos and hrp and (hrp.Position - npcPos).Magnitude > 8 then
			local away = Vector3.new(hrp.Position.X - npcPos.X, 0, hrp.Position.Z - npcPos.Z)
			if away.Magnitude < 1 then away = Vector3.new(0, 0, 1) end
			G.teleport(npcPos + away.Unit * 4)
		end
		return G.talk(npc, answers, nil, strict)
	end

	local function talkTo(name, tag, answers, spotName, strict)
		local spot = spotName and goTo(spotName)
		local npc = G.findNpc(name, tag, spot)
		local npcPos = npc and positionOf(npc)
		if spot and (not npcPos or (npcPos - spot).Magnitude > 150) then
			local prompt = G.promptsNear(spot, 60, "talk")[1]
			local nearest = prompt and prompt:FindFirstAncestorOfClass("Model")
			if nearest then
				log(("talk: using %s, the nearest Talk prompt at %s"):format(nearest.Name, spotName))
				npc, npcPos = nearest, positionOf(nearest)
			end
		end
		if not npc then error("couldn't find " .. name .. " (check its saved location)", 0) end
		return talkToNpc(npc, answers, strict)
	end

	-- Energy Crystals and their pedestals (Northern Summit, next to Hiker #12). The game doesn't show which ones are in,
	-- so each one put in is saved (settings.placedCrystals); a placed crystal isn't fetched again.
	local function needCrystal(color)
		state.settings.placedCrystals = state.settings.placedCrystals or {}
		return not state.settings.placedCrystals[color] and G.count(color .. " Energy Crystal") < 1
	end

	-- Puts an item into whatever takes it at a saved spot: the nearest prompt there (one whose text or path has
	-- `prefer` in it, if any). It went in if the item left the inventory; if not, it's tried again with the item in hand.
	-- With mustHold (the Chaotic relic, user: it has to be held to go in), it's in hand from the first press.
	local function placeItem(spotName, item, filter, prefer, mustHold)
		local had = G.count(item, filter)
		if had < 1 then
			log(("%s: no %s to put in"):format(spotName, item))
			return false
		end
		setStatus(spotName, "putting in the " .. item)
		local spot = goTo(spotName)
		-- In hand before looking: its prompt may only show while it's held.
		if mustHold and not G.hold(item, filter) then
			log(("%s: couldn't hold the %s to put it in"):format(spotName, item))
			return false
		end
		local prompt
		waitFor(function()
			local near = G.promptsNear(spot, 15)
			for _, p in ipairs(near) do
				if prefer and (p.ActionText .. " " .. p.ObjectText .. " " .. p:GetFullName()):lower():find(prefer:lower(), 1, true) then
					prompt = p
					return true
				end
			end
			prompt = near[1]
			return prompt ~= nil
		end, 6, 0.5)
		if not prompt then
			local list = {}
			for i, p in ipairs(G.promptsNear(spot, 40)) do
				if i > 8 then break end
				list[#list + 1] = ("%s [%s | %s]"):format(p:GetFullName(), p.ActionText, p.ObjectText)
			end
			log(("%s: no prompt here; prompts within 40: %s"):format(spotName, #list > 0 and table.concat(list, "; ") or "none"))
			G.unhold()
			return false
		end
		log(("%s: %s [%s | %s]"):format(spotName, prompt:GetFullName(), prompt.ActionText, prompt.ObjectText))
		local function placed() return G.count(item, filter) < had end
		for _, holding in ipairs(mustHold and { true } or { false, true }) do
			if holding and not mustHold then G.hold(item, filter) end
			for _, how in ipairs({ "hold", "key" }) do
				G.pressPrompt(prompt, how)
				if waitFor(placed, 3, 0.3) then
					G.unhold()
					log(("%s: %s in (%s%s)"):format(spotName, item, how, holding and ", holding it" or ""))
					return true
				end
			end
		end
		G.unhold()
		return false
	end

	-- Stands where the user did for that colour and puts the crystal in its pedestal (the prompt naming the colour).
	local function placeCrystal(color)
		state.settings.placedCrystals = state.settings.placedCrystals or {}
		if state.settings.placedCrystals[color] then return true end
		if not placeItem(color .. " pedestal", color .. " Energy Crystal", nil, color) then return false end
		state.settings.placedCrystals[color] = true
		saveSettings()
		return true
	end

	-- ---- Pinion's Aria (the user's steps) -------------------------------------------------------
	-- Steps the game doesn't show are saved as they're done (settings.aria), so a restart carries on from there.
	local function ariaStep(name)
		state.settings.aria = state.settings.aria or {}
		return state.settings.aria[name] == true
	end
	local function ariaDone(name)
		state.settings.aria = state.settings.aria or {}
		state.settings.aria[name] = true
		saveSettings()
		log("Pinion's Aria: " .. name .. " done")
	end

	-- The Mysterious Songstress closest to a saved spot (she's in the music venue and up at the cloud). Only she is
	-- talked to: if she isn't near that spot, nobody is. Her answers (from the user's dialogue tree), and nothing
	-- else: "It kinda reminds me of Santa's M-" gets you punished, and the "maybe later"/"nevermind" ones go nowhere.
	local SONGSTRESS_ANSWERS = {
		"can you teach me", "how do i do that", "sure, i can go get", "where do you think", -- the musical fish
		"nope", "how am i supposed to get up there", -- the Harmonic Dove and the Hang Glider
		"yep", "got it", -- handing in the Dove, for Pinion's Aria
		"you're on", -- the Megalodon challenge
		"i love it", -- after everything
	}
	local function songstressAt(spotName)
		local spot = goTo(spotName)
		local npc
		waitFor(function()
			npc = G.findNpc("Mysterious Songstress", "MysteriousSongstress", spot)
			local pos = npc and positionOf(npc)
			return pos ~= nil and (pos - spot).Magnitude < 300
		end, 6, 0.5)
		local pos = npc and positionOf(npc)
		if not (pos and (pos - spot).Magnitude < 300) then
			log("no Songstress near " .. spotName)
			return false
		end
		talkToNpc(npc, SONGSTRESS_ANSWERS, true)
		return true
	end

	-- A plain Megalodon only (user): Ancient and Phantom Megalodons come from the same hunts but aren't the one.
	local function megalodonCatches()
		return state.caught["Megalodon"] or 0
	end

	-- Hunt events are fishing zones out at sea, in workspace.zones.fishing, looked up by name the way the NewFish5 hub's
	-- Auto Zone Event does (user: "try the event fishing first"). Its list names the Megalodon ones "MegHunt" (a hunt
	-- totem's, like its KrakenHunt and ScyllaHunt), "Megalodon", "Megalodon Ancient" and "Megalodon Phantom"; the fish
	-- zones library adds Megalodon Default and seasonal ones (Birthday, Shamrock Megalodon). Never a Kraken (user).
	-- Open water means swimming, so a raft (a part on this client only) is put on the water at the zone, and casting
	-- is done from it as usual.
	local Hunt = {} -- the Megalodon hunt helpers, in one table to stay under the 200 locals of the joined script
	Hunt.zones = { "MegHunt", "Megalodon", "Megalodon Default", "Megalodon Ancient", "Megalodon Phantom" }
	function Hunt.megalodonName(name)
		return name:find("Megalodon", 1, true) ~= nil or name:find("MegHunt", 1, true) ~= nil
	end
	function Hunt.fishingZones()
		local zones = workspace:FindFirstChild("zones")
		return zones and zones:FindFirstChild("fishing")
	end
	-- One of those zones, else any zone whose name passes match.
	local function eventZone(names, match)
		local fishing = Hunt.fishingZones()
		for _, name in ipairs(names) do
			local zone = fishing and fishing:FindFirstChild(name)
			if zone and zone:IsA("BasePart") then return zone end
		end
		for _, zone in ipairs(match and fishing and fishing:GetChildren() or {}) do
			if zone:IsA("BasePart") and match(zone.Name) then return zone end
		end
		return nil
	end

	local raft
	-- Goes straight there and stands on the raft at the hunt zone's height (the water), then puts it on the water's
	-- surface (terrain water) once that area has loaded in. Loading the area first from far away
	-- (RequestStreamAroundAsync) left the user stuck floating, 7000 studs from the hunt.
	local function standOnWater(pos)
		if not (raft and raft.Parent) then
			raft = Instance.new("Part")
			raft.Name = "Raft"
			raft.Anchored = true
			raft.Size = Vector3.new(5, 1, 5) -- small, so the bobber flies past it into the water
			raft.Transparency = 0.6
			raft.Parent = workspace
		end
		local function standAt(surface)
			raft.CFrame = CFrame.new(pos.X, surface + 0.5, pos.Z)
			local hrp = G.hrp()
			if hrp then
				hrp.CFrame = CFrame.new(pos.X, surface + 4, pos.Z)
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
		end
		standAt(pos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		params.IgnoreWater = false
		local hit
		waitFor(function()
			hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 300, pos.Z), Vector3.new(0, -800, 0), params)
			return hit ~= nil
		end, 5, 0.2)
		local surface = hit and hit.Position.Y or pos.Y
		if math.abs(surface - pos.Y) > 1 then standAt(surface) end
		log(("raft on the water at %d, %d, %d"):format(math.floor(pos.X), math.floor(surface), math.floor(pos.Z)))
	end
	local function removeRaft()
		if raft then raft:Destroy() end
		raft = nil
	end

	-- The Megalodon is fished from a boat (user: the raft didn't work). Spawning one anywhere (the quick-access boat
	-- slot) asks for a gamepass (user), so it comes out the ordinary way: talking to the Moosewood Shipwright makes
	-- the server open the shipwright menu (Boats/Open), its Spawn button is Boats/Spawn with the boat's name, and
	-- hiding the menu closes it the game's way (its Close script fires Boats/Close). Sitting in the boat, a teleport
	-- takes the boat along (user), so you sit, go to the hunt, and stand up on deck to fish.
	-- Your boats are in workspace.active.boats.<you>.
	Hunt.shipwright = Vector3.new(357, 133, 258) -- Moosewood Shipwright (world scan)
	function Hunt.boat()
		local active = workspace:FindFirstChild("active")
		local boats = active and active:FindFirstChild("boats")
		local mine = boats and boats:FindFirstChild(LP.Name)
		return mine and mine:FindFirstChildWhichIsA("Model")
	end
	-- The boat you have out, else the first one you own (alphabetically).
	function Hunt.boatName()
		local out = Hunt.boat()
		if out then return out.Name end
		local ok, name = pcall(function()
			local vessels = require(ReplicatedStorage.shared.modules.vessels)
			local owned = {}
			for n, v in pairs(vessels.library) do
				if type(v) == "table" and vessels:Has(LP, n) then owned[#owned + 1] = n end
			end
			table.sort(owned)
			return owned[1]
		end)
		return ok and name or nil
	end
	-- The driver's seat, else any seat.
	function Hunt.seat(boat)
		local any
		for _, d in ipairs(boat:GetDescendants()) do
			if d:IsA("VehicleSeat") then return d end
			if not any and d:IsA("Seat") then any = d end
		end
		return any
	end
	-- The top of the deck straight down from above its middle (not a seat: those sit you down when touched).
	function Hunt.deck(boat)
		local skip = { LP.Character }
		for _, d in ipairs(boat:GetDescendants()) do
			if d:IsA("Seat") or d:IsA("VehicleSeat") then skip[#skip + 1] = d end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = skip
		local pos = boat:GetPivot().Position
		local hit = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
		return (hit and hit.Instance:IsDescendantOf(boat)) and hit.Position or pos + Vector3.new(0, 3, 0)
	end
	function Hunt.board(boat)
		local hrp, humanoid = G.hrp(), G.humanoid()
		if not hrp then return end
		if humanoid and humanoid.Sit then humanoid.Sit = false end
		sleep(0.3)
		hrp.CFrame = CFrame.new(Hunt.deck(boat) + Vector3.new(0, 3.5, 0))
		hrp.AssemblyLinearVelocity = Vector3.zero
		sleep(0.5)
		if humanoid and humanoid.Sit then humanoid.Sit = false end
	end
	function Hunt.sit(boat)
		local seat, humanoid, hrp = Hunt.seat(boat), G.humanoid(), G.hrp()
		if not (seat and humanoid and hrp) then return false end
		if humanoid.SeatPart == seat then return true end
		hrp.CFrame = seat.CFrame + Vector3.new(0, 3, 0)
		sleep(0.3)
		pcall(function() seat:Sit(humanoid) end) -- what the game's AutoSeat does
		return waitFor(function() return humanoid.SeatPart == seat end, 3, 0.1)
	end
	-- The shipwright menu: the Moosewood Shipwright's prompt, then the boat's Spawn, then the menu closed.
	function Hunt.spawnBoat()
		local name = Hunt.boatName()
		if not name then
			log("no boat owned")
			return nil
		end
		setStatus("Megalodon", "getting the " .. name .. " out at the Moosewood Shipwright")
		G.teleport(Hunt.shipwright)
		local npc = G.findNpc("Moosewood Shipwright", nil, Hunt.shipwright)
		local prompt = npc and npc:FindFirstChildWhichIsA("ProximityPrompt", true)
		local menu
		pcall(function() menu = LP.PlayerGui.hud.safezone.shipwright end)
		if not (prompt and menu) then
			log("no Moosewood Shipwright (or its menu) to get the boat from")
			return nil
		end
		-- Open: docked at the shipwright (LastDock, which the quick-access slot also checks), or the menu showing when
		-- it wasn't before.
		local shownBefore = menu.Visible
		local function open()
			local dock = LP:GetAttribute("LastDock")
			return (dock ~= nil and dock ~= "None") or (menu.Visible and not shownBefore)
		end
		-- The shipwright talks first (user: an extra dialogue): lines are skipped and an answer about boats picked, until
		-- the menu is open. Only conversation answers are ever clicked (G.talk would also press menu buttons that
		-- mention a boat, like Purchase). The answers are logged, so a wording not covered here shows up in the log.
		if not open() then
			G.unhold()
			G.pressPrompt(prompt, "hold")
			local deadline, lastPress, lastList, clicked = os.clock() + 12, os.clock(), "", {}
			while os.clock() < deadline and not open() do
				checkStop()
				local options = G.dialogOptions()
				if #options > 0 then
					local texts = {}
					for _, o in ipairs(options) do texts[#texts + 1] = "\"" .. o.text .. "\"" end
					local list = table.concat(texts, ", ")
					if list ~= lastList then
						log("shipwright answers: " .. list)
						lastList = list
					end
					local choice
					for _, word in ipairs({ "boat", "spawn", "ship", "vessel", "browse", "show" }) do
						for _, o in ipairs(options) do
							if not choice and not clicked[o.button] and o.text:lower():find(word, 1, true) then choice = o end
						end
					end
					if choice then
						clicked[choice.button] = true
						log("shipwright: picked \"" .. choice.text .. "\"")
						if G.setIdentity then
							G.click(choice.button)
						else
							local torso = LP.Character and (LP.Character:FindFirstChild("Torso") or LP.Character:FindFirstChild("HumanoidRootPart"))
							G.pressButton(choice.button, torso and torso.Position)
						end
						sleep(1)
					else
						sleep(0.3)
					end
				else
					if LP.Character and LP.Character:FindFirstChild("dialoglink") then G.skipDialog() end
					-- Nothing started: the prompt once more.
					if os.clock() - lastPress > 4 and not (LP.Character and LP.Character:FindFirstChild("dialoglink")) then
						lastPress = os.clock()
						G.pressPrompt(prompt, "key")
					end
					sleep(0.3)
				end
			end
		end
		if not waitFor(open, 4, 0.2) then
			log(("the shipwright menu didn't open (LastDock %s, menu %s)"):format(tostring(LP:GetAttribute("LastDock")),
				tostring(menu.Visible)))
			G.closeMenus()
			return nil
		end
		local spawn = G.net("RF/Boats/Spawn")
		if spawn then pcall(spawn.InvokeServer, spawn, name) end
		menu.Visible = false
		local boat
		waitFor(function()
			boat = Hunt.boat()
			return boat ~= nil and (boat:GetPivot().Position - Hunt.shipwright).Magnitude < 300
		end, 10, 0.25)
		if not boat then log("the " .. name .. " didn't come out at the shipwright") end
		return boat
	end
	-- Sitting in it, over to pos (the boat comes along), keeping its height on the water.
	function Hunt.sail(boat, pos)
		if not Hunt.sit(boat) then
			log("couldn't sit in the " .. boat.Name)
			return false
		end
		local hrp = G.hrp()
		local pivot = boat:GetPivot().Position
		local offset = hrp.Position - pivot
		hrp.CFrame = CFrame.new(Vector3.new(pos.X, pivot.Y, pos.Z) + offset) * hrp.CFrame.Rotation
		return waitFor(function()
			local p = boat:GetPivot().Position
			return (Vector3.new(p.X, 0, p.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < 60
		end, 3, 0.1)
	end
	-- Your boat on the water at pos, with you on its deck; nil (and the raft) if that can't be done.
	function Hunt.toBoat(pos)
		local boat = Hunt.boat() or Hunt.spawnBoat()
		if boat and Hunt.sail(boat, pos) then
			removeRaft()
			Hunt.board(boat)
			log("fishing the hunt from the " .. boat.Name)
			return boat
		end
		log("no boat at the hunt; fishing from the raft")
		local humanoid = G.humanoid()
		if humanoid and humanoid.Sit then humanoid.Sit = false end
		standOnWater(pos)
		return nil
	end

	-- Where hunts turned up before (saved), looked at first: hunts may come back to the same places.
	Hunt.file = DIR .. "/hunts.json"
	function Hunt.remember(pos)
		local spots = readJson(Hunt.file) or {}
		for _, p in ipairs(spots) do
			if type(p) == "table" and (Vector3.new(p[1], p[2], p[3]) - pos).Magnitude < 300 then return end
		end
		spots[#spots + 1] = { math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z) }
		writeJson(Hunt.file, spots)
	end

	-- Fishing zones only load near you (hunt watch: a totem used at Moosewood made "Megalodon Default" at 7343, 126,
	-- 1146, 7000 studs away, and it showed up once the user was about 480 studs from it). Loading areas without moving
	-- (RequestStreamAroundAsync) didn't bring a running hunt in and left the user stuck floating, so the search flies:
	-- held in the air, a stop at each point while the zones load around the character, as they did around the user.
	-- The Megalodon only turns up around where it was first found (user), so only that area is gone over: the spots
	-- hunts were found at, then a grid within 1200 studs of the first spot, nearest first.
	Hunt.area = { center = Vector3.new(7343, 250, 1146), radius = 1200, step = 450, y = 250 }
	function Hunt.stopHover()
		if Hunt.hover then Hunt.hover:Disconnect() end
		Hunt.hover = nil
	end
	-- Hunts are announced (hunt watch): events.anno_serverEvent("A Whale Shark has been spotted near The Desolate
	-- Deep!") and a chat line with MessageType "Event" ("...has drifted into the Boreal Hollow..."). The place is an
	-- area zone (workspace.zones.player, which loads map-wide), so the announcement says where to look. Every hunt
	-- announcement is logged; one about the Megalodon sets where the search starts.
	function Hunt.areaNamed(name)
		local zones = workspace:FindFirstChild("zones")
		local areas = zones and zones:FindFirstChild("player")
		if not (areas and name) then return nil end
		name = name:gsub("^%s+", ""):gsub("[%s%.!]+$", "")
		local part = areas:FindFirstChild(name) or areas:FindFirstChild((name:gsub("^[Tt]he ", "")))
		return part and part:IsA("BasePart") and part.Position or nil
	end
	function Hunt.heard(raw)
		if type(raw) ~= "string" or not alive() then return end
		local text = raw:gsub("<[^>]+>", "")
		local place = text:match("[Nn]ear ([^!%.]+)") or text:match("[Ii]nto ([^!%.]+)") or text:match(" circling ([^!%.]+)")
			or text:match(" in ([^!%.]+)") or text:match(" at ([^!%.]+)")
		local pos = Hunt.areaNamed(place)
		-- Only announcements that name a known place or the Megalodon (others, like the Humpback breaching, repeat a lot).
		if pos or text:lower():find("megalodon", 1, true) then
			log(("hunt announced: %s%s"):format(text, pos and (" (%s at %d, %d)"):format(place, math.floor(pos.X), math.floor(pos.Z)) or ""))
		end
		if pos and text:lower():find("megalodon", 1, true) then
			Hunt.announced = { place = place, pos = pos, at = os.clock() }
		end
	end
	pcall(function()
		local events = ReplicatedStorage:WaitForChild("events", 10)
		local serverEvent = events and events:FindFirstChild("anno_serverEvent")
		if serverEvent then serverEvent.OnClientEvent:Connect(function(text) Hunt.heard(text) end) end
		local chat = events and events:FindFirstChild("chat")
		if chat then
			chat.OnClientEvent:Connect(function(message)
				if type(message) == "table" and message.MessageType == "Event" and type(message.Text) == "string"
					and not message.Text:find(" caught the ", 1, true) and Hunt.megalodonName(message.Text) then
					Hunt.heard(message.Text)
				end
			end)
		end
	end)

	function Hunt.search()
		local zone = eventZone(Hunt.zones, Hunt.megalodonName)
		if zone then return zone end
		local area = Hunt.area
		local function flat(v) return Vector3.new(v.X, 0, v.Z) end
		local stops = {}
		local function around(center, radius)
			local grid = {}
			for dx = -radius, radius, area.step do
				for dz = -radius, radius, area.step do
					if Vector3.new(dx, 0, dz).Magnitude <= radius then
						grid[#grid + 1] = Vector3.new(center.X + dx, area.y, center.Z + dz)
					end
				end
			end
			table.sort(grid, function(a, b) return (flat(a) - flat(center)).Magnitude < (flat(b) - flat(center)).Magnitude end)
			for _, p in ipairs(grid) do stops[#stops + 1] = p end
		end
		-- Where the last Megalodon announcement (within 30 minutes) said it was, first.
		local heard = Hunt.announced
		if heard and os.clock() - heard.at < 1800 then
			log(("searching near %s first (announced)"):format(heard.place))
			around(heard.pos, 900)
		end
		for _, p in ipairs(readJson(Hunt.file) or {}) do
			if type(p) == "table" then stops[#stops + 1] = Vector3.new(p[1], area.y, p[3]) end
		end
		around(area.center, area.radius)

		setStatus("Megalodon", ("looking for the hunt around where it turns up (%d stops)"):format(#stops))
		local RunService = game:GetService("RunService")
		local target
		Hunt.stopHover()
		Hunt.hover = RunService.Heartbeat:Connect(function()
			if not alive() then Hunt.stopHover() return end
			local root = G.hrp()
			if root and target then
				root.CFrame = target
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end)
		-- Zones arriving from the server (the area around a stop loading in).
		local lastArrival = 0
		local fishing = Hunt.fishingZones()
		local arrivals = fishing and fishing.ChildAdded:Connect(function() lastArrival = os.clock() end)
		local ok, result = pcall(function()
			for i, p in ipairs(stops) do
				-- Just there and a look: no RequestStreamAroundAsync (from far away it left the user stuck floating).
				-- The zones only come once the server has seen you there (about your ping), so not one frame: checked
				-- every frame, and on to the next stop once the area's zones have come in and gone quiet for 0.15 s,
				-- 0.75 s at most.
				target = CFrame.new(p)
				local arrived, z = os.clock(), nil
				while true do
					RunService.Heartbeat:Wait()
					z = eventZone(Hunt.zones, Hunt.megalodonName)
					local now = os.clock()
					if z or now - arrived > 0.75 or (lastArrival > arrived and now - lastArrival > 0.15) then break end
				end
				checkStop()
				if z then
					log(("found the Megalodon hunt flying over %d, %d (stop %d of %d)"):format(math.floor(p.X), math.floor(p.Z), i, #stops))
					return z
				end
				if i % 25 == 0 then log(("searching for the Megalodon hunt: %d of %d stops"):format(i, #stops)) end
			end
		end)
		Hunt.stopHover()
		if arrivals then arrivals:Disconnect() end
		if not ok then error(result, 0) end
		return result
	end

	-- The Megalodon (user): find the hunt, go to it, and fish it from a boat, with Pinion's Aria and the reel played out
	-- (bar 100%, progress 100%, no Super Instant: "without missing any notes"; an instant one didn't count, user). A Megalodon Hunt Totem is used when no hunt is on. A totem's hunt
	-- is taken to last 20 minutes: no second totem before then, unless the hunt was seen to end (user: a restart used
	-- the second totem while the first hunt was still out at sea).
	Hunt.totemSeconds = 20 * 60
	local function huntMegalodon(bait)
		local before = megalodonCatches()
		for _ = 1, 3 do
			local zone = eventZone(Hunt.zones, Hunt.megalodonName)
			local totems = G.count("Megalodon Hunt Totem", nil, true)
			local recent = os.time() - (tonumber(state.settings.megalodonTotemAt) or 0) < Hunt.totemSeconds
			if not zone and (recent or totems < 1) then zone = Hunt.search() end
			if not zone then
				if recent then
					log("no Megalodon hunt found, and a totem was used under 20 minutes ago: not using another yet")
					break
				end
				if totems < 1 then break end
				goTo("Driftwood spot")
				setStatus("Megalodon", "using a Megalodon Hunt Totem")
				G.useItem("Megalodon Hunt Totem")
				G.unhold()
				if waitFor(function() return G.count("Megalodon Hunt Totem", nil, true) < totems end, 5, 0.5) then
					state.settings.megalodonTotemAt = os.time()
					saveSettings()
				end
				-- The hunt can take a moment to start after the totem.
				sleep(10)
				zone = Hunt.search()
				if not zone then
					sleep(30)
					zone = Hunt.search()
				end
				if not zone then
					log("the Megalodon Hunt from the totem wasn't found anywhere on the ocean")
					break
				end
			end
			local p = zone.Position
			log(("Megalodon hunt: %s at %d, %d, %d"):format(zone.Name, math.floor(p.X), math.floor(p.Y), math.floor(p.Z)))
			Hunt.remember(p)
			local boat = Hunt.toBoat(p)
			local function flat(v) return Vector3.new(v.X, 0, v.Z) end
			local function others() return (state.caught["Ancient Megalodon"] or 0) + (state.caught["Phantom Megalodon"] or 0) end
			local othersBefore = others()
			fishUntil("a Megalodon", function()
				if megalodonCatches() > before or not zone.Parent then return true end
				if others() > othersBefore then
					othersBefore = others()
					log("caught an Ancient or Phantom Megalodon: not the plain one, still fishing")
				end
				if boat and boat.Parent then
					-- The hunt moved off: the boat comes out again there. Fell in: back on deck.
					if (flat(zone.Position) - flat(boat:GetPivot().Position)).Magnitude > 80 then
						boat = Hunt.toBoat(zone.Position)
					else
						local hrp = G.hrp()
						if hrp and hrp.Position.Y < Hunt.deck(boat).Y - 3 then Hunt.board(boat) end
					end
				else
					-- No boat: the raft follows the hunt.
					local here = raft and raft.Position or p
					if (flat(zone.Position) - flat(here)).Magnitude > 25 then standOnWater(zone.Position) end
				end
				return false
			end, { rod = "Pinion's Aria", bait = bait, zone = "None", perfect = true, minigame = true })
			if megalodonCatches() > before then break end
			-- Gone while standing on it: the hunt is over, so the next totem can be used.
			local stood = (boat and boat.Parent and boat:GetPivot().Position) or (raft and raft.Position)
			if not zone.Parent and stood and G.near(stood, 60) then
				state.settings.megalodonTotemAt = 0
				saveSettings()
			end
			log("the Megalodon Hunt ended without a Megalodon")
		end
		removeRaft()
		-- Off the boat and the boat put away (the game's own Despawn button), so nothing drags you back to it.
		local humanoid = G.humanoid()
		if humanoid and (humanoid.SeatPart or humanoid.Sit) then
			humanoid.Sit = false
			humanoid.Jump = true
			task.wait(0.4)
		end
		if Hunt.boat() then
			local despawn = G.net("RE/Boats/Despawn")
			if despawn then pcall(despawn.FireServer, despawn) end
			log("boat put away")
		end
		return megalodonCatches() > before
	end

	-- The Chaotic relic (user): an ordinary Enchant Relic with the Chaotic mutation, which the Chaotic enchant gives
	-- caught fish and relics a 12% chance of. Other relics with the mutation aren't it, and are left alone.
	local CHAOTIC = { Mutation = "Chaotic" }
	local function chaoticRelic()
		return G.count("Enchant Relic", CHAOTIC) > 0
	end

	-- The owned rod that lures fastest. In the rod data a LOWER LureSpeed is faster: the game shows 100 - LureSpeed as
	-- the Lure Speed % (Flimsy 100 shows 0%, Wisdom 45 shows 55%).
	local function fastestLureRod()
		local owned = {}
		pcall(function() owned = G.data().PlayerDataReplicator:TryIndex({ "Rods" }) or {} end)
		local best, fastest = nil, math.huge
		for name in pairs(owned) do
			local wait = tonumber((rodStats(name) or {}).LureSpeed)
			if wait and wait < fastest then best, fastest = name, wait end
		end
		return best or G.bestRod()
	end

	-- The rod for the Chaotic relic: the one picked in the Rods section when its switch is on, else the fastest lure.
	local function chaoticRelicRod()
		local chosen = state.settings.chaoticRod
		if state.settings.useChaoticRod and chosen and G.ownsRod(chosen) then return chosen end
		if state.settings.useChaoticRod then log("the chosen Chaotic relic rod isn't owned; using the fastest lure instead") end
		return fastestLureRod()
	end

	-- Ours, else an alt's, else: the fastest-luring rod gets Chaotic and fishes at the C$ farm spot until one turns up.
	local function getChaoticRelic()
		if chaoticRelic() then return true end
		if askAlts("Enchant Relic", 1, CHAOTIC) then return true end
		state.protected["Enchant Relic"] = CHAOTIC
		local rod = chaoticRelicRod()
		log("Chaotic relic rod: " .. rod)
		if G.rodEnchant(rod, "enchant") ~= "Chaotic" and not enchant(rod, { "Chaotic" }, "Enchant Relic", "enchant") then
			error("couldn't put Chaotic on the " .. rod .. " (see the log)", 0)
		end
		fishUntil("a Chaotic Enchant Relic", chaoticRelic,
			{ rod = rod, zone = "C$ farm spot", sell = true })
		return true
	end

	local function heavenlyDove()
		return G.count("Harmonic Dove", { Mutation = "Heavenly" }) > 0 or G.count("Heavenly Harmonic Dove") > 0
	end

	-- ---- the glider ring course (Pinion's Aria step 4) -----------------------------------------
	-- The green rings are the game's AboveTheClouds time trial (TimeTrialController, decompiled). Standing in its start
	-- zone at Castaways peak starts it: the server hands over the course and the client loads it a section at a time.
	-- Touching the last ring of a section (its Root has a SectionName attribute) loads the next one. Touching the end
	-- zone on the island with section 6 loaded finishes it ("Challenge complete!"). Touching ground or water anywhere
	-- else, or the HumanoidRootPart being anchored (as G.teleport does), ends it as a fail.
	-- The user's plan: up into the air, the Hang Glider out, then through the green rings only, as fast as it goes, and
	-- down at the progression's Cloud spot. The green ring of a section is its last one, the one that loads the next
	-- section (section 1's scan: only that ring is green, 88,255,88); the rest are boost rings and are skipped.
	local ringHover -- holds the character in the air while the course is flown
	local function stopRingHover()
		if ringHover then ringHover:Disconnect() end
		ringHover = nil
	end

	local function flyRingCourse()
		local RunService = game:GetService("RunService")
		local function frames(n)
			for _ = 1, n do RunService.Heartbeat:Wait() end
		end
		local trials = workspace:FindFirstChild("TimeTrials")
		local trial = trials and trials:FindFirstChild("AboveTheClouds")
		if not trial then
			log("ring course: no AboveTheClouds time trial in the world")
			return false
		end
		local controller
		pcall(function() controller = require(ReplicatedStorage.client.legacyControllers.TimeTrialController) end)
		local function loaded(name)
			local sections = trial:FindFirstChild("LoadedSections")
			return sections and sections:FindFirstChild(name)
		end
		local function active() return controller == nil or controller.ActiveTrialName ~= nil end

		-- "Challenge complete!" is the client's own line for a finished run (a local BindableEvent).
		local finished = false
		local events = ReplicatedStorage:FindFirstChild("events")
		local thought = events and events:FindFirstChild("anno_localthought")
		local listen = thought and thought:IsA("BindableEvent") and thought.Event:Connect(function(text)
			if type(text) == "string" and text:find("Challenge complete", 1, true) then finished = true end
		end)

		-- Held at a point every frame (never anchored: that counts as landing), facing along the course.
		local target
		stopRingHover()
		ringHover = RunService.Heartbeat:Connect(function()
			if not alive() then stopRingHover() return end
			local hrp = G.hrp()
			if hrp and target then
				hrp.CFrame = target
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
		end)
		local function holdAt(pos, dir)
			local flat = Vector3.new(dir.X, 0, dir.Z)
			if flat.Magnitude < 0.1 then
				local hrp = G.hrp()
				local look = hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)
				flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
			end
			target = CFrame.lookAt(pos, pos + flat.Unit)
			local hrp = G.hrp()
			if hrp then
				hrp.CFrame = target
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
		end

		-- Just in front of a ring, then through it (the rings are thin: a couple of frames on it so the touch registers).
		local function through(root)
			local dir = -root.CFrame.LookVector -- the way the ring boosts you
			local center = root.Position
			holdAt(center - dir * 3, dir)
			frames(1)
			holdAt(center, dir)
			frames(2)
			holdAt(center + dir * 3, dir)
			frames(1)
		end

		local function green(part)
			local c = part.Color
			return c.G > 0.45 and c.G > c.R * 1.3 and c.G > c.B * 1.15
		end
		local function rgb(part)
			local c = part.Color
			return ("%d,%d,%d"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
		end

		-- A section's green rings, the last one (it loads the next section) at the end. Any other green ring goes in
		-- course order: how far along it is from where the section starts towards the last ring (the Cloud for the last
		-- section). The colours are logged, to check that the green one is always the last.
		local function ringsOf(section, from, name)
			local rings, last, others = {}, nil, {}
			for _, model in ipairs(section:GetChildren()) do
				local root = model:FindFirstChild("Root")
				if root and root:IsA("BasePart") then
					if root:GetAttribute("SectionName") then
						last = root
					elseif green(root) and root.Transparency < 1 then
						rings[#rings + 1] = root
					else
						others[#others + 1] = rgb(root) .. (root.Transparency >= 1 and " (see-through)" or "")
					end
				end
			end
			local axis = (last and last.Position or G.spot("Cloud") or from) - from
			table.sort(rings, function(a, b) return (a.Position - from):Dot(axis) < (b.Position - from):Dot(axis) end)
			log(("ring course: section %s: last ring %s, %d other green, skipped %s"):format(name,
				last and rgb(last) or "none", #rings, #others > 0 and table.concat(others, " / ") or "none"))
			if last then rings[#rings + 1] = last end
			return rings, last
		end

		local function run()
			pcall(Fish.stop)
			goTo("Castaways peak")
			setStatus("Pinion's Aria", "starting the glider ring course")
			if not waitFor(function() return loaded("1") ~= nil end, 15, 0.25) then
				log("ring course: section 1 never loaded (the server didn't start the trial; is the quest on?)")
				return false
			end

			-- Up into the air while still inside the start zone (nothing ends the trial there), and the Hang Glider out.
			local hrp = G.hrp()
			if not hrp then return false end
			local startZone = trial:FindFirstChild("StartZone")
			local from = startZone and startZone.Position or hrp.Position
			holdAt(hrp.Position + Vector3.new(0, 15, 0), hrp.CFrame.LookVector)
			frames(3)
			if not G.hold("Hang Glider") then log("ring course: no Hang Glider to take out; flying the rings without it") end

			local name, passed = "1", from
			while true do
				local rings, last = ringsOf(loaded(name), from, name)
				setStatus("Pinion's Aria", ("ring course: section %s"):format(name))
				for _, root in ipairs(rings) do
					through(root)
					passed = root.Position
					if not active() then
						log("ring course: the trial ended in section " .. name)
						return false
					end
				end
				if not last then break end
				local nextName = tostring(last:GetAttribute("SectionName"))
				if not waitFor(function() return loaded(nextName) ~= nil end, 1, 0.05) then
					-- Passing through didn't register: the same touch the ring's Touched handler gets.
					log("ring course: section " .. nextName .. " didn't load from the pass; touching its ring")
					pcall(function()
						firetouchinterest(G.hrp(), last, 0)
						firetouchinterest(G.hrp(), last, 1)
					end)
					if not waitFor(function() return loaded(nextName) ~= nil end, 3, 0.1) then
						log("ring course: section " .. nextName .. " never loaded")
						return false
					end
				end
				from, name = last.Position, nextName
			end

			-- The last section is loaded: over to the progression's Cloud spot. The trial's end zone there finishes the run
			-- when it's touched, or when you land within its reach (the Cloud spot is), so it's streamed in first: a
			-- landing while it isn't there counts as a fail.
			local cloud = G.spot("Cloud")
			if not cloud then
				log("ring course: no Cloud spot saved")
				return false
			end
			local dir = cloud - passed
			dir = dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, 1)
			holdAt(cloud + Vector3.new(0, 12, 0), dir)
			pcall(function() LP:RequestStreamAroundAsync(cloud, 3) end)
			waitFor(function() return trial:FindFirstChild("EndZone") ~= nil end, 5, 0.1)
			local zone = trial:FindFirstChild("EndZone")
			if zone then
				holdAt(zone.Position, dir)
				frames(2)
				waitFor(function() return finished or not active() end, 1, 0.05)
				if not finished and active() then
					pcall(function()
						firetouchinterest(G.hrp(), zone, 0)
						firetouchinterest(G.hrp(), zone, 1)
					end)
					waitFor(function() return finished or not active() end, 1, 0.05)
				end
			else
				log("ring course: the end zone didn't stream in at the Cloud; landing there anyway")
			end
			stopRingHover()
			G.unhold()
			goTo("Cloud")
			waitFor(function() return finished or not active() end, 3, 0.1)
			return finished
		end

		local ok, result = pcall(run)
		stopRingHover()
		if listen then listen:Disconnect() end
		if not ok then
			pcall(G.unhold)
			error(result, 0)
		end
		if result then
			log("ring course: Challenge complete")
		else
			-- Out of the air so the half-done trial ends before another go (the start zone keeps it running).
			G.unhold()
			if controller and controller.ActiveTrialName then
				waitFor(function() return controller.ActiveTrialName == nil end, 15, 0.5)
				if controller.ActiveTrialName then
					goTo("XP spot")
					waitFor(function() return controller.ActiveTrialName == nil end, 5, 0.5)
				end
			end
		end
		return result
	end

