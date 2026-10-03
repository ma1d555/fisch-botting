	-- [Progression part 04-dialogue: game notices, NPC dialogue, holding and using items, crafting. The loader joins the parts in order into one scope.]
	-- The game's own notices (thought bubbles like "Maybe search the other islands") and puzzle button updates,
	-- logged while state.watchNotices is on.
	pcall(function()
		G.event("anno_thought").OnClientEvent:Connect(function(text)
			if not alive() then return end
			if state.watchNotices then log("game says: " .. tostring(text):gsub("<[^>]+>", "")) end
		end)
	end)
	pcall(function()
		G.net("RE/PuzzleButtonService/UpdateState").OnClientEvent:Connect(function(name, on)
			if not alive() then return end
			if state.watchNotices then log(("button update: %s is %s"):format(tostring(name), on and "on" or "off")) end
		end)
	end)

	-- When the server starts a conversation (events.dialogstart, the event the game's Dialog script listens to).
	-- Lets talk() tell "the NPC didn't answer" apart from "it answered but the game didn't show it".
	local lastDialog = { at = 0, npc = nil }
	pcall(function()
		G.event("dialogstart").OnClientEvent:Connect(function(context)
			if not alive() then return end
			if type(context) == "table" and typeof(context.npc) == "Instance" then
				lastDialog.at, lastDialog.npc = os.clock(), context.npc
			end
		end)
	end)

	-- NPC dialogue (Dialog.lua) has two layouts, picked by the UseNewDialogueUI attribute:
	--   default: PlayerGui.options.safezone["<n>option"], a frame whose .button is clicked and .text says ["..."]
	--   new:     hud.safezone.options.responses["<n>option"], TextButtons saying ["..."]
	local function optionText(text)
		return (text:gsub("<[^>]+>", ""):gsub('^%[%"', ""):gsub('%"%]$', ""):lower())
	end

	function G.dialogOptions()
		local out = {}
		local classic = LP.PlayerGui:FindFirstChild("options")
		local classicZone = classic and classic:FindFirstChild("safezone")
		for _, frame in ipairs(classicZone and classicZone:GetChildren() or {}) do
			local button = frame:FindFirstChild("button")
			local label = frame:FindFirstChild("text")
			if frame.Name:match("^%d+option$") and frame.Visible and button and button:IsA("GuiButton") and label and label:IsA("TextLabel") then
				out[#out + 1] = { n = tonumber(frame.Name:match("^%d+")), button = button, text = optionText(label.Text) }
			end
		end
		local hud = LP.PlayerGui:FindFirstChild("hud")
		local safezone = hud and hud:FindFirstChild("safezone")
		for _, root in ipairs({ classic or false, safezone and safezone:FindFirstChild("options") or false }) do
			local responses = root and root:FindFirstChild("responses")
			for _, b in ipairs(responses and responses:GetChildren() or {}) do
				if b:IsA("TextButton") and b.Visible and b.Name:match("^%d+option$") then
					out[#out + 1] = { n = tonumber(b.Name:match("^%d+")), button = b, text = optionText(b.Text) }
				end
			end
		end
		table.sort(out, function(a, b) return (a.n or 0) < (b.n or 0) end)
		return out
	end

	-- An NPC by tag or name. With `near` (a position), the closest of them: some NPCs, like the Songstress, stand in
	-- more than one place.
	function G.findNpc(name, tag, near)
		local found = {}
		if tag then
			for _, inst in ipairs(CollectionService:GetTagged(tag)) do
				if inst:IsA("Model") and inst:IsDescendantOf(workspace) then found[#found + 1] = inst end
			end
		end
		local world = workspace:FindFirstChild("world")
		local npcs = world and world:FindFirstChild("npcs")
		if not near then return found[1] or (npcs and npcs:FindFirstChild(name, true)) or nil end
		for _, inst in ipairs(npcs and npcs:GetDescendants() or {}) do
			if inst.Name == name and inst:IsA("Model") then found[#found + 1] = inst end
		end
		local best, bestDistance = nil, math.huge
		for _, inst in ipairs(found) do
			local ok, pos = pcall(function() return inst:GetPivot().Position end)
			if ok and (pos - near).Magnitude < bestDistance then best, bestDistance = inst, (pos - near).Magnitude end
		end
		return best
	end

	-- Presses a prompt's key the way you do: standing just in front of it, facing it. Some prompts (Merlin's) start
	-- nothing through fireproximityprompt but work like this.
	-- Which prompts the game is showing right now (ProximityPromptService's own shown/hidden events).
	local shownPrompts = setmetatable({}, { __mode = "k" })
	local PromptService = game:GetService("ProximityPromptService")
	pcall(function()
		PromptService.PromptShown:Connect(function(p) shownPrompts[p] = true end)
		PromptService.PromptHidden:Connect(function(p) shownPrompts[p] = nil end)
	end)

	-- how: "key" (default) the real key, like a player; "hold" the prompt's own InputHoldBegin/End (what the game's
	-- prompt UI calls; doesn't depend on the keyboard reaching the game, e.g. with the F9 console focused);
	-- "handler" the prompt's Triggered handlers on this side, run as the game (for prompts the game handles here).
	-- closeUp: stand 3 studs from it at its own height instead of dropping to the ground nearby (for buttons: the
	-- server can be stricter about distance than the prompt showing on screen is).
	function G.pressPrompt(prompt, how, closeUp)
		how = how or "key"
		local pos = positionOf(prompt)
		local hrp = G.hrp()
		if not (pos and hrp) then return false end
		local range = math.max(3, (tonumber(prompt.MaxActivationDistance) or 10) - 3)
		if closeUp then
			local away = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)
			if away.Magnitude < 1 then away = Vector3.new(0, 0, 1) end
			local standAt = pos + away.Unit * 3
			pcall(function() LP:RequestStreamAroundAsync(standAt, 2) end)
			hrp.CFrame = CFrame.lookAt(standAt, Vector3.new(pos.X, standAt.Y, pos.Z))
			hrp.AssemblyLinearVelocity = Vector3.zero
			task.wait(0.5) -- the server catches up with where you are
		elseif (hrp.Position - pos).Magnitude > range then
			local away = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)
			if away.Magnitude < 1 then away = Vector3.new(0, 0, 1) end
			G.teleport(pos + away.Unit * math.min(4, range))
		end
		hrp = G.hrp()
		if hrp then hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(pos.X, hrp.Position.Y, pos.Z)) end
		-- The key goes to whichever prompt the game is showing, so for this press (on this client only): other
		-- prompts on the same key close by are switched off, this one doesn't need a clear line of sight, and
		-- prompts are switched back on if a conversation left them off.
		local character = LP.Character
		if not (character and character:FindFirstChild("dialoglink")) then pcall(function() PromptService.Enabled = true end) end
		local muted, parked = {}, {}
		for _, other in ipairs(G.promptsNear(pos, 25)) do
			if other ~= prompt and other.KeyboardKeyCode == prompt.KeyboardKeyCode then
				muted[#muted + 1] = other
				pcall(function() other.Enabled = false end)
				-- closeUp (buttons): the NPC or shop display the other prompt belongs to is taken out of the world on
				-- this client for the press (a Glider display and Ashe next to the Roslit button kept it from taking),
				-- and put back afterwards.
				if closeUp then
					local world = workspace:FindFirstChild("world")
					local node = other
					while node and node.Parent and node.Parent ~= workspace and not (world and (node.Parent.Parent == world)) do
						node = node.Parent
					end
					local holder = node and node.Parent
					if node and holder and world and holder.Parent == world and (holder.Name == "npcs" or holder.Name == "interactables") then
						local already = false
						for _, p in ipairs(parked) do
							if p.model == node then already = true end
						end
						if not already then
							parked[#parked + 1] = { model = node, parent = holder }
							pcall(function() node.Parent = nil end)
						end
					end
				end
			end
		end
		local lineOfSight = prompt.RequiresLineOfSight
		pcall(function() prompt.RequiresLineOfSight = false end)
		local showing = waitFor(function() return shownPrompts[prompt] == true end, 2, 0.1)
		if not showing then log(("%s isn't showing on screen; pressing anyway"):format(prompt:GetFullName())) end
		local key = prompt.KeyboardKeyCode
		local hold = (tonumber(prompt.HoldDuration) or 0) + 0.15
		if how == "hold" then
			pcall(function()
				prompt:InputHoldBegin()
				task.wait(hold)
				prompt:InputHoldEnd()
			end)
		elseif how == "handler" then
			local ok, conns = pcall(function() return getconnections and getconnections(prompt.Triggered) end)
			for _, conn in ipairs(ok and type(conns) == "table" and conns or {}) do
				local fn
				pcall(function() fn = conn.Function end)
				if type(fn) == "function" then
					task.spawn(function()
						if G.setIdentity then pcall(G.setIdentity, 2) end
						local good, err = pcall(fn, LP)
						if not good then log("prompt handler failed: " .. tostring(err)) end
					end)
				end
			end
		else
			pcall(function()
				VirtualInputManager:SendKeyEvent(true, key, false, game)
				task.wait(hold)
				VirtualInputManager:SendKeyEvent(false, key, false, game)
			end)
		end
		task.wait(0.2)
		for _, p in ipairs(parked) do pcall(function() p.model.Parent = p.parent end) end
		for _, other in ipairs(muted) do pcall(function() other.Enabled = true end) end
		pcall(function() prompt.RequiresLineOfSight = lineOfSight end)
		local mutedNames = {}
		for i, other in ipairs(muted) do
			if i <= 3 then mutedNames[#mutedNames + 1] = other:GetFullName() .. " [" .. other.ActionText .. "]" end
		end
		log(("pressed %s (%s) on %s [%s %s]%s"):format(key.Name, how, prompt:GetFullName(), prompt.ActionText, prompt.ObjectText,
			#muted > 0 and (" (muted: %s%s)"):format(table.concat(mutedNames, ", "), #parked > 0 and ("; %d moved out of the way"):format(#parked) or "") or ""))
		return true
	end

	-- Skipping lines the way a click does. The game's Dialog script (its UserInputService.InputBegan handler) skips the
	-- line being typed, and the pause after it, when you click while a line is playing; a click while the answers are
	-- up does nothing. That handler is called here with a made-up left click, so nothing is really clicked and no
	-- answer can be hit by accident.
	local dialogSkip
	function G.skipDialog()
		if dialogSkip == nil then
			dialogSkip = false
			local ok, conns = pcall(function() return getconnections(game:GetService("UserInputService").InputBegan) end)
			for _, conn in ipairs(ok and type(conns) == "table" and conns or {}) do
				local fn
				pcall(function() fn = conn.Function end)
				local source = type(fn) == "function" and select(2, pcall(debug.info, fn, "s"))
				if type(source) == "string" and source:match("%.Dialog$") then
					dialogSkip = fn
					break
				end
			end
			log(dialogSkip and "dialogue: skipping lines like a click does" or "dialogue: couldn't find the game's skip; lines play at normal speed")
		end
		if not dialogSkip then return end
		task.spawn(function()
			if G.setIdentity then pcall(G.setIdentity, 2) end
			pcall(dialogSkip, { UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown }, false)
		end)
	end

	-- Starts a conversation and picks answers containing any of the given words (in order of preference).
	-- With strict, an answer is only picked if it matches (for shops, where the first option could buy something
	-- else); otherwise the first one keeps a story conversation going. Returns the answers it picked.
	-- opts: once = each word is used at most once (a "Sure." that pays can't be picked a second time); stay = never
	-- teleport (walking away ends a conversation), so no fireproximityprompt fallback; quick = done as soon as the
	-- conversation closes after an answer.
	-- Lines are skipped the way a click skips them (G.skipDialog); the answers are only ever picked by text.
	function G.talk(npc, answers, seconds, strict, opts)
		opts = opts or {}
		if not npc then return {} end
		G.closeMenus()
		local prompt = npc:FindFirstChild("dialogprompt") or npc:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not prompt then
			log("talk: " .. npc.Name .. " has no prompt")
			return {}
		end
		-- Empty hands (holding a rod or relic can keep a conversation from starting), and note what's on screen so
		-- a shop menu that opens instead of a conversation can be told apart.
		G.unhold()
		-- The game turns the NPC's prompt off during a conversation and back on when it ends.
		waitFor(function() return prompt.Enabled end, 3, 0.1)
		local before, seen, pressed = {}, {}, {}
		for _, b in ipairs(G.visibleButtons()) do before[b] = true end
		local started = os.clock()
		local deadline = started + (seconds or 30)
		-- Ways to start it, one every few seconds until something happens: the key press, fireproximityprompt, the
		-- key press again after closing anything left open.
		local attempts = {
			function() G.pressPrompt(prompt, "hold") end,
			function() G.pressPrompt(prompt, "key") end,
			function()
				if opts.stay then G.pressPrompt(prompt, "hold") else G.firePrompt(prompt) end
			end,
			function()
				G.closeMenus()
				G.pressPrompt(prompt, "key")
			end,
		}
		local attempt, lastAttempt = 1, os.clock()
		attempts[1]()
		local picked, used, clicked = {}, {}, {}
		local wasTalking, lastOptions, quiet = false, "", 0
		while os.clock() < deadline do
			checkStop()
			local character = LP.Character
			local talking = character and character:FindFirstChild("dialoglink") ~= nil
			if talking ~= wasTalking then
				log(("talk %s: conversation %s"):format(npc.Name, talking and "open" or "closed"))
				wasTalking = talking
			end
			local options = G.dialogOptions()
			-- Answers already clicked that are still on screen: the game hasn't moved on yet, so nothing is picked.
			local stale = false
			for _, option in ipairs(options) do
				if clicked[option.button] then stale = true end
			end
			if stale then
				sleep(0.3)
			elseif #options > 0 then
				quiet = 0
				local texts = {}
				for _, option in ipairs(options) do texts[#texts + 1] = "\"" .. option.text .. "\"" end
				local list = table.concat(texts, ", ")
				if list ~= lastOptions then
					log(("talk %s: answers %s"):format(npc.Name, list))
					lastOptions = list
				end
				local choice, choiceWord
				for _, word in ipairs(answers or {}) do
					for _, option in ipairs((opts.once and used[word]) and {} or options) do
						-- A word starting with ^ has to be the start of the answer ("^5 (" must not match "25 (").
						local w = word:lower()
						local fits = w:sub(1, 1) == "^" and option.text:sub(1, #w - 1) == w:sub(2) or (w:sub(1, 1) ~= "^" and option.text:find(w, 1, true))
						if fits then
							choice, choiceWord = option, word
							break
						end
					end
					if choice then break end
				end
				if not choice and strict then
					log(("talk %s: none of the answers fit; leaving it"):format(npc.Name))
					break
				end
				choice = choice or options[1]
				if choiceWord then used[choiceWord] = true end
				log("talk " .. npc.Name .. ": picked \"" .. choice.text .. "\"")
				picked[#picked + 1] = choice.text
				clicked[choice.button] = true
				-- The answer's own handler, run as a normal game script so it can load the next line. Without a way to set
				-- that, a real click on it instead (the answers float over your character).
				if G.setIdentity then
					G.click(choice.button)
				else
					local torso = character and (character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart"))
					G.pressButton(choice.button, torso and torso.Position)
				end
				lastOptions = ""
				sleep(opts.quick and 0.8 or 1.2)
			else
				-- A line is playing: skip it like a click would.
				if talking then G.skipDialog() end
				G.confirm()
				-- A shop menu instead of a conversation: new buttons are logged, and in strict mode one that says the
				-- first answer (e.g. "relic") is pressed.
				for _, b in ipairs(G.visibleButtons()) do
					if not before[b] then
						local words = buttonText(b):lower()
						if not seen[b] then
							seen[b] = true
							seen.n = (seen.n or 0) + 1
							local backpack = LP.PlayerGui:FindFirstChild("backpack")
							if seen.n <= 10 and not (backpack and b:IsDescendantOf(backpack)) then
								log(("talk %s: new button %s \"%s\""):format(npc.Name, b:GetFullName(), words))
							end
						end
						if strict and answers and answers[1] and not pressed[b] and words:find(answers[1]:lower(), 1, true) then
							pressed[b] = true
							log(("talk %s: pressing \"%s\""):format(npc.Name, words))
							picked[#picked + 1] = words
							G.click(b)
						end
					end
				end
				sleep(talking and 0.2 or 0.5)
				if #picked == 0 and not talking and os.clock() - lastAttempt > 3.5 then
					if attempt < #attempts then
						attempt = attempt + 1
						lastAttempt = os.clock()
						local came = lastDialog.npc == npc and lastDialog.at >= started
						log(("talk %s: nothing opened yet (%s); trying again"):format(npc.Name,
							came and "the conversation came in but didn't show" or "no conversation came back"))
						attempts[attempt]()
					else
						break
					end
				end
				-- After an answer, the conversation is over once it closes.
				if #picked > 0 and not talking then
					quiet = quiet + 1
					if quiet >= (opts.quick and 1 or 4) then break end
				end
			end
		end
		if #picked == 0 then log("talk " .. npc.Name .. ": no answers showed up") end
		return picked
	end

	function G.tool(name)
		local char = LP.Character
		return (char and char:FindFirstChild(name)) or LP.Backpack:FindFirstChild(name)
	end

	-- Puts an item in hand the way the Backpack UI does: equip its Tool if one exists, otherwise ask the server for it
	-- with Backpack/Equip(inventoryKey), which hands the Tool over. With a filter (a particular mutation), always
	-- the latter: a Tool of that name could be another one of them.
	function G.hold(name, filter)
		local humanoid = G.humanoid()
		if not humanoid then return false end
		local held = LP.Character:FindFirstChildOfClass("Tool")
		if held and held.Name == name and not filter then return true end
		local tool = not filter and LP.Backpack:FindFirstChild(name)
		if tool then
			humanoid:EquipTool(tool)
		else
			local key = G.itemKey(name, filter)
			local remote = G.net("RE/Backpack/Equip")
			if not (key and remote) then
				log("hold: no " .. name .. " in the inventory")
				return false
			end
			pcall(remote.FireServer, remote, key)
		end
		local ok = waitFor(function()
			local t = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
			return t and t.Name == name
		end, 5, 0.2)
		log((ok and "holding " or "couldn't hold ") .. name)
		return ok
	end

	function G.unhold()
		local humanoid = G.humanoid()
		if humanoid then humanoid:UnequipTools() end
	end

	function G.useItem(name)
		if not G.hold(name) then return false end
		local tool = LP.Character:FindFirstChildOfClass("Tool")
		pcall(function() tool:Activate() end)
		sleep(1)
		G.confirm()
		-- Some items ask in the game's own prompt (PlayerGui.over.prompt) rather than the yes/no box.
		local over = LP.PlayerGui:FindFirstChild("over")
		local prompt = over and over:FindFirstChild("prompt")
		if prompt and prompt:FindFirstChild("confirm") then G.click(prompt.confirm) end
		log("used " .. name)
		return true
	end

	-- Closes what an interaction can leave open: the altar's enchant box, an amount/open prompt, a yes/no box.
	-- Something left open can stop the next conversation from showing.
	function G.closeMenus()
		pcall(function()
			local hud = LP.PlayerGui:FindFirstChild("hud")
			local safezone = hud and hud:FindFirstChild("safezone")
			local enchantBox = safezone and safezone:FindFirstChild("EnchantConfirm")
			if enchantBox and enchantBox.Visible and enchantBox:FindFirstChild("cancelButton") then
				G.click(enchantBox.cancelButton)
				log("closed the altar's enchant box")
			end
			local over = LP.PlayerGui:FindFirstChild("over")
			local prompt = over and over:FindFirstChild("prompt")
			if prompt and prompt:FindFirstChild("deny") then
				G.click(prompt.deny)
				log("closed an open prompt")
			end
			G.confirm({ "[cancel]", "[no]" })
		end)
	end

	function G.claimDaily()
		local remote = G.net("RE/DailyReward/Claim")
		if remote then pcall(remote.FireServer, remote) end
		log("claimed daily reward (if available)")
	end

	function G.isNight()
		local world = ReplicatedStorage:FindFirstChild("world")
		local cycle = world and world:FindFirstChild("cycle")
		return cycle and cycle.Value == "Night"
	end

	-- Crafting (CraftingController): events.AttemptCraft:InvokeServer(recipeName) -> success, message.
	function G.craft(recipe)
		local remote = G.event("AttemptCraft")
		if not remote then return false, "AttemptCraft missing" end
		local ok, success, message = pcall(remote.InvokeServer, remote, recipe)
		log(("craft %s: %s %s"):format(recipe, tostring(ok and success), tostring(message)))
		return ok and success, message
	end

	-- Catches, from the same announcement the hub's AutoSell listens to (a plain event listener, not a hook).
	pcall(function()
		local announce = G.event("anno_catch")
		announce.OnClientEvent:Connect(function(fish)
			if not alive() then return end
			state.catches = state.catches + 1
			local name = type(fish) == "table" and tostring(fish.Name or "?") or "?"
			state.caught[name] = (state.caught[name] or 0) + 1
			for _, hook in ipairs(Progression.catchHooks) do task.spawn(pcall, hook, name, fish) end
		end)
	end)

