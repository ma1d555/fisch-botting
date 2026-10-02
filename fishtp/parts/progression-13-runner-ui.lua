	-- [Progression part 13-runner-ui: the runner and the Progression tab. The loader joins the parts in order into one scope.]
	-- ---- runner -----------------------------------------------------------------------------

	local function nextRod()
		for _, rod in ipairs(ROD_ORDER) do
			if state.settings.rods[rod] and not PLAN[rod].done() then return rod end
		end
		return nil
	end

	local function run()
		log("---- started (level " .. G.level() .. ", " .. G.coins() .. " C$)")
		while not state.stop do
			local rod = nextRod()
			if not rod then
				setStatus("Done", "every selected rod is finished")
				break
			end
			setStatus("Working on " .. rod)
			state.stageRod = nil -- a stage can pick the rod its fishing uses
			local ok, err = pcall(PLAN[rod].run)
			Fish.stop()
			G.unhold()
			if not ok then
				if err == STOP then break end
				-- A script error names a line of the joined script: the loader says which part and line that is.
				local message = tostring(err)
				local where = getgenv and getgenv().FishTPWhere
				if where then message = message:gsub("FishTP:(%d+):", function(n) return where(tonumber(n)) .. ":" end) end
				setStatus("Stuck on " .. rod, message)
				break
			end
		end
		if state.stop then setStatus(state.resumeAfterTrade and "Paused" or "Stopped") end
		state.running = false
		state.stop = false
		notify()
	end

	function Progression.start()
		if state.running then return end
		if state.tradePause > 0 then
			-- A trade is on: start once it's over.
			state.resumeAfterTrade = true
			setStatus("Waiting", "starts after the trade")
			return
		end
		state.running = true
		state.stop = false
		-- With "Teleport to the grind zone" off, this is where grinding happens (and where errands come back to).
		local hrp = G.hrp()
		state.home = hrp and hrp.Position or nil
		if state.home then
			log(("grind spot: %d, %d, %d%s"):format(math.floor(state.home.X), math.floor(state.home.Y), math.floor(state.home.Z),
				state.settings.teleportToGrind and " (not used: teleporting to the grind zone is on)" or ""))
		end
		task.spawn(run)
	end

	function Progression.stop()
		state.resumeAfterTrade = false -- turned off during a trade: stays off afterwards
		if state.running then state.stop = true end
	end

	-- Unload: the plan stops, fishing goes back to how it was, and nothing is left held, pressed or floating.
	if getgenv().FishTPOnUnload then
		getgenv().FishTPOnUnload(function()
			Progression.stop()
			pcall(Fish.stop)
			pcall(G.mouse, false)
			pcall(removeRaft)
			pcall(stopRingHover)
			pcall(Hunt.stopHover)
		end)
	end

	-- ---- UI -----------------------------------------------------------------------------------

	local function setText(paragraph, text)
		if not paragraph then return end
		pcall(function()
			if paragraph.SetDesc then paragraph:SetDesc(text) elseif paragraph.Set then paragraph:Set({ Content = text }) end
		end)
	end

	local function accountText()
		local lines = { ("Level %d · %s C$"):format(G.level(), tostring(G.coins())) }
		for _, rod in ipairs(ROD_ORDER) do
			local mark = PLAN[rod].done() and "✓" or (G.ownsRod(rod) and "½" or "·")
			local enchants = {}
			local primary, secondary = G.rodEnchant(rod, "enchant"), G.rodEnchant(rod, "secondaryEnchant")
			if primary then enchants[#enchants + 1] = primary end
			if secondary then enchants[#enchants + 1] = secondary end
			lines[#lines + 1] = ("%s %s%s"):format(mark, rod, #enchants > 0 and (" (" .. table.concat(enchants, ", ") .. ")") or "")
		end
		local wisdom = ("Wisdom mats: Ruby %d/1 · Mythical Driftwood %d/2 · Magic Thread %d/1"):format(
			G.count("Ruby"), G.count("Driftwood", { Mutation = "Mythical" }), G.count("Magic Thread"))
		lines[#lines + 1] = wisdom
		return table.concat(lines, "\n")
	end

	local function altsText()
		local alts = Alts.list()
		if #alts == 0 then return "No other alts running this script right now." end
		local lines = {}
		for _, alt in ipairs(alts) do
			local needs = {}
			for need, qty in pairs(alt.needs or {}) do needs[#needs + 1] = qty .. " " .. need end
			lines[#lines + 1] = ("%s%s · Lv %d · %s%s"):format(
				alt.name, alt.jobId == game.JobId and " (this server)" or "", alt.level or 0, alt.status or "?",
				#needs > 0 and (" · needs " .. table.concat(needs, ", ")) or "")
		end
		return table.concat(lines, "\n")
	end

	function Progression.build(tab, zones)
		local building = true
		-- Sections stack in creation order per column; Extras goes first on the right so its buttons are in view.
		local main = tab:AddSection("Progression", true, "Left")
		local extrasSection = tab:AddSection("Extras", true, "Right")
		local rodsSection = tab:AddSection("Rods", true, "Right")
		local altsSection = tab:AddSection("Alts", true, "Right")
		local baitSection = tab:AddSection("Bait", true, "Left")
		local placesSection = tab:AddSection("Locations", true, "Left")

		baitSection:AddToggle({
			Title = "Auto bait (puts on the bait you have most of when none is on)",
			Default = state.settings.autoBait ~= false,
			Callback = function(on)
				if building then return end -- some UI libraries fire callbacks while building; keep saved settings
				state.settings.autoBait = on
				saveSettings()
			end,
		})
		baitSection:AddToggle({
			Title = "Buy bait crates when out (100 at Moosewood, then opens them)",
			Default = state.settings.buyBaitCrates ~= false,
			Callback = function(on)
				if building then return end -- some UI libraries fire callbacks while building; keep saved settings
				state.settings.buyBaitCrates = on
				saveSettings()
			end,
		})
		baitSection:AddButton({
			Title = "Open my bait crates now (buys 100 if I have none)",
			Callback = function()
				task.spawn(function() withProgressionPaused(Progression.restockBait) end)
			end,
		})
		local crateAmount = 100
		if baitSection.AddInput then
			baitSection:AddInput({
				Title = "Bait crates to buy",
				Default = "100",
				Callback = function(v) crateAmount = math.max(1, math.floor(tonumber(v) or 100)) end,
			})
		end
		baitSection:AddButton({
			Title = "Buy that many bait crates (then back to where I was)",
			Callback = function()
				task.spawn(function() withProgressionPaused(Progression.buyBaitCrates, crateAmount) end)
			end,
		})

		extrasSection:AddButton({
			Title = "Redeem all codes",
			Callback = function() task.spawn(Progression.redeemCodes) end,
		})
		extrasSection:AddButton({
			Title = "Explore all areas (press again to stop)",
			Callback = function() task.spawn(Progression.exploreAreas) end,
		})
		extrasSection:AddButton({
			Title = "Save what's on screen (F7)",
			Callback = function() task.spawn(Progression.snapshot) end,
		})
		pcall(function()
			game:GetService("UserInputService").InputBegan:Connect(function(input, typing)
				if not alive() then return end
				if not typing and input.KeyCode == Enum.KeyCode.F7 then task.spawn(Progression.snapshot) end
			end)
		end)

		-- Hopped servers with the progression running (in the last 5 minutes): it carries on here.
		local resumeHop = tonumber(state.settings.resumeAfterHop) and os.time() - state.settings.resumeAfterHop < 300
		if state.settings.resumeAfterHop then
			state.settings.resumeAfterHop = nil
			saveSettings()
		end
		main:AddToggle({
			Title = "Auto progression",
			Default = resumeHop == true,
			Callback = function(on)
				if building then return end -- some UI libraries fire callbacks while building; keep saved settings
				if on then Progression.start() else Progression.stop() end
			end,
		})
		local statusPara = main:AddParagraph({ Title = "Status", Content = "Idle" })
		local accountPara = main:AddParagraph({ Title = "This account", Content = "…" })

		for _, rod in ipairs(ROD_ORDER) do
			rodsSection:AddToggle({
				Title = ("%s (Lv %d)"):format(rod, PLAN[rod].level),
				Default = state.settings.rods[rod] ~= false,
				Callback = function(on)
					if building then return end -- some UI libraries fire callbacks while building; keep saved settings
					state.settings.rods[rod] = on
					saveSettings()
				end,
			})
		end
		rodsSection:AddToggle({
			Title = "Sundial Totem for enchanting in the day (buys one if needed)",
			Default = state.settings.useSundial ~= false,
			Callback = function(on)
				if building then return end -- some UI libraries fire callbacks while building; keep saved settings
				state.settings.useSundial = on
				saveSettings()
			end,
		})
		-- The rod the Chaotic relic is fished with (Pinion's Aria): your pick when the switch is on, else the fastest lure.
		rodsSection:AddToggle({
			Title = "Chaotic relic: use my rod below (off: fastest lure)",
			Default = state.settings.useChaoticRod == true,
			Callback = function(on)
				if building then return end -- some UI libraries fire callbacks while building; keep saved settings
				state.settings.useChaoticRod = on
				saveSettings()
			end,
		})
		local ownedRods = {}
		pcall(function()
			for name in pairs(G.data().PlayerDataReplicator:TryIndex({ "Rods" }) or {}) do ownedRods[#ownedRods + 1] = name end
		end)
		table.sort(ownedRods)
		if #ownedRods > 0 then
			rodsSection:AddDropdown({
				Title = "Chaotic relic rod",
				Options = ownedRods,
				Default = state.settings.chaoticRod or ownedRods[1],
				Callback = function(v)
					if building then return end -- some UI libraries fire callbacks while building; keep saved settings
					if type(v) == "table" then v = v[1] end
					state.settings.chaoticRod = v
					saveSettings()
				end,
			})
		end
		rodsSection:AddButton({
			Title = "Fly the ring course now (Pinion's Aria)",
			Callback = function()
				task.spawn(function()
					withProgressionPaused(function()
						if flyRingCourse() then ariaDone("cloud") end
					end)
				end)
			end,
		})
		rodsSection:AddButton({
			Title = "Mark the ring course done (Pinion's Aria)",
			Callback = function() ariaDone("cloud") end,
		})
		rodsSection:AddButton({
			Title = "Redo Pinion's Aria steps from the start",
			Callback = function()
				state.settings.aria = {}
				saveSettings()
				log("Pinion's Aria steps cleared; they'll be done again")
			end,
		})
		rodsSection:AddToggle({
			Title = "Teleport to the grind zone (off: fish where I turn it on)",
			Default = state.settings.teleportToGrind == true,
			Callback = function(on)
				if building then return end -- some UI libraries fire callbacks while building; keep saved settings
				state.settings.teleportToGrind = on
				saveSettings()
			end,
		})
		local zoneOptions = { "XP spot", "C$ farm spot" }
		for _, zone in ipairs(zones) do zoneOptions[#zoneOptions + 1] = zone end
		rodsSection:AddDropdown({
			Title = "Grind zone (other fishing; levels use the XP spot, C$ the C$ farm spot)",
			Options = zoneOptions,
			Default = state.settings.grindZone or "None",
			Callback = function(v)
				if building then return end -- some UI libraries fire callbacks while building; keep saved settings
				if type(v) == "table" then v = v[1] or "None" end
				state.settings.grindZone = v
				saveSettings()
			end,
		})

		altsSection:AddToggle({
			Title = "Share items with my other alts",
			Default = state.settings.shareWithAlts,
			Callback = function(on)
				if building then return end -- some UI libraries fire callbacks while building; keep saved settings
				state.settings.shareWithAlts = on
				saveSettings()
			end,
		})
		-- Get an item from the alts in this server (they need this script running and sharing on).
		local shareItem, shareAmount = "", 1
		if altsSection.AddInput then
			altsSection:AddInput({
				Title = "Item to get",
				Content = "Fish or item, e.g. Perch or Driftwood (Mythical)",
				Default = "",
				Callback = function(v) shareItem = tostring(v or "") end,
			})
			altsSection:AddInput({
				Title = "Amount",
				Default = "1",
				Callback = function(v) shareAmount = math.max(1, math.floor(tonumber(v) or 1)) end,
			})
			altsSection:AddButton({
				Title = "Get it from my alts",
				Callback = function() task.spawn(Progression.shareRequest, shareItem, shareAmount) end,
			})
		end
		-- Servers (user): the alts with sharing on come along (see Alts.followHop).
		altsSection:AddButton({
			Title = "Server hop (my sharing alts come too)",
			Callback = function() task.spawn(Progression.serverHop, true) end,
		})
		local altsJobId = ""
		if altsSection.AddInput then
			altsSection:AddInput({
				Title = "Job ID to join",
				Content = "the server's job ID",
				Default = "",
				Callback = function(v) altsJobId = tostring(v or "") end,
			})
			altsSection:AddButton({
				Title = "Join that server (my sharing alts come too)",
				Callback = function() task.spawn(Progression.joinServer, altsJobId, true) end,
			})
		end
		local altsPara = altsSection:AddParagraph({ Title = "Alts", Content = "…" })

		local selectedSpot = SPOT_NAMES[1]
		placesSection:AddDropdown({
			Title = "Location",
			Options = SPOT_NAMES,
			Default = selectedSpot,
			Callback = function(v)
				if building then return end -- some UI libraries fire callbacks while building; keep saved settings
				if type(v) == "table" then v = v[1] end
				selectedSpot = v or selectedSpot
			end,
		})
		placesSection:AddButton({
			Title = "Save my position as this location",
			Callback = function() saveSpot(selectedSpot) notify() end,
		})
		placesSection:AddButton({
			Title = "Go to this location",
			Callback = function()
				local pos = G.spot(selectedSpot)
				if pos then task.spawn(G.teleport, pos) end
			end,
		})
		local placesPara = placesSection:AddParagraph({ Title = "Not saved yet", Content = "…" })

		local function refresh()
			setText(statusPara, state.status .. (state.detail ~= "" and ("\n" .. state.detail) or ""))
			local missing = {}
			for _, name in ipairs(SPOT_NAMES) do
				if not G.spot(name) then missing[#missing + 1] = name end
			end
			setText(placesPara, #missing > 0 and table.concat(missing, ", ") or "All saved.")
		end
		listeners[#listeners + 1] = refresh
		refresh()

		task.spawn(function()
			while alive() do
				pcall(function() setText(accountPara, accountText()) end)
				pcall(function() setText(altsPara, altsText()) end)
				pcall(refresh)
				task.wait(3)
			end
		end)
		task.spawn(altsLoop)
		if resumeHop then
			log("carrying on with the progression after the server hop")
			task.delay(5, Progression.start)
		end
		for _, menu in ipairs(tpMenus) do
			local options = menu.opts.Options or menu.opts.Values or menu.opts.List
			log(("TP menu [%s] \"%s\": %d options"):format(menu.section, tostring(menu.opts.Title), type(options) == "table" and #options or 0))
		end
		building = false
		log("Progression tab ready")
	end

	Progression.G = G
end
