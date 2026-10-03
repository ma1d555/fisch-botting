-- (Progression build) this run's session: loops and event handlers stop when it ends
local NOVA_SESSION = getgenv().NovaSession
-- AutoReel (Nova module), deobfuscated and cleaned.
-- Hooks the game's ReelController: Update() scales the bar by barSize (Legit mode snaps the fish to the bar),
-- StartReel() snap-skips fish that _G.CheckSnapFilter rejects (drops the bobber, fires Reel/Finish itself and returns a fake reel), or with
-- InstantReel/AutoPerfectCatch waits until ready and finishes the reel itself, rolling "perfect" from
-- PerfectCatchChance. (Break Streak removed by the Progression build.) Also widens the reel GUI bars.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
game:GetService("RunService") -- fetched by the hub, never used
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local hooked = false
local originalStartReel
task.spawn(function()
	if hooked then
		return
	end

	local waited = 0

	while not ReplicatedStorage:FindFirstChild("client") and waited < 10 do
		task.wait(0.5)
		waited += 0.5
	end

	if not ReplicatedStorage:FindFirstChild("client") then
		return
	end

	local ok, ReelController = pcall(require, ReplicatedStorage.client.legacyControllers.ReelController)
	local failed = not ok or not ReelController

	if failed then
		return
	end

	local originals = getgenv().NovaReelOriginals
	if not originals then
		originals = { StartReel = ReelController.StartReel, Update = ReelController.Update }
		getgenv().NovaReelOriginals = originals
	end
	originalStartReel = originals.StartReel
	if getgenv().NovaOnUnload then
		getgenv().NovaOnUnload(function()
			ReelController.StartReel = originals.StartReel
			ReelController.Update = originals.Update
		end)
	end
	hooked = true

	if ReelController.Update then
		local originalUpdate = originals.Update

		-- Reel options (Fishing tab; added by the Progression build), through the game's own modifiers: every frame the
		-- reel rebuilds barSize, progressefficiency and the rest from its modifier lists (ReelController.Update), so a
		-- value set directly doesn't stick, but a modifier of our own does.
		--   Bar size: BarSizePercent % of the reel's width (100 fills it; 0 leaves the rod's own bar).
		--   Progress speed: progress gained times ReelProgressSpeed.
		--   Freeze progress: no gain, no loss, and nothing else adds any (progressLocked); the reel waits while it's on.
		--   Freeze fish: the fish stays where it was.
		local mods = setmetatable({}, { __mode = "k" })
		local frozenAt = setmetatable({}, { __mode = "k" })
		local function setModifier(reel, field, kind, value)
			local mine = mods[reel]
			if not mine then
				mine = {}
				mods[reel] = mine
			end
			local key = field .. "_" .. kind
			if value == nil then
				if mine[key] then
					pcall(function() mine[key]:Destroy() end)
					mine[key] = nil
				end
				return
			end
			if not mine[key] then
				local ok, made = pcall(reel.CreateModifier, reel, field, kind)
				if not ok then return end
				mine[key] = made
			end
			mine[key].Value = value
		end

		function ReelController.Update(reel, dt)
			local config = _G.Config or {}
			pcall(function()
				local percent = tonumber(config.BarSizePercent) or 0
				setModifier(reel, "barSize", "force_final", percent > 0 and math.clamp(percent / 100, 0.01, 1) or nil)
				local speed = tonumber(config.ReelProgressSpeed) or 1
				setModifier(reel, "progressefficiency", "force_multiply", speed ~= 1 and speed or nil)
				local freeze = config.FreezeReelProgress == true
				setModifier(reel, "progressefficiency", "force_final", freeze and 0 or nil)
				setModifier(reel, "progressLossMultiplier", "force_final", freeze and 0 or nil)
				if freeze then
					reel.progressLocked = true
					mods[reel].locked = true
				elseif mods[reel].locked then
					reel.progressLocked = false
					mods[reel].locked = nil
				end
			end)

			originalUpdate(reel, dt)

			if config.FreezeFish and reel.fishPosition ~= nil then
				if frozenAt[reel] == nil then frozenAt[reel] = reel.fishPosition end
				reel.fishPosition = frozenAt[reel]
			end

			local legitReel = _G.Config and _G.Config.AutoReel and _G.Config.ReelMode == "Legit"

			if legitReel then
				reel.fishPosition = reel.barPosition
			end
		end
	end

	task.spawn(function()
		local function resizeBars(gui)
			if not gui then
				return
			end

			local barSize2 = _G.__var and _G.__var.barSize or _G.Config and _G.Config.barSize or 1

			pcall(function()
				for _, descendant in ipairs(gui:GetDescendants()) do
					if descendant:IsA("GuiObject") then
						local name = descendant.Name:lower()
						local isPlayerBar = (name == "playerbar" or name == "player_bar" or name == "whitebar" or name == "catchbar") and not descendant:FindFirstChild("fish") and not descendant:FindFirstChild("Fish")

						if isPlayerBar then
							local BaseSizeXScale = descendant:GetAttribute("BaseSizeXScale")

							if not BaseSizeXScale then
								BaseSizeXScale = descendant.Size.X.Scale

								if BaseSizeXScale > 0 then
									descendant:SetAttribute("BaseSizeXScale", BaseSizeXScale)
								end
							end

							if BaseSizeXScale and BaseSizeXScale > 0 then
								if barSize2 and barSize2 > 1 then
									descendant.Size = UDim2.new(math.clamp(BaseSizeXScale * barSize2, 0.02, 1), descendant.Size.X.Offset, descendant.Size.Y.Scale, descendant.Size.Y.Offset)
								else
									descendant.Size = UDim2.new(BaseSizeXScale, descendant.Size.X.Offset, descendant.Size.Y.Scale, descendant.Size.Y.Offset)
								end
							end
						end
					end
				end
			end)
		end

		local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

		local function watchReelGui(reelGui)
			if not reelGui then
				return
			end

			reelGui:GetPropertyChangedSignal("Enabled"):Connect(function()
				if getgenv().NovaSession ~= NOVA_SESSION then return end
				if reelGui.Enabled then
					resizeBars(reelGui)
				end
			end)

			if reelGui.Enabled then
				resizeBars(reelGui)
			end
		end

		local existingGui = PlayerGui:FindFirstChild("reel") or PlayerGui:FindFirstChild("Reel")

		if existingGui then
			watchReelGui(existingGui)
		end

		PlayerGui.ChildAdded:Connect(function(child)
			if getgenv().NovaSession ~= NOVA_SESSION then return end
			if child.Name == "reel" or child.Name == "Reel" then
				watchReelGui(child)
			end
		end)
	end)

	local snapping = false

	function ReelController.StartReel(params)
		if not params or not _G.Config then
			return originalStartReel(params)
		end

		local timestamp = tick()

		_G.IsReeling = true
		_G.ReelStartTick = timestamp

		if _G.ShowCatchNotification and params.fish then
			task.spawn(_G.ShowCatchNotification, params.fish)
		end

		if params.fish then
			local fish = params.fish
			local mutation = tostring(fish.Mutation or ""):lower()
			local fishName = tostring(fish.Name or fish):lower()
			local isShady = mutation:find("shady", 1, true) or mutation:find("sludge", 1, true) or fishName:find("shady", 1, true) or fishName:find("sludge", 1, true)

			if isShady then
				_G.ShadyInInventory = true
				_G.LastShadyStartReelTime = tick()
			end
		end

		local snapEnabled = not snapping and _G.__var and _G.__var.AutoSnapEnabled and _G.CheckSnapFilter

		if snapEnabled then
			local Character = LocalPlayer.Character

			if (not Character or not Character:GetAttribute("Reeling")) and not _G.CheckSnapFilter(params.fish) then
				snapping = true
				pcall(function()
					local events = ReplicatedStorage:FindFirstChild("events")

					if events then
						local dropBobber = events:FindFirstChild("drop_bobber") or events:FindFirstChild("DropBobber")

						if dropBobber then
							dropBobber:FireServer()
						end
					end
				end)

				local fakeSignal = {
					Connect = function()
						return {
							Disconnect = function()
							end
						}
					end
				}

				pcall(function()
					local packages = ReplicatedStorage:FindFirstChild("packages")
					local net = packages and packages:FindFirstChild("Net")

					if net then
						local netOk, Net = pcall(require, net)

						if netOk and Net then
							local reelFinish = Net:RemoteEvent("Reel/Finish")

							if reelFinish then
								reelFinish:FireServer({
									e = -0.033138427883387,
									p = false,
									l = {},
									d = {}
								})
							end
						end
					end
				end)

				local fakeReel = {
					active = false,
					ready = false,
					OnReady = fakeSignal,
					Destroy = function()
					end,
					Finish = function()
					end,
					EndMinigame = function()
					end
				}

				if timestamp == _G.ReelStartTick then
					_G.LastCatchTick = 0
					_G.IsReeling = false

					if _G.ResetAutoCastState then
						pcall(_G.ResetAutoCastState, true)
					end
				end

				snapping = false

				return fakeReel
			end
		end

		local reelOk, reelObject = pcall(originalStartReel, params)

		if not reelOk or not reelObject then
			if timestamp == _G.ReelStartTick then
				_G.IsReeling = false
			end

			return reelObject
		end

		-- (bar size is set in ReelController.Update)

		_G.LastCatchTick = tick()

		local instantOrPerfect = _G.Config and (_G.Config.InstantReel or _G.Config.AutoPerfectCatch)

		if instantOrPerfect then
			local perfectChance = 100

			if type(_G.Config.PerfectCatchChance) == "number" then
				perfectChance = _G.Config.PerfectCatchChance
			elseif type(_G.Config.perfectCatchEnabled) == "number" then
				perfectChance = _G.Config.perfectCatchEnabled
			end

			reelObject.perfect = perfectChance >= math.random(100)
			task.spawn(function()
				local Character = LocalPlayer.Character

				if not Character then
					return
				end

				if not Character:GetAttribute("Reeling") then
					local waited2 = 0
					local reelingStarted = false
					local connection = Character:GetAttributeChangedSignal("Reeling"):Connect(function()
						if getgenv().NovaSession ~= NOVA_SESSION then return end
						reelingStarted = Character:GetAttribute("Reeling")
					end)

					while not reelingStarted and waited2 < 3 do
						task.wait(0.05)
						waited2 += 0.05
					end

					connection:Disconnect()
				end

				if not reelObject.ready then
					local MAX_WAIT = 3
					local waited3 = 0
					local ready = false

					if reelObject.OnReady then
						local connection = reelObject.OnReady:Connect(function()
							if getgenv().NovaSession ~= NOVA_SESSION then return end
							ready = true
						end)

						while not ready and waited3 < MAX_WAIT do
							task.wait(0.05)
							waited3 += 0.05
						end

						connection:Disconnect()
					else
						while not reelObject.ready and waited3 < MAX_WAIT do
							task.wait(0.05)
							waited3 += 0.05
						end
					end
				end

				if _G.Config and _G.Config.InstantReel then
					task.wait(math.clamp((tonumber(_G.Config and _G.Config.InstantReelDelayMs) or 280) / 1000, 0, 1))
					reelObject.active = true
					reelObject.ready = true

					pcall(function()
						_G.LocalFishCaught = (_G.LocalFishCaught or 0) + 1

						if reelObject.perfect then
							_G.LocalPerfectCatches = (_G.LocalPerfectCatches or 0) + 1
						end

						reelObject.progress = 100

						if typeof(reelObject.Finish) == "function" then
							reelObject:Finish(true)

							return
						end

						if typeof(reelObject.EndMinigame) == "function" then
							reelObject:EndMinigame(true)

							return
						end

						if reelObject.OnReelFinished then
							reelObject.OnReelFinished:Fire(true)
						end
					end)
					task.wait(0.05)

					if _G.ReelStartTick == timestamp then
						_G.IsReeling = false
						_G.LastCatchTick = 0

						if _G.ResetAutoCastState then
							pcall(_G.ResetAutoCastState, true)
						end
					end

					return
				end

				if _G.ReelStartTick == timestamp then
					_G.IsReeling = false
				end
			end)

			return reelObject
		end

		if timestamp == _G.ReelStartTick then
			_G.IsReeling = false
		end

		return reelObject
	end

	task.spawn(function()
		while getgenv().NovaSession == NOVA_SESSION do
			task.wait(5)

			local reelStuck = _G.IsReeling and _G.ReelStartTick and tick() - _G.ReelStartTick > 10

			if reelStuck then
				_G.IsReeling = false
				snapping = false
				_G.LastCatchTick = 0

				if _G.ResetAutoCastState then
					pcall(_G.ResetAutoCastState, true)
				end
			end

			local snapStuck = snapping and _G.ReelStartTick and tick() - _G.ReelStartTick > 5

			if snapStuck then
				snapping = false
			end
		end
	end)
end)
local function dropBobberSoon()
	task.wait(0.3)
	pcall(function()
		local events = ReplicatedStorage:FindFirstChild("events")

		if events then
			local dropRemote = events:FindFirstChild("drop_bobber") or events:FindFirstChild("DropBobber")

			if dropRemote then
				dropRemote:FireServer()
			end
		end
	end)
end
LocalPlayer.CharacterAdded:Connect(function()
	if getgenv().NovaSession ~= NOVA_SESSION then return end
	task.wait(1)
	dropBobberSoon()
end)
if LocalPlayer.Character then
	task.spawn(dropBobberSoon)
end
return function(enabled)
	_G.Config.AutoReel = enabled

	if not enabled then
		_G.Config.InstantReel = false
	end
end
