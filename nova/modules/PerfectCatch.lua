-- (Progression build) this run's session: loops and event handlers stop when it ends
local NOVA_SESSION = getgenv().NovaSession
-- PerfectCatch (Nova module), deobfuscated and cleaned.
-- Only a callable table that sets _G.Config.AutoPerfectCatch; AutoReel does the actual perfect catches.

game:GetService("ReplicatedStorage") -- fetched by the hub, never used
local Players = game:GetService("Players")
game:GetService("RunService") -- fetched by the hub, never used
local LocalPlayer = Players.LocalPlayer
local PerfectCatch = {}
setmetatable(PerfectCatch, {
	__call = function(_, enabled)
		_G.Config.AutoPerfectCatch = enabled
	end
})
return PerfectCatch
