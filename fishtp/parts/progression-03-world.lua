	-- [Progression part 03-world: moving, prompts, clicking buttons and the screen. The loader joins the parts in order into one scope.]
	function G.hrp()
		local char = LP.Character
		return char and char:FindFirstChild("HumanoidRootPart")
	end

	function G.humanoid()
		local char = LP.Character
		return char and char:FindFirstChildOfClass("Humanoid")
	end

	function G.teleport(pos)
		local hrp = G.hrp()
		if not hrp then return false end
		-- Sitting (a boat's seats sit you down when touched), the move would take the seat along, or be undone: the
		-- server kept the user at the hunt ("You're too far away!" from the Songstress). Stand up first.
		local humanoid = G.humanoid()
		if humanoid and (humanoid.SeatPart or humanoid.Sit) then
			humanoid.Sit = false
			humanoid.Jump = true
			task.wait(0.4)
		end
		pcall(function() LP:RequestStreamAroundAsync(pos, 5) end)
		hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
		snapToGround(hrp)
		task.wait(0.6)
		return true
	end

	function G.near(pos, radius)
		local hrp = G.hrp()
		return hrp and (hrp.Position - pos).Magnitude <= (radius or 20)
	end

	local function positionOf(inst)
		local ok, pos = pcall(function()
			if inst:IsA("BasePart") then return inst.Position end
			if inst:IsA("Model") then return inst:GetPivot().Position end
			if inst:IsA("Attachment") then return inst.WorldPosition end
			local parent = inst.Parent
			if parent and parent:IsA("BasePart") then return parent.Position end
			if parent and parent:IsA("Attachment") then return parent.WorldPosition end
			if parent and parent:IsA("Model") then return parent:GetPivot().Position end
		end)
		return ok and pos or nil
	end
	G.positionOf = positionOf

	function G.firePrompt(prompt)
		if not prompt then return false end
		local pos = positionOf(prompt)
		if pos and not G.near(pos, math.max(4, prompt.MaxActivationDistance - 2)) then G.teleport(pos) end
		local ok = pcall(function()
			if fireproximityprompt then
				fireproximityprompt(prompt)
			else
				prompt:InputHoldBegin()
				task.wait(prompt.HoldDuration + 0.1)
				prompt:InputHoldEnd()
			end
		end)
		log(("prompt %s [%s %s] %s"):format(prompt:GetFullName(), prompt.ActionText, prompt.ObjectText, ok and "fired" or "FAILED"))
		return ok
	end

	-- Enabled prompts within radius of pos (or anywhere under root), best match first.
	function G.promptsNear(pos, radius, match)
		local found = {}
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Enabled then
				local p = positionOf(d)
				if p and (not pos or (p - pos).Magnitude <= radius) then
					local text = (d.ActionText .. " " .. d.ObjectText):lower()
					if not match or text:find(match:lower(), 1, true) then
						found[#found + 1] = { prompt = d, distance = pos and (p - pos).Magnitude or 0 }
					end
				end
			end
		end
		table.sort(found, function(a, b) return a.distance < b.distance end)
		local out = {}
		for i, entry in ipairs(found) do out[i] = entry.prompt end
		return out
	end

	-- The executor's way to set a thread's permission level, if it has one.
	G.setIdentity = setthreadidentity or set_thread_identity or setidentity or (syn and syn.set_thread_identity) or nil

	-- Presses a GUI button by running its handlers. Each runs in a thread of its own: a handler that waits (a
	-- dialogue answer waits 0.6s before loading the next line) dies at the wait if it's run inside conn:Fire(), which
	-- can't yield. conn:Fire() is only the fallback for handlers the executor can't hand over.
	function G.click(button)
		local fired = false
		for _, signal in ipairs({ "Activated", "MouseButton1Click" }) do
			local ok, conns = pcall(function() return getconnections and getconnections(button[signal]) end)
			for _, conn in ipairs(ok and type(conns) == "table" and conns or {}) do
				local fn
				pcall(function() fn = conn.Function end)
				if type(fn) == "function" then
					task.spawn(function()
						-- Run as a normal game script: at the executor's level the game's code can't require its own
						-- modules ("Cannot require a non-RobloxScript module from a RobloxScript").
						if G.setIdentity then pcall(G.setIdentity, 2) end
						local good, err = pcall(fn)
						if not good then log(("button %s: its handler failed: %s"):format(button.Name, tostring(err))) end
					end)
					fired = true
				elseif pcall(function() conn:Fire() end) then
					fired = true
				end
			end
		end
		if not fired and firesignal then
			pcall(firesignal, button.Activated)
			pcall(firesignal, button.MouseButton1Click)
			fired = true
		end
		return fired
	end

	-- Where a button is on screen, found by asking which GUI is under each point (works for 3D billboards too, like
	-- the dialogue answers over your character, whose own positions aren't screen positions). Looks around `near`
	-- (a world position) first, then the whole screen; skips points where this hub's window (CoreGui) is on top.
	local function screenPointOf(button, near)
		local camera = workspace.CurrentCamera
		local size = camera.ViewportSize
		local coreGui
		pcall(function() coreGui = game:GetService("CoreGui") end)
		local function covered(x, y)
			if not coreGui then return false end
			local ok, top = pcall(function() return coreGui:GetGuiObjectsAtPosition(x, y) end)
			for _, obj in ipairs(ok and top or {}) do
				if obj:IsA("GuiButton") or obj:IsA("TextBox") or obj.BackgroundTransparency < 0.9 then return true end
			end
			return false
		end
		local function hit(x, y)
			local ok, objects = pcall(function() return LP.PlayerGui:GetGuiObjectsAtPosition(x, y) end)
			for _, obj in ipairs(ok and objects or {}) do
				if obj == button or obj:IsDescendantOf(button) then return not covered(x, y) end
			end
			return false
		end
		local areas = {}
		if near then
			local point, visible = camera:WorldToScreenPoint(near)
			if visible then areas[#areas + 1] = { point.X - 350, point.Y - 350, point.X + 350, point.Y + 350, 16 } end
		end
		areas[#areas + 1] = { 0, 0, size.X, size.Y, 40 }
		for _, a in ipairs(areas) do
			for y = math.max(0, a[2]), math.min(size.Y, a[4]), a[5] do
				for x = math.max(0, a[1]), math.min(size.X, a[3]), a[5] do
					if hit(x, y) then return x, y end
				end
			end
		end
		return nil
	end

	-- Clicks a button with the real mouse, so the game handles it exactly as your own click. Its code then runs as
	-- the game's own, which matters for the dialogue: run from here, the next line showed but its answers didn't.
	-- Falls back to running its handlers.
	function G.pressButton(button, near)
		local x, y = screenPointOf(button, near)
		if not x then
			log(("button %s: not clickable on screen; pressing it directly"):format(button.Name))
			return G.click(button)
		end
		local inset = game:GetService("GuiService"):GetGuiInset()
		pcall(function()
			VirtualInputManager:SendMouseMoveEvent(x, y + inset.Y, game)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(x, y + inset.Y, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(x, y + inset.Y, 0, false, game, 0)
		end)
		return true
	end

	-- A spot on screen with nothing over it: no game button or panel (PlayerGui) and not this hub's window
	-- (CoreGui), so a click there lands in the world. In GUI coordinates (without the top bar).
	local function openScreenPoint()
		local size = workspace.CurrentCamera.ViewportSize
		local roots = { LP.PlayerGui }
		pcall(function() roots[#roots + 1] = game:GetService("CoreGui") end)
		local function blocked(x, y)
			for _, root in ipairs(roots) do
				local ok, objects = pcall(function() return root:GetGuiObjectsAtPosition(x, y) end)
				for _, obj in ipairs(ok and objects or {}) do
					if obj:IsA("GuiButton") or obj:IsA("TextBox") or obj.Active or obj.BackgroundTransparency < 0.9 then return true end
				end
			end
			return false
		end
		for _, at in ipairs({ { 0.5, 0.3 }, { 0.35, 0.3 }, { 0.65, 0.3 }, { 0.5, 0.15 }, { 0.25, 0.5 }, { 0.75, 0.5 }, { 0.5, 0.55 } }) do
			local x, y = math.floor(size.X * at[1]), math.floor(size.Y * at[2])
			if not blocked(x, y) then return x, y end
		end
		return math.floor(size.X * 0.5), math.floor(size.Y * 0.3)
	end

	-- The left mouse button, really pressed (down = true) or let go, at an open spot on screen.
	local mouseAt
	function G.mouse(down)
		if down or not mouseAt then
			local x, y = openScreenPoint()
			mouseAt = Vector2.new(x, y + game:GetService("GuiService"):GetGuiInset().Y)
		end
		pcall(function()
			if down then VirtualInputManager:SendMouseMoveEvent(mouseAt.X, mouseAt.Y, game) end
			VirtualInputManager:SendMouseButtonEvent(mouseAt.X, mouseAt.Y, 0, down, game, 0)
		end)
	end

	-- A real click on an open spot of the screen (in hand: nothing, or the click casts).
	function G.tapScreen()
		G.mouse(true)
		task.wait(0.06)
		G.mouse(false)
	end

	local function shown(obj)
		local node = obj
		while node and node ~= LP.PlayerGui do
			if node:IsA("GuiObject") and not node.Visible then return false end
			if node:IsA("LayerCollector") and not node.Enabled then return false end
			node = node.Parent
		end
		return node == LP.PlayerGui
	end

	local function buttonText(button)
		local text = button:IsA("TextButton") and button.Text or ""
		if text == "" then
			local label = button:FindFirstChildWhichIsA("TextLabel", true)
			text = label and label.Text or ""
		end
		return (text:gsub("<[^>]+>", ""))
	end

	function G.visibleButtons()
		local out = {}
		for _, d in ipairs(LP.PlayerGui:GetDescendants()) do
			if d:IsA("GuiButton") and shown(d) then out[#out + 1] = d end
		end
		return out
	end

	-- The game's yes/no box (PlayerGui.PromptConfirmation, see ConfirmationController). Returns true if it clicked.
	function G.confirm(words)
		words = words or { "yes", "confirm", "purchase", "buy", "accept", "okay", "sure" }
		local gui = LP.PlayerGui:FindFirstChild("PromptConfirmation")
		local frame = gui and gui:FindFirstChild("Frame")
		if not (frame and frame.Visible) then return false end
		for _, button in ipairs(frame:GetDescendants()) do
			if button:IsA("GuiButton") then
				local text = buttonText(button):lower()
				for _, word in ipairs(words) do
					if text:find(word, 1, true) then
						log("confirm: " .. text)
						return G.click(button)
					end
				end
			end
		end
		return false
	end

