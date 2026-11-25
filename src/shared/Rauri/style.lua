--!nolint
-- Rauri :: style
-- Applies a style table to a Roblox GuiObject: colors, fonts, radius,
-- padding, borders, plus hover/press variants.

local Util = require(script.Parent.util)
local Theme = require(script.Parent.theme)

local Style = {}

local FONTS = {
	regular = Enum.Font.Gotham,
	medium = Enum.Font.GothamMedium,
	semibold = Enum.Font.GothamSemibold,
	bold = Enum.Font.GothamBold,
	black = Enum.Font.GothamBlack,
	mono = Enum.Font.RobotoMono,
}

local X_ALIGN = {
	left = Enum.TextXAlignment.Left,
	center = Enum.TextXAlignment.Center,
	right = Enum.TextXAlignment.Right,
}

local Y_ALIGN = {
	top = Enum.TextYAlignment.Top,
	center = Enum.TextYAlignment.Center,
	bottom = Enum.TextYAlignment.Bottom,
}

local function set(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function ensure(instance, className, name)
	local child = instance:FindFirstChild(name)
	if not child then
		child = Instance.new(className)
		child.Name = name
		child.Parent = instance
	end
	return child
end

-- Returns top, right, bottom, left.
local function sides(value)
	if type(value) == "number" then
		return value, value, value, value
	end
	if type(value) == "table" then
		if value.top or value.right or value.bottom or value.left then
			return value.top or 0, value.right or 0, value.bottom or 0, value.left or 0
		end
		local horizontal = value[1] or value.x or 0
		local vertical = value[2] or value.y or 0
		return vertical, horizontal, vertical, horizontal
	end
	return 0, 0, 0, 0
end

local function cornerRadius(value)
	if type(value) == "number" then
		return UDim.new(0, value)
	end
	if type(value) == "table" then
		return UDim.new(value[1] or value.scale or 0, value[2] or value.offset or 0)
	end
	return UDim.new(0, 0)
end

function Style.apply(instance, style, variant)
	style = style or {}
	if variant then
		style = Util.merge(style, variant)
	end

	if not instance:IsA("GuiObject") then
		return
	end

	if style.bg == nil or style.bg == false then
		set(instance, "BackgroundTransparency", 1)
	else
		set(instance, "BackgroundColor3", Theme.resolve(style.bg, Color3.new(0.07, 0.07, 0.1)))
		set(instance, "BackgroundTransparency", style.bgAlpha or 0)
	end

	local isText = instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")
	if isText then
		if style.fg then
			set(instance, "TextColor3", Theme.resolve(style.fg, Color3.new(1, 1, 1)))
		end
		if style.fontSize then
			set(instance, "TextSize", style.fontSize)
		end
		if style.font then
			set(instance, "Font", FONTS[style.font] or style.font)
		end
		if style.align then
			set(instance, "TextXAlignment", X_ALIGN[style.align] or Enum.TextXAlignment.Left)
		end
		if style.valign then
			set(instance, "TextYAlignment", Y_ALIGN[style.valign] or Enum.TextYAlignment.Center)
		end
		if style.wrap ~= nil then
			set(instance, "TextWrapped", style.wrap == true)
		end
		if style.rich ~= nil then
			set(instance, "RichText", style.rich == true)
		end
	end

	if instance:IsA("ImageLabel") and style.fg then
		set(instance, "ImageColor3", Theme.resolve(style.fg, Color3.new(1, 1, 1)))
	end

	local corner = instance:FindFirstChild("__rauriCorner")
	if style.radius ~= nil then
		if not corner then
			corner = ensure(instance, "UICorner", "__rauriCorner")
		end
		set(corner, "CornerRadius", cornerRadius(style.radius))
	elseif corner then
		set(corner, "CornerRadius", UDim.new(0, 0))
	end

	local padding = instance:FindFirstChild("__rauriPadding")
	if style.pad ~= nil then
		if not padding then
			padding = ensure(instance, "UIPadding", "__rauriPadding")
		end
		local top, right, bottom, left = sides(style.pad)
		set(padding, "PaddingTop", UDim.new(0, top))
		set(padding, "PaddingRight", UDim.new(0, right))
		set(padding, "PaddingBottom", UDim.new(0, bottom))
		set(padding, "PaddingLeft", UDim.new(0, left))
	elseif padding then
		set(padding, "PaddingTop", UDim.new(0, 0))
		set(padding, "PaddingRight", UDim.new(0, 0))
		set(padding, "PaddingBottom", UDim.new(0, 0))
		set(padding, "PaddingLeft", UDim.new(0, 0))
	end

	local stroke = instance:FindFirstChild("__rauriStroke")
	if style.border ~= nil and style.border ~= false then
		if not stroke then
			stroke = ensure(instance, "UIStroke", "__rauriStroke")
		end
		local thickness, color = 1, "$border"
		if type(style.border) == "number" then
			thickness = style.border
		elseif type(style.border) == "table" then
			thickness = style.border[1] or style.border.width or 1
			color = style.border[2] or style.border.color or "$border"
		end
		set(stroke, "Thickness", thickness)
		set(stroke, "Color", Theme.resolve(color, Color3.new(0.2, 0.2, 0.25)))
		set(stroke, "ApplyStrokeMode", Enum.ApplyStrokeMode.Border)
	elseif stroke then
		set(stroke, "Thickness", 0)
	end
end

local function connect(instance, event, fn)
	local signal = instance[event]
	if signal and signal.Connect then
		return signal:Connect(fn)
	end
	return nil
end

-- Connects hover/press variants once per instance.
function Style.bind(instance, meta)
	if meta.styleBound then
		return
	end
	meta.styleBound = true

	local function show(state)
		if not meta.style then
			return
		end
		meta.pseudo = state
		Style.apply(instance, meta.style, state and meta.style[state] or nil)
	end

	connect(instance, "MouseEnter", function()
		show("hover")
	end)
	connect(instance, "MouseLeave", function()
		show(nil)
	end)
	connect(instance, "MouseButton1Down", function()
		show("press")
	end)
	connect(instance, "MouseButton1Up", function()
		show("hover")
	end)
end

Style.FONTS = FONTS

-- Total padding on each axis, used to turn "fill" into a padded fill.
function Style.paddingSides(style)
	if not style or style.pad == nil then
		return 0, 0
	end
	local top, right, bottom, left = sides(style.pad)
	return left + right, top + bottom
end

return Style
