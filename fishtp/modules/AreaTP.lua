-- (Progression build) this run's session: loops and event handlers stop when it ends
local FISHTP_SESSION = getgenv().FishTPSession
-- AreaTP (KAN-FISCH / ShieldTeam hub module), deobfuscated and cleaned.
-- Builds the teleport sections: NPCs (anglers, Merlin, appraisers, plus a live scan of world.npcs), areas
-- (hardcoded zones + workspace.zones.player + world.spawns.TpSpots), coordinates, zones, players, the 20
-- balloons, and saved spots kept in saved_positions_shieldteam.json. Called with the 4 UI sections.
-- Fixed deobfuscator mistakes: the NPC scan called GetChildren("pairs") (the VM does pairs(npcs:GetChildren())),
-- and the saved-spots refresh passed nil to SetValues (the VM passes the list from getSavedList()).
-- UI text is partly Indonesian: "Teleport ke" = teleport to, Pemain = player, Posisi = position, Balon = balloon.
-- The hub also had a getMod/"[NewFish5]" module loader here that nothing called; it was dropped as dead code.

game:GetService("ReplicatedStorage") -- fetched by the hub, never used
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

return function(mainSection, savedSection, npcSection, balloonSection)
	local npcCFrames = {}

	local anglerCFrames = {
		["Angler (Moosewood)"] = CFrame.new(481, 151, 299),
		["Angler (Roslit)"] = CFrame.new(-1512, 140, 688),
		["Angler (Sunstone)"] = CFrame.new(-885, 135, -1115),
		["Angler (Terrapin)"] = CFrame.new(-153, 144, 1954),
		["Angler (Depths)"] = CFrame.new(980, -700, 1230),
		["Angler (Ancient)"] = CFrame.new(5737, 177, -57),
		["Angler (Forsaken)"] = CFrame.new(-2702, 169, 1798),
		["Angler (Crimson)"] = CFrame.new(-1069, -361, -4811),
		["Angler (Luminescent)"] = CFrame.new(-1050, -337, -4078),
		["Angler (Jungle)"] = CFrame.new(-2726, 226, -2186),
		Merlin = CFrame.new(-929, 224, -996),
		Pierre = CFrame.new(387, 133, 258),
		Halt = CFrame.new(-1319, 133, 412),
		["Appraiser (Roslit)"] = CFrame.new(-1644, 137, 727),
		["Appraiser (Moosewood)"] = CFrame.new(446, 150, 230),
		["Appraiser (Terrapin)"] = CFrame.new(-109, 157, 1956)
	}

	for k, v in pairs(anglerCFrames) do
		npcCFrames[k] = v
	end

	local function scanNpcs()
		local world = workspace:FindFirstChild("world")
		local npcs = world and world:FindFirstChild("npcs")

		if npcs then
			for _, v in pairs(npcs:GetChildren()) do
				if v:IsA("Model") then
					local HumanoidRootPart = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Head") or v.PrimaryPart

					if HumanoidRootPart then
						npcCFrames[v.Name] = HumanoidRootPart.CFrame
					end
				end
			end
		end
	end

	local npcNames = {}

	local function refreshNpcNames()
		scanNpcs()
		npcNames = {}

		for k in pairs(npcCFrames) do
			table.insert(npcNames, k)
		end

		table.sort(npcNames)
	end

	refreshNpcNames()
	local selectedNpc = nil
	selectedNpc = nil
	local npcDropdown = npcSection:AddDropdown({
		Title = "Select NPC",
		Options = npcNames,
		Default = "None",
		Callback = function(npcName)
			selectedNpc = npcName
		end
	})
	npcSection:AddButton({
		Title = "Teleport",
		Callback = function()
			if not selectedNpc then
				return
			end

			local target = npcCFrames[selectedNpc]
			local npc = workspace:FindFirstChild("world") and workspace.world:FindFirstChild("npcs")

			if npc then
				npc = npc:FindFirstChild(selectedNpc)
			end

			if npc then
				local HumanoidRootPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head") or npc.PrimaryPart

				if HumanoidRootPart then
					target = HumanoidRootPart.CFrame
				end
			end

			local canTeleport = target and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

			if canTeleport then
				LocalPlayer.Character.HumanoidRootPart.CFrame = target + Vector3.new(0, 3, 0)

				return
			end

			print("NPC location unknown or character not ready.")
		end
	})
	npcSection:AddButton({
		Title = "Refresh NPC List",
		Callback = function()
			refreshNpcNames()
			pcall(function()
				if npcDropdown.SetValues then
					npcDropdown:SetValues(npcNames)

					return
				end

				if npcDropdown.SetOptions then
					npcDropdown:SetOptions(npcNames)

					return
				end

				if npcDropdown.Refresh then
					npcDropdown:Refresh(npcNames)
				end
			end)
		end
	})
	local returnCFrame = nil
	local areaCFrames = {}

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

	local areaNames = (function()
		local names = {}
		local seen = {}

		local function addArea(name, areaCFrame)
			if not seen[name] then
				seen[name] = true
				table.insert(names, name)
				areaCFrames[name] = areaCFrame
			end
		end

		for k, v in pairs(zoneCFrames) do
			addArea(k, v)
		end

		local zones = workspace:FindFirstChild("zones")
		local playerZones = zones and zones:FindFirstChild("player")

		if playerZones then
			for _, v in pairs(playerZones:GetChildren()) do
				local zoneCFrame = v:IsA("BasePart") and v.CFrame or v:IsA("Model") and (v.PrimaryPart and v.PrimaryPart.CFrame or v:GetPivot())

				if zoneCFrame then
					addArea(v.Name, zoneCFrame)
				end
			end
		end

		local world = workspace:FindFirstChild("world")
		local spawns = world and world:FindFirstChild("spawns")
		local tpSpots = spawns and spawns:FindFirstChild("TpSpots")

		if tpSpots then
			for _, v in pairs(tpSpots:GetChildren()) do
				if v:IsA("Part") then
					addArea(v.Name, v.CFrame)
				elseif v:IsA("CFrameValue") then
					addArea(v.Name, v.Value)
				end
			end
		end

		table.sort(names)
		table.insert(names, 1, "None")

		return names
	end)()

	mainSection:AddDropdown({
		Title = "TP Area",
		Content = "Choose an area to teleport",
		Options = areaNames,
		Default = "None",
		Callback = function(areaName)
			local Character = LocalPlayer.Character

			if not Character then
				return
			end

			if areaName == "None" and returnCFrame then
				safeTeleport(Character, returnCFrame)

				return
			end

			local areaTarget = areaCFrames[areaName] or zoneCFrames[areaName]

			if not areaTarget then
				for k, v in pairs(zoneCFrames) do
					local matches = areaName:lower():find(k:lower(), 1, true) or k:lower():find(areaName:lower(), 1, true)

					if matches then
						areaTarget = v

						break
					end
				end
			end

			if areaTarget then
				returnCFrame = Character:FindFirstChild("HumanoidRootPart") and Character.HumanoidRootPart.CFrame
				safeTeleport(Character, areaTarget)
				pcall(function()
					local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")

					if HumanoidRootPart then
						HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
					end

					local Backpack = LocalPlayer:FindFirstChild("Backpack")

					if not Character:FindFirstChildOfClass("Tool") and Backpack then
						for _, child in ipairs(Backpack:GetChildren()) do
							local isRod = child:IsA("Tool") and (child.Name:lower():find("rod") or child:GetAttribute("ToolType") == "Rod")

							if isRod then
								child.Parent = Character

								return
							end
						end
					end
				end)
			end
		end
	})
	local coordTarget = nil
	coordTarget = nil
	mainSection:AddInput({
		Title = "Teleport Coordinate",
		Default = "",
		Callback = function(text)
			if text and text ~= "" then
				local numbers = {}

				for match in string.gmatch(text, "[-%d%.]+") do
					table.insert(numbers, (tonumber(match)))
				end

				if #numbers >= 3 then
					coordTarget = Vector3.new(numbers[1], numbers[2], numbers[3])
				end
			end
		end
	})
	mainSection:AddButton({
		Title = "Teleport Coords",
		Callback = function()
			local Character = LocalPlayer.Character

			if Character and coordTarget then
				safeTeleport(Character, CFrame.new(coordTarget))
			end
		end
	})

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

				for _, child in ipairs(zone:GetChildren()) do
					if child:IsA("BasePart") then
						table.insert(partsByZone[name], child)
					end
				end
			end
		end

		local player = zones:FindFirstChild("player")

		if player then
			for _, v in ipairs(player:GetChildren()) do
				addZone(v)
			end
		end

		local fishing = zones:FindFirstChild("fishing")

		if fishing then
			for _, child in ipairs(fishing:GetChildren()) do
				addZone(child)
			end
		end

		for _, child in ipairs(zones:GetChildren()) do
			if child.Name ~= "player" and child.Name ~= "fishing" then
				if child:IsA("Folder") or child:IsA("Model") then
					for _, part in ipairs(child:GetChildren()) do
						addZone(part)
					end
				elseif child:IsA("BasePart") then
					addZone(child)
				end
			end
		end

		table.sort(zoneNames)
		table.insert(zoneNames, 1, "None")

		return zoneNames, partsByZone
	end

	local zoneList, _ = scanZones()

	for k in pairs(zoneCFrames) do
		if not table.find(zoneList, k) then
			table.insert(zoneList, k)
		end
	end

	table.sort(zoneList)

	if not table.find(zoneList, "None") then
		table.insert(zoneList, 1, "None")
	end

	local function teleportToZone(zoneName)
		local Character = LocalPlayer.Character

		if not Character then
			return
		end

		if zoneName == "None" and returnCFrame then
			safeTeleport(Character, returnCFrame)

			return
		end

		returnCFrame = Character:FindFirstChild("HumanoidRootPart") and Character.HumanoidRootPart.CFrame

		if zoneCFrames[zoneName] then
			safeTeleport(Character, zoneCFrames[zoneName])

			return
		end

		for k, v in pairs(zoneCFrames) do
			local matches2 = zoneName:lower():find(k:lower(), 1, true) or k:lower():find(zoneName:lower(), 1, true)

			if matches2 then
				safeTeleport(Character, v)

				return
			end
		end

		local _, zoneParts = scanZones()
		local parts = zoneParts[zoneName]

		if parts and #parts > 0 then
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
		end
	end

	local savedZone = _G.Config.selectedZone or "None"
	local zoneDropdown = mainSection:AddDropdown({
		Title = "Teleport Zone",
		Content = "Teleport to selected zone",
		Options = zoneList,
		Default = savedZone,
		Callback = function(zone2)
			_G.Config.selectedZone = zone2
		end
	})

	if getgenv().regUIElement then
		getgenv().regUIElement(zoneDropdown, "selectedZone", function(value)
			_G.Config.selectedZone = value
		end)
	end

	local zoneButton = {
		Title = "Teleport Zone",
		Content = "Teleport to selected zone",
		Callback = function()
			if _G.Config.selectedZone and _G.Config.selectedZone ~= "None" then
				task.spawn(function()
					teleportToZone(_G.Config.selectedZone)
				end)
			end
		end
	}

	mainSection:AddButton(zoneButton)
	local selectedPlayer = "None"
	mainSection:AddDropdown({
		Title = "Teleport Player",
		Options = (function()
			local playerNames = { "None" }

			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					table.insert(playerNames, player.Name)
				end
			end

			return playerNames
		end)(),
		Default = "None",
		Callback = function(playerName)
			selectedPlayer = playerName
		end
	})
	local stopVelocity = nil

	function stopVelocity()
		local Character = LocalPlayer.Character
		local root = Character and Character:FindFirstChild("HumanoidRootPart")

		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
	local function teleportToPlayer(targetName)
		local Character = LocalPlayer.Character
		local myRoot = Character and Character:FindFirstChild("HumanoidRootPart")
		local missing = not myRoot
		local targetPlayer = Players:FindFirstChild(targetName)

		if not missing then
			missing = not targetPlayer or not targetPlayer.Character
		end

		if missing then
			return
		end

		local HumanoidRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")

		if not HumanoidRootPart then
			return
		end

		local targetCFrame = HumanoidRootPart.CFrame + Vector3.new(3, 1, 0)

		myRoot.Anchored = true
		task.wait(0.05)

		if (myRoot.Position - HumanoidRootPart.Position).Magnitude > 500 then
			myRoot.CFrame = myRoot.CFrame:Lerp(targetCFrame, 0.5)
			task.wait(0.1)
		end

		myRoot.CFrame = targetCFrame
		task.wait(0.05)
		myRoot.Anchored = false
		stopVelocity()
	end

	mainSection:AddButton({
		Title = "Teleport ke Pemain",
		Callback = function()
			if selectedPlayer ~= "None" then
				teleportToPlayer(selectedPlayer)
			end
		end
	})

	balloonSection:AddSeperator({ Title = "Ballon Teleport" })

	local function teleportToBalloon(position)
		local Character = LocalPlayer.Character

		if Character and Character:FindFirstChild("HumanoidRootPart") then
			Character.HumanoidRootPart.CFrame = CFrame.new(position)
		end
	end

	for _, v in ipairs({
		{ name = "Balon 1", pos = Vector3.new(201.9, 162, -33.7) },
		{ name = "Balon 2", pos = Vector3.new(1005, 131, -1234) },
		{ name = "Balon 3", pos = Vector3.new(-2800, 260, 1550) },
		{ name = "Balon 4", pos = Vector3.new(-1244, 131, 1594) },
		{ name = "Balon 5", pos = Vector3.new(-2001, 190, 389) },
		{ name = "Balon 6", pos = Vector3.new(-1129, 228, -1158) },
		{ name = "Balon 7", pos = Vector3.new(1237, 140, 551) },
		{ name = "Balon 8", pos = Vector3.new(2747, 142, -785) },
		{ name = "Balon 9", pos = Vector3.new(-3881, 131, 326) },
		{ name = "Balon 10", pos = Vector3.new(-1804, 188, 256) },
		{ name = "Balon 11", pos = Vector3.new(-9.5, 157, -1079) },
		{ name = "Balon 12", pos = Vector3.new(545, 295, -1887) },
		{ name = "Balon 13", pos = Vector3.new(-2015, 224, -496) },
		{ name = "Balon 14", pos = Vector3.new(506, 172, 220) },
		{ name = "Balon 15", pos = Vector3.new(1742, 141, -2481) },
		{ name = "Balon 16", pos = Vector3.new(1742, 141, -2481) },
		{ name = "Balon 17", pos = Vector3.new(106, 184, 2074) },
		{ name = "Balon 18", pos = Vector3.new(3019, -130, 2451) },
		{ name = "Balon 19", pos = Vector3.new(5934, 259, 216) },
		{ name = "Balon 20", pos = Vector3.new(-1520, 130, 2194) }
	}) do
		balloonSection:AddButton({
			Title = "Teleport ke " .. v.name,
			Callback = function()
				teleportToBalloon(v.pos)
			end
		})
	end

	local savedPositions = {}
	local spotName = "SHIELD"
	local selectedSpot = "None"
	local SAVE_FILE = "saved_positions_shieldteam.json"

	local function saveToFile()
		pcall(function()
			if writefile then
				local json = HttpService:JSONEncode(savedPositions)

				writefile(SAVE_FILE, json)
			end
		end)
	end

	savedPositions = (function()
		local ok, decoded = pcall(function()
			if isfile and isfile(SAVE_FILE) then
				local json = readfile(SAVE_FILE)

				return HttpService:JSONDecode(json)
			end

			return {}
		end)

		if ok then
			ok = type(decoded) == "table"
		end

		if ok then
			return decoded
		end

		return {}
	end)()

	local function getSavedList()
		local names2 = { "None" }

		for k in pairs(savedPositions) do
			table.insert(names2, k)
		end

		return names2
	end

	savedSection:AddInput({
		Title = "Name Spot",
		Default = spotName,
		Callback = function(newName)
			if newName and newName ~= "" then
				spotName = newName
			end
		end
	})
	local savedDropdown = nil

	local savedNames = getSavedList()
	local dropdown = savedSection:AddDropdown({
		Title = "Saved Positions",
		Content = "Select a saved position to teleport",
		Multi = false,
		Options = savedNames,
		Default = "None",
		Callback = function(choice)
			selectedSpot = choice
		end
	})

	local refreshSavedDropdown = nil
	savedDropdown = dropdown

	function refreshSavedDropdown()
		local savedList = getSavedList()
		pcall(function()
			if savedDropdown.SetValues then
				savedDropdown:SetValues(savedList)

				return
			end

			if savedDropdown.SetOptions then
				savedDropdown:SetOptions(savedList)

				return
			end

			if savedDropdown.Refresh then
				savedDropdown:Refresh(savedList)
			end
		end)
	end

	savedSection:AddButton({
		Title = "Save Position",
		Callback = function()
			if spotName and spotName ~= "" then
				local Character = LocalPlayer.Character
				local root2 = Character and Character:FindFirstChild("HumanoidRootPart")

				if root2 then
					local Position = root2.Position
					local PositionX = Position.X
					local PositionY = Position.Y
					local PositionZ = Position.Z

					savedPositions[spotName] = { X = PositionX, Y = PositionY, Z = PositionZ }
					saveToFile()
					refreshSavedDropdown()
				end
			end
		end
	})
	savedSection:AddButton({
		Title = "Teleport ke Posisi",
		Callback = function()
			if selectedSpot ~= "None" and savedPositions[selectedSpot] then
				local Character = LocalPlayer.Character
				local root3 = Character and Character:FindFirstChild("HumanoidRootPart")

				if root3 then
					local spot = savedPositions[selectedSpot]

					root3.CFrame = CFrame.new(Vector3.new(spot.X, spot.Y, spot.Z))
				end
			end
		end
	})
	savedSection:AddButton({
		Title = "Delete Selected Position",
		Callback = function()
			if selectedSpot ~= "None" and savedPositions[selectedSpot] then
				savedPositions[selectedSpot] = nil
				saveToFile()
				refreshSavedDropdown()
				selectedSpot = "None"
			end
		end
	})
end
