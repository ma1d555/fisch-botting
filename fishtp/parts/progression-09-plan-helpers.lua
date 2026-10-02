	-- [Progression part 09-plan-helpers: plan helpers and bait crates. The loader joins the parts in order into one scope.]
	-- ---- the plan ----------------------------------------------------------------------------

	local function getRuby()
		G.claimDaily()
		sleep(2)
		while G.count("Ruby") < 1 do
			-- Our own Meteor Totem if we have one; otherwise an alt's, used next to us (totems can't be traded);
			-- otherwise buy one.
			local usedByAlt = false
			if G.count("Meteor Totem", nil, true) < 1 and state.settings.shareWithAlts then
				usedByAlt = requestFromAlts("Meteor Totem", 1, nil, "use") >= 1
				checkStop()
			end
			if not usedByAlt then
				if G.count("Meteor Totem", nil, true) < 1 then
					earn(75000, "a Meteor Totem")
					buyFromDisplay("Meteor Totem", have("Meteor Totem", 1), "Meteor Totem shop")
				end
				if not G.useItem("Meteor Totem") then error("couldn't use a Meteor Totem (is it on the hotbar?)", 0) end
			end
			setStatus("Meteor", "waiting for it to land")
			local got = waitFor(function() return #CollectionService:GetTagged("MeteorItem") > 0 end, 180, 2)
			if got then
				for _, item in ipairs(CollectionService:GetTagged("MeteorItem")) do
					local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt then G.firePrompt(prompt) sleep(0.8) end
				end
			end
		end
	end

	-- The Travelling Merchant sells three rods from displays next to him. Only a prompt that says "Mythical Rod"
	-- (in its text or the display it sits on) is ever used, so the other two are never bought.
	local function mythicalRodPrompt(near)
		for _, prompt in ipairs(G.promptsNear(near, 80)) do
			local text = (prompt.ObjectText .. " " .. prompt.ActionText .. " " .. prompt:GetFullName()):lower()
			if text:find("mythical rod", 1, true) then return prompt end
		end
		return nil
	end

	local function logPromptsNear(pos, label)
		local list = {}
		for i, prompt in ipairs(G.promptsNear(pos, 80)) do
			if i > 12 then break end
			list[#list + 1] = ("%s [%s | %s]"):format(prompt:GetFullName(), prompt.ActionText, prompt.ObjectText)
		end
		log(label .. ": " .. (#list > 0 and table.concat(list, "; ") or "none"))
	end

	local function buyMythicalRod()
		earn(90000, "the Mythical Rod")
		setStatus("Travelling Merchant", "waiting for him to show up")
		local logged = false
		while not G.ownsRod("Mythical Rod") do
			local merchant = G.findNpc("Travelling Merchant")
			local merchantPos = merchant and positionOf(merchant)
			if merchantPos then
				G.teleport(merchantPos + Vector3.new(4, 0, 0))
				sleep(1.5) -- his stand streams in
				local prompt = mythicalRodPrompt(merchantPos)
				if prompt then
					setStatus("Travelling Merchant", "buying the Mythical Rod")
					buyWithPrompt(prompt, function() return G.ownsRod("Mythical Rod") end, "Mythical Rod")
				elseif not logged then
					logged = true
					logPromptsNear(merchantPos, "the Travelling Merchant has no Mythical Rod prompt; his prompts are")
				end
			end
			if not G.ownsRod("Mythical Rod") then
				-- Not here, or not selling it this time: grind a minute and look again.
				Fish.start(nil, { sell = true })
				sleep(60)
				Fish.stop()
			end
		end
	end

	-- ---- bait crates -----------------------------------------------------------------------------

	-- The bait crate stand at Moosewood: a prompt there that mentions a crate. The Robux bait shop (its prompt sits
	-- on something tagged BuyBait) is never used.
	local function baitCratePrompt(spot)
		for _, prompt in ipairs(G.promptsNear(spot, 30)) do
			local text = (prompt.ObjectText .. " " .. prompt.ActionText .. " " .. prompt:GetFullName()):lower()
			local robux = false
			local node = prompt.Parent
			for _ = 1, 4 do
				if not node then break end
				if CollectionService:HasTag(node, "BuyBait") then robux = true end
				node = node.Parent
			end
			if text:find("crate", 1, true) and not robux then return prompt end
		end
		return nil
	end

	local function buyBaitCrates(amount)
		local spot = goTo("Bait crate shop")
		sleep(1.5)
		local prompt = baitCratePrompt(spot)
		if not prompt then
			logPromptsNear(spot, "no bait crate prompt at the bait crate shop; prompts there")
			return 0
		end
		local before = G.count("Bait Crate")
		local misses = 0
		-- Until `amount` more crates, or two tries in a row that don't add any.
		while G.count("Bait Crate") - before < amount and misses < 2 do
			local now = G.count("Bait Crate")
			setStatus("Bait", ("buying bait crates (%d/%d)"):format(now - before, amount))
			buyWithPrompt(prompt, function() return G.count("Bait Crate") > now end, "Bait Crate", amount - (now - before))
			sleep(1)
			misses = G.count("Bait Crate") > now and 0 or misses + 1
		end
		local bought = G.count("Bait Crate") - before
		log(("bought %d bait crates"):format(bought))
		return bought
	end

	-- Using a crate makes the game ask "Open Crates / Open x1 [Bait Crate]?" (PlayerGui.over.prompt, from the prompt
	-- script's PromptAmount). Its openMode button switches "Opening: Held Only" to "All Unfavorited", and the amount
	-- box goes up to 1000, so one confirm opens every crate.
	local function crateMenu()
		local over = LP.PlayerGui:FindFirstChild("over")
		local menu = over and over:FindFirstChild("prompt")
		local title = menu and menu:FindFirstChild("title")
		if menu and title and title:IsA("TextLabel") and title.Text:lower():find("open", 1, true) and menu:FindFirstChild("confirm") then
			return menu
		end
		return nil
	end

	local function openBaitCrates()
		local left = G.count("Bait Crate", nil, true)
		local start = left
		local stuck = 0
		while left > 0 and stuck < 3 do
			setStatus("Bait", ("opening bait crates (%d left)"):format(left))
			local menu = crateMenu()
			if not menu and G.hold("Bait Crate") then
				local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
				pcall(function() tool:Activate() end)
				waitFor(function() return crateMenu() ~= nil end, 5, 0.2)
				menu = crateMenu()
			end
			if menu then
				local mode = menu:FindFirstChild("openMode")
				if mode and mode:IsA("GuiButton") and mode.Visible and buttonText(mode):lower():find("held", 1, true) then
					G.click(mode)
					sleep(0.3)
				end
				local amount = menu:FindFirstChild("amount")
				if amount and amount:IsA("TextBox") then amount.Text = "1000" end
				sleep(0.3)
				local question = menu:FindFirstChild("question")
				log("crates: " .. (question and question.Text or "opening"))
				G.click(menu.confirm)
			else
				log("crates: the Open Crates menu didn't show up")
			end
			sleep(2.5)
			local now = G.count("Bait Crate", nil, true)
			stuck = now < left and 0 or stuck + 1
			left = now
		end
		G.unhold()
		if left > 0 then log(("%d bait crates didn't open (see the log above)"):format(left)) end
		local baits = {}
		for name, n in pairs(G.baitCounts()) do baits[#baits + 1] = ("%s x%d"):format(name, n) end
		log("baits now: " .. (#baits > 0 and table.concat(baits, ", ") or "none"))
		return start - left
	end

	-- Buys 100 bait crates and opens them. At most every 15 minutes unless forced (the button, or a step that needs
	-- a bait), so a shop that doesn't work isn't retried over and over.
	local lastRestock, lastOpenFail = -math.huge, -math.huge
	restockBait = function(force)
		-- Crates already on hand are opened first; new ones are only bought when there are none left, so crates
		-- that won't open never lead to buying more.
		if G.count("Bait Crate", nil, true) > 0 then
			if not force and os.clock() - lastOpenFail < 900 then return false end
			local opened = openBaitCrates()
			if opened == 0 then lastOpenFail = os.clock() end
			return opened > 0
		end
		if not force and os.clock() - lastRestock < 900 then return false end
		lastRestock = os.clock()
		if G.coins() < 5000 then
			log("not buying bait crates: under 5,000 C$")
			return false
		end
		buyBaitCrates(100)
		openBaitCrates()
		return true
	end
	Progression.restockBait = function() restockBait(true) end
	-- The Bait section's button: buys that many crates at the shop, then goes back to where you were.
	Progression.buyBaitCrates = function(amount)
		local hrp = G.hrp()
		local back = hrp and hrp.CFrame
		local bought = buyBaitCrates(amount)
		setStatus("Bait", ("bought %d of %d bait crates"):format(bought, amount))
		if back then
			G.teleport(back.Position)
			local now = G.hrp()
			if now then now.CFrame = CFrame.new(now.Position) * back.Rotation end
		end
	end

