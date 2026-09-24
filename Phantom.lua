--[[
	================================================================
	  PHANTOM UI  --  Roblox UI Library (Luau)
	================================================================
	  Dark / purple "Phantom" theme, sidebar tabs, panel cards,
	  checkboxes, sliders, dropdowns, textboxes, buttons, keybinds,
	  section headers, labels & tips.

	  USAGE
	  -----
	    local Phantom = require(path.to.Phantom)          -- Studio
	    local Phantom = loadstring(game:HttpGet("url"))()  -- Executor

	    local UI = Phantom.new({
	        Name    = "Phantom",
	        Tip     = "Daily Question: Did you back up your config before the last change?",
	        User    = "pikun223",
	        Keybind = Enum.KeyCode.RightShift,   -- show / hide menu
	    })

	    local tab = UI:Tab({ Name = "Skins", Icon = "*" })
	    local sec = tab:Section("SKIN CHANGER")
	    sec:Checkbox({ Label = "Enable Skin Changer", Default = false })
	    sec:Slider({ Label = "FOV", Min = 0, Max = 180, Default = 60, Step = 1, Suffix = "" })
	    sec:Dropdown({ Label = "Assault Rifle", Options = { "Default", "Neo Noir" } })
	    sec:Textbox({ Label = "Player", Placeholder = "name" })
	    sec:Button({ Text = "Apply", Callback = function() end })
	================================================================
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")

local Library = {}
Library.__index = Library
Library.Animate = true -- set false to snap instead of tween (Themes tab)

----------------------------------------------------------------
-- Theme
----------------------------------------------------------------
local Theme = {
	Window     = Color3.fromRGB(12, 9, 18),    -- window background
	Panel      = Color3.fromRGB(23, 19, 33),   -- card / panel background
	Input      = Color3.fromRGB(33, 27, 48),   -- inputs, dropdown button
	InputHover = Color3.fromRGB(42, 35, 62),
	Hover      = Color3.fromRGB(30, 25, 45),
	Active     = Color3.fromRGB(29, 24, 43),   -- active sidebar tab
	Stroke     = Color3.fromRGB(41, 35, 59),   -- borders
	Track      = Color3.fromRGB(30, 25, 45),   -- slider track
	Accent     = Color3.fromRGB(139, 111, 214),-- purple accent
	AccentSoft = Color3.fromRGB(46, 38, 74),
	Text       = Color3.fromRGB(236, 233, 247),
	SubText    = Color3.fromRGB(150, 144, 171),
	DimText    = Color3.fromRGB(110, 105, 128),
	Star       = Color3.fromRGB(170, 160, 215),
}
Library.Theme = Theme

-- NOTE: this table is named `Fonts` (not `Font`) so it never shadows the
-- global `Font` datatype (Font.new / Font.fromId) that we use for the logo.
local Fonts = {
	Regular = Enum.Font.Gotham,
	Medium  = Enum.Font.GothamMedium,
	Bold    = Enum.Font.GothamBold,
	Code    = Enum.Font.Code,     -- monospace (console / output boxes)
	Logo    = Enum.Font.Kalam, -- built-in handwriting fallback (always valid)
}

local WIN_W, WIN_H = 1100, 660
local SIDEBAR_W    = 250

----------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------
local function New(class, props)
	local inst = Instance.new(class)
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function Corner(parent, radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function Stroke(parent, color, thickness, transparency)
	return New("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function Tween(inst, props, duration)
	-- Library.Animate = false -> apply instantly (used by the
	-- "Animated Transitions" checkbox in the Themes tab)
	if not Library.Animate then
		for k, v in pairs(props) do
			inst[k] = v
		end
		return { Completed = { Connect = function() end } }
	end
	local t = TweenService:Create(
		inst,
		TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function Text(props, parent) -- TextLabel with sane defaults
	local defaults = {
		BackgroundTransparency = 1,
		Font = Fonts.Regular,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}
	for k, v in pairs(defaults) do
		if props[k] == nil then props[k] = v end
	end
	props.Parent = parent
	return New("TextLabel", props)
end

local function Row(parent, order, pad) -- vertical auto-sized control row
	local r = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, pad or 6),
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = r,
	})
	return r
end

local function Wrap(parent, height) -- full-width fixed-height positioning container
	return New("Frame", {
		Size = UDim2.new(1, 0, 0, height or 20),
		BackgroundTransparency = 1,
		Parent = parent,
	})
end

local function hoverify(obj, base, hover)
	-- base/hover colors are stored as attributes so SetAccent() can
	-- update them after a live theme change
	obj:SetAttribute("BaseColor", base)
	obj:SetAttribute("HoverColor", hover)
	obj.MouseEnter:Connect(function()
		Tween(obj, { BackgroundColor3 = obj:GetAttribute("HoverColor") or hover }, 0.12)
	end)
	obj.MouseLeave:Connect(function()
		Tween(obj, { BackgroundColor3 = obj:GetAttribute("BaseColor") or base }, 0.12)
	end)
end

local function chevron(parent) -- little "v" drawn from two bars, rotates when open
	local c = New("Frame", {
		Size = UDim2.fromOffset(12, 7),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local function bar(x, rot)
		local b = New("Frame", {
			Size = UDim2.fromOffset(7, 2),
			Position = UDim2.fromOffset(x, 3.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.SubText,
			Rotation = rot,
			Parent = c,
		})
		Corner(b, 1)
	end
	bar(3.5, 45)
	bar(8.5, -45)
	return c
end

local function decimalsFor(step) -- how many decimal places this step needs
	local dec, s = 0, step
	while dec < 4 do
		if math.abs(s - math.floor(s + 0.5)) < 1e-9 then break end
		s = s * 10
		dec = dec + 1
	end
	return dec
end

----------------------------------------------------------------
-- Controls  (parent = scrolling frame, order = UIListLayout order)
----------------------------------------------------------------
local function makeSectionHeader(parent, title, order)
	return Text({
		Text = string.upper(tostring(title)),
		Font = Fonts.Medium,
		TextSize = 12,
		TextColor3 = Theme.Text,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = order,
	}, parent)
end

local function makeLabel(parent, text, order, opts)
	opts = opts or {}
	return Text({
		Text = tostring(text),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextColor3 = opts.Color or Theme.SubText,
		TextSize = opts.TextSize or 13,
		Font = opts.Font or Fonts.Regular,
		LayoutOrder = order,
	}, parent)
end

local function makeSpace(parent, px, order)
	return New("Frame", {
		Size = UDim2.new(1, 0, 0, px),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function makeCheckbox(parent, opts, order)
	opts = opts or {}
	local state = opts.Default == true

	local row = Row(parent, order, 6)
	local head = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Parent = row,
	})

	local label = Text({
		Text = opts.Label or "Checkbox",
		Size = UDim2.new(1, -32, 1, 0),
		TextSize = opts.TextSize or 14,
		Font = Fonts.Medium,
		TextColor3 = Theme.Text,
		Position = UDim2.fromOffset(4, 0),
	}, head)

	local box = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Input,
		Parent = head,
	})
	Corner(box, 6)
	local boxStroke = Stroke(box, Theme.Stroke, 1)

	local check = Text({
		Text = "✓",
		Size = UDim2.fromScale(1, 1),
		Font = Fonts.Bold,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
	}, box)

	local function render()
		check.TextTransparency = state and 0 or 1
		box.BackgroundColor3 = state and Theme.Accent or Theme.Input
		boxStroke.Color = state and Theme.Accent or Theme.Stroke
	end

	local function toggle()
		state = not state
		render()
		if opts.OnChanged then opts.OnChanged(state) end
	end

	-- ONLY the checkbox box highlights while hovered (the row stays clean)
	box.MouseEnter:Connect(function()
		if state then return end
		Tween(box, { BackgroundColor3 = Theme.InputHover }, 0.12)
		boxStroke.Color = Theme.Accent
	end)
	box.MouseLeave:Connect(function()
		render() -- snap back to the real on/off colors
	end)

	-- clicking the box or the row text both toggle (no double fire:
	-- clicks on the box are consumed by the box itself)
	head.Activated:Connect(toggle)
	box.Activated:Connect(toggle)
	render()

	local handle = {}

	function handle:Get()
		return state
	end

	function handle:Set(v, fire)
		state = v and true or false
		render()
		if fire and opts.OnChanged then opts.OnChanged(state) end
	end

	return handle
end

local function makeSlider(parent, opts, order)
	opts = opts or {}
	local minV  = opts.Min or 0
	local maxV  = opts.Max or 100
	-- default step: 1 for normal ranges, a fraction for tiny ranges (0..1)
	local step  = opts.Step
		or ((maxV - minV) >= 1 and 1 or math.max((maxV - minV) / 100, 1e-6))
	local dec   = decimalsFor(step)
	local suffix = opts.Suffix or ""

	local function round(v)
		return math.floor(v / step + 0.5) * step
	end
	local function fmt(v)
		return string.format("%." .. dec .. "f", v) .. suffix
	end

	local row  = Row(parent, order, 6)
	local head = Wrap(row, 18)

	Text({
		Text = opts.Label or "Slider",
		Size = UDim2.new(1, -76, 1, 0),
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, head)

	local valueLabel = Text({
		Text = "",
		Size = UDim2.new(0, 72, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.SubText,
		TextSize = 13,
		Font = Fonts.Medium,
	}, head)

	local area = Wrap(row, 16)
	local hit = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = area,
	})

	local track = New("Frame", {
		Size = UDim2.new(1, -10, 0, 4),
		Position = UDim2.new(0, 5, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Track,
		Parent = area,
	})
	Corner(track, 2)

	local fill = New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
		Parent = track,
	})
	Corner(fill, 2)

	local knob = New("Frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Text,
		Parent = track,
	})
	Corner(knob, 5)

	local current = opts.Default or minV

	local function update(v, fire)
		v = math.clamp(round(v), minV, maxV)
		current = v
		local r = 0
		if maxV ~= minV then r = (v - minV) / (maxV - minV) end
		fill.Size = UDim2.fromScale(r, 1)
		knob.Position = UDim2.fromScale(r, 0.5)
		valueLabel.Text = fmt(v)
		if fire and opts.OnChanged then opts.OnChanged(v) end
	end

	local dragging = false
	local function setFromX(x)
		local abs = track.AbsolutePosition
		local w = track.AbsoluteSize.X
		if w <= 0 then return end
		local r = math.clamp((x - abs.X) / w, 0, 1)
		update(minV + r * (maxV - minV), true)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	hit.MouseEnter:Connect(function() Tween(knob, { Size = UDim2.fromOffset(12, 12) }, 0.1) end)
	hit.MouseLeave:Connect(function() Tween(knob, { Size = UDim2.fromOffset(10, 10) }, 0.1) end)

	update(current, false)

	local handle = {}

	function handle:Get()
		return current
	end

	function handle:Set(v, fire)
		update(v or current, fire)
	end

	return handle
end

local function makeDropdown(parent, opts, order, lib)
	opts = opts or {}
	local multi = opts.Multi == true
	local options = opts.Options or {}

	local chosen = {} -- set of selected values
	if multi then
		if type(opts.Default) == "table" then
			for _, v in ipairs(opts.Default) do chosen[v] = true end
		end
	else
		local d = (opts.Default ~= nil) and opts.Default or options[1]
		if d ~= nil then chosen[d] = true end
	end

	local function chosenList()
		local t = {}
		for _, o in ipairs(options) do
			if chosen[o] then t[#t + 1] = o end
		end
		return t
	end
	local function displayText()
		local t = chosenList()
		if #t == 0 then return opts.Placeholder or "Select..." end
		if multi then return table.concat(t, ", ") end
		return tostring(t[1])
	end

	local row = Row(parent, order, 6)

	if opts.Label then
		local lw = Wrap(row, 16)
		Text({
			Text = opts.Label,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = Theme.Text,
			TextSize = 13,
		}, lw)
	end

	-- dropdown button -------------------------------------------------
	local bw = Wrap(row, 34)
	local btn = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Input,
		Parent = bw,
	})
	Corner(btn, 8)
	Stroke(btn, Theme.Stroke, 1)
	hoverify(btn, Theme.Input, Theme.InputHover)

	local valueLabel = Text({
		Text = "",
		Size = UDim2.new(1, -44, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, btn)

	local chev = chevron(btn)

	-- options list ----------------------------------------------------
	local clip = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = row,
	})
	local box = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Input,
		Parent = clip,
	})
	Corner(box, 8)
	Stroke(box, Theme.Stroke, 1)
	New("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = box,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = box,
	})

	local optionButtons = {}

	-- open / close state (declared before the option loop so the option
	-- click handlers can call state:Close())
	local open = false
	local state = { Gui = row }

	local function refresh()
		valueLabel.Text = displayText()
		for _, entry in ipairs(optionButtons) do
			local isOn = chosen[entry.value] == true
			entry.bg.BackgroundColor3 = isOn and Theme.AccentSoft or Theme.Input
			entry.name.TextColor3 = isOn and Theme.Text or Theme.SubText
			entry.check.TextTransparency = isOn and 0 or 1
		end
	end

	for i, opt in ipairs(options) do
		local ob = New("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Theme.Input,
			LayoutOrder = i,
			Parent = box,
		})
		Corner(ob, 6)

		local name = Text({
			Text = tostring(opt),
			Size = UDim2.new(1, -30, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			TextColor3 = Theme.SubText,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, ob)

		local check = Text({
			Text = "✓",
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(1, -8, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Font = Fonts.Bold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Accent,
			TextTransparency = 1,
		}, ob)

		ob.MouseEnter:Connect(function()
			if chosen[opt] ~= true then Tween(ob, { BackgroundColor3 = Theme.Hover }, 0.1) end
		end)
		ob.MouseLeave:Connect(function()
			if chosen[opt] ~= true then Tween(ob, { BackgroundColor3 = Theme.Input }, 0.1) end
		end)

		ob.Activated:Connect(function()
			if multi then
				chosen[opt] = not chosen[opt]
				refresh()
			else
				if chosen[opt] ~= true then
					for k in pairs(chosen) do chosen[k] = nil end
					chosen[opt] = true
					refresh()
					state:Close()
				end
			end
			if opts.OnChanged then opts.OnChanged(chosenList()) end
		end)

		optionButtons[#optionButtons + 1] = { value = opt, bg = ob, name = name, check = check }
	end

	-- open / close ----------------------------------------------------
	function state:Open()
		if open then return end
		if lib and lib._openDrop and lib._openDrop ~= state then
			lib._openDrop:Close()
		end
		open = true
		if lib then lib._openDrop = state end

		clip.Visible = true
		clip.Size = UDim2.new(1, 0, 0, 0)
		Tween(chev, { Rotation = 180 }, 0.15)
		Tween(btn, { BackgroundColor3 = Theme.InputHover }, 0.15)

		task.defer(function()
			local h = box.AbsoluteSize.Y + 4
			Tween(clip, { Size = UDim2.new(1, 0, 0, h) }, 0.18)
		end)
	end

	function state:Close()
		if not open then return end
		open = false
		if lib and lib._openDrop == state then lib._openDrop = nil end
		Tween(chev, { Rotation = 0 }, 0.15)
		Tween(btn, { BackgroundColor3 = Theme.Input }, 0.15)
		local t = Tween(clip, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
		t.Completed:Connect(function()
			if not open then clip.Visible = false end
		end)
	end

	btn.Activated:Connect(function()
		if open then state:Close() else state:Open() end
	end)

	refresh()

	local handle = {}

	function handle:Open()
		state:Open()
	end

	function handle:Close()
		state:Close()
	end

	function handle:Get()
		return chosenList()
	end

	function handle:Set(values, fire)
		for k in pairs(chosen) do chosen[k] = nil end
		if type(values) == "table" then
			for _, v in ipairs(values) do chosen[v] = true end
		elseif values ~= nil then
			chosen[values] = true
		end
		refresh()
		if fire and opts.OnChanged then opts.OnChanged(chosenList()) end
	end

	return handle
end

local function makeTextbox(parent, opts, order)
	opts = opts or {}
	local row = Row(parent, order, 6)

	if opts.Label then
		local lw = Wrap(row, 16)
		Text({
			Text = opts.Label,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = Theme.Text,
			TextSize = 13,
		}, lw)
	end

	local field = Wrap(row, 34)
	local box = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Input,
		Parent = field,
	})
	Corner(box, 8)
	local st = Stroke(box, Theme.Stroke, 1)

	local boxStroke = st
	local input = New("TextBox", {
		Text = opts.Default or "",
		PlaceholderText = opts.Placeholder or "",
		ClearTextOnFocus = false,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Font = Fonts.Regular,
		TextSize = 13,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.DimText,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		Parent = box,
	})

	input.Focused:Connect(function() Tween(box, { BackgroundColor3 = Theme.InputHover }, 0.12) boxStroke.Color = Theme.Accent end)
	input.FocusLost:Connect(function()
		Tween(box, { BackgroundColor3 = Theme.Input }, 0.12)
		boxStroke.Color = Theme.Stroke
		if opts.OnChanged then opts.OnChanged(input.Text) end
	end)

	local handle = {}

	function handle:Get()
		return input.Text
	end

	function handle:Set(t, fire)
		input.Text = tostring(t or "")
		if fire and opts.OnChanged then opts.OnChanged(input.Text) end
	end

	return handle
end

local function makeButton(parent, opts, order)
	opts = opts or {}
	local base = opts.Color or Theme.Accent
	local hoverColor = base:Lerp(Color3.new(1, 1, 1), 0.12)

	local b = New("TextButton", {
		Text = opts.Text or "Button",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = base,
		Font = Fonts.Medium,
		TextSize = 13,
		TextColor3 = Theme.Text,
		LayoutOrder = order,
		Parent = parent,
	})
	Corner(b, 8)
	hoverify(b, base, hoverColor)
	b.Activated:Connect(function()
		if opts.Callback then opts.Callback() end
		if opts.OnClick then opts.OnClick() end
	end)
	local handle = {}

	function handle:Set(text)
		b.Text = tostring(text)
	end

	function handle:SetColor(c)
		base = c
		b.BackgroundColor3 = c
	end

	return handle
end

local function makeKeybind(parent, opts, order)
	opts = opts or {}
	local row = Row(parent, order, 6)
	local head = Wrap(row, 22)

	Text({
		Text = opts.Label or "Keybind",
		Size = UDim2.new(1, -92, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		Font = Fonts.Medium,
		TextSize = 14,
		TextColor3 = Theme.Text,
	}, head)

	local kb = New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(0, 84, 0, 22),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Input,
		Parent = head,
	})
	Corner(kb, 6)
	local kbStroke = Stroke(kb, Theme.Stroke, 1)
	hoverify(kb, Theme.Input, Theme.InputHover)

	local keyText = Text({
		Text = "",
		Size = UDim2.new(1, -8, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.SubText,
		TextSize = 12,
		Font = Fonts.Medium,
	}, kb)

	local current = opts.Default
	local listening = false

	local function paint()
		keyText.Text = current and current.Name or "None"
	end
	paint()

	kb.Activated:Connect(function()
		listening = true
		keyText.Text = "..."
		keyText.TextColor3 = Theme.Accent
		kbStroke.Color = Theme.Accent
	end)

	UserInputService.InputBegan:Connect(function(input)
		if not listening then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		listening = false
		if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
			current = nil
		else
			current = input.KeyCode
		end
		keyText.TextColor3 = Theme.SubText
		kbStroke.Color = Theme.Stroke
		paint()
		if opts.OnChanged then opts.OnChanged(current) end
	end)

	local handle = {}

	function handle:Get()
		return current
	end

	function handle:Set(k, fire)
		current = k
		paint()
		if fire and opts.OnChanged then opts.OnChanged(current) end
	end

	return handle
end

-- A simple console / log box. Returns { Write(line), Clear(), Get() }
local function makeOutput(parent, opts, order)
	opts = opts or {}
	local row = Row(parent, order, 6)

	if opts.Label then
		local lw = Wrap(row, 16)
		Text({
			Text = opts.Label,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = Theme.Text,
			TextSize = 13,
		}, lw)
	end

	local holder = Wrap(row, opts.Height or 150)
	local box = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Input,
		ClipsDescendants = true,
		Parent = holder,
	})
	Corner(box, 8)
	Stroke(box, Theme.Stroke, 1)
	New("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = box,
	})

	local view = Text({
		Text = opts.Default or "",
		Size = UDim2.fromScale(1, 1),
		Font = Fonts.Code,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}, box)

	local lines = {}
	local maxLines = opts.MaxLines or 60
	if opts.Default and opts.Default ~= "" then
		lines[1] = opts.Default
	end

	local function paint()
		view.Text = table.concat(lines, "\n")
	end

	-- method style: output:Write("hi") / output:Clear() / output:Get()
	local handle = {}

	function handle:Write(line)
		for _, l in ipairs(tostring(line):split("\n")) do
			lines[#lines + 1] = l
		end
		while #lines > maxLines do
			table.remove(lines, 1)
		end
		paint()
	end

	function handle:Clear()
		table.clear(lines)
		paint()
	end

	function handle:Get()
		return table.concat(lines, "\n")
	end

	return handle
end

----------------------------------------------------------------
-- Page (Tab / Section / Settings panel share this API)
----------------------------------------------------------------
local Page = {}
Page.__index = Page

function Page:_next()
	local host = self._counter or self
	host._n = (host._n or 0) + 1
	return host._n
end

-- Creates a titled group inside the same scroll frame.
-- Everything you add to the returned section lands underneath its header.
function Page:Section(title)
	local order = self:_next()
	makeSectionHeader(self.Frame, title, order)
	return setmetatable({
		Frame = self.Frame,
		_counter = self._counter or self, -- always share the root page counter
		_lib = self._lib,
	}, Page)
end

function Page:Label(text, opts)  return makeLabel(self.Frame, text, self:_next(), opts) end
function Page:Tip(text)          return makeLabel(self.Frame, text, self:_next(), { Color = Theme.DimText, TextSize = 12 }) end
function Page:Space(px)          return makeSpace(self.Frame, px or 6, self:_next()) end
function Page:Header(title)      return makeSectionHeader(self.Frame, title, self:_next()) end

function Page:Checkbox(opts)  return makeCheckbox(self.Frame, opts, self:_next()) end
function Page:Slider(opts)    return makeSlider(self.Frame, opts, self:_next()) end
function Page:Dropdown(opts)  return makeDropdown(self.Frame, opts, self:_next(), self._lib) end
function Page:Textbox(opts)   return makeTextbox(self.Frame, opts, self:_next()) end
function Page:Button(opts)    return makeButton(self.Frame, opts, self:_next()) end
function Page:Keybind(opts)   return makeKeybind(self.Frame, opts, self:_next()) end
function Page:Output(opts)    return makeOutput(self.Frame, opts, self:_next()) end

----------------------------------------------------------------
-- Card (panel with title + scrolling content)
----------------------------------------------------------------
local function makeCard(parent, title, position, size, noLayout)
	local card = New("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Corner(card, 10)
	Stroke(card, Theme.Stroke, 1)

	local header = Text({
		Text = string.upper(tostring(title)),
		Font = Fonts.Medium,
		TextSize = 13,
		TextColor3 = Theme.Text,
		Size = UDim2.new(1, -32, 0, 16),
		Position = UDim2.fromOffset(16, 13),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	local scroll = New("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -24, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.fromRGB(75, 64, 110),
		ScrollBarImageTransparency = 0.25,
		Parent = card,
	})
	if not noLayout then
		New("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = scroll,
		})
	end

	return card, scroll, header
end

----------------------------------------------------------------
-- Library
----------------------------------------------------------------
function Library.new(options)
	options = options or {}
	local self = setmetatable({}, Library)

	self.Name    = options.Name or "Phantom"
	self.Tip     = options.Tip or "Tip: change me with UI:SetTip()"
	self.User    = options.User or "Guest"
	self.Keybind = options.Keybind or Enum.KeyCode.RightShift

	self._tabs     = {}
	self._openDrop = nil
	self._visible  = true

	------------------------------------------------ player gui ----
	local player    = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- remove a previous instance of the menu (script re-run)
	local old = playerGui:FindFirstChild("PhantomUI")
	if old then old:Destroy() end

	local screen = New("ScreenGui", {
		Name = "PhantomUI",
		ResetOnSpawn = false,
		DisplayOrder = 999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true, -- keeps input.Position and AbsolutePosition in the same space
		Parent = playerGui,
	})

	------------------------------------------------ window --------
	local window = New("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(WIN_W, WIN_H),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = screen,
	})
	Corner(window, 14)
	Stroke(window, Theme.Stroke, 1)
	self.Window = window
	self.Gui = screen

	local scaleObj = New("UIScale", { Parent = window })
	self._scale = scaleObj

	local function updateScale()
		local vp = Workspace.CurrentCamera.ViewportSize
		local s = math.min((vp.X - 60) / WIN_W, (vp.Y - 60) / WIN_H, 1)
		scaleObj.Scale = math.max(s, 0.4) * (self._scaleMult or 1)
	end
	self._updateScale = updateScale
	updateScale()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	-- static star specks (background) -------------------------------
	math.randomseed(os.time())
	for i = 1, 40 do
		local sz = math.random(1, 3)
		New("Frame", {
			Size = UDim2.fromOffset(sz, sz),
			Position = UDim2.fromOffset(math.random(8, WIN_W - 8), math.random(8, WIN_H - 8)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Star,
			BackgroundTransparency = math.random(30, 75) / 100,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = window,
		})
	end

	-- animated snow particles (front layer, toggle with UI:SetSnow()) --
	self._snowEnabled = true
	self._flakes = {}

	local snowLayer = New("Frame", {
		Name = "Snow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Active = false, -- never blocks clicks
		ZIndex = 30,
		Parent = window,
	})
	self._snowLayer = snowLayer

	for i = 1, 55 do
		local sz = math.random(1, 3)
		local x0 = math.random(6, WIN_W - 6)
		local y0 = math.random(6, WIN_H - 6)
		local flake = New("Frame", {
			Size = UDim2.fromOffset(sz, sz),
			Position = UDim2.fromOffset(x0, y0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = math.random(25, 70) / 100,
			BorderSizePixel = 0,
			ZIndex = 30,
			Parent = snowLayer,
		})
		Corner(flake, sz) -- round the speck into a flake
		self._flakes[i] = {
			gui = flake,
			x = x0,
			y = y0,
			speed = math.random(18, 70),
			sway = math.random(6, 30),
			phase = math.random() * math.pi * 2,
		}
	end

	self._snowConn = RunService.Heartbeat:Connect(function(dt)
		if not self._snowEnabled or not self._snowLayer.Visible then return end
		for _, f in ipairs(self._flakes) do
			f.y = f.y + f.speed * dt
			f.phase = f.phase + dt * 1.1
			if f.y > WIN_H + 6 then
				f.y = -6
				f.x = math.random(6, WIN_W - 6)
			end
			local x = f.x + math.sin(f.phase) * f.sway
			f.gui.Position = UDim2.fromOffset(x, f.y)
		end
	end)

	------------------------------------------------ sidebar -------
	local sidebar = New("Frame", {
		Size = UDim2.new(0, SIDEBAR_W, 1, 0),
		BackgroundTransparency = 1,
		Parent = window,
	})

	-- logo
	local logo = New("Frame", {
		Size = UDim2.new(1, -24, 0, 52),
		Position = UDim2.fromOffset(18, 6),
		BackgroundTransparency = 1,
		Parent = sidebar,
	})
	local ghost = New("Frame", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.AccentSoft,
		Parent = logo,
	})
	Corner(ghost, 17)
	Stroke(ghost, Theme.Accent, 1)
	Text({
		Text = "👻", -- ghost emoji
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Text,
	}, ghost)

	self._title = Text({
		Text = self.Name,
		Font = Fonts.Logo,
		TextSize = 32,
		TextColor3 = Theme.Text,
		Size = UDim2.new(1, -46, 1, 0),
		Position = UDim2.fromOffset(46, -2),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, logo)

	-- handwritten cursive logo: try the Pacifico cloud font family
	-- (verified font-family asset id); on any failure the Kalam enum
	-- font set above stays in place.
	pcall(function()
		self._title.FontFace = Font.fromId(12187367362, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	end)

	-- tab list
	local tabList = New("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 68),
		Size = UDim2.new(1, -20, 1, -68 - 64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Parent = sidebar,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabList,
	})

	-- welcome / user row
	local userRow = New("Frame", {
		Position = UDim2.new(0, 0, 1, -56),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Parent = sidebar,
	})
	local avatar = New("ImageLabel", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(0, 18, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Input,
		BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Crop,
		Parent = userRow,
	})
	Corner(avatar, 17)
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then avatar.Image = url end
	end)

	self._user = Text({
		Text = "Welcome, " .. self.User,
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(62, 0),
		Font = Fonts.Medium,
		TextSize = 14,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, userRow)

	------------------------------------------------ content -------
	local content = New("Frame", {
		Position = UDim2.fromOffset(SIDEBAR_W, 0),
		Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
		BackgroundTransparency = 1,
		Parent = window,
	})
	New("UIPadding", {
		PaddingLeft = UDim.new(0, 30),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 14),
		Parent = content,
	})

	-- top tip line
	local tipRow = New("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = content,
	})
	self._tip = Text({
		Text = self.Tip,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Fonts.Medium,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, tipRow)

	-- main card (tab content) + settings card
	-- mainScroll has NO UIListLayout: tab pages are stacked on top of
	-- each other at (0,0) and toggled with .Visible
	local mainCard, mainScroll, mainHeader = makeCard(
		content, self.Name,
		UDim2.new(0, 0, 0, 44),
		UDim2.new(1, -404, 1, -58),
		true -- noLayout
	)
	local setCard, setScroll = makeCard(
		content, "SETTINGS",
		UDim2.new(1, -384, 0, 44),
		UDim2.new(0, 384, 1, -58)
	)
	self._mainCard, self._mainHeader = mainCard, mainHeader
	self.Settings = setmetatable({ Frame = setScroll, _n = 0, _lib = self }, Page)

	------------------------------------------------ tabs ---------
	function self:_select(tab)
		for _, t in ipairs(self._tabs) do
			local active = (t == tab)
			t.Frame.Visible = active
			Tween(t.Highlight, { BackgroundTransparency = active and 0 or 1 }, 0.15)
			Tween(t.NameLabel, { TextColor3 = active and Theme.Text or Theme.SubText }, 0.15)
			Tween(t.IconLabel, { TextColor3 = active and Theme.Accent or Theme.SubText }, 0.15)
		end
		mainHeader.Text = string.upper(tab.Title or tab.Name)
		self._active = tab
	end

	function self:Tab(opts)
		opts = opts or {}
		local name = opts.Name or "Tab"
		local title = opts.Title or name -- shown on the panel header

		local scroll = New("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(75, 64, 110),
			ScrollBarImageTransparency = 0.25,
			Parent = mainScroll,
		})
		New("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = scroll,
		})

		-- sidebar button
		local btn = New("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = Theme.Active,
			BackgroundTransparency = 1,
			LayoutOrder = #self._tabs + 1,
			Parent = tabList,
		})
		Corner(btn, 10)

		local highlight = New("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Active,
			BackgroundTransparency = 1,
			Parent = btn,
		})
		Corner(highlight, 10)
		New("UIStroke", {
			Color = Theme.Stroke,
			Transparency = 0.6,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = highlight,
		})

		local iconLabel = Text({
			Text = opts.Icon or "•",
			Size = UDim2.new(0, 26, 1, 0),
			Position = UDim2.fromOffset(14, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Fonts.Medium,
			TextSize = 17,
			TextColor3 = Theme.SubText,
		}, btn)

		local nameLabel = Text({
			Text = name,
			Size = UDim2.new(1, -56, 1, 0),
			Position = UDim2.fromOffset(48, 0),
			Font = Fonts.Medium,
			TextSize = 15,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, btn)

		local tab = setmetatable({
			Name = name,
			Title = title,
			Frame = scroll,
			Button = btn,
			Highlight = highlight,
			NameLabel = nameLabel,
			IconLabel = iconLabel,
			_n = 0,
			_lib = self,
		}, Page)

		btn.Activated:Connect(function() self:_select(tab) end)
		btn.MouseEnter:Connect(function()
			if self._active ~= tab then Tween(btn, { BackgroundTransparency = 0.88 }, 0.12) end
		end)
		btn.MouseLeave:Connect(function()
			if self._active ~= tab then Tween(btn, { BackgroundTransparency = 1 }, 0.12) end
		end)

		self._tabs[#self._tabs + 1] = tab
		if not self._active then self:_select(tab) end
		return tab
	end

	------------------------------------------------ drag ---------
	-- Press & drag anywhere on the window EXCEPT on a button, textbox
	-- or a scrollbar. This replaces the old tiny drag strip, so the
	-- whole sidebar / panel background / gaps between controls drag.
	local dragging, grabOffset = false, Vector2.new(0, 0)

	local function canDragAt(pos)
		if not self._visible then return false end

		local ok, objs = pcall(function()
			return GuiService:GetGuiObjectsAtPosition(pos.X, pos.Y)
		end)

		if not ok or objs == nil then
			-- fallback: dragging only inside the window bounds
			local p, s = window.AbsolutePosition, window.AbsoluteSize
			return pos.X >= p.X and pos.X <= p.X + s.X
				and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
		end

		local sawOurs, blocked = false, false
		for _, o in ipairs(objs) do
			if o:IsDescendantOf(window) then
				sawOurs = true
				if o:IsA("TextButton") or o:IsA("TextBox") then
					blocked = true -- it's a control: let the control work
				elseif o:IsA("ScrollingFrame") then
					local p, s = o.AbsolutePosition, o.AbsoluteSize
					if pos.X >= p.X + s.X - 12 then
						blocked = true -- right edge = scrollbar
					end
				end
			elseif o:IsA("TextButton") or o:IsA("TextBox") then
				return false -- some other gui (chat / core ui) is on top
			end
		end
		return sawOurs and not blocked
	end

	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if not canDragAt(input.Position) then return end

		dragging = true
		local center = window.AbsolutePosition + window.AbsoluteSize / 2
		-- switch to offset coordinates first so the window never jumps
		window.Position = UDim2.fromOffset(center.X, center.Y)
		grabOffset = Vector2.new(input.Position.X - center.X, input.Position.Y - center.Y)
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local vp = Workspace.CurrentCamera.ViewportSize
		local half = window.AbsoluteSize / 2
		local x = math.clamp(input.Position.X - grabOffset.X, half.X, vp.X - half.X)
		local y = math.clamp(input.Position.Y - grabOffset.Y, half.Y, vp.Y - half.Y)
		window.Position = UDim2.fromOffset(x, y)
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	------------------------------------------------ global input --
	-- close open dropdown when clicking outside of it
	UserInputService.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		local drop = self._openDrop
		if not drop or not drop.Gui then return end
		local p = input.Position
		local a = drop.Gui.AbsolutePosition
		local s = drop.Gui.AbsoluteSize
		local inside = p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
		if not inside then drop:Close() end
	end)

	-- show / hide hotkey
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == self.Keybind then
			self:Toggle()
		end
	end)

	return self
end

----------------------------------------------------------------
-- Public helpers
----------------------------------------------------------------
function Library:SetName(name)
	self.Name = tostring(name)
	if self._title then self._title.Text = self.Name end
	if self._mainCard and self._mainHeader and self._active then
		self._mainHeader.Text = string.upper(self._active.Title or self._active.Name)
	end
	return self
end

function Library:SetTip(text)
	self.Tip = tostring(text)
	if self._tip then self._tip.Text = self.Tip end
	return self
end

function Library:SetUser(name)
	self.User = tostring(name)
	if self._user then self._user.Text = "Welcome, " .. self.User end
	return self
end

function Library:SetKeybind(keyCode)
	self.Keybind = keyCode
	return self
end

-- turn the drifting snow on / off (the Themes tab checkbox)
function Library:SetSnow(enabled)
	self._snowEnabled = enabled and true or false
	if self._snowLayer then self._snowLayer.Visible = self._snowEnabled end
	return self._snowEnabled
end

function Library:IsSnowEnabled()
	return self._snowEnabled == true
end

-- live accent / theme colour change for every element using it
function Library:SetAccent(color)
	local old = Theme.Accent
	Theme.Accent = color
	if self.Window then
		for _, d in ipairs(self.Window:GetDescendants()) do
			if d:IsA("GuiObject") and d.BackgroundColor3 == old then
				d.BackgroundColor3 = color
				if d:GetAttribute("BaseColor") ~= nil then
					d:SetAttribute("BaseColor", color)
					d:SetAttribute("HoverColor", color:Lerp(Color3.new(1, 1, 1), 0.12))
				end
			elseif d:IsA("UIStroke") and d.Color == old then
				d.Color = color
			elseif (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox"))
				and d.TextColor3 == old then
				d.TextColor3 = color
			end
		end
	end
	return self
end

-- extra UI scale multiplier (1 = auto-fit), used by the UI Scale slider
function Library:SetScale(multiplier)
	self._scaleMult = multiplier or 1
	if self._updateScale then self._updateScale() end
	return self._scaleMult
end

function Library:SetVisible(v)
	self._visible = v and true or false
	self.Window.Visible = self._visible
	if not self._visible and self._openDrop then self._openDrop:Close() end
	return self._visible
end

function Library:Toggle()
	return self:SetVisible(not self._visible)
end

function Library:IsVisible()
	return self._visible
end

function Library:Destroy()
	if self._snowConn then self._snowConn:Disconnect() end
	self._snowConn = nil
	if self.Gui then self.Gui:Destroy() end
	self.Gui = nil
end

-- If this file was pasted / execute()'d directly in an executor (instead of
-- being require'd), expose the library everywhere another loader might look:
--     getgenv().Phantom / shared.Phantom / _G.Phantom
pcall(function()
	if getgenv ~= nil then
		getgenv().Phantom = Library
	end
end)
pcall(function() shared.Phantom = Library end)
pcall(function() _G.Phantom = Library end)

print("[Phantom] UI library loaded - now run example.lua")

return Library
