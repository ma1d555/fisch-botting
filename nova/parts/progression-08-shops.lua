	-- [Progression part 08-shops: buying, relics, enchanting. The loader joins the parts in order into one scope.]
	-- ---- shared steps ---------------------------------------------------------------------

	local function have(name, qty, filter)
		return function() return G.count(name, filter) >= (qty or 1) end
	end

	-- Gets `qty` of an item: already have it, else ask alts, else run the fallback.
	local function gather(name, qty, filter, fallback)
		local label = filter and filter.Mutation and (filter.Mutation .. " " .. name) or name
		state.protected[name] = filter or true
		if G.count(name, filter) >= qty then return end
		if askAlts(name, qty - G.count(name, filter), filter, 60) then return end
		if fallback then fallback() end
		if G.count(name, filter) < qty then error(("couldn't get %d %s"):format(qty, label), 0) end
	end

	-- Buys a shop item from its display (workspace.world.interactables[name], "View [price]" prompt), then presses
	-- whatever buy/confirm button the game shows. verify() says whether it worked.
	local BUY_WORDS = { "purchase", "buy", "c%$", "yes", "confirm" }
	local NOT_BUY = { "robux", "r%$", "gift", "cancel", "close", "^no$", "%[no%]" }
	local buyWithPrompt -- below
	local function buyFromDisplay(name, verify, spotName)
		if verify() then return true end
		if spotName then goTo(spotName) end
		-- A far-off shop streams in a moment after arriving: look for its display for a few seconds.
		local prompt
		waitFor(function()
			local world = workspace:FindFirstChild("world")
			local display = world and world:FindFirstChild("interactables") and world.interactables:FindFirstChild(name)
			prompt = display and (display:FindFirstChild("PromptTemplate", true) or display:FindFirstChildWhichIsA("ProximityPrompt", true))
			if not prompt then
				local hrp = G.hrp()
				prompt = hrp and G.promptsNear(hrp.Position, 80, name)[1] or nil
			end
			return prompt ~= nil
		end, 8, 0.5)
		if not prompt then
			local hrp = G.hrp()
			local list = {}
			for i, p in ipairs(hrp and G.promptsNear(hrp.Position, 80) or {}) do
				if i > 10 then break end
				list[#list + 1] = ("%s [%s | %s]"):format(p:GetFullName(), p.ActionText, p.ObjectText)
			end
			log(("buy: no display for %s here; prompts nearby: %s"):format(name, #list > 0 and table.concat(list, "; ") or "none"))
			return false
		end
		return buyWithPrompt(prompt, verify, name)
	end

	-- Never pressed while buying: anything in the Robux bait shop (hud.safezone.BuyBait) or showing the Robux sign.
	local ROBUX_SIGN = utf8.char(57346)
	local function robuxButton(button)
		local hud = LP.PlayerGui:FindFirstChild("hud")
		local safezone = hud and hud:FindFirstChild("safezone")
		local robuxShop = safezone and safezone:FindFirstChild("BuyBait")
		if robuxShop and button:IsDescendantOf(robuxShop) then return true end
		return buttonText(button):find(ROBUX_SIGN, 1, true) ~= nil
	end

	-- Fires a shop prompt, then presses the buy/confirm button the game shows until verify() says it worked.
	-- With amount: an amount box that shows up is filled in, and a buy button that mentions the amount is preferred.
	buyWithPrompt = function(prompt, verify, name, amount)
		local before = {}
		for _, b in ipairs(G.visibleButtons()) do before[b] = true end
		-- Only amount boxes that the shop opens get filled; ones already on screen (like this hub's) are left alone.
		local filled = {}
		if amount then
			for _, d in ipairs(LP.PlayerGui:GetDescendants()) do
				if d:IsA("TextBox") and shown(d) then filled[d] = true end
			end
		end
		G.firePrompt(prompt)
		for _ = 1, 20 do
			sleep(0.6)
			if verify() then break end
			if amount then
				for _, d in ipairs(LP.PlayerGui:GetDescendants()) do
					if d:IsA("TextBox") and not filled[d] and shown(d) then
						filled[d] = true
						d.Text = tostring(amount)
						log(("buy: amount box %s set to %d"):format(d:GetFullName(), amount))
					end
				end
			end
			if not G.confirm() then
				local candidates, preferred = {}, nil
				for _, b in ipairs(G.visibleButtons()) do
					if not before[b] and not robuxButton(b) then
						local text = buttonText(b):lower()
						local skip = false
						for _, pattern in ipairs(NOT_BUY) do
							if text:find(pattern) then skip = true end
						end
						if not skip then
							for _, pattern in ipairs(BUY_WORDS) do
								if text:find(pattern) then
									candidates[#candidates + 1] = { button = b, text = text }
									if amount and text:find(tostring(amount), 1, true) then preferred = candidates[#candidates] end
									break
								end
							end
						end
					end
				end
				for _, candidate in ipairs(preferred and { preferred } or candidates) do
					log("buy: pressing \"" .. candidate.text .. "\"")
					G.click(candidate.button)
				end
			end
		end
		local ok = verify()
		log(("buy %s: %s"):format(name, ok and "done" or "didn't go through"))
		return ok
	end

	local function buyRod(rod, price, spotName)
		if G.ownsRod(rod) then return end
		earn(price, rod)
		if not buyFromDisplay(rod, function() return G.ownsRod(rod) end, spotName) then
			error("couldn't buy " .. rod .. " (see the log)", 0)
		end
	end

	-- Relics: have one, ask alts, or (Enchant Relics) buy from Merlin.
	-- Enchanting spends relics with no mutation only (G.unmutated): a mutated one is kept for whatever it's for.
	local function getRelic(relic)
		if G.count(relic, G.unmutated, true) > 0 then return true end
		if askAlts(relic, 1, nil, 60) then return true end
		if relic == "Enchant Relic" then
			earn(48000, "5 Enchant Relics")
			-- Merlin (from the listener): "How may I assist you?" -> "I need power." -> "How many would you like?"
			-- -> "5 (48,000C$)" (5 at once is cheaper than 1 at a time) -> "Thank you for your patronage." -> "See you." A first visit starts his story instead
			-- ("You don't look so happy." ... "Are you up to the task?" "Yes."), so there's a second try after it.
			local MERLIN = { "i need power", "^5 (", "see you", "you don't look so happy", "understood", "yes." }
			for _ = 1, 3 do
				goTo("Merlin")
				G.talk(G.findNpc("Merlin"), MERLIN, 30, true)
				sleep(1)
				if G.count(relic, G.unmutated, true) > 0 then return true end
			end
			return false
		end
		if relic == "Cosmic Relic" then
			-- Starfall Totems drop Cosmic Relics; an alt with one could use it in this server.
			log("no Cosmic Relic: an alt with a Starfall Totem can help")
		end
		return false
	end

	-- The Keepers' Altar only works at night. During the day a Sundial Totem skips to night (one is bought at the
	-- Sundial Totem shop if there's none). Sacred weather like a Rainbow stops totems; then it's fishing for a while
	-- and trying again later.
	local sundialRestUntil = 0
	local function makeNight()
		if G.isNight() then return true end
		if not state.settings.useSundial or os.clock() < sundialRestUntil then return false end
		if G.count("Sundial Totem", nil, true) < 1 then
			earn(5000, "a Sundial Totem")
			setStatus("Sundial Totem", "buying one")
			buyFromDisplay("Sundial Totem", function() return G.count("Sundial Totem", nil, true) > 0 end, "Sundial Totem shop")
		end
		if G.count("Sundial Totem", nil, true) < 1 then
			log("no Sundial Totem to use; waiting for night instead")
			sundialRestUntil = os.clock() + 300
			return false
		end
		setStatus("Sundial Totem", "turning day into night")
		local before = G.count("Sundial Totem", nil, true)
		G.useItem("Sundial Totem")
		if waitFor(G.isNight, 25, 1) then
			log("Sundial Totem used: it's night")
			return true
		end
		G.unhold()
		if G.count("Sundial Totem", nil, true) >= before then
			log("the Sundial Totem couldn't be used (sacred weather like a Rainbow?); trying again in 5 minutes")
		else
			log("a Sundial Totem was used but it's still day; trying again in 5 minutes")
		end
		sundialRestUntil = os.clock() + 300
		return false
	end

	-- Rerolls a rod's enchant at the Keepers' Altar until one of `wanted` lands in `slot`.
	-- The altar needs night, the rod equipped, and the relic in hand (EnchantAltar.lua).
	local ENCHANT_GAP = 5 -- seconds between rolls; rolling again straight away can land while the altar is still busy
	-- maxRolls: stop after that many relics (for rare ones like Cosmic Relics); nil keeps rolling until it lands.
	local function enchant(rod, wanted, relic, slot, maxRolls)
		local rolls = 0
		local function done()
			local current = G.rodEnchant(rod, slot)
			for _, name in ipairs(wanted) do
				if current == name then return true end
			end
			return false
		end
		while not done() do
			if maxRolls and rolls >= maxRolls then
				log(("%s: used %d %s, no %s; leaving it"):format(rod, rolls, relic, table.concat(wanted, "/")))
				return false
			end
			if not getRelic(relic) then
				log(("no %s left for %s on the %s"):format(relic, table.concat(wanted, "/"), rod))
				return false
			end
			if not G.isNight() and not makeNight() then
				-- Still day: fish a while (5 minutes, or until night) and look again.
				setStatus("Waiting for night", "the altar only works at night")
				Fish.start()
				waitFor(G.isNight, 300, 10)
				Fish.stop()
			else
				G.equipRod(rod)
				local altar = goTo("Enchant altar")
				-- Only a relic with no mutation is spent (a mutated one, like the Chaotic Enchant Relic, is kept).
				G.hold(relic, G.unmutated)
				local before = G.count(relic, G.unmutated, true)
				local prompt = G.promptsNear(altar, 60, "enchant")[1] or G.promptsNear(altar, 60)[1]
				G.firePrompt(prompt)
				-- The altar first asks "The Keepers Await ... [Enchant Fishing Rod] [Cancel]" (EnchantAltar.lua), then
				-- shows its own Enchant button (EnchantConfirm); answer both as they show up.
				local used = waitFor(function()
					G.confirm({ "enchant", "yes", "confirm", "okay" })
					local hud = LP.PlayerGui:FindFirstChild("hud")
					local frame = hud and hud:FindFirstChild("safezone") and hud.safezone:FindFirstChild("EnchantConfirm")
					if frame and frame.Visible and frame:FindFirstChild("enchantButton") then G.click(frame.enchantButton) end
					return G.count(relic, G.unmutated, true) < before
				end, 20, 0.8)
				if not used then
					log("enchant: the relic wasn't used (see the prompts above)")
					G.closeMenus()
				end
				G.unhold()
				log(("%s %s is now: %s"):format(rod, slot, tostring(G.rodEnchant(rod, slot))))
				if used then rolls = rolls + 1 end
				if not done() then sleep(ENCHANT_GAP) end
			end
		end
		return true
	end

	local function bestRod()
		return G.equipRod(G.bestRod())
	end

