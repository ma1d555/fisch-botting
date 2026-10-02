	-- [Progression part 02-inventory: reading the game: items, rods, baits. The loader joins the parts in order into one scope.]
	-- ---- game ----------------------------------------------------------------------

	local G = {}

	function G.net(name) -- e.g. "RF/Rod/Equip"
		local packages = ReplicatedStorage:FindFirstChild("packages")
		local net = packages and packages:FindFirstChild("Net")
		return net and net:FindFirstChild(name)
	end

	function G.event(name)
		local events = ReplicatedStorage:FindFirstChild("events")
		return events and events:FindFirstChild(name)
	end

	local dataController
	function G.data()
		if not dataController then
			dataController = require(ReplicatedStorage.client.legacyControllers.DataController)
		end
		return dataController
	end

	local function leaderstat(name)
		local stats = LP:FindFirstChild("leaderstats")
		local value = stats and stats:FindFirstChild(name)
		return value and tonumber(value.Value) or 0
	end
	function G.level() return leaderstat("Level") end
	function G.coins() return leaderstat("C$") end

	-- Whether an item's fields (its sub table) fit a filter: a table of fields, e.g. { Mutation = "Mythical" }, or a
	-- function given the fields (G.unmutated).
	local function fits(sub, filter)
		if type(filter) == "function" then return filter(sub) == true end
		for field, value in pairs(filter or {}) do
			if sub[field] ~= value then return false end
		end
		return true
	end
	-- No mutation: what enchanting spends, so a mutated relic (the Chaotic Enchant Relic for Pinion's Aria) is kept.
	function G.unmutated(sub) return sub.Mutation == nil end

	-- Counts like the game's DataController.CountItem, reading the same inventory and storage tables directly
	-- (calling CountItem from here always came back 0).
	local function countIn(replicator, path, name, filter)
		local ok, items = pcall(function() return replicator:Index(path) end)
		if not ok or type(items) ~= "table" then return 0 end
		local n = 0
		for _, item in pairs(items) do
			if type(item) == "table" and (not name or item.name == name) then
				local sub = item.sub or {}
				if fits(sub, filter) then n = n + (tonumber(sub.Stack) or 1) end
			end
		end
		return n
	end

	function G.count(name, filter, inventoryOnly)
		local ok, n = pcall(function()
			local data = G.data()
			local total = countIn(data.InventoryReplicator, { "Inventory" }, name, filter)
			if not inventoryOnly and data.StorageReplicator then
				total = total + countIn(data.StorageReplicator, { "Storage" }, name, filter)
			end
			return total
		end)
		return ok and n or 0
	end

	-- Favourites every matching inventory item (Backpack/Favourite, like the backpack's favourite button). The
	-- game's Sell All, which the hub's AutoSell uses, skips favourited items. Returns false if some couldn't be.
	function G.favourite(name, filter)
		local remote = G.net("RE/Backpack/Favourite")
		local ok, all = pcall(function()
			local done = true
			for key, item in pairs(G.data().InventoryReplicator:Index({ "Inventory" })) do
				local sub = item.sub or {}
				local match = item.name == name
				for field, value in pairs(filter or {}) do
					if sub[field] ~= value then match = false end
				end
				if match and not sub.Favourited then
					if remote then
						remote:FireServer(key, true)
						log("favourited " .. name .. " so it isn't sold")
					else
						done = false
					end
				end
			end
			return done
		end)
		return ok and all
	end

	-- The inventory key of the first matching item (trades and some remotes take the key, not the name).
	function G.itemKey(name, filter)
		local ok, key = pcall(function()
			for k, item in pairs(G.data().InventoryReplicator:Index({ "Inventory" })) do
				if item.name == name and fits(item.sub or {}, filter) then return k end
			end
		end)
		return ok and key or nil
	end

	function G.rod(name)
		local ok, entry = pcall(function() return G.data().PlayerDataReplicator:TryIndex({ "Rods", name }) end)
		return ok and entry or nil
	end
	function G.ownsRod(name) return G.rod(name) ~= nil end
	function G.rodEnchant(name, slot) -- slot "enchant" or "secondaryEnchant"
		local entry = G.rod(name)
		return entry and entry[slot] or nil
	end

	local function statsFolder()
		local all = workspace:FindFirstChild("PlayerStats")
		local mine = all and all:FindFirstChild(LP.Name)
		local t = mine and mine:FindFirstChild("T")
		local inner = t and t:FindFirstChild(LP.Name)
		return inner and inner:FindFirstChild("Stats")
	end
	-- The game's active quests: workspace.PlayerStats.<you>.T.<you>.QuestActive, one child per quest id (the quest log
	-- reads the same folder). Nil while it can't be read.
	function G.activeQuests()
		local all = workspace:FindFirstChild("PlayerStats")
		local mine = all and all:FindFirstChild(LP.Name)
		local t = mine and mine:FindFirstChild("T")
		local inner = t and t:FindFirstChild(LP.Name)
		return inner and inner:FindFirstChild("QuestActive")
	end
	function G.questActive(id)
		local quests = G.activeQuests()
		return quests ~= nil and quests:FindFirstChild(id) ~= nil
	end
	-- An active quest's values (name=value under its folder), for the log: what its progress looks like.
	function G.questInfo(id)
		local quests = G.activeQuests()
		local quest = quests and quests:FindFirstChild(id)
		if not quest then return "not active" end
		local parts = {}
		for _, d in ipairs(quest:GetDescendants()) do
			if d:IsA("ValueBase") then parts[#parts + 1] = d.Name .. "=" .. tostring(d.Value) end
		end
		return #parts > 0 and table.concat(parts, " ") or "active, no values"
	end

	function G.equippedRod()
		local stats = statsFolder()
		local rod = stats and stats:FindFirstChild("rod")
		return rod and rod.Value or nil
	end

	local rodLibrary
	local function rodStats(name)
		if not rodLibrary then
			pcall(function() rodLibrary = require(ReplicatedStorage.shared.modules.library.rods) end)
		end
		return rodLibrary and rodLibrary[name]
	end

	-- The owned rod that fishes best for levels and C$: luck first (rarer, pricier fish), then what helps land them.
	-- The Tryhard Rod only counts once it has the enchant it needs to work.
	function G.bestRod()
		local owned = {}
		pcall(function() owned = G.data().PlayerDataReplicator:TryIndex({ "Rods" }) or {} end)
		local best, bestScore = nil, -math.huge
		for name, entry in pairs(owned) do
			local stats = rodStats(name)
			local usable = name ~= "Tryhard Rod" or (type(entry) == "table" and (entry.enchant == "Herculean" or entry.enchant == "Controlled"))
			if stats and usable then
				local score = (tonumber(stats.Luck) or 0) + (tonumber(stats.Resilience) or 0) + (tonumber(stats.Control) or 0) * 200
				if score > bestScore then best, bestScore = name, score end
			end
		end
		return best
	end

	function G.equipRod(name)
		if not name then return false end
		if G.equippedRod() == name then return true end
		if not G.ownsRod(name) then
			log("can't equip " .. name .. ": not owned")
			return false
		end
		local remote = G.net("RF/Rod/Equip")
		if remote then pcall(remote.InvokeServer, remote, name) end
		local ok = waitFor(function() return G.equippedRod() == name end, 8)
		log((ok and "equipped " or "couldn't equip ") .. name)
		return ok
	end

	-- Baits aren't inventory items. Stats.bait holds the equipped one, and its children bait_<Name_With_Underscores>
	-- hold how many of each you have (the equipment menu reads them the same way).
	local function baitValue()
		local stats = statsFolder()
		return stats and stats:FindFirstChild("bait")
	end

	function G.equippedBait()
		local value = baitValue()
		local name = value and value.Value
		return (name and name ~= "" and name ~= "None") and name or nil
	end

	function G.baitCounts()
		local out = {}
		local value = baitValue()
		for _, child in ipairs(value and value:GetChildren() or {}) do
			local name = child.Name:match("^bait_(.+)$")
			if name and tonumber(child.Value) then out[(name:gsub("_", " "))] = tonumber(child.Value) end
		end
		return out
	end

	function G.baitCount(name)
		return G.baitCounts()[name] or 0
	end

	function G.equipBait(name)
		if G.equippedBait() == name then return end
		local remote = G.net("RE/Bait/Equip")
		if remote then pcall(remote.FireServer, remote, name) end
		log("bait: " .. name)
	end

	-- Baits kept for the steps that need them.
	local RESERVED_BAITS = { Magnet = true, Garbage = true, ["Shark Head"] = true, ["Tryhard Worm"] = true }

	-- Puts on the bait you have the most of, but only when none is on or the one on has run out: a bait you
	-- picked yourself stays on.
	-- Returns whether a bait is on afterwards (false: nothing usable left).
	function G.autoBait()
		local current = G.equippedBait()
		local counts = G.baitCounts()
		if current and (counts[current] == nil or counts[current] > 0) then return true end
		local best, most = nil, 0
		for name, n in pairs(counts) do
			if not RESERVED_BAITS[name] and n > most then best, most = name, n end
		end
		if best then G.equipBait(best) end
		return best ~= nil
	end

