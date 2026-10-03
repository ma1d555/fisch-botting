-- NovaUI: draggable window, RightShift toggle, RGB themes. Same call shape the hub already uses:
-- Library:CreateWindow -> :CreateGroup -> :CreateTab -> :AddSection -> :AddToggle/AddSlider/AddDropdown/AddButton/AddInput/AddParagraph.
-- Every toggle/slider/dropdown registers itself (Library.controls) so configs can read and write them by key.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Library = {}
Library.controls = {}   -- { key = control } for every saveable control
Library.GuiName = "Nova_UI"

-- ---- theme ---------------------------------------------------------------------------------

local DEFAULT_THEME = {
	Accent = Color3.fromRGB(145, 80, 255),
	Background = Color3.fromRGB(38, 38, 42),
	Text = Color3.fromRGB(255, 255, 255),
	Rainbow = false,
}

local theme = { Accent = DEFAULT_THEME.Accent, Background = DEFAULT_THEME.Background, Text = DEFAULT_THEME.Text, Rainbow = false }
local themed = {}        -- { {inst, prop, role} }
local themeListeners = {}

local function shade(c, amount)
	if amount >= 0 then return c:Lerp(Color3.new(1, 1, 1), amount) end
	return c:Lerp(Color3.new(0, 0, 0), -amount)
end

local roles = {
	bg      = function() return theme.Background end,
	panel   = function() return shade(theme.Background, 0.05) end,
	elem    = function() return shade(theme.Background, 0.11) end,
	hover   = function() return shade(theme.Background, 0.18) end,
	accent  = function() return theme.Accent end,
	text    = function() return theme.Text end,
	ontop   = function() return (theme.Accent.R * 0.299 + theme.Accent.G * 0.587 + theme.Accent.B * 0.114) > 0.62 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1) end,
	subtext = function() return theme.Text:Lerp(theme.Background, 0.45) end,
}

local function paint(entry)
	local inst, prop, role = entry[1], entry[2], entry[3]
	if inst.Parent or inst:IsA("ScreenGui") then inst[prop] = roles[role]() end
end

local entryOf = setmetatable({}, { __mode = "k" })   -- inst -> { prop = entry }

local function bind(inst, prop, role)
	local props = entryOf[inst]
	if not props then props = {}; entryOf[inst] = props end
	local entry = props[prop]
	if entry then
		entry[3] = role
	else
		entry = { inst, prop, role }
		props[prop] = entry
		themed[#themed + 1] = entry
	end
	inst[prop] = roles[role]()
	return inst
end

local function applyTheme()
	for i = #themed, 1, -1 do
		local entry = themed[i]
		if entry[1].Parent == nil then table.remove(themed, i) else paint(entry) end
	end
	for _, fn in ipairs(themeListeners) do pcall(fn, theme) end
end

local function colorToTable(c) return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } end
local function tableToColor(t, fallback)
	if type(t) ~= "table" or #t < 3 then return fallback end
	return Color3.fromRGB(math.clamp(tonumber(t[1]) or 0, 0, 255), math.clamp(tonumber(t[2]) or 0, 0, 255), math.clamp(tonumber(t[3]) or 0, 0, 255))
end

function Library.GetTheme()
	return { Accent = colorToTable(theme.Accent), Background = colorToTable(theme.Background), Text = colorToTable(theme.Text), Rainbow = theme.Rainbow }
end

function Library.SetTheme(t)
	t = t or {}
	theme.Accent = tableToColor(t.Accent, theme.Accent)
	theme.Background = tableToColor(t.Background, theme.Background)
	theme.Text = tableToColor(t.Text, theme.Text)
	if t.Rainbow ~= nil then theme.Rainbow = t.Rainbow == true end
	applyTheme()
end

function Library.ResetTheme()
	theme.Accent, theme.Background, theme.Text, theme.Rainbow = DEFAULT_THEME.Accent, DEFAULT_THEME.Background, DEFAULT_THEME.Text, false
	applyTheme()
end

function Library.OnThemeChanged(fn) themeListeners[#themeListeners + 1] = fn end

-- accent cycles through the hue wheel while Rainbow is on
local rainbowConn
local function startRainbow()
	rainbowConn = RunService.Heartbeat:Connect(function()
		if not theme.Rainbow then return end
		theme.Accent = Color3.fromHSV((os.clock() * 0.2) % 1, 0.75, 1)
		for _, entry in ipairs(themed) do
			if entry[3] == "accent" or entry[3] == "ontop" then paint(entry) end
		end
	end)
end

-- ---- helpers -------------------------------------------------------------------------------

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(inst, r) make("UICorner", { CornerRadius = UDim.new(0, r or 6) }, inst) end
-- a thin border (UIStroke in Border mode: on a TextButton the default would outline the text instead)
local function outline(inst, role, transparency)
	local stroke = make("UIStroke", { Thickness = 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
	bind(stroke, "Color", role)
	return stroke
end
local function pad(inst, l, t, r, b)
	make("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l) }, inst)
end
local function list(inst, gap)
	return make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, gap or 6) }, inst)
end

local conns = {}
local function conn(signal, fn)
	local c = signal:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local function tween(inst, props, t)
	pcall(function() TweenService:Create(inst, TweenInfo.new(t or 0.12), props):Play() end)
end

local function label(parent, text, size, role, props)
	local l = make("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size or 13, Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, RichText = false,
	}, parent)
	bind(l, "TextColor3", role or "text")
	if props then for k, v in pairs(props) do l[k] = v end end
	return l
end

local function mountGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = Library.GuiName
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	local parent
	pcall(function() if gethui then parent = gethui() end end)
	if not parent then pcall(function() parent = game:GetService("CoreGui") end) end
	if not parent then parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
	local ok = pcall(function() gui.Parent = parent end)
	if not ok then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
	return gui
end

-- ---- controls ------------------------------------------------------------------------------

local function newRow(parent, height)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, height or 30), BorderSizePixel = 0 }, parent)
	bind(row, "BackgroundColor3", "elem")
	corner(row, 6)
	return row
end

local Section = {}
Section.__index = Section

-- every control's top frame + title, so a tab's search box can hide what doesn't match
local function trackEl(section, frame, title)
	section.elements[#section.elements + 1] = { frame = frame, title = tostring(title or ""):lower() }
end

local function register(section, ctl, title, save)
	if save == false then return end
	if section.tab.noSave then return end
	local base = section.tab.name .. "/" .. section.name .. "/" .. title
	local key, n = base, 1
	while Library.controls[key] do n = n + 1; key = base .. " #" .. n end
	ctl.key = key
	Library.controls[key] = ctl
end

function Section:AddToggle(o)
	local value = o.Default == true
	local row = newRow(self.body, 30)
	local text = label(row, o.Title or "", 13, "text", { Size = UDim2.new(1, -56, 1, 0), Position = UDim2.fromOffset(10, 0), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	local track = make("Frame", { Size = UDim2.fromOffset(34, 16), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), BorderSizePixel = 0 }, row)
	corner(track, 8)
	local knob = make("Frame", { Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0 }, track)
	corner(knob, 6)
	bind(knob, "BackgroundColor3", "text")
	local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, row)
	trackEl(self, row, o.Title)

	local ctl = { kind = "toggle" }
	local function render()
		knob.Position = value and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
		bind(track, "BackgroundColor3", value and "accent" or "hover")
	end
	render()

	function ctl:Get() return value end
	function ctl:Set(v, silent)
		v = v == true
		if v == value then return end
		value = v
		render()
		if not silent and o.Callback then task.spawn(o.Callback, value) end
	end
	ctl.SetValue = ctl.Set
	hit.MouseButton1Click:Connect(function() ctl:Set(not value) end)
	register(self, ctl, o.Title or "", o.Save)
	return ctl
end

function Section:AddButton(o)
	local btn = make("TextButton", { Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0, AutoButtonColor = false, Text = o.Title or "", TextSize = 13, Font = Enum.Font.GothamMedium, TextTruncate = Enum.TextTruncate.AtEnd }, self.body)
	bind(btn, "BackgroundColor3", "elem")
	bind(btn, "TextColor3", "text")
	corner(btn, 6)
	outline(btn, "hover", 0.2)
	trackEl(self, btn, o.Title)
	btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = roles.hover() }) end)
	btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = roles.elem() }) end)
	btn.MouseButton1Down:Connect(function() tween(btn, { BackgroundColor3 = roles.accent() }, 0.06) end)
	btn.MouseButton1Up:Connect(function() tween(btn, { BackgroundColor3 = roles.hover() }, 0.1) end)
	btn.MouseButton1Click:Connect(function()
		if o.Callback then task.spawn(o.Callback) end
	end)
	local ctl = {}
	function ctl:SetTitle(t) btn.Text = t end
	return ctl
end

function Section:AddSlider(o)
	local min, max = o.Min or 0, o.Max or 100
	local inc = o.Increment or 1
	local value = math.clamp(o.Default or min, min, max)
	local row = newRow(self.body, 42)
	trackEl(self, row, o.Title)
	local title = label(row, o.Title or "", 13, "text", { Size = UDim2.new(1, -70, 0, 18), Position = UDim2.fromOffset(10, 4), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	local num = label(row, "", 13, "subtext", { Size = UDim2.fromOffset(60, 18), Position = UDim2.new(1, -70, 0, 4), TextXAlignment = Enum.TextXAlignment.Right })
	local bar = make("Frame", { Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 29), BorderSizePixel = 0 }, row)
	bind(bar, "BackgroundColor3", "hover")
	corner(bar, 3)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, bar)
	bind(fill, "BackgroundColor3", "accent")
	corner(fill, 3)
	local ctl = { kind = "slider" }

	local function render()
		local alpha = max == min and 0 or (value - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		num.Text = tostring(math.floor(value * 1000 + 0.5) / 1000)
	end
	local function snap(v)
		v = math.clamp(v, min, max)
		v = min + math.floor((v - min) / inc + 0.5) * inc
		return math.clamp(math.floor(v * 100000 + 0.5) / 100000, min, max)
	end
	render()
	function ctl:Get() return value end
	function ctl:Set(v, silent)
		v = snap(tonumber(v) or value)
		if v == value then return end
		value = v
		render()
		if not silent and o.Callback then task.spawn(o.Callback, value) end
	end
	ctl.SetValue = ctl.Set

	local dragging = false
	local function fromX(x)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		ctl:Set(min + (max - min) * alpha)
	end
	local hit = make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, row)
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	conn(UIS.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromX(input.Position.X) end
	end)
	conn(UIS.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	register(self, ctl, o.Title or "", o.Save)
	return ctl
end

function Section:AddInput(o)
	local row = newRow(self.body, 30)
	trackEl(self, row, o.Title)
	label(row, o.Title or "", 13, "text", { Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.fromOffset(10, 0), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	local box = make("TextBox", {
		Size = UDim2.new(0.5, -14, 0, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), BorderSizePixel = 0,
		Text = tostring(o.Default or ""), PlaceholderText = o.Placeholder or "", TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	bind(box, "BackgroundColor3", "hover")
	bind(box, "TextColor3", "text")
	bind(box, "PlaceholderColor3", "subtext")
	corner(box, 5)
	pad(box, 6, 0, 6, 0)
	local ctl = { kind = "input" }
	function ctl:Get() return box.Text end
	function ctl:Set(v, silent)
		box.Text = tostring(v or "")
		if not silent and o.Callback then task.spawn(o.Callback, box.Text) end
	end
	ctl.SetValue = ctl.Set
	box.FocusLost:Connect(function() if o.Callback then task.spawn(o.Callback, box.Text) end end)
	-- inputs are one-off values (IDs, amounts, names): not part of configs unless asked for
	if o.Save == true then register(self, ctl, o.Title or "", true) end
	return ctl
end

function Section:AddParagraph(o)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 }, self.body)
	bind(row, "BackgroundColor3", "elem")
	corner(row, 6)
	pad(row, 10, 7, 10, 7)
	list(row, 2)
	trackEl(self, row, (o.Title or "") .. " " .. (o.Content or ""))
	local title = label(row, o.Title or "", 13, "accent", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.GothamBold, LayoutOrder = 1 })
	local body = label(row, o.Content or "", 12, "subtext", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham, LayoutOrder = 2 })
	local ctl = {}
	function ctl:SetDesc(text) body.Text = tostring(text or "") end
	function ctl:SetTitle(text) title.Text = tostring(text or "") end
	function ctl:Set(t)
		if type(t) ~= "table" then return end
		if t.Title then title.Text = tostring(t.Title) end
		if t.Content then body.Text = tostring(t.Content) end
	end
	return ctl
end

-- A key picker: click it, press a key (Escape cancels). Value is the KeyCode's name, e.g. "RightShift".
Library.listening = 0
function Section:AddKeybind(o)
	local value = tostring(o.Default or "None")
	local row = newRow(self.body, 30)
	trackEl(self, row, o.Title)
	label(row, o.Title or "", 13, "text", { Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(10, 0), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	local btn = make("TextButton", { Size = UDim2.fromOffset(92, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), BorderSizePixel = 0, AutoButtonColor = false, TextSize = 12, Font = Enum.Font.GothamMedium, Text = value }, row)
	bind(btn, "BackgroundColor3", "hover")
	bind(btn, "TextColor3", "accent")
	corner(btn, 5)
	local listening = false
	local ctl = { kind = "keybind" }
	function ctl:Get() return value end
	function ctl:Set(v, silent)
		v = tostring(v or "None")
		if v ~= "None" and not pcall(function() return Enum.KeyCode[v] end) then return end
		value = v
		btn.Text = value
		if not silent and o.Callback then task.spawn(o.Callback, value) end
	end
	ctl.SetValue = ctl.Set
	btn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		Library.listening = Library.listening + 1
		btn.Text = "press a key"
	end)
	conn(UIS.InputBegan, function(input)
		if not listening or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		listening = false
		task.delay(0.2, function() Library.listening = math.max(0, Library.listening - 1) end)
		if input.KeyCode == Enum.KeyCode.Escape then btn.Text = value return end
		ctl:Set(input.KeyCode.Name)
	end)
	if o.Save == true then register(self, ctl, o.Title or "", true) end
	return ctl
end

function Section:AddSeperator() end
Section.AddSeparator = Section.AddSeperator

function Section:AddDropdown(o)
	local options = {}
	for _, v in ipairs(o.Options or {}) do options[#options + 1] = tostring(v) end
	local value = o.Default ~= nil and tostring(o.Default) or options[1] or "None"
	local open = false

	local holder = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, self.body)
	list(holder, 2)
	local head = make("TextButton", { Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = 1 }, holder)
	bind(head, "BackgroundColor3", "elem")
	corner(head, 6)
	label(head, o.Title or "", 13, "text", { Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.fromOffset(10, 0), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	local current = label(head, value, 12, "accent", { Size = UDim2.new(0.5, -28, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	local arrow = label(head, "v", 12, "subtext", { Size = UDim2.fromOffset(16, 30), Position = UDim2.new(1, -20, 0, 0), TextXAlignment = Enum.TextXAlignment.Center })

	trackEl(self, holder, o.Title)
	local search = make("TextBox", {
		Size = UDim2.new(1, 0, 0, 24), BorderSizePixel = 0, Visible = false, LayoutOrder = 2, Text = "", PlaceholderText = "Search",
		TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	}, holder)
	bind(search, "BackgroundColor3", "panel")
	bind(search, "TextColor3", "text")
	bind(search, "PlaceholderColor3", "subtext")
	corner(search, 6)
	pad(search, 8, 0, 8, 0)
	local scroll = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0), BorderSizePixel = 0, Visible = false, LayoutOrder = 3, ScrollBarThickness = 3,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, holder)
	bind(scroll, "BackgroundColor3", "panel")
	bind(scroll, "ScrollBarImageColor3", "accent")
	corner(scroll, 6)
	pad(scroll, 4, 4, 6, 4)
	list(scroll, 2)

	local ctl = { kind = "dropdown" }
	local function fire(silent)
		current.Text = value
		if not silent and o.Callback then task.spawn(o.Callback, value) end
	end
	local buttons = {}
	local function applyFilter()
		local q = search.Text:lower()
		local shown = 0
		for _, b in ipairs(buttons) do
			local match = q == "" or b.Text:lower():find(q, 1, true) ~= nil
			b.Visible = match
			if match then shown = shown + 1 end
		end
		scroll.Size = UDim2.new(1, 0, 0, math.min(math.max(shown, 1) * 24 + 8, 148))
	end
	local function close()
		open = false
		scroll.Visible = false
		search.Visible = false
		arrow.Text = "v"
	end
	local function rebuild()
		for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		buttons = {}
		for i, opt in ipairs(options) do
			local b = make("TextButton", { Size = UDim2.new(1, 0, 0, 22), BorderSizePixel = 0, AutoButtonColor = false, Text = opt, TextSize = 12, Font = Enum.Font.Gotham, LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, scroll)
			buttons[#buttons + 1] = b
			bind(b, "BackgroundColor3", "panel")
			bind(b, "TextColor3", opt == value and "accent" or "text")
			pad(b, 8, 0, 8, 0)
			corner(b, 4)
			b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = roles.hover() }, 0.08) end)
			b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = roles.panel() }, 0.08) end)
			b.MouseButton1Click:Connect(function()
				value = opt
				fire(false)
				rebuild()
				close()
			end)
		end
		applyFilter()
	end
	rebuild()
	search:GetPropertyChangedSignal("Text"):Connect(applyFilter)

	head.MouseButton1Click:Connect(function()
		open = not open
		scroll.Visible = open
		search.Visible = open and #options > 8
		arrow.Text = open and "^" or "v"
	end)

	function ctl:Get() return value end
	function ctl:Set(v, silent)
		if type(v) == "table" then v = v[1] end
		v = tostring(v)
		if v == value then return end
		value = v
		fire(silent)
		rebuild()
	end
	ctl.SetValue = ctl.Set
	function ctl:SetOptions(list2)
		options = {}
		for _, v in ipairs(list2 or {}) do options[#options + 1] = tostring(v) end
		rebuild()
	end
	ctl.SetValues = ctl.SetOptions
	ctl.Refresh = ctl.SetOptions
	register(self, ctl, o.Title or "", o.Save)
	return ctl
end

-- ---- tabs, groups, window ------------------------------------------------------------------

local Tab = {}
Tab.__index = Tab

function Tab:AddSection(name, open, side)
	local column = (side == "Right") and self.right or self.left
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = #column:GetChildren() }, column)
	bind(frame, "BackgroundColor3", "panel")
	corner(frame, 8)
	pad(frame, 8, 8, 8, 8)
	list(frame, 6)
	local head = make("TextButton", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "", LayoutOrder = 0 }, frame)
	local bar = make("Frame", { Size = UDim2.fromOffset(3, 14), Position = UDim2.fromOffset(0, 3), BorderSizePixel = 0 }, head)
	bind(bar, "BackgroundColor3", "accent")
	corner(bar, 2)
	label(head, name, 14, "text", { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(10, 0), Font = Enum.Font.GothamBold, TextWrapped = false })
	local chevron = label(head, open == false and "+" or "-", 14, "subtext", { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -20, 0, 0), TextXAlignment = Enum.TextXAlignment.Center })
	local body = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Visible = open ~= false }, frame)
	list(body, 5)
	local sec = setmetatable({ tab = self, name = name, body = body, frame = frame, elements = {}, expanded = open ~= false, query = "" }, Section)
	function sec:Refresh()
		local searching = self.query ~= ""
		body.Visible = self.expanded or (searching and self.matches == true)
		chevron.Text = self.expanded and "-" or "+"
	end
	head.MouseButton1Click:Connect(function()
		sec.expanded = not sec.expanded
		sec:Refresh()
	end)
	self.sections[#self.sections + 1] = sec
	return sec
end

-- Hides what doesn't match the search text; sections with a match open up while searching.
function Tab:Filter(text)
	local q = tostring(text or ""):lower()
	for _, sec in ipairs(self.sections) do
		local any = false
		local nameMatch = q ~= "" and sec.name:lower():find(q, 1, true) ~= nil
		for _, el in ipairs(sec.elements) do
			local match = q == "" or nameMatch or el.title:find(q, 1, true) ~= nil
			el.frame.Visible = match
			if match then any = true end
		end
		sec.query = q
		sec.matches = any
		sec.frame.Visible = q == "" or any or nameMatch
		sec:Refresh()
	end
end

local Group = {}
Group.__index = Group

function Group:CreateTab(args)
	local name = args[1] or args.Name or "Tab"
	local win = self.window
	local btn = make("TextButton", { Size = UDim2.new(1, 0, 0, 28), BorderSizePixel = 0, AutoButtonColor = false, Text = name, TextSize = 13, Font = Enum.Font.GothamMedium, LayoutOrder = #win.tabList:GetChildren() }, win.tabList)
	bind(btn, "BackgroundColor3", "elem")
	bind(btn, "TextColor3", "subtext")
	corner(btn, 6)
	local btnStroke = outline(btn, "hover", 0)
	local searchBox = make("TextBox", {
		Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(8, 6), BorderSizePixel = 0, Visible = false, Text = "", PlaceholderText = "Search " .. name,
		TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	}, win.content)
	bind(searchBox, "BackgroundColor3", "panel")
	bind(searchBox, "TextColor3", "text")
	bind(searchBox, "PlaceholderColor3", "subtext")
	corner(searchBox, 6)
	pad(searchBox, 8, 0, 8, 0)
	local page = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ScrollBarThickness = 4,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, win.content)
	bind(page, "ScrollBarImageColor3", "accent")
	pad(page, 8, 8, 12, 8)
	local function column(x)
		local c = make("Frame", { Size = UDim2.new(0.5, -4, 0, 0), Position = UDim2.new(x, x == 0 and 0 or 4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, page)
		list(c, 8)
		return c
	end
	local tab = setmetatable({ name = name, left = column(0), right = column(0.5), page = page, button = btn, stroke = btnStroke, search = searchBox, sections = {}, noSave = args.NoSave == true }, Tab)
	searchBox:GetPropertyChangedSignal("Text"):Connect(function() tab:Filter(searchBox.Text) end)
	btn.MouseButton1Click:Connect(function() win:SelectTab(tab) end)
	win.tabs[#win.tabs + 1] = tab
	if not win.current then win:SelectTab(tab) end
	return tab
end

local Window = {}
Window.__index = Window

function Window:SelectTab(tab)
	for _, t in ipairs(self.tabs) do
		t.page.Visible = t == tab
		t.search.Visible = t == tab
		-- every tab is a framed button; the open one is filled with the accent
		bind(t.button, "TextColor3", t == tab and "ontop" or "subtext")
		bind(t.button, "BackgroundColor3", t == tab and "accent" or "elem")
		bind(t.stroke, "Color", t == tab and "accent" or "hover")
	end
	self.current = tab
end

function Window:CreateGroup(args)
	local name = args[1] or "Main"
	return setmetatable({ window = self, name = name }, Group)
end

function Window:SetVisible(state)
	self.visible = state == true
	self.frame.Visible = self.visible
end

function Window:Toggle(state)
	if state == nil then state = not self.visible end
	self:SetVisible(state)
end

function Window:Destroy()
	if self.gui then self.gui:Destroy() end
end

function Library:CreateWindow(o)
	o = o or {}
	local size = o.SizeUi or UDim2.fromOffset(640, 440)
	local sidebar = o["Tab Width"] or 110
	local gui = mountGui()
	Library.Gui = gui
	local layout = o.Layout
	local position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2)
	if type(layout) == "table" and tonumber(layout.w) and tonumber(layout.h) then
		size = UDim2.fromOffset(math.clamp(layout.w, 480, 1100), math.clamp(layout.h, 320, 800))
		position = UDim2.new(tonumber(layout.xs) or 0, tonumber(layout.xo) or 0, tonumber(layout.ys) or 0, tonumber(layout.yo) or 0)
	end
	local frame = make("Frame", { Size = size, Position = position, BorderSizePixel = 0, ClipsDescendants = true }, gui)
	local defaultSize, defaultPosition = o.SizeUi or UDim2.fromOffset(640, 440), nil
	defaultPosition = UDim2.new(0.5, -defaultSize.X.Offset / 2, 0.5, -defaultSize.Y.Offset / 2)
	bind(frame, "BackgroundColor3", "bg")
	corner(frame, 10)
	make("UIStroke", { Thickness = 1, Transparency = 0.6 }, frame)
	bind(frame:FindFirstChildOfClass("UIStroke"), "Color", "accent")

	-- ClipsDescendants doesn't follow UICorner, so the title bar and sidebar are rounded themselves; the fillers
	-- (behind them) fill in the corners that must stay square.
	local top = make("Frame", { Size = UDim2.new(1, 0, 0, 34), BorderSizePixel = 0 }, frame)
	bind(top, "BackgroundColor3", "panel")
	corner(top, 10)
	local topFill = make("Frame", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 16), BorderSizePixel = 0, ZIndex = 0 }, frame)
	bind(topFill, "BackgroundColor3", "panel")
	local accentLine = make("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BorderSizePixel = 0 }, top)
	bind(accentLine, "BackgroundColor3", "accent")
	label(top, o.Title or "Nova", 14, "text", { Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(12, 0), Font = Enum.Font.GothamBold, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	label(top, o.Description or "", 11, "subtext", { Size = UDim2.fromOffset(140, 34), Position = UDim2.new(1, -148, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })

	local tabList = make("ScrollingFrame", {
		Size = UDim2.new(0, sidebar, 1, -34), Position = UDim2.fromOffset(0, 34), BorderSizePixel = 0, ScrollBarThickness = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, frame)
	bind(tabList, "BackgroundColor3", "panel")
	corner(tabList, 10)
	local sideTopFill = make("Frame", { Size = UDim2.new(0, sidebar, 0, 14), Position = UDim2.fromOffset(0, 34), BorderSizePixel = 0, ZIndex = 0 }, frame)
	bind(sideTopFill, "BackgroundColor3", "panel")
	local sideRightFill = make("Frame", { Size = UDim2.new(0, 14, 1, -34), Position = UDim2.fromOffset(sidebar - 14, 34), BorderSizePixel = 0, ZIndex = 0 }, frame)
	bind(sideRightFill, "BackgroundColor3", "panel")
	pad(tabList, 6, 8, 6, 6)
	list(tabList, 4)

	local content = make("Frame", { Size = UDim2.new(1, -sidebar, 1, -34), Position = UDim2.new(0, sidebar, 0, 34), BackgroundTransparency = 1 }, frame)

	local win = setmetatable({ gui = gui, frame = frame, tabList = tabList, content = content, tabs = {}, visible = o.Visible ~= false }, Window)
	frame.Visible = win.visible

	local function saveLayout()
		if not o.OnLayout then return end
		local p, sz = frame.Position, frame.Size
		pcall(o.OnLayout, { xs = p.X.Scale, xo = p.X.Offset, ys = p.Y.Scale, yo = p.Y.Offset, w = sz.X.Offset, h = sz.Y.Offset })
	end
	function win:ResetLayout()
		frame.Size, frame.Position = defaultSize, defaultPosition
		saveLayout()
	end

	-- corner grip: drag to resize
	local grip = make("TextButton", { Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, -2), BackgroundTransparency = 1, Text = "", ZIndex = 5 }, frame)
	local gripDot = make("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 5 }, grip)
	bind(gripDot, "BackgroundColor3", "accent")
	corner(gripDot, 2)
	local resizing, resizeStart, startSize
	grip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing, resizeStart, startSize = true, input.Position, frame.Size
		end
	end)
	conn(UIS.InputChanged, function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - resizeStart
			frame.Size = UDim2.fromOffset(math.clamp(startSize.X.Offset + d.X, 480, 1100), math.clamp(startSize.Y.Offset + d.Y, 320, 800))
		end
	end)
	conn(UIS.InputEnded, function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			resizing = false
			saveLayout()
		end
	end)

	-- drag from the title bar (mouse or touch)
	local dragging, dragStart, startPos
	top.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, frame.Position
		end
	end)
	conn(UIS.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	conn(UIS.InputEnded, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			saveLayout()
		end
	end)

	if not rainbowConn then startRainbow() end
	return win
end

-- Small pop-ups in the top right: they slide in, wait, slide out. They work while the window is hidden.
-- Library.ToastsEnabled = false turns them all off (the hub's Misc tab has the switch).
Library.ToastsEnabled = true
local toastHolder
function Library.Notify(title, content, duration)
	if not Library.ToastsEnabled then return end
	local gui = Library.Gui
	if not gui or not gui.Parent then print("[Nova] " .. tostring(title) .. ": " .. tostring(content or "")) return end
	if not toastHolder or not toastHolder.Parent then
		toastHolder = make("Frame", { Size = UDim2.new(0, 260, 1, -28), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), BackgroundTransparency = 1, ZIndex = 10 }, gui)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Top }, toastHolder)
	end
	-- the slot keeps its place in the list while the toast inside it slides
	local slot = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 10, LayoutOrder = math.floor(os.clock() * 100) }, toastHolder)
	local toast = make("Frame", { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(1.2, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, ZIndex = 10 }, slot)
	bind(toast, "BackgroundColor3", "panel")
	corner(toast, 8)
	pad(toast, 10, 7, 10, 7)
	list(toast, 2)
	make("UIStroke", { Thickness = 1, Transparency = 0.5 }, toast)
	bind(toast:FindFirstChildOfClass("UIStroke"), "Color", "accent")
	label(toast, tostring(title or ""), 13, "accent", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.GothamBold, LayoutOrder = 1, ZIndex = 10 })
	if content and content ~= "" then
		label(toast, tostring(content), 12, "subtext", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham, LayoutOrder = 2, ZIndex = 10 })
	end
	pcall(function()
		TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()
	end)
	task.delay(duration or 4, function()
		if not toast.Parent then return end
		pcall(function()
			TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1.2, 0, 0, 0) }):Play()
		end)
		task.delay(0.3, function() if slot.Parent then slot:Destroy() end end)
	end)
end

function Library.Destroy()
	if rainbowConn then rainbowConn:Disconnect() rainbowConn = nil end
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	Library.controls = {}
	themed = {}
end

return Library
