--!nolint
-- Rauri :: props
-- Translates element props into Roblox instance properties, styles, layouts,
-- icons and event connections.

local Util = require(script.Parent.util)
local Theme = require(script.Parent.theme)
local Style = require(script.Parent.style)
local Icons = require(script.Parent.icons)

local Props = {}

local H_ALIGN = {
	left = Enum.HorizontalAlignment.Left,
	center = Enum.HorizontalAlignment.Center,
	right = Enum.HorizontalAlignment.Right,
	start = Enum.HorizontalAlignment.Left,
	["end"] = Enum.HorizontalAlignment.Right,
}

local V_ALIGN = {
	top = Enum.VerticalAlignment.Top,
	center = Enum.VerticalAlignment.Center,
	bottom = Enum.VerticalAlignment.Bottom,
	start = Enum.VerticalAlignment.Top,
	["end"] = Enum.VerticalAlignment.Bottom,
}

local AUTO_SIZE = {
	none = Enum.AutomaticSize.None,
	x = Enum.AutomaticSize.X,
	y = Enum.AutomaticSize.Y,
	xy = Enum.AutomaticSize.XY,
	both = Enum.AutomaticSize.XY,
}

local EVENT_KEYS = {
	onClick = true,
	onPress = true,
	onRelease = true,
	onHover = true,
	onInput = true,
	onSubmit = true,
	onFocus = true,
	onBlur = true,
	onInputBegan = true,
}

local function set(instance, property, value)
	local current = instance[property]
	if current == value then
		return
	end
	pcall(function()
		instance[property] = value
	end)
end

local function connect(instance, event, fn)
	local ok, signal = pcall(function()
		return instance[event]
	end)
	if ok and signal and signal.Connect then
		return signal:Connect(fn)
	end
	return nil
end

local function bindEvent(instance, meta, key)
	local function call(...)
		local fn = meta.handlers[key]
		if not fn then
			return
		end
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Rauri] " .. key .. " failed: " .. tostring(err))
		end
	end

	if key == "onClick" then
		meta.connections[key] = connect(instance, "MouseButton1Click", function()
			call(instance)
		end)
	elseif key == "onPress" then
		meta.connections[key] = connect(instance, "MouseButton1Down", function()
			call(instance)
		end)
	elseif key == "onRelease" then
		meta.connections[key] = connect(instance, "MouseButton1Up", function()
			call(instance)
		end)
	elseif key == "onHover" then
		meta.connections[key] = {
			connect(instance, "MouseEnter", function()
				call(true, instance)
			end),
			connect(instance, "MouseLeave", function()
				call(false, instance)
			end),
		}
	elseif key == "onInput" then
		local signal = instance:GetPropertyChangedSignal("Text")
		meta.connections[key] = signal:Connect(function()
			call(instance.Text, instance)
		end)
	elseif key == "onSubmit" then
		meta.connections[key] = connect(instance, "FocusLost", function(enterPressed)
			if enterPressed then
				call(instance.Text, instance)
			end
		end)
	elseif key == "onFocus" then
		meta.connections[key] = connect(instance, "Focused", function()
			call(instance)
		end)
	elseif key == "onBlur" then
		meta.connections[key] = connect(instance, "FocusLost", function()
			call(instance)
		end)
	elseif key == "onInputBegan" then
		meta.connections[key] = connect(instance, "InputBegan", function(input)
			call(input, instance)
		end)
	end
end

local function applyIcon(instance, name, provider)
	local asset = Icons.get(name, provider)
	if not asset then
		set(instance, "Image", "")
		return false
	end
	set(instance, "Image", asset.Image)
	set(instance, "ImageRectSize", asset.RectSize)
	set(instance, "ImageRectOffset", asset.RectOffset)
	return true
end

-- CSS linear gradients become a UIGradient child; CSS 180deg points down,
-- which is UIGradient rotation 90.
local function applyGradient(instance, spec)
	local gradient = instance:FindFirstChild("__rauriGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Name = "__rauriGradient"
		gradient.Parent = instance
	end
	local from = spec.from or Color3.new(1, 1, 1)
	local to = spec.to or Color3.new(0, 0, 0)
	pcall(function()
		gradient.Color = ColorSequence.new(from, to)
	end)
	set(gradient, "Rotation", (spec.angle or 180) - 90)
end

local function ensureLayout(instance, kind)
	local className = kind == "grid" and "UIGridLayout" or "UIListLayout"
	local layout = instance:FindFirstChild("__rauriLayout")
	if layout and layout.ClassName ~= className then
		layout:Destroy()
		layout = nil
	end
	if not layout then
		layout = Instance.new(className)
		layout.Name = "__rauriLayout"
		layout.Parent = instance
	end
	return layout
end

local function applyLayout(instance, props)
	local kind = props.__layout
	if not kind then
		return
	end
	local style = props.style or {}
	local gap = props.gap
	if gap == nil then
		gap = style.gap or 0
	end
	local layout = ensureLayout(instance, kind)

	if kind == "grid" then
		layout.CellSize = UDim2.fromOffset(props.cell or 112, props.cellHeight or 92)
		layout.CellPadding = UDim2.fromOffset(gap, gap)
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.SortOrder = Enum.SortOrder.LayoutOrder
	else
		layout.FillDirection = if kind == "row" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0, gap)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		local justify = props.justify
		local cross = props.cross
		if kind == "row" then
			layout.HorizontalAlignment = H_ALIGN[justify] or Enum.HorizontalAlignment.Left
			layout.VerticalAlignment = V_ALIGN[cross] or Enum.VerticalAlignment.Top
		else
			layout.VerticalAlignment = V_ALIGN[justify] or Enum.VerticalAlignment.Top
			layout.HorizontalAlignment = H_ALIGN[cross] or Enum.HorizontalAlignment.Left
		end
	end
end

function Props.apply(instance, meta, props, kind, padX, padY)
	-- Dimensions -----------------------------------------------------------
	-- A full-scale child of a padded frame fills the padded box, not the frame.
	if props.size ~= nil then
		local target = Util.size(props.size)
		local x, y = target.X, target.Y
		if padX and padX > 0 and x.Scale == 1 and x.Offset == 0 then
			x = UDim.new(1, -padX)
		end
		if padY and padY > 0 and y.Scale == 1 and y.Offset == 0 then
			y = UDim.new(1, -padY)
		end
		set(instance, "Size", UDim2.new(x.Scale, x.Offset, y.Scale, y.Offset))
	elseif props.width ~= nil or props.height ~= nil then
		local current = instance.Size
		local width = props.width ~= nil and Util.scaleOffset(props.width) or current.X
		local height = props.height ~= nil and Util.scaleOffset(props.height) or current.Y
		if padX and padX > 0 and width.Scale == 1 and width.Offset == 0 then
			width = UDim.new(1, -padX)
		end
		if padY and padY > 0 and height.Scale == 1 and height.Offset == 0 then
			height = UDim.new(1, -padY)
		end
		set(instance, "Size", UDim2.new(width.Scale, width.Offset, height.Scale, height.Offset))
	end
	if props.position ~= nil then
		set(instance, "Position", Util.size(props.position))
	end
	if props.anchor ~= nil then
		local anchor = props.anchor
		if typeof(anchor) == "Vector2" then
			set(instance, "AnchorPoint", anchor)
		elseif anchor == "center" then
			set(instance, "AnchorPoint", Vector2.new(0.5, 0.5))
		elseif type(anchor) == "table" then
			set(instance, "AnchorPoint", Vector2.new(anchor[1] or 0, anchor[2] or 0))
		end
	end
	if props.automaticSize ~= nil then
		set(instance, "AutomaticSize", AUTO_SIZE[props.automaticSize] or props.automaticSize)
	end
	if props.scale ~= nil then
		local uiScale = instance:FindFirstChild("__rauriScale")
		if not uiScale then
			uiScale = Instance.new("UIScale")
			uiScale.Name = "__rauriScale"
			uiScale.Parent = instance
		end
		set(uiScale, "Scale", props.scale)
	end

	-- Stacking and visibility ----------------------------------------------
	if props.visible ~= nil then
		set(instance, "Visible", props.visible ~= false)
	end
	if props.clip ~= nil then
		set(instance, "ClipsDescendants", props.clip == true)
	end
	if props.zIndex ~= nil then
		set(instance, "ZIndex", props.zIndex)
	end
	if props.layoutOrder ~= nil then
		set(instance, "LayoutOrder", props.layoutOrder)
	end
	if props.name ~= nil then
		set(instance, "Name", tostring(props.name))
	end

	-- Content ---------------------------------------------------------------
	if props.text ~= nil then
		set(instance, "Text", tostring(props.text))
	end
	if props.placeholder ~= nil then
		set(instance, "PlaceholderText", tostring(props.placeholder))
	end
	if props.placeholderColor ~= nil then
		set(instance, "PlaceholderColor3", Theme.resolve(props.placeholderColor, Color3.new(0.5, 0.5, 0.55)))
	end
	if props.image ~= nil then
		set(instance, "Image", props.image)
	end
	if props.truncate ~= nil then
		set(instance, "TextTruncate", if props.truncate then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None)
	end
	if props.multiline ~= nil then
		set(instance, "MultiLine", props.multiline == true)
	end
	if props.clearOnFocus ~= nil then
		set(instance, "ClearTextOnFocus", props.clearOnFocus == true)
	end
	if props.active ~= nil then
		set(instance, "Active", props.active == true)
	end
	if props.scrollingEnabled ~= nil then
		set(instance, "ScrollingEnabled", props.scrollingEnabled == true)
	end
	if props.canvasSize ~= nil then
		set(instance, "CanvasSize", Util.size(props.canvasSize))
	end
	if props.automaticCanvasSize ~= nil then
		set(instance, "AutomaticCanvasSize", AUTO_SIZE[props.automaticCanvasSize] or props.automaticCanvasSize)
	end
	if props.scrollBarThickness ~= nil then
		set(instance, "ScrollBarThickness", props.scrollBarThickness)
	end
	if props.scrollBarImageColor3 ~= nil then
		set(instance, "ScrollBarImageColor3", Theme.resolve(props.scrollBarImageColor3, Color3.new(0.2, 0.2, 0.25)))
	end
	if props.lineHeight ~= nil then
		set(instance, "LineHeight", props.lineHeight)
	end
	if props.__gradient ~= nil then
		applyGradient(instance, props.__gradient)
	end

	-- Style -----------------------------------------------------------------
	if props.style ~= nil then
		meta.style = props.style
		Style.bind(instance, meta)
		Style.apply(instance, meta.style, meta.pseudo and meta.style[meta.pseudo] or nil)
	end

	-- Layout ----------------------------------------------------------------
	applyLayout(instance, props)

	-- Icons -----------------------------------------------------------------
	if props.__icon ~= nil then
		applyIcon(instance, props.__icon, props.__iconProvider)
	end

	-- Events ----------------------------------------------------------------
	for key, value in props do
		if EVENT_KEYS[key] then
			meta.handlers[key] = value
			if meta.connections[key] == nil then
				bindEvent(instance, meta, key)
			end
		end
	end
	for key in meta.handlers do
		if props[key] == nil then
			meta.handlers[key] = nil
		end
	end
end

return Props
