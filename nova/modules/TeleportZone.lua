-- (Progression build) this run's session: loops and event handlers stop when it ends
local NOVA_SESSION = getgenv().NovaSession
-- TeleportZone (Nova module), deobfuscated and cleaned.
-- Teleports to a zone by name: hardcoded CFrames, else a fuzzy name match, else the first part of that zone in
-- workspace.zones with a raycast down. GetZoneList merges the scanned and hardcoded zone names.

local function safeTeleport(character, cframe)
	if not character or not cframe then
		return
	end

	pcall(function()
		local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local Humanoid = character:FindFirstChildOfClass("Humanoid")

		if HumanoidRootPart then
			HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			HumanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

			if Humanoid then
				Humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end

			character:PivotTo(cframe)
			task.wait(0.02)
			HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		end
	end)
end
local LocalPlayer = game:GetService("Players").LocalPlayer
local returnCFrame
local function scanZones()
	local zones = workspace:FindFirstChild("zones")

	if not zones then
		return { "None" }, {}
	end

	local zoneNames = {}
	local partsByZone = {}

	local function addZone(zone)
		if not zone then
			return
		end

		local name = zone.Name

		if not partsByZone[name] then
			partsByZone[name] = {}
			table.insert(zoneNames, name)
		end

		if zone:IsA("BasePart") then
			table.insert(partsByZone[name], zone)

			return
		end

		if zone:IsA("Model") or zone:IsA("Folder") then
			if zone:IsA("Model") and zone.PrimaryPart then
				table.insert(partsByZone[name], zone.PrimaryPart)
			end

			for _, v in ipairs(zone:GetChildren()) do
				if v:IsA("BasePart") then
					table.insert(partsByZone[name], v)
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

	for _, v in ipairs(zones:GetChildren()) do
		if v.Name ~= "player" and v.Name ~= "fishing" then
			if v:IsA("Folder") or v:IsA("Model") then
				for _, child in ipairs(v:GetChildren()) do
					addZone(child)
				end
			elseif v:IsA("BasePart") then
				addZone(v)
			end
		end
	end

	table.sort(zoneNames)
	table.insert(zoneNames, 1, "None")

	return zoneNames, partsByZone
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
	TeleportToZone = function(zoneName)
		local Character = LocalPlayer.Character
		if not Character then
			return
		end
		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		if not HumanoidRootPart then
			return
		end
		if zoneName == "None" and returnCFrame then
			safeTeleport(Character, returnCFrame)

			return
		end
		returnCFrame = HumanoidRootPart.CFrame
		if zoneCFrames[zoneName] then
			safeTeleport(Character, zoneCFrames[zoneName])

			return
		end
		for k, v in pairs(zoneCFrames) do
			local matches = zoneName:lower():find(k:lower(), 1, true) or k:lower():find(zoneName:lower(), 1, true)

			if matches then
				safeTeleport(Character, v)

				return
			end
		end
		local _, zoneParts = scanZones()
		local parts = zoneParts[zoneName]
		if not parts or #parts == 0 then
			warn("[TeleportZone] Zone not found: " .. tostring(zoneName))

			return
		end
		local landing
		local firstPart = parts[1]
		if firstPart then
			local Position = firstPart.Position
			local raycastParams = RaycastParams.new()

			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = { Character }
			raycastParams.IgnoreWater = false

			local raycastResult = workspace:Raycast(Vector3.new(Position.X, Position.Y + 500, Position.Z), Vector3.new(0, -1000, 0), raycastParams)

			landing = if not raycastResult then firstPart.CFrame + Vector3.new(0, 4, 0) else CFrame.new(Position.X, raycastResult.Position.Y + 4, Position.Z)
		end
		if landing then
			safeTeleport(Character, landing)
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

		return zoneList
	end
}
