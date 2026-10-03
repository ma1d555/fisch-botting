-- (Progression build) this run's session: loops and event handlers stop when it ends
local NOVA_SESSION = getgenv().NovaSession
-- TeleportArea (Nova module), deobfuscated and cleaned.
-- Teleports to fishing zones (hardcoded CFrames, else name match, else the first zone part with a raycast down to
-- land or water) and equips a rod. A background loop puts you back on your boat or on the spot when you fall
-- below it or swim in deep water. The hub also had a Rowboat buy/spawn helper here (Moosewood Shipwright,
-- RF/Boats/*) that nothing called; it was dropped as dead code.

local waterCacheTime = nil
local Players = game:GetService("Players")
game:GetService("RunService") -- fetched by the hub, never used
local LocalPlayer = Players.LocalPlayer
local me = nil
me = LocalPlayer
local returnCFrame = nil
local fishingSpot = nil
task.spawn(function()
	while getgenv().NovaSession == NOVA_SESSION do
		task.wait(0.5)
		pcall(function()
			if fishingSpot then
				local Character = me.Character
				local humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
				local root = Character and Character:FindFirstChild("HumanoidRootPart")

				if humanoid and root then
					local active = workspace:FindFirstChild("active")
					local boat = active and active:FindFirstChild("boats")

					if boat then
						boat = boat:FindFirstChild(me.Name)
					end

					if boat then
						boat = boat:FindFirstChild("Rowboat") or boat:FindFirstChildOfClass("Model")
					end

					if boat then
						local Pivot = boat:GetPivot()

						if root.Position.Y < Pivot.Y - 2.5 then
							root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
							humanoid:ChangeState(Enum.HumanoidStateType.Running)
							root.CFrame = Pivot + Vector3.new(0, 5, 0)
							warn("[TeleportArea] Player fell below boat! Teleporting back onto deck.")

							return
						end
					elseif humanoid:GetState() == Enum.HumanoidStateType.Swimming and root.Position.Y < fishingSpot.Y - 5 then
						root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						humanoid:ChangeState(Enum.HumanoidStateType.Running)
						root.CFrame = fishingSpot + Vector3.new(0, 5, 0)
						warn("[TeleportArea] Swimming in deep water! Teleporting back to spot.")
					end
				end
			end
		end)
	end
end)
local WATER_CACHE_SECONDS = nil
local waterParts = nil
waterCacheTime = 0
WATER_CACHE_SECONDS = 15
local function getWaterParts()
	local timestamp = tick()
	if waterParts and timestamp - waterCacheTime < WATER_CACHE_SECONDS then
		local alive = {}

		for _, v in ipairs(waterParts) do
			if v and v.Parent then
				table.insert(alive, v)
			end
		end

		return alive
	end
	local Terrain = workspace.Terrain
	local collectWater
	waterParts = { Terrain }
	waterCacheTime = timestamp
	function collectWater(parent, depth)
		if depth > 4 then
			return
		end

		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("BasePart") then
				local name = child.Name:lower()
				local isWater = name:match("water") or name:match("pool") or name:match("ocean") or name:match("lake") or name:match("river") or name:match("sea") or parent.Name:lower():find("fishing")

				if isWater then
					table.insert(waterParts, child)
				end
			elseif child:IsA("Model") or child:IsA("Folder") then
				collectWater(child, depth + 1)
			end
		end
	end
	local world = workspace:FindFirstChild("world")
	local map = world and world:FindFirstChild("map")
	if map then
		pcall(collectWater, map, 0)
	end
	local zones = workspace:FindFirstChild("zones")
	if zones then
		local player = zones:FindFirstChild("player")

		if player then
			pcall(collectWater, player, 0)
		end

		local fishing = zones:FindFirstChild("fishing")

		if fishing then
			pcall(collectWater, fishing, 0)
		end
	end

	return waterParts
end
local function scanZones()
	local zones = workspace:FindFirstChild("zones")

	if not zones then
		return {}, {}
	end

	local partsByZone = {}

	local function add(zoneName, part)
		if not partsByZone[zoneName] then
			partsByZone[zoneName] = {}
		end

		table.insert(partsByZone[zoneName], part)
	end
	local function addZone(zone)
		if not zone then
			return
		end

		if zone:IsA("BasePart") then
			add(zone.Name, zone)

			return
		end

		if zone:IsA("Model") or zone:IsA("Folder") then
			if zone:IsA("Model") and zone.PrimaryPart then
				add(zone.Name, zone.PrimaryPart)
			end

			for _, child in ipairs(zone:GetChildren()) do
				if child:IsA("BasePart") then
					add(zone.Name, child)
				end
			end
		end
	end

	local player = zones:FindFirstChild("player")

	if player then
		for _, child in ipairs(player:GetChildren()) do
			addZone(child)
		end
	end

	local fishing = zones:FindFirstChild("fishing")

	if fishing then
		for _, v in ipairs(fishing:GetChildren()) do
			addZone(v)
		end
	end

	for _, child in ipairs(zones:GetChildren()) do
		if child.Name ~= "player" and child.Name ~= "fishing" then
			if child:IsA("Folder") or child:IsA("Model") then
				for _, v in ipairs(child:GetChildren()) do
					addZone(v)
				end
			elseif child:IsA("BasePart") then
				addZone(child)
			end
		end
	end

	local zoneNames = {}

	for k in pairs(partsByZone) do
		table.insert(zoneNames, k)
	end

	table.sort(zoneNames)

	return zoneNames, partsByZone
end
local function setAnchored(anchored)
	local Character = me.Character

	if Character then
		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")

		if HumanoidRootPart then
			HumanoidRootPart.Anchored = anchored
		end
	end
end
local function equipRod()
	local Backpack = me.Backpack
	local Character = me.Character

	if not Character then
		return
	end

	for _, v in ipairs(Backpack:GetChildren()) do
		local isRod = v:IsA("Tool") and (v.Name:find("Rod") or v.Name:find("Fishing"))

		if isRod then
			Character.Humanoid:EquipTool(v)

			return
		end
	end
end

local zoneCFrames = {
	Moosewood = CFrame.new(380, 134, 235),
	["Roslit Bay"] = CFrame.new(-1475, 133, 680),
	["Roslit Volcano"] = CFrame.new(-1930, 165, 310),
	["Sunstone Island"] = CFrame.new(-935, 132, -1125),
	["Terrapin Island"] = CFrame.new(-185, 134, 1940),
	["Snowcap Island"] = CFrame.new(2625, 135, 2370),
	["Snowcap Cave"] = CFrame.new(2710, 140, 2480),
	Snowburrow = CFrame.new(2600, 135, 2400),
	["Mushgrove Swamp"] = CFrame.new(2450, 131, -730),
	["Forsaken Shores"] = CFrame.new(-2425, 135, 1555),
	["Forsaken Veil"] = CFrame.new(-2620, 133, 1540),
	["Ancient Isle"] = CFrame.new(5850, 135, 320),
	["Ancient Archives"] = CFrame.new(5740, 135, 420),
	Vertigo = CFrame.new(-105, -515, 1070),
	Aether = CFrame.new(-110, -500, 1040),
	["The Depths"] = CFrame.new(990, -710, 1240),
	["Desolate Deep"] = CFrame.new(-1650, -215, -2850),
	["Desolate Pocket"] = CFrame.new(-1650, -215, -2850),
	["Brine Pool"] = CFrame.new(-1800, -140, -3300),
	["Keepers Altar"] = CFrame.new(1300, -805, -280),
	["Crystal Cove"] = CFrame.new(1364, -612, 2472),
	["The Arch"] = CFrame.new(1000, 125, -1250),
	["Statue of Sovereignty"] = CFrame.new(45, 133, -1010),
	["Earmark Island"] = CFrame.new(1230, 125, 570),
	["Harvesters Spike"] = CFrame.new(-1260, 134, 1570),
	["Crimson Cavern"] = CFrame.new(-1035, -360, -4800),
	["Luminescent Cavern"] = CFrame.new(-1013, -313, -4038),
	["Birch Cay"] = CFrame.new(1700, 125, -2500),
	["Haddock Rock"] = CFrame.new(-530, 125, -420),
	["Grand Reef"] = CFrame.new(-3530, 130, 550),
	Atlantis = CFrame.new(-4300, -580, 1800),
	["Boreal Pines"] = CFrame.new(21400, 135, 4123),
	["Northern Expedition"] = CFrame.new(20000, 133, 5300),
	Drylands = CFrame.new(-23525, 2630, -5750),
	["Treasure Island"] = CFrame.new(8582, 175, -17304),
	["Everturn Forest"] = CFrame.new(2365, 130, -2330),
	Tidefall = CFrame.new(3223, 130, 850),
	["Scoria Reach"] = CFrame.new(-4781, 138, -1378),
	["Lost Jungle"] = CFrame.new(-2680, 154, -2078),
	["Castaway Cliffs"] = CFrame.new(690, 135, -1693),
	["Wrath of Olympus"] = CFrame.new(-4265, -1117, 1825),
	["Trade Plaza"] = CFrame.new(535, 82, 775),
	["Underground Music Venue"] = CFrame.new(2015, -645, 2460),
	["Carrot Garden"] = CFrame.new(415, 133, 275),
	["Oil Rig"] = CFrame.new(-2450, 135, -1450),
	["Shady Bazaar"] = CFrame.new(990, -710, 1240),
	["Personal Aquarium"] = CFrame.new(3699, 4252, 2999),
	["Cursed Isle"] = CFrame.new(1860, 135, 1210),
	Waveborne = CFrame.new(360, 90, 780),
	["Pine Shoals"] = CFrame.new(1165, 80, 480),
	["Netter's Haven"] = CFrame.new(-640, 85, 1030),
	["The Deep"] = CFrame.new(-194, 130, -4669),
	["Mariana's Veil"] = CFrame.new(-1500, 125, 530),
	["Isle of New Beginnings"] = CFrame.new(-300, 83, -380),
	Lushgrove = CFrame.new(1133, 105, -560),
	Emberreach = CFrame.new(2390, 83, -490),
	["The Cursed Shores"] = CFrame.new(-235, 85, 1930),
	["Cults Curse"] = CFrame.new(655, 2130, 16984),
	["Azure Lagoon"] = CFrame.new(1310, 80, 2113),
	["Gilded Arch"] = CFrame.new(450, 90, 2850)
}
return {
	TeleportToZone = function(targetZone)
		local Character = me.Character
		if not Character then
			return
		end
		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		if not HumanoidRootPart then
			return
		end
		if targetZone == "None" and returnCFrame then
			fishingSpot = nil
			HumanoidRootPart.CFrame = returnCFrame
			setAnchored(false)

			return
		end
		returnCFrame = HumanoidRootPart.CFrame
		if zoneCFrames[targetZone] then
			local target = zoneCFrames[targetZone]

			HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
			HumanoidRootPart.CFrame = target
			fishingSpot = target
			setAnchored(false)
			equipRod()

			return
		end
		for k, v in pairs(zoneCFrames) do
			local matches = targetZone:lower():find(k:lower(), 1, true) or k:lower():find(targetZone:lower(), 1, true)

			if matches then
				HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
				HumanoidRootPart.CFrame = v
				fishingSpot = v
				setAnchored(false)
				equipRod()

				return
			end
		end
		local _, zoneParts = scanZones()
		local parts = zoneParts[targetZone]
		if not parts or #parts == 0 then
			warn("[TeleportArea] Zone not found: " .. tostring(targetZone))

			return
		end
		local firstPart = parts[1]
		local landing
		if firstPart then
			local Position = firstPart.Position
			local water = getWaterParts()
			local raycastParams = RaycastParams.new()

			raycastParams.FilterType = Enum.RaycastFilterType.Include
			raycastParams.FilterDescendantsInstances = water
			raycastParams.IgnoreWater = false

			local raycastResult = workspace:Raycast(Vector3.new(Position.X, Position.Y + 500, Position.Z), Vector3.new(0, -1000, 0), raycastParams)

			landing = if not raycastResult then firstPart.CFrame + Vector3.new(0, 4, 0) else CFrame.new(Position.X, raycastResult.Position.Y + 4, Position.Z)
		end
		if landing then
			HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
			HumanoidRootPart.CFrame = landing
			fishingSpot = landing
			setAnchored(false)
			equipRod()
		end
	end,
	GetZoneList = function()
		local zoneList, _ = scanZones()

		for k in pairs(zoneCFrames) do
			if not table.find(zoneList, k) then
				table.insert(zoneList, k)
			end
		end

		table.sort(zoneList)
		table.insert(zoneList, 1, "None")

		return zoneList
	end,
	GetFishingZones = scanZones
}
