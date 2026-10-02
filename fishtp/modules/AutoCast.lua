-- (Progression build) this run's session: loops and event handlers stop when it ends
local FISHTP_SESSION = getgenv().FishTPSession
-- AutoCast (KAN-FISCH / ShieldTeam hub module), deobfuscated and cleaned.
-- Casting loop on Heartbeat: IDLE -> cast via RF/FishingRod/Cast:InvokeServer(power, perfect) -> CASTING until the
-- bobber appears -> WAITING. With InstantCast it PivotTo()s the bobber onto the nearest water (Carrot Secret pool,
-- terrain-water raycasts ahead, then a ring search). Drops a bobber stuck for 4s via events.drop_bobber.
-- Exposes _G.InstantTeleportBobber, _G.GetTargetPosition and _G.ResetAutoCastState. Returns the on/off setter.

local bobber = nil
local Players = game:GetService("Players")
local cachedFrom = nil
local RunService = game:GetService("RunService")
local bobberOut = nil

local LocalPlayer = Players.LocalPlayer
local castRemote = nil
local heartbeatConnection = nil
local cachedTarget = nil
local bobberConnection = nil
local STATE_IDLE = 1
local STATE_CASTING = 2
local STATE_WAITING = 3
local state = STATE_IDLE
local lastTick = 0
local lastCast = 0
local bobberLandedAt = 0
local bobberTarget = nil
local unusedFlag = false
bobberOut = false
bobberTarget = nil
bobber = nil
local TICK_INTERVAL = 0.01
cachedFrom = nil
cachedTarget = nil
local function getTargetPosition(fromRoot, _)
	local root = fromRoot or LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local Position = root.Position
	local cacheValid = cachedFrom and cachedTarget and (Position - cachedFrom).Magnitude < 2
	if cacheValid then
		return cachedTarget
	end
	local carrotSecret = workspace:FindFirstChild("world") and workspace.world:FindFirstChild("map") and workspace.world.map:FindFirstChild("Carrot Secret")
	if carrotSecret then
		local closestDist = math.huge
		local closestMesh
		for _, child in ipairs(carrotSecret:GetChildren()) do
			local pool = child:FindFirstChild("Meshes/CarrotPool_Cube.001 (1)")

			if pool and pool:IsA("MeshPart") then
				local dist = (Position - pool.Position).Magnitude

				if dist < closestDist then
					closestDist = dist
					closestMesh = pool
				end
			end
		end
		if closestMesh and closestDist < 50 then
			return CFrame.new(closestMesh.Position - Vector3.new(0, 3, 0))
		end
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { workspace.Terrain }
	raycastParams.IgnoreWater = false
	local rayY = Position.Y + 50
	local head = root.Parent and root.Parent:FindFirstChild("Head")
	local look = root.CFrame.LookVector
	for _, distance in ipairs({ 10, 15, 20, 25, 30, 35, 45 }) do
		local ahead = Position + look * distance
		local rayOrigin = Vector3.new(ahead.X, rayY, ahead.Z)
		local raycastResult = workspace:Raycast(rayOrigin, Vector3.new(0, -300, 0), raycastParams)
		local isWater = raycastResult and raycastResult.Instance:IsA("Terrain") and raycastResult.Material == Enum.Material.Water

		if isWater then
			return CFrame.new(raycastResult.Position - Vector3.new(0, 3, 0))
		end
	end
	local bestWaterPos
	local bestRadius = math.huge
	for i = 0, 23 do
		local pi = math.pi
		local angle = i / 24 * (pi * 2)
		local dirX = math.cos(angle)
		local dirZ = math.sin(angle)

		for _, radius in ipairs({ 8, 12, 16, 22, 30, 40 }) do
			local x = Position.X + dirX * radius
			local z = Position.Z + dirZ * radius
			local raycastResult = workspace:Raycast(Vector3.new(x, rayY, z), Vector3.new(0, -300, 0), raycastParams)
			local isWater2 = raycastResult and raycastResult.Instance:IsA("Terrain") and raycastResult.Material == Enum.Material.Water

			if isWater2 then
				if not (radius < bestRadius) then
					break
				end

				bestRadius = radius
				bestWaterPos = raycastResult.Position

				break
			end
		end
	end
	-- closestMesh/closestDist below are GLOBALS (always nil): the hub's locals of those names ended with the
	-- Carrot Secret block above, which already returned for a pool within 50 studs. So this always takes the
	-- best water hit, else 10 studs ahead of the head and 11 down. Kept as the hub wrote it.
	local targetPos
	if closestMesh and closestDist < 50 then
		targetPos = closestMesh.Position - Vector3.new(0, 3, 0)
	elseif bestWaterPos then
		targetPos = bestWaterPos - Vector3.new(0, 3, 0)
	else
		targetPos = (head and head.Position or Position) + look * 10 - Vector3.new(0, 11, 0)
	end
	cachedFrom = Position
	cachedTarget = CFrame.new(targetPos)

	return cachedTarget
end
local function teleportBobber(bobberPart, target, root2)
	if not bobberPart or not bobberPart.Parent then
		return target
	end

	if not root2 then
		root2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	end

	local targetCFrame = target or getTargetPosition(root2, bobberPart)

	if not targetCFrame then
		return target
	end

	pcall(function()
		bobberPart:PivotTo(targetCFrame)
	end)

	return targetCFrame
end
_G.InstantTeleportBobber = teleportBobber
_G.GetTargetPosition = getTargetPosition
local function getCastRemote()
	if castRemote and castRemote.Parent then
		return castRemote
	end

	pcall(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local packages = ReplicatedStorage:FindFirstChild("packages")
		local net = packages and packages:FindFirstChild("Net")

		if net then
			castRemote = net:FindFirstChild("RF/FishingRod/Cast")
		end

		if not castRemote then
			castRemote = ReplicatedStorage:WaitForChild("packages", 5):WaitForChild("Net", 5):WaitForChild("RF/FishingRod/Cast", 5)
		end
	end)

	return castRemote
end
local function getRod(character)
	if not character then
		return nil
	end
	local rodName
	pcall(function()
		rodName = workspace.PlayerStats[LocalPlayer.Name].T[LocalPlayer.Name].Stats.rod.Value
	end)
	if rodName and rodName ~= "" then
		local rod = character:FindFirstChild(rodName)

		if rod then
			return rod
		end
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end

	return nil
end
local function resetState(clearCastTime)
	state = STATE_IDLE
	unusedFlag = false
	bobberOut = false
	bobberTarget = nil
	bobberLandedAt = 0

	if clearCastTime then
		lastCast = 0
	end

	bobber = nil

	if bobberConnection then
		bobberConnection:Disconnect()
		bobberConnection = nil
	end
end
_G.ResetAutoCastState = resetState
task.spawn(function()
	while getgenv().FishTPSession == FISHTP_SESSION do
		task.wait(1)

		if _G.Config and _G.Config.AutoCast and not _G.IsReeling then
			local timestamp = tick()
			local bobberStuck = state == STATE_WAITING

			if bobberStuck then
				bobberStuck = false

				if bobberLandedAt > 0 then
					bobberStuck = timestamp - bobberLandedAt > 4
				end
			end

			if bobberStuck then
				pcall(function()
					local events = game:GetService("ReplicatedStorage"):FindFirstChild("events")

					if events then
						events = events:FindFirstChild("drop_bobber") or events:FindFirstChild("DropBobber")
					end

					if events then
						events:FireServer()
					end
				end)
				resetState(true)
			end
		end
	end
end)
local CAST_COOLDOWN = 0.25
local function cast(_, _)
	local timestamp = tick()

	if timestamp - lastCast < CAST_COOLDOWN then
		return
	end

	local remote = getCastRemote()

	if not remote then
		return
	end

	lastCast = timestamp
	state = STATE_CASTING
	bobberOut = false
	bobberTarget = nil
	bobber = nil
	task.spawn(function()
		pcall(function()
			local power = math.random(10) > 7 and math.random(95, 99) or 100
			local perfect = math.random(100) <= (type(_G.Config.perfectCastEnabled) == "number" and _G.Config.perfectCastEnabled or 0)

			remote:InvokeServer(power, perfect)
		end)
	end)
end
task.spawn(function()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		if getgenv().FishTPSession ~= FISHTP_SESSION then return end
		local timestamp = tick()

		if timestamp - lastTick < TICK_INTERVAL then
			return
		end

		lastTick = timestamp

		if not _G.Config or not _G.Config.AutoCast or _G.Config.LegitCast then
			return
		end

		local Character = LocalPlayer.Character

		if not Character then
			return
		end

		if _G.IsReeling then
			return
		end

		if Character:GetAttribute("Reeling") then
			local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
			local minigameOpen = PlayerGui and PlayerGui:FindFirstChild("reel")
			local shakeUi = PlayerGui and PlayerGui:FindFirstChild("shakeui")

			if minigameOpen then
				minigameOpen = minigameOpen.Enabled
			end

			if not minigameOpen then
				minigameOpen = shakeUi and shakeUi.Enabled
			end

			if minigameOpen then
				return
			end

			pcall(function()
				Character:SetAttribute("Reeling", nil)
			end)
		end

		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")

		if not HumanoidRootPart then
			return
		end

		local equippedRod = getRod(Character)

		if not equippedRod then
			resetState()

			return
		end

		if state == STATE_IDLE then
			cast(equippedRod, HumanoidRootPart)

			return
		end

		if state == STATE_CASTING then
			local newBobber = equippedRod:FindFirstChild("bobber") or equippedRod:FindFirstChild("Bobber")

			if newBobber and newBobber.Parent then
				bobberOut = true

				if _G.Config and _G.Config.InstantCast then
					bobberTarget = teleportBobber(newBobber, nil, HumanoidRootPart)
				end

				bobber = newBobber
				state = STATE_WAITING
				bobberLandedAt = tick()

				return
			end

			if timestamp - lastCast > 0.85 then
				state = STATE_IDLE

				return
			end
		elseif state == STATE_WAITING then
			local pinBobber = _G.Config and _G.Config.InstantCast and bobberTarget and bobber and bobber.Parent

			if pinBobber then
				pcall(function()
					bobber:PivotTo(bobberTarget)
				end)
			end

			if bobberLandedAt > 0 and timestamp - bobberLandedAt > 4 then
				pcall(function()
					local events = game:GetService("ReplicatedStorage"):FindFirstChild("events")

					if events then
						events = events:FindFirstChild("drop_bobber") or events:FindFirstChild("DropBobber")
					end

					if events then
						events:FireServer()
					end
				end)
				resetState()

				return
			end

			if not bobber or not bobber.Parent then
				if _G.IsReeling or Character:GetAttribute("Reeling") then
					return
				end

				if not _G._bobberGoneTick then
					_G._bobberGoneTick = timestamp
				end

				if timestamp - _G._bobberGoneTick < 0.15 then
					return
				end

				_G._bobberGoneTick = nil
				resetState()

				return
			end

			_G._bobberGoneTick = nil
		end
	end)
end)

return function(enabled)
	_G.Config.AutoCast = enabled

	if not enabled then
		resetState()
	end
end
