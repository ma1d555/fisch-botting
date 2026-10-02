-- (Progression build) this run's session: loops and event handlers stop when it ends
local FISHTP_SESSION = getgenv().FishTPSession
-- MiscFishing (KAN-FISCH / ShieldTeam hub module), deobfuscated and cleaned.
-- Extras: AutoEquipRod (equips the rod named in PlayerStats every 0.1s), DeleteFishModel (destroys current and new
-- workspace.active children except crates/chests/totems), DeleteAllMap (deletes world.map and decoration folders,
-- adds a 100k-stud AntiFallBaseplate and an anti-void loop), DeleteAllCharacters. Also adds a "S$" Shady Scrip
-- counter under the coins HUD. AutoPasifLullaby is an empty stub in the hub.

local isKeptItem
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local fishModelConnection
local function equipRod()
	local rodName = workspace.PlayerStats[LocalPlayer.Name].T[LocalPlayer.Name].Stats.rod.Value

	if rodName and rodName ~= "" then
		local rod = LocalPlayer:WaitForChild("Backpack"):FindFirstChild(rodName)

		if rod then
			local Character = LocalPlayer.Character
			local humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				humanoid:EquipTool(rod)
			end
		end
	end
end
function isKeptItem(itemName)
	local lower = itemName:lower()
	local found = lower:find("crate") or lower:find("chest") or lower:find("totem")

	return found
end
local function removeFishModel(model)
	if not model then
		return
	end

	task.delay(0.01, function()
		if not model or not model.Parent then
			return
		end

		pcall(function()
			if not isKeptItem(model.Name) then
				model:Destroy()
			end
		end)
	end)
end
task.spawn(function()
	local player = game.Players.LocalPlayer

	local function addScripCounter()
		local PlayerGui = player:WaitForChild("PlayerGui", 10)

		if not PlayerGui then
			return
		end

		local hud = PlayerGui:WaitForChild("hud", 10)

		if not hud then
			return
		end

		local safezone = hud:WaitForChild("safezone", 5)

		if not safezone then
			return
		end

		local coins = safezone:WaitForChild("coins", 5)

		if not coins then
			return
		end

		if safezone:FindFirstChild("ShadyCoinGui") then
			return
		end

		local clone = coins:Clone()

		clone.Name = "ShadyCoinGui"

		for _, v in ipairs(clone:GetDescendants()) do
			if v:IsA("LocalScript") or v:IsA("Script") then
				v:Destroy()
			end
		end

		if not safezone:FindFirstChildOfClass("UIListLayout") then
			clone.Position = UDim2.new(coins.Position.X.Scale, coins.Position.X.Offset, coins.Position.Y.Scale, coins.Position.Y.Offset - 85)
		end

		clone.Parent = safezone

		local icon = clone:FindFirstChild("icon")

		if icon then
			icon:Destroy()
		end

		local fishBG = clone:FindFirstChild("fishBG")

		if fishBG then
			fishBG:Destroy()
		end

		local label = clone:IsA("TextLabel") and clone or clone:FindFirstChild("TextLabel") or clone:FindFirstChildOfClass("TextLabel")

		if not label then
			return
		end

		if label ~= clone then
			label.Position = UDim2.new(0, 0, 0, 0)
			label.Size = UDim2.new(1, 0, 1, 0)
		end

		label.TextXAlignment = Enum.TextXAlignment.Right
		label.TextColor3 = Color3.fromRGB(185, 125, 130)

		local function updateScrip()
			pcall(function()
				local PlayerStats = workspace:FindFirstChild("PlayerStats")

				if not PlayerStats then
					return
				end

				local statsRoot = PlayerStats:FindFirstChild(player.Name)

				if not statsRoot then
					return
				end

				local T = statsRoot:FindFirstChild("T")

				if not T then
					return
				end

				local playerStats = T:FindFirstChild(player.Name)

				if not playerStats then
					return
				end

				local LocalCurrencies = playerStats:FindFirstChild("LocalCurrencies")

				if not LocalCurrencies then
					return
				end

				local scrip = LocalCurrencies:FindFirstChild("Shady Scrip")

				if scrip then
					label.Text = tostring(scrip.Value):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "") .. " S$"

					return
				end

				label.Text = "0 S$"
			end)
		end

		task.spawn(function()
			while label and label.Parent and getgenv().FishTPSession == FISHTP_SESSION do
				updateScrip()
				task.wait(1)
			end
		end)
	end

	addScripCounter()
	player.CharacterAdded:Connect(function()
		if getgenv().FishTPSession ~= FISHTP_SESSION then return end
		task.wait(2)
		addScripCounter()
	end)
end)

return {
	AutoEquipRod = function(enabled)
		_G.Config.isEquipRpd = enabled

		if enabled then
			task.spawn(function()
				while getgenv().FishTPSession == FISHTP_SESSION and _G.Config.isEquipRpd do
					equipRod()
					task.wait(0.1)
				end
			end)
		end
	end,
	AutoPasifLullaby = function()
	end,
	DeleteFishModel = function(enabled2)
		_G.Config.DeleteFishModel = enabled2

		local active = workspace:FindFirstChild("active")

		if enabled2 then
			if active then
				for _, v in ipairs(active:GetChildren()) do
					removeFishModel(v)
				end

				if fishModelConnection then
					fishModelConnection:Disconnect()
				end

				fishModelConnection = active.ChildAdded:Connect(removeFishModel)

				return
			end
		elseif fishModelConnection then
			fishModelConnection:Disconnect()
			fishModelConnection = nil
		end
	end,
	DeleteAllMap = function(enabled3)
		task.spawn(function()
			_G.Config.DeleteMap = enabled3

			if enabled3 then
				local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local basePos = root and root.Position or Vector3.new(0, 130, 0)

				if not workspace:FindFirstChild("AntiFallBaseplate") then
					local Part = Instance.new("Part")

					Part.Name = "AntiFallBaseplate"
					Part.Size = Vector3.new(100000, 4, 100000)
					Part.Position = Vector3.new(basePos.X, basePos.Y - 3.2, basePos.Z)
					Part.Anchored = true
					Part.CanCollide = true
					Part.Transparency = 0.5
					Part.Material = Enum.Material.SmoothPlastic
					Part.BrickColor = BrickColor.new("Shamrock")
					Part.Parent = workspace
				end

				local world = workspace:FindFirstChild("world")

				if world then
					local map = world:FindFirstChild("map")

					if map then
						for _, v in ipairs(map:GetChildren()) do
							pcall(function()
								v:Destroy()
							end)
						end
					end

					for _, v in ipairs({ "nature", "props", "decorations", "structures", "islands" }) do
						local folder = world:FindFirstChild(v)

						if folder then
							pcall(function()
								folder:Destroy()
							end)
						end
					end
				end

				if not _G.__antiVoidRunning then
					_G.__antiVoidRunning = true
					task.spawn(function()
						while getgenv().FishTPSession == FISHTP_SESSION and _G.Config.DeleteMap do
							task.wait(1)
							pcall(function()
								local Character = LocalPlayer.Character
								local root2 = Character and Character:FindFirstChild("HumanoidRootPart")
								local AntiFallBaseplate = workspace:FindFirstChild("AntiFallBaseplate")
								local fellBelow = root2 and AntiFallBaseplate and root2.Position.Y < AntiFallBaseplate.Position.Y - 20

								if fellBelow then
									root2.AssemblyLinearVelocity = Vector3.zero
									root2.CFrame = CFrame.new(root2.Position.X, AntiFallBaseplate.Position.Y + 4, root2.Position.Z)
								end
							end)
						end

						_G.__antiVoidRunning = false
					end)

					return
				end
			elseif workspace:FindFirstChild("AntiFallBaseplate") then
				pcall(function()
					workspace.AntiFallBaseplate:Destroy()
				end)
			end
		end)
	end,
	DeleteAllCharacters = function(enabled4)
		task.spawn(function()
			_G.Config.DeletePlayer = enabled4

			if enabled4 then
				for _, child in pairs(workspace:GetChildren()) do
					local isOtherCharacter = child:IsA("Model") and child:FindFirstChild("Humanoid") and child ~= LocalPlayer.Character

					if isOtherCharacter then
						pcall(function()
							child:Destroy()
						end)
					end
				end

				for _, player in pairs(Players:GetPlayers()) do
					if player ~= LocalPlayer and player.Character then
						pcall(function()
							player.Character:Destroy()
						end)
					end
				end
			end
		end)
	end
}
