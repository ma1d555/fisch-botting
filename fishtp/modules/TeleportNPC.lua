-- (Progression build) this run's session: loops and event handlers stop when it ends
local FISHTP_SESSION = getgenv().FishTPSession
-- TeleportNPC (KAN-FISCH / ShieldTeam hub module), deobfuscated and cleaned.
-- TP spots from world.spawns.TpSpots and the 20 balloon positions; "None" returns to where you were.
-- Fixed deobfuscator mistake: the spot scan called GetChildren("pairs") (the VM does pairs(tpSpots:GetChildren())).

local LocalPlayer = game:GetService("Players").LocalPlayer
local returnCFrame
local tpSpotCFrames = {}
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
local function getTpSpotList()
	local world = workspace:FindFirstChild("world")
	local spawns = world and world:FindFirstChild("spawns")
	local tpSpots = spawns and spawns:FindFirstChild("TpSpots")

	if not tpSpots then
		return { "None" }
	end

	local names = {}

	for _, v in pairs(tpSpots:GetChildren()) do
		if v:IsA("Part") or v:IsA("CFrameValue") then
			table.insert(names, v.Name)

			if v:IsA("Part") then
				tpSpotCFrames[v.Name] = v.CFrame
			elseif v:IsA("CFrameValue") then
				tpSpotCFrames[v.Name] = v.Value
			end
		end
	end

	table.sort(names)
	table.insert(names, 1, "None")

	return names
end

local balloonSpots = {
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
}

return {
	TeleportTo = function(spotName)
		local Character = LocalPlayer.Character

		if not Character then
			return
		end

		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")

		if not HumanoidRootPart then
			return
		end

		if spotName == "None" and returnCFrame then
			safeTeleport(Character, returnCFrame)

			return
		end

		local target = tpSpotCFrames[spotName]

		if target then
			returnCFrame = HumanoidRootPart.CFrame
			safeTeleport(Character, target)
		end
	end,
	TeleportToCoords = function(x, y, z)
		local Character = LocalPlayer.Character

		if Character then
			safeTeleport(Character, CFrame.new(x, y, z))
		end
	end,
	TeleportToBalloon = function(index)
		local spot = balloonSpots[index]

		if not spot then
			return
		end

		local Character = LocalPlayer.Character

		if Character then
			safeTeleport(Character, CFrame.new(spot.pos))
		end
	end,
	GetTpSpotList = function()
		return getTpSpotList()
	end,
	GetBalloonList = function()
		local balloonNames = {}

		for _, v in ipairs(balloonSpots) do
			table.insert(balloonNames, v.name)
		end

		return balloonNames
	end,
	BalloonSpots = balloonSpots,
	SafeTP = safeTeleport
}
