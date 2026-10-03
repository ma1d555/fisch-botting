	-- [Progression part 07-alts: alts: sharing items and trading. The loader joins the parts in order into one scope.]
	-- ---- alts: sharing items ------------------------------------------------------------------
	--
	-- One account asks for an item (the box in the Alts section, or a step of the plan). The alts in the same server
	-- running this script say how many they can spare, the asker splits the amount between them, and they trade it
	-- over one at a time. Each account only writes its own files in workspace/amethyst/progression:
	--   req-<asker>.json            the request: item and amount, then the plan and whose turn it is
	--   stock-<alt>.json            an alt's answer: how many it can spare, and its C$
	--   give-<alt>.json             an alt's progress on its share
	--   offer-<alt>-<asker>.json    tells the asker a trade request is coming, so it accepts it
	-- Trading follows the game's trade window (ui/Trade): the giver needs a fish in hand and level 15+ to see the
	-- "Request Trade" prompt on the other player, items go in one inventory entry at a time (fish are usually one
	-- entry per catch), and Ready only counts 3 seconds after the offer last changed.

	local Alts = {}

	function Alts.publish()
		local has = {}
		for _, name in ipairs({ "Ruby", "Magic Thread", "Driftwood", "Enchant Relic", "Cosmic Relic", "Exalted Relic", "Meteor Totem", "Starfall Totem", "Megalodon Hunt Totem" }) do
			local n = G.count(name, nil, true)
			if n > 0 then has[name] = n end
		end
		local mythical = G.count("Driftwood", { Mutation = "Mythical" }, true)
		if mythical > 0 then has["Driftwood (Mythical)"] = mythical end
		local needs = {}
		for name, need in pairs(state.needs) do needs[name] = need.qty end
		writeJson(DIR .. "/alt-" .. LP.UserId .. ".json", {
			userId = LP.UserId,
			name = LP.Name,
			jobId = game.JobId,
			sharing = state.settings.shareWithAlts == true,
			t = os.time(),
			level = G.level(),
			coins = G.coins(),
			status = state.status,
			needs = needs,
			has = has,
		})
	end

	function Alts.list()
		local out = {}
		pcall(function()
			for _, file in ipairs(listfiles(DIR)) do
				local id = file:match("alt%-(%d+)%.json$")
				if id and tonumber(id) ~= LP.UserId then
					local alt = readJson(file)
					if type(alt) == "table" and os.time() - (alt.t or 0) < 60 then out[#out + 1] = alt end
				end
			end
		end)
		return out
	end

	-- Other accounts' files of one kind ("req", "stock", "give"), by UserId.
	local function altFiles(kind)
		local out = {}
		pcall(function()
			for _, file in ipairs(listfiles(DIR)) do
				local id = tonumber(file:match(kind .. "%-(%d+)%.json$"))
				if id and id ~= LP.UserId then
					local data = readJson(file)
					if type(data) == "table" then out[id] = data end
				end
			end
		end)
		return out
	end

	local itemLibrary
	local function library()
		if not itemLibrary then
			pcall(function() itemLibrary = require(ReplicatedStorage.shared.modules.library) end)
		end
		return itemLibrary
	end

	local function itemLabel(name, filter)
		return filter and filter.Mutation and (name .. " (" .. filter.Mutation .. ")") or name
	end

	-- "Perch", "perch" or "Driftwood (Mythical)" -> the game's item name and a mutation filter.
	local function parseItem(text)
		text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		local base, mutation = text:match("^(.-)%s*%((.-)%)$")
		base = base or text
		local lib = library()
		local function canonical(list, name)
			if type(list) ~= "table" or not name or name == "" or list[name] then return name end
			local lower = name:lower()
			for key in pairs(list) do
				if type(key) == "string" and key:lower() == lower then return key end
			end
			return name
		end
		local name = canonical(lib and lib.fish, base)
		mutation = mutation and mutation ~= "" and canonical(lib and lib.mutations, mutation) or nil
		return name, mutation and { Mutation = mutation } or nil
	end

	-- This account's inventory entries of an item that the trade window accepts (same rules as ui/Trade), unmutated
	-- ones first when no mutation was asked for.
	local function tradeableEntries(name, filter)
		local out = {}
		local lib = library()
		pcall(function()
			local now = workspace:GetServerTimeNow()
			for key, item in pairs(G.data().InventoryReplicator:Index({ "Inventory" })) do
				local sub = item.sub or {}
				local match = item.name == name
				for field, value in pairs(filter or {}) do
					if sub[field] ~= value then match = false end
				end
				local info = lib and lib.fish and lib.fish[item.name]
				local mutation = sub.Mutation and lib and lib.mutations and lib.mutations[sub.Mutation]
				local locked = sub.CanTradeIn and (sub.CanTradeIn == -1 or sub.CanTradeIn > now)
				if match and info and not info.IsCrate and not info.Untradeable and not locked and not (mutation and mutation.Untradeable) then
					out[#out + 1] = { key = key, stack = tonumber(sub.Stack) or 1, mutated = sub.Mutation ~= nil }
				end
			end
		end)
		table.sort(out, function(a, b) return (not a.mutated) and b.mutated end)
		return out
	end

	local function tradeableCount(name, filter)
		local n = 0
		for _, entry in ipairs(tradeableEntries(name, filter)) do n = n + entry.stack end
		return n
	end

	-- How many this account can give: none while its own plan is busy with something other than fishing or is
	-- keeping that item for itself.
	local function spareOf(name, filter)
		if state.running and state.protected[name] then return 0 end
		return tradeableCount(name, filter)
	end

	-- Trades come first and the progression last: it stops completely for a trade (giving or getting) and starts
	-- again afterwards. Every step checks what's already done, so it carries on where it was. Turning it off in the
	-- meantime keeps it off.
	state.tradePause = 0
	local function withProgressionPaused(fn, ...)
		state.tradePause = state.tradePause + 1
		if state.running and not state.stop then
			log("pausing the progression")
			state.resumeAfterTrade = true
			state.stop = true
			local deadline = os.clock() + 20
			while state.running and os.clock() < deadline do task.wait(0.2) end
		end
		local results = table.pack(pcall(fn, ...))
		state.tradePause = state.tradePause - 1
		if state.tradePause == 0 and state.resumeAfterTrade then
			state.resumeAfterTrade = false
			log("done; the progression carries on")
			Progression.start()
		end
		if not results[1] then
			log("trade stopped: " .. tostring(results[2]))
			return nil
		end
		return table.unpack(results, 2, results.n)
	end

	local function tradeRemote(name) return G.net("RE/Trade/" .. name) end

	-- The trade window's state, from the same events its UI listens to: who's ready (player1Confirmed /
	-- player2Confirmed), and when the offer last changed (Ready only counts 3 seconds after that).
	local tradeOpen, tradeState, offerChangedAt = false, nil, 0
	pcall(function()
		tradeRemote("TradeStarted").OnClientEvent:Connect(function()
			if not alive() then return end
			tradeOpen, tradeState, offerChangedAt = true, nil, os.clock()
			log("trade window opened")
		end)
		tradeRemote("TradeEnded").OnClientEvent:Connect(function()
			if not alive() then return end
			tradeOpen, tradeState = false, nil
			log("trade window closed")
		end)
		tradeRemote("UpdateOfferedItems").OnClientEvent:Connect(function(newState, offerChanged)
			if not alive() then return end
			tradeState = newState
			if offerChanged then offerChangedAt = os.clock() end
		end)
	end)

	local function readyInTrade()
		local s = tradeState
		if type(s) ~= "table" then return nil end -- unknown
		local me = s.player1 == LP and "player1" or "player2"
		return s[me .. "Confirmed"] == true
	end

	-- Our side of an open trade window: put the items in (giver), then keep pressing Ready until it ends.
	local function finishTrade(give)
		local deadline = os.clock() + 25
		while not tradeOpen and os.clock() < deadline do task.wait(0.25) end
		if not tradeOpen then
			log("trade: the window never opened")
			return false
		end
		if give then
			local left = give.qty
			for _, entry in ipairs(tradeableEntries(give.name, give.filter)) do
				if left <= 0 then break end
				local n = math.min(left, entry.stack)
				pcall(function() tradeRemote("AddItem"):FireServer("Item", entry.key, n) end)
				left = left - n
				task.wait(0.3)
			end
			if left == give.qty then
				log("trade: none of " .. itemLabel(give.name, give.filter) .. " to put in; cancelling")
				pcall(function() tradeRemote("CancelTrade"):FireServer() end)
				return false
			end
			log(("trade: offered %d %s"):format(give.qty - left, itemLabel(give.name, give.filter)))
		end
		-- Ready only counts 3 seconds after the offer last changed, and pressing it again restarts the trade's
		-- countdown, so it's pressed once the offer has settled and only again if this side isn't ready any more
		-- (the other side changing the offer un-readies both).
		deadline = os.clock() + 60
		local lastPress = 0
		while tradeOpen and os.clock() < deadline do
			local ready = readyInTrade()
			local settled = os.clock() - offerChangedAt > 3.4
			-- Without the window's state, wait long enough between presses for a countdown to finish.
			local wait = ready == nil and 6 or 1.5
			if settled and ready ~= true and os.clock() - lastPress > wait then
				lastPress = os.clock()
				pcall(function() tradeRemote("SetReady"):FireServer(true) end)
				log("trade: ready")
			end
			task.wait(0.25)
		end
		if tradeOpen then
			log("trade: didn't go through in time; cancelling")
			pcall(function() tradeRemote("CancelTrade"):FireServer() end)
			return false
		end
		return true
	end

	-- Everything a button says: its name and every bit of text on or inside it, lowercased.
	local function buttonWords(button)
		local parts = { button.Name }
		if button:IsA("TextButton") then parts[#parts + 1] = button.Text end
		for _, d in ipairs(button:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") then parts[#parts + 1] = d.Text end
		end
		return (table.concat(parts, " "):gsub("<[^>]+>", ""):lower())
	end

	-- The incoming trade request. `before` holds the buttons that were on screen before it was sent; a new button
	-- that says Accept (or Yes/Confirm inside something named trade or request) is the one. New buttons are logged
	-- once each, so the log shows what the request looked like if none of them matched.
	local GuiService = game:GetService("GuiService")
	local function realClick(button)
		pcall(function()
			local inset = GuiService:GetGuiInset()
			local x = button.AbsolutePosition.X + button.AbsoluteSize.X / 2 + inset.X
			local y = button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2 + inset.Y
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
		end)
	end

	-- Fisch shows a trade request as hud.safezone.bodyannouncements.offer with "confirm [yes]" / "deny [no]".
	-- It's pressed when it's from the alt that announced it (or doesn't say who it's from).
	local function tradeRequestButton(fromName)
		local hud = LP.PlayerGui:FindFirstChild("hud")
		local safezone = hud and hud:FindFirstChild("safezone")
		local announcements = safezone and safezone:FindFirstChild("bodyannouncements")
		local offer = announcements and announcements:FindFirstChild("offer")
		local confirm = offer and offer:FindFirstChild("confirm")
		if not (confirm and confirm:IsA("GuiButton") and shown(confirm)) then return nil end
		local text = buttonWords(offer)
		local from = fromName and Players:FindFirstChild(fromName)
		if from and (text:find(from.Name:lower(), 1, true) or text:find(from.DisplayName:lower(), 1, true)) then return confirm end
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LP and player ~= from and (text:find(player.Name:lower(), 1, true) or text:find(player.DisplayName:lower(), 1, true)) then
				return nil -- someone else's request
			end
		end
		return confirm
	end

	local function acceptTradeRequest(watch)
		local request = tradeRequestButton(watch.from)
		if request then
			local tries = (watch.tries[request] or 0) + 1
			watch.tries[request] = tries
			log(("trade request: pressing confirm (%s)"):format(tries <= 2 and "handlers" or "click"))
			if tries <= 2 then return G.click(request) end
			realClick(request)
			return true
		end
		if G.confirm({ "accept", "yes", "trade" }) then return true end
		for _, button in ipairs(G.visibleButtons()) do
			if not watch.before[button] then
				local words = buttonWords(button)
				if not watch.seen[button] then
					watch.seen[button] = true
					log(("trade request: new button %s \"%s\""):format(button:GetFullName(), words))
				end
				local context = button:GetFullName():lower()
				local tradeBox = context:find("trade", 1, true) or context:find("request", 1, true)
				local says = words:find("accept", 1, true)
					or (tradeBox and (words:find("yes", 1, true) or words:find("confirm", 1, true)))
				if says and not words:find("decline", 1, true) and not words:find("cancel", 1, true) then
					-- Its handlers first; if that doesn't open the trade, a real click on it.
					local tries = (watch.tries[button] or 0) + 1
					watch.tries[button] = tries
					log(("trade request: pressing %s (%s)"):format(button:GetFullName(), tries <= 2 and "handlers" or "click"))
					if tries <= 2 then return G.click(button) end
					realClick(button)
					return true
				end
			end
		end
		return false
	end

	-- Giver: go to the alt, hold a fish so their "Request Trade" prompt shows, send the request, fill the offer,
	-- then go back. Returns how many actually left this account.
	local function giveTo(alt, item, qty, filter)
		local player = Players:GetPlayerByUserId(alt.userId)
		if not player then
			log("trade: " .. tostring(alt.name) .. " isn't in this server")
			return 0
		end
		local function targetParts()
			local character = player.Character
			return character and character:FindFirstChild("HumanoidRootPart"), character and character:FindFirstChild("Torso")
		end
		local hrp = G.hrp()
		local home = hrp and hrp.Position
		local root, torso = targetParts()
		if not (root and torso) and alt.pos then
			-- Players far away aren't loaded on this client (the map streams in around you): go to where the asker
			-- said it's standing and wait for its character to load.
			G.teleport(alt.pos + Vector3.new(4, 0, 0))
			local deadline = os.clock() + 8
			repeat
				task.wait(0.25)
				root, torso = targetParts()
			until (root and torso) or os.clock() > deadline
		end
		if not (root and torso) then
			log("trade: " .. tostring(alt.name) .. "'s character didn't load here")
			if home then G.teleport(home) end
			return 0
		end
		local before = tradeableCount(item, filter)
		G.teleport(root.Position + Vector3.new(3, 0, 0))
		local offerFile = DIR .. ("/offer-%d-%d.json"):format(LP.UserId, alt.userId)
		writeJson(offerFile, { from = LP.UserId, name = LP.Name, item = item, qty = qty, t = os.time() })
		-- The prompt only shows with a fish in hand: the item being given, else the first fish that works.
		local offer = torso:FindFirstChild("TradeOffer")
		if not (offer and offer.Enabled) then
			pcall(G.hold, item, filter)
			task.wait(0.6)
		end
		for _, tool in ipairs(LP.Backpack:GetChildren()) do
			if offer and offer.Enabled then break end
			if tool:IsA("Tool") and tool:FindFirstChild("link") then
				pcall(G.hold, tool.Name)
				task.wait(0.6)
			end
		end
		local given = 0
		if offer and offer.Enabled then
			G.firePrompt(offer)
			finishTrade({ name = item, qty = qty, filter = filter })
			task.wait(1)
			given = math.max(0, before - tradeableCount(item, filter))
			log(("trade with %s: gave %d/%d %s"):format(alt.name, given, qty, itemLabel(item, filter)))
		else
			log("trade: no Request Trade prompt on " .. alt.name .. " (needs a fish in hand and level 15+)")
			pcall(delfile, offerFile)
		end
		G.unhold()
		if home then G.teleport(home) end
		return given
	end

	-- Receiver: accept trade requests from alts that announced one, then press Ready until the trade goes through.
	local accepting = false
	local function acceptOffers()
		if accepting then return end
		accepting = true
		pcall(function()
			for _, file in ipairs(listfiles(DIR)) do
				local from = file:match("offer%-(%d+)%-" .. LP.UserId .. "%.json$")
				local offer = from and readJson(file)
				if type(offer) == "table" and os.time() - (tonumber(offer.t) or 0) < 60 then
					pcall(delfile, file)
					log(("%s is sending %d %s; accepting"):format(tostring(offer.name or from), tonumber(offer.qty) or 1, tostring(offer.item)))
					-- The request hasn't arrived yet (the alt writes this file first), so what's on screen now isn't it.
					local watch = { before = {}, seen = {}, tries = {}, from = offer.name }
					for _, button in ipairs(G.visibleButtons()) do watch.before[button] = true end
					local deadline = os.clock() + 25
					while not tradeOpen and os.clock() < deadline do
						acceptTradeRequest(watch)
						task.wait(0.5)
					end
					if tradeOpen then finishTrade(nil) else log("trade: the request never showed up") end
				end
			end
		end)
		accepting = false
	end

	-- Who gives what. One alt that has enough gives it all (one trade instead of several); if none does, the alts
	-- with the most C$ give first, each as much as it has, until the amount is covered.
	local function planShares(stocks, qty)
		table.sort(stocks, function(a, b) return a.coins > b.coins end)
		for _, stock in ipairs(stocks) do
			if stock.count >= qty then return { { userId = stock.userId, name = stock.name, qty = qty } } end
		end
		local plan, left = {}, qty
		for _, stock in ipairs(stocks) do
			if left <= 0 then break end
			local n = math.min(stock.count, left)
			plan[#plan + 1] = { userId = stock.userId, name = stock.name, qty = n }
			left = left - n
		end
		return plan
	end

	local SHARE_ANSWER_SECONDS = 6 -- how long alts get to say what they have
	local SHARE_TURN_SECONDS = 120 -- how long one alt gets to hand its share over
	local REQ_FILE = DIR .. "/req-" .. LP.UserId .. ".json"
	local sharing = false

	-- Whether Fisch lets an item be traded: the trade window only lists entries of library.fish that aren't crates
	-- or untradeable. Totems, threads and crates can't be.
	local function canTrade(name)
		local lib = library()
		if not (lib and lib.fish) then return true end -- library unreadable: let the alts decide
		local info = lib.fish[name]
		return info ~= nil and not info.IsCrate and not info.Untradeable
	end

	-- Asker. action "give" (default): gets `qty` more of an item traded over, returns how many arrived.
	-- action "use": items that can't be traded but work for whoever's nearby (totems): an alt comes over and uses
	-- them next to us; returns how many were used.
	local function requestFromAlts(name, qty, filter, action)
		action = action or "give"
		if sharing then
			setStatus("Sharing", "already getting something from alts")
			return 0
		end
		sharing = true
		local label = itemLabel(name, filter)
		local verb = action == "use" and "use" or "give"
		-- Inventory and storage: a traded item can land in either.
		local before = G.count(name, filter)
		local delivered = 0
		local req = {
			id = ("%d-%d-%d"):format(LP.UserId, os.time(), math.random(1000, 9999)),
			from = LP.UserId, name = LP.Name, jobId = game.JobId, action = action,
			item = name, mutation = filter and filter.Mutation, qty = qty,
			phase = "asking", t = os.time(),
		}
		state.needs[label] = { qty = qty }
		local ok, err = pcall(function()
			writeJson(REQ_FILE, req)
			setStatus("Sharing", ("asking alts in this server to %s %d %s"):format(verb, qty, label))
			task.wait(SHARE_ANSWER_SECONDS)
			local stocks, answers = {}, {}
			for userId, stock in pairs(altFiles("stock")) do
				if stock.req == req.id then
					local count = tonumber(stock.count) or 0
					answers[#answers + 1] = ("%s %d"):format(tostring(stock.name), count)
					if count > 0 then
						stocks[#stocks + 1] = { userId = userId, name = tostring(stock.name), count = count, coins = tonumber(stock.coins) or 0 }
					end
				end
			end
			log(("share %s: answers: %s"):format(label, #answers > 0 and table.concat(answers, ", ") or "none"))
			local plan = planShares(stocks, qty)
			if #plan == 0 then
				setStatus("Sharing", ("no alt in this server has %s to %s"):format(label, action == "use" and "use" or "spare"))
				return
			end
			req.phase, req.plan = "giving", plan
			for i, share in ipairs(plan) do
				req.turn, req.t = i, os.time()
				-- Where to find us: alts far away don't have our character loaded.
				local hrp = G.hrp()
				req.pos = hrp and { math.floor(hrp.Position.X), math.floor(hrp.Position.Y), math.floor(hrp.Position.Z) } or nil
				writeJson(REQ_FILE, req)
				setStatus("Sharing", ("%s is %s %d %s (%d/%d)"):format(share.name, action == "use" and "using" or "giving", share.qty, label, i, #plan))
				local deadline = os.clock() + SHARE_TURN_SECONDS
				local result
				repeat
					if action == "give" then acceptOffers() end
					local progress = altFiles("give")[share.userId]
					if progress and progress.req == req.id and progress.turn == i and progress.state ~= "giving" then result = progress end
					if not result then task.wait(1) end
				until result or os.clock() > deadline
				delivered = delivered + (result and tonumber(result.given) or 0)
				log(("share %s: %s %s"):format(label, share.name, result and (verb .. " " .. tostring(result.given)) or "didn't answer in time"))
			end
			if action == "use" then
				setStatus(delivered >= qty and "Sharing done" or "Sharing came up short", ("alts used %d/%d %s here"):format(delivered, qty, label))
				return
			end
			-- The inventory updates a moment after the trade window closes.
			local deadline = os.clock() + 6
			while G.count(name, filter) - before < qty and os.clock() < deadline do task.wait(0.5) end
			local got = math.max(0, G.count(name, filter) - before)
			setStatus(got >= qty and "Sharing done" or "Sharing came up short", ("got %d/%d %s"):format(got, qty, label))
		end)
		req.phase, req.t = "done", os.time()
		writeJson(REQ_FILE, req)
		state.needs[label] = nil
		sharing = false
		if not ok then setStatus("Sharing stopped", tostring(err)) end
		if action == "use" then return delivered end
		return math.max(0, G.count(name, filter) - before)
	end

	-- Giver for "use" requests: go to the asker, use the item there, come back. Returns how many were used.
	local function useFor(alt, item, qty)
		local hrp = G.hrp()
		local home = hrp and hrp.Position
		if alt.pos then G.teleport(alt.pos + Vector3.new(6, 0, 0)) end
		local before = G.count(item, nil, true)
		for _ = 1, qty do
			G.useItem(item)
			task.wait(1)
		end
		G.unhold()
		task.wait(1)
		local used = math.max(0, before - G.count(item, nil, true))
		log(("used %d/%d %s for %s"):format(used, qty, item, tostring(alt.name)))
		if home then G.teleport(home) end
		return used
	end

	-- Giver: answer requests from alts in this server and hand over (or use) our share when it's our turn.
	local answered, handled = {}, {}
	local function serveRequests()
		if not state.settings.shareWithAlts or sharing then return end
		for _, req in pairs(altFiles("req")) do
			local fresh = req.jobId == game.JobId and os.time() - (tonumber(req.t) or 0) < 300 and req.phase ~= "done"
			local filter = req.mutation and { Mutation = req.mutation } or nil
			local using = req.action == "use"
			if fresh and req.phase == "asking" and req.id and not answered[req.id] then
				answered[req.id] = true
				local spare
				if using then
					spare = (state.running and state.protected[req.item]) and 0 or G.count(req.item, filter, true)
				else
					spare = spareOf(req.item, filter)
				end
				writeJson(DIR .. "/stock-" .. LP.UserId .. ".json", { req = req.id, name = LP.Name, count = spare, coins = G.coins(), t = os.time() })
				log(("%s asked me to %s %s %s; I have %d"):format(tostring(req.name), using and "use" or "give", tostring(req.qty), itemLabel(req.item, filter), spare))
			elseif fresh and req.phase == "giving" and type(req.plan) == "table" and req.turn then
				local share = req.plan[req.turn]
				local key = tostring(req.id) .. "#" .. tostring(req.turn)
				if type(share) == "table" and share.userId == LP.UserId and not handled[key] then
					handled[key] = true
					local progressFile = DIR .. "/give-" .. LP.UserId .. ".json"
					writeJson(progressFile, { req = req.id, turn = req.turn, state = "giving", t = os.time() })
					-- The progression stops for this; we come back to where we were before it starts again.
					local pos = type(req.pos) == "table" and #req.pos == 3 and Vector3.new(req.pos[1], req.pos[2], req.pos[3]) or nil
					local asker = { userId = req.from, name = req.name, pos = pos }
					local given
					if using then
						given = withProgressionPaused(useFor, asker, req.item, share.qty)
					else
						given = withProgressionPaused(giveTo, asker, req.item, share.qty, filter)
					end
					given = tonumber(given) or 0
					writeJson(progressFile, { req = req.id, turn = req.turn, state = given >= share.qty and "done" or "short", given = given, t = os.time() })
				end
			end
		end
	end

	-- Called by the plan: ask the alts for what's missing (only items Fisch lets you trade).
	local function askAlts(item, qty, filter)
		if not state.settings.shareWithAlts then return false end
		if not canTrade(item) then
			log(item .. " can't be traded in Fisch; not asking alts")
			return false
		end
		local got = requestFromAlts(item, qty, filter)
		checkStop()
		return got >= qty
	end

	-- The "Get it from my alts" button. Totems can't be traded, so for those an alt comes over and uses it here.
	-- The progression stops while this happens.
	function Progression.shareRequest(text, amount)
		local name, filter = parseItem(text)
		if name == "" then
			setStatus("Sharing", "type an item name first")
			return
		end
		amount = math.max(1, math.floor(tonumber(amount) or 1))
		if canTrade(name) then
			withProgressionPaused(requestFromAlts, name, amount, filter)
		elseif name:find("Totem", 1, true) then
			withProgressionPaused(requestFromAlts, name, amount, nil, "use")
		else
			setStatus("Sharing", name .. " isn't tradeable (check the name; threads, totems and crates can't be traded)")
		end
	end

	-- ---- servers (user): hop to another public server, or join one by its job ID ---------------------------------
	-- From the Fishing tab it's just this account. From the Alts section the alts sharing items (theirs on) come too:
	-- the server goes in hop.json and their background loop takes them there. The script is queued to run again after
	-- the teleport (queue_on_teleport), so the alts keep sharing there, and a progression that was running carries on.
	Alts.hopFile = DIR .. "/hop.json"
	function Alts.teleport(placeId, jobId)
		local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
		if queue then pcall(queue, getgenv().NovaQueueSource or 'loadstring(readfile("nova/loader.lua"))()') end
		if state.running then
			state.settings.resumeAfterHop = os.time()
			saveSettings()
		end
		local ok, err = pcall(function()
			game:GetService("TeleportService"):TeleportToPlaceInstance(placeId or game.PlaceId, jobId, LP)
		end)
		if not ok then
			state.settings.resumeAfterHop = nil
			saveSettings()
			setStatus("Servers", "couldn't join: " .. tostring(err))
		end
		return ok
	end
	function Progression.joinServer(jobId, withAlts)
		jobId = tostring(jobId or ""):gsub("%s+", "")
		if jobId == "" then
			setStatus("Servers", "enter a job ID first")
			return
		end
		if withAlts then
			writeJson(Alts.hopFile, { jobId = jobId, placeId = game.PlaceId, from = LP.UserId, name = LP.Name, t = os.time() })
			log("server: the alts sharing items are coming to " .. jobId)
		end
		if jobId == game.JobId then
			setStatus("Servers", "already in that server")
			return
		end
		setStatus("Servers", "joining server " .. jobId)
		Alts.teleport(game.PlaceId, jobId)
	end
	-- Another public server with room for everyone going (the Roblox games API, no login), picked at random.
	function Progression.serverHop(withAlts)
		local going = 1
		if withAlts then
			for _, alt in ipairs(Alts.list()) do
				if alt.sharing then going = going + 1 end
			end
		end
		setStatus("Servers", "looking for a server with room for " .. going)
		local ok, data = pcall(function()
			local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"):format(game.PlaceId)
			return HttpService:JSONDecode(game:HttpGet(url))
		end)
		local choices = {}
		for _, s in ipairs(ok and type(data) == "table" and type(data.data) == "table" and data.data or {}) do
			local playing, max = tonumber(s.playing), tonumber(s.maxPlayers)
			if type(s.id) == "string" and s.id ~= game.JobId and playing and max and max - playing >= going then
				choices[#choices + 1] = s.id
			end
		end
		if #choices == 0 then
			setStatus("Servers", ok and ("no other public server with room for " .. going) or "couldn't get the server list")
			return
		end
		Progression.joinServer(choices[math.random(#choices)], withAlts)
	end
	-- An alt's side: a server the alts were sent to in the last 2 minutes by another account, while sharing is on.
	function Alts.followHop()
		if not state.settings.shareWithAlts then return end
		local hop = readJson(Alts.hopFile)
		if type(hop) ~= "table" or hop.from == LP.UserId or type(hop.jobId) ~= "string" then return end
		if os.time() - (tonumber(hop.t) or 0) > 120 or hop.jobId == game.JobId or Alts.followed == hop.t then return end
		Alts.followed = hop.t
		setStatus("Servers", ("following %s to server %s"):format(tostring(hop.name), hop.jobId))
		Alts.teleport(hop.placeId, hop.jobId)
	end

	-- Background: keep our status file fresh (every 5s), answer alts' requests and follow a server hop (every second).
	local function altsLoop()
		local lastPublish = 0
		while alive() do
			if os.clock() - lastPublish > 5 then
				lastPublish = os.clock()
				pcall(Alts.publish)
			end
			pcall(serveRequests)
			pcall(Alts.followHop)
			task.wait(1)
		end
	end

