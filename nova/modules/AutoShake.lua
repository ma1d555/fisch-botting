-- (Progression build) this run's session: loops and event handlers stop when it ends
local NOVA_SESSION = getgenv().NovaSession
-- AutoShake (Nova module), deobfuscated and cleaned.
-- While Config.AutoShake is on, clicks every button in PlayerGui.shakeui.safezone every 0.02s by firing its
-- MouseButton1Click/Activated connections (getconnections, or firesignal). Returns the on/off setter.

local LocalPlayer = game:GetService("Players").LocalPlayer
task.spawn(function()
	while getgenv().NovaSession == NOVA_SESSION do
		if _G.Config and _G.Config.AutoShake then
			local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
			local shakeUi = PlayerGui and PlayerGui:FindFirstChild("shakeui")

			if shakeUi and shakeUi.Enabled then
				local safezone = shakeUi:FindFirstChild("safezone")

				if safezone then
					for _, button in ipairs(safezone:GetChildren()) do
						if button:IsA("ImageButton") or (button:IsA("TextButton") and button.Visible) then -- as the hub groups it
							pcall(function()
								if getconnections then
									for _, connection in ipairs(getconnections(button.MouseButton1Click)) do
										connection:Fire()
									end

									for _, connection2 in ipairs(getconnections(button.Activated)) do
										connection2:Fire()
									end

									return
								end

								if firesignal then
									firesignal(button.MouseButton1Click)
									firesignal(button.Activated)
								end
							end)
						end
					end
				end

				task.wait(0.02)
			else
				task.wait(0.1)
			end
		else
			task.wait(0.5)
		end
	end
end)

return function(enabled)
	_G.Config.AutoShake = enabled
end
