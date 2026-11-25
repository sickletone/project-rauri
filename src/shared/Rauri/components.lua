--!nolint
-- Rauri :: components
-- Built-in elements. Everything composes out of frame/text/button/image/icon/
-- scroll/input, so an app can drop to plain elements at any time.

local Element = require(script.Parent.element)
local Util = require(script.Parent.util)

local ui = {}

local function append(out, value)
	if value == nil or value == false then
		return
	end
	local valueType = type(value)
	if valueType == "string" or valueType == "number" then
		out[#out + 1] = tostring(value)
		return
	end
	if valueType ~= "table" then
		return
	end
	if value.__rauri then
		out[#out + 1] = value
		return
	end
	for _, child in value do
		append(out, child)
	end
end

local function collect(props, ...)
	local out = {}
	append(out, props.children)
	for index = 1, select("#", ...) do
		append(out, select(index, ...))
	end
	return out
end

local function box(layout, props, ...)
	props = Util.merge({}, props or {})
	props.__layout = layout
	return Element.new("frame", props, collect(props, ...))
end

function ui.frame(props, ...)
	props = props or {}
	return Element.new("frame", props, collect(props, ...))
end

function ui.row(props, ...)
	return box("row", props, ...)
end

function ui.column(props, ...)
	return box("column", props, ...)
end

function ui.grid(props, ...)
	props = Util.merge({ __layout = "grid", automaticSize = "y", width = "fill" }, props or {})
	return Element.new("frame", props, collect(props, ...))
end

function ui.scroll(props, ...)
	props = Util.merge({ size = "fill" }, props or {})
	return Element.new("scroll", props, collect(props, ...))
end

function ui.text(value, props)
	if type(value) == "table" and not value.__rauri then
		props = value
		value = props.text
	end
	props = Util.merge({}, props or {})
	props.text = value ~= nil and tostring(value) or tostring(props.text or "")
	props.style = Util.merge({ fg = "$text", fontSize = 14, font = "regular", valign = "center" }, props.style)
	if props.size == nil and props.width == nil then
		props.width = "fill"
	end
	if props.size == nil and props.height == nil then
		props.height = (props.style.fontSize or 14) + 8
	end
	return Element.new("text", props, {})
end

function ui.button(props, ...)
	if type(props) == "string" then
		props = { text = props }
	end
	props = Util.merge({}, props or {})
	props.style = Util.merge({
		bg = "$surfaceAlt",
		fg = "$text",
		fontSize = 13,
		font = "medium",
		radius = 8,
		pad = { 10, 7 },
		hover = { bg = "$border" },
		press = { bg = "$surface" },
	}, props.style)
	if props.height == nil and props.size == nil then
		props.height = 32
	end
	if props.size == nil and props.width == nil and props.automaticSize == nil then
		props.automaticSize = "x"
	end
	return Element.new("button", props, collect(props, ...))
end

function ui.iconButton(name, props)
	props = Util.merge({ width = 28, height = 28 }, props or {})
	props.style = Util.merge({ bg = false, radius = 6, hover = { bg = "$surfaceAlt" } }, props.style)
	return ui.button(props, ui.icon(name, {
		size = props.iconSize or 15,
		anchor = { 0.5, 0.5 },
		position = { 0.5, 0.5 },
	}))
end

function ui.input(props)
	props = Util.merge({}, props or {})
	props.style = Util.merge({
		bg = "$panel",
		fg = "$text",
		fontSize = 13,
		font = "regular",
		radius = 8,
		pad = { 10, 7 },
	}, props.style)
	props.placeholder = props.placeholder or "Search"
	props.placeholderColor = props.placeholderColor or "$muted"
	if props.height == nil and props.size == nil then
		props.height = 34
	end
	if props.size == nil and props.width == nil then
		props.width = 240
	end
	return Element.new("input", props, {})
end

function ui.icon(name, props)
	props = Util.merge({}, props or {})
	if type(name) == "table" then
		props = Util.merge(name, props)
		name = props.name or props.icon
	end
	local iconSize = props.size or 18
	props.__icon = name
	props.__iconProvider = props.provider
	props.width = props.width or iconSize
	props.height = props.height or iconSize
	props.style = Util.merge({ fg = props.color or "$text" }, props.style)
	props.size = nil
	return Element.new("icon", props, {})
end

function ui.image(props)
	props = Util.merge({}, props or {})
	return Element.new("image", props, {})
end

function ui.divider(props)
	props = Util.merge({ height = 1, width = "fill", style = { bg = "$border" } }, props or {})
	return Element.new("frame", props, {})
end

function ui.spacer(props)
	props = Util.merge({ width = 0, height = 0 }, props or {})
	return Element.new("frame", props, {})
end

function ui.chip(props, ...)
	props = Util.merge({
		height = 26,
		style = {
			bg = "$surfaceAlt",
			fg = "$muted",
			radius = 999,
			pad = { 10, 4 },
			fontSize = 12,
			font = "medium",
			hover = { bg = "$border", fg = "$text" },
		},
	}, props or {})
	return ui.button(props, ...)
end

function ui.switch(props)
	props = props or {}
	local checked = props.checked == true
	local onChange = props.onChange
	return Element.new("button", {
		size = UDim2.fromOffset(38, 22),
		style = {
			bg = checked and "$accent" or "$surfaceAlt",
			radius = 999,
			border = { 1, checked and "$accent" or "$border" },
			pad = 0,
			hover = { bg = checked and "$accent" or "$border" },
		},
		onClick = function()
			if onChange then
				onChange(not checked)
			end
		end,
	}, {
		Element.new("frame", {
			size = UDim2.fromOffset(16, 16),
			position = if checked then UDim2.new(1, -3, 0.5, 0) else UDim2.new(0, 3, 0.5, 0),
			anchor = if checked then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
			style = { bg = "#ffffff", radius = 999 },
		}, {}),
	})
end

function ui.slider(props)
	props = props or {}
	local min = props.min or 0
	local max = props.max or 1
	local value = math.clamp(props.value or min, min, max)
	local range = math.max(1e-6, max - min)
	local fraction = math.clamp((value - min) / range, 0, 1)

	local function handleInput(input, self)
		local userInputService = game:GetService("UserInputService")
		local mouse = userInputService:GetMouseLocation()
		local ratio = math.clamp((mouse.X - self.AbsolutePosition.X) / math.max(1, self.AbsoluteSize.X), 0, 1)
		local nextValue = min + range * ratio
		if props.step then
			nextValue = math.floor(nextValue / props.step + 0.5) * props.step
		end
		if props.onChange then
			props.onChange(math.clamp(nextValue, min, max))
		end
	end

	return Element.new("frame", {
		width = props.width or 260,
		height = 18,
		active = true,
		onInputBegan = function(input, self)
			if input and input.UserInputType == Enum.UserInputType.MouseButton1 then
				handleInput(input, self)
			end
		end,
	}, {
		Element.new("frame", {
			width = "fill",
			height = 6,
			anchor = { 0, 0.5 },
			position = { 0, 0, 0.5, 0 },
			style = { bg = "$surfaceAlt", radius = 999 },
		}, {}),
		Element.new("frame", {
			width = { fraction, 0 },
			height = 6,
			anchor = { 0, 0.5 },
			position = { 0, 0, 0.5, 0 },
			style = { bg = "$accent", radius = 999 },
		}, {}),
		Element.new("frame", {
			size = UDim2.fromOffset(16, 16),
			anchor = { fraction, 0.5 },
			position = UDim2.new(fraction, 0, 0.5, 0),
			style = { bg = "#ffffff", radius = 999, border = { 2, "$accent" } },
		}, {}),
	})
end

ui.collect = collect

return ui
