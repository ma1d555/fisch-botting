-- (Progression build) this run's session: loops and event handlers stop when it ends
local NOVA_SESSION = getgenv().NovaSession
-- Utils (Nova module), deobfuscated and cleaned.
-- DetectExecutor (identifyexecutor/getexecutorname/known globals; NX reports as "Luna"), DeepCopy, and
-- FormatSeconds, which prints Indonesian units: Tahun = years, Bulan = months, Hari = days, Jam = hours, Mnt = minutes.

local Utils = {
	DetectExecutor = function()
		local name = "Unknown"

		if identifyexecutor then
			name = identifyexecutor()
		elseif getexecutorname and type(getexecutorname) == "function" then
			name = getexecutorname()
		else
			local synExecutor = syn and syn.executor and type(syn.executor) == "string"

			if synExecutor then
				name = syn.executor
			elseif is_sirhurt_closure then
				name = "SirHurt"
			elseif is_protosmasher_closure then
				name = "ProtoSmasher"
			elseif KRNL_LOADED then
				name = "KRNL"
			elseif SENTINEL_LOADED then
				name = "Sentinel"
			elseif is_synapse_function then
				name = "Synapse X"
			elseif debug and debug.getregistry then
				for _, v in ipairs(debug.getregistry()) do
					if type(v) == "table" and rawget(v, "luadecomp") then
						name = "Luna"
					end
				end
			end
		end

		if name == "NX" or string.find(name:lower(), "nx") then
			name = "Luna"
		end

		return name
	end
}
function Utils.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}

	for k, v in pairs(value) do
		copy[Utils.DeepCopy(k)] = Utils.DeepCopy(v)
	end

	return setmetatable(copy, getmetatable(value))
end
function Utils.FormatSeconds(seconds)
	local ok, secs = pcall(function()
		return (tonumber(seconds))
	end)
	local expired = not ok or not secs or secs <= 0

	if expired then
		return "Expired"
	end

	local remaining = math.floor(secs)
	local years = 0

	if remaining >= 31536000 then
		years = math.floor(remaining / 31536000)
		remaining -= years * 31536000
	end

	local months = 0

	if remaining >= 2592000 then
		months = math.floor(remaining / 2592000)
		remaining -= months * 2592000
	end

	local days = 0

	if remaining >= 86400 then
		days = math.floor(remaining / 86400)
		remaining -= days * 86400
	end

	local hours = 0

	if remaining >= 3600 then
		hours = math.floor(remaining / 3600)
		remaining -= hours * 3600
	end

	local minutes = 0

	if remaining >= 60 then
		minutes = math.floor(remaining / 60)

		local _ = remaining - minutes * 60
	end

	if years > 0 then
		if months > 0 then
			return years .. " Tahun " .. months .. " Bulan"
		end

		return years .. " Tahun"
	end

	if months > 0 then
		return months .. " Bulan " .. days .. " Hari"
	end

	if days > 0 then
		return days .. " Hari " .. hours .. " Jam " .. minutes .. " Mnt"
	end

	if hours > 0 then
		return hours .. " Jam " .. minutes .. " Mnt"
	end

	return minutes .. " Mnt"
end
return Utils
