--!nolint
-- Rauri :: web/render
-- Converts layout boxes into Rauri virtual nodes. Text becomes labels, block
-- boxes become frames (or text buttons when they are interactive), inputs
-- become real Rauri inputs and data-icon nodes use the Molto icon registry.

local Css = require(script.Parent.css)
local Html = require(script.Parent.html)
local Components = require(script.Parent.Parent.components)

local Render = {}

local function fontToken(style)
	if style.fontFamily == "mono" then
		return "mono"
	end
	local weight = style.fontWeight or 400
	if weight >= 900 then
		return "black"
	elseif weight >= 700 then
		return "bold"
	elseif weight >= 600 then
		return "semibold"
	elseif weight >= 500 then
		return "medium"
	end
	return "regular"
end

local function radiusFor(style, width, height)
	local radius = style.borderRadius
	if not radius then
		return 0
	end
	if radius.unit == "%" then
		return math.floor(math.min(width, height) * radius.value / 100)
	end
	return math.floor(radius.value)
end

local function borderFor(style)
	if style.borderStyle ~= "solid" or not style.borderWidth then
		return nil
	end
	local width = Css.resolve(style.borderWidth, 1, 0)
	if not width or width <= 0 then
		return nil
	end
	return { width, style.borderColor or Color3.fromHex("#2c2c3a") }
end

local function paint(style, width, height)
	local alpha = (style.backgroundAlpha or 1) * (style.opacity or 1)
	if style.gradient then
		return {
			bg = style.gradient.from,
			bgAlpha = 1 - alpha,
			radius = radiusFor(style, width, height),
			border = borderFor(style),
			pad = 0,
		}
	end
	return {
		bg = style.background or false,
		bgAlpha = 1 - alpha,
		radius = radiusFor(style, width, height),
		border = borderFor(style),
		pad = 0,
	}
end

function Render.text(box, parentX, parentY, web)
	return Components.text({
		key = "t" .. box.node.id,
		width = box.width,
		height = box.height,
		position = UDim2.fromOffset(box.x - parentX, box.y - parentY),
		text = box.text,
		lineHeight = box.style.lineHeight,
		style = {
			fg = box.style.color,
			fontSize = math.max(1, math.floor(box.style.fontSize + 0.5)),
			font = fontToken(box.style),
			align = box.style.textAlign,
			valign = "top",
			wrap = box.style.whiteSpace ~= "nowrap",
		},
	})
end

local function hoverHandler(node, web)
	if not web.hoverable then
		return nil
	end
	return function(hovered)
		web:setHover(node, hovered)
	end
end

local function isInteractive(node)
	if node.attrs["data-drag"] or node.attrs["data-action"] then
		return true
	end
	if node.tag == "summary" or node.tag == "label" or node.attrs["for"] ~= nil then
		return true
	end
	return next(node.listeners) ~= nil
end

function Render.box(box, parentX, parentY, web)
	if box.kind == "text" then
		return Render.text(box, parentX, parentY, web)
	end

	local node = box.node
	local style = box.style
	local attrs = node.attrs or {}
	local width, height = box.width, box.height
	local position = UDim2.fromOffset(box.x - parentX, box.y - parentY)
	local radius = radiusFor(style, width, height)

	-- Molto icon glyph: data-icon="lucide:house" or data-icon="house".
	if attrs["data-icon"] then
		local provider, name = attrs["data-icon"]:match("^([%w_]+):(.+)$")
		return Components.icon(name or attrs["data-icon"], {
			key = "i" .. node.id,
			provider = provider,
			width = width,
			height = height,
			position = position,
			style = { fg = style.color },
		})
	end

	if node.tag == "img" then
		return Components.image({
			key = "i" .. node.id,
			image = attrs.src or "",
			width = width,
			height = height,
			position = position,
			style = { bg = style.background or false, radius = radius },
		})
	end

	if node.tag == "select" then
		local options = {}
		for _, child in ipairs(node.children) do
			if child.type == "element" and child.tag == "option" then
				options[#options + 1] = child
			end
		end
		local selectedIndex
		for index, option in ipairs(options) do
			local value = option.attrs.value or Html.flattenText(option)
			if option.attrs.selected ~= nil or (node.value ~= nil and node.value == value) then
				selectedIndex = index
				break
			end
		end
		selectedIndex = selectedIndex or 1
		local selected = options[selectedIndex]
		local label = selected and (selected.attrs.value or Html.flattenText(selected)) or "Select"
		if node.value == nil then
			node.value = selected and (selected.attrs.value or Html.flattenText(selected)) or ""
		end
		return Components.button({
			key = "s" .. node.id,
			width = width,
			height = height,
			position = position,
			text = label .. "  v",
			style = {
				bg = style.background or false,
				bgAlpha = 1 - ((style.backgroundAlpha or 1) * (style.opacity or 1)),
				fg = style.color,
				fontSize = math.max(1, math.floor(style.fontSize)),
				font = fontToken(style),
				radius = radius,
				border = borderFor(style),
				pad = { 8, 0 },
				align = "left",
			},
			onClick = function()
				web:click(node)
			end,
		})
	end

	if node.tag == "progress" then
		local maximum = tonumber(attrs.max) or 1
		local current = tonumber(node.value or attrs.value) or 0
		local fraction = math.clamp(current / math.max(0.0001, maximum), 0, 1)
		return Components.frame({
			key = "p" .. node.id,
			width = width,
			height = height,
			position = position,
			clip = true,
			style = paint(style, width, height),
		}, {
			Components.frame({
				key = "pf" .. node.id,
				width = math.max(0, (width - 2) * fraction),
				height = math.max(0, height - 2),
				position = UDim2.fromOffset(1, 1),
				style = { bg = style.color or Color3.fromHex("#6d6dfb"), radius = 999 },
			}, {}),
		})
	end

	if node.tag == "textarea" then
		return Components.input({
			key = "t" .. node.id,
			width = width,
			height = height,
			position = position,
			value = node.value or Html.flattenText(node),
			multiline = true,
			placeholder = attrs.placeholder or "",
			onInput = function(value)
				web:setInput(node, value)
			end,
			onSubmit = function(value)
				web:submit(node, value)
			end,
			style = {
				bg = style.background or Color3.fromHex("#121218"),
				bgAlpha = 1 - ((style.backgroundAlpha or 1) * (style.opacity or 1)),
				fg = style.color,
				fontSize = math.max(1, math.floor(style.fontSize)),
				font = fontToken(style),
				radius = radius,
				border = borderFor(style),
				pad = { 8, 6 },
			},
		})
	end

	if node.tag == "input" then
		local inputType = (attrs.type or "text"):lower()
		if inputType == "checkbox" then
			local check
			if node.checked then
				check = Components.icon("check", {
					key = "c" .. node.id,
					size = math.max(8, math.min(width, height) - 8),
					anchor = { 0.5, 0.5 },
					position = { 0.5, 0.5 },
					style = { fg = style.color },
				})
			end
			local props = {
				key = "b" .. node.id,
				width = width,
				height = height,
				position = position,
				style = paint(style, width, height),
				onClick = function()
					web:click(node)
				end,
			}
			local hover = hoverHandler(node, web)
			if hover then
				props.onHover = hover
			end
			return Components.button(props, check)
		elseif inputType == "radio" then
			local dot
			if node.checked then
				dot = Components.frame({
					key = "rd" .. node.id,
					size = math.max(4, math.floor(math.min(width, height) / 2)),
					anchor = { 0.5, 0.5 },
					position = { 0.5, 0, 0.5, 0 },
					style = { bg = style.color or Color3.fromHex("#6d6dfb"), radius = 999 },
				}, {})
			end
			local props = {
				key = "b" .. node.id,
				width = width,
				height = height,
				position = position,
				style = paint(style, width, height),
				onClick = function()
					web:click(node)
				end,
			}
			local hover = hoverHandler(node, web)
			if hover then
				props.onHover = hover
			end
			return Components.button(props, dot)
		elseif inputType == "range" then
			return Components.slider({
				key = "r" .. node.id,
				width = width,
				height = math.max(16, height),
				position = position,
				min = tonumber(attrs.min) or 0,
				max = tonumber(attrs.max) or 100,
				step = tonumber(attrs.step),
				value = tonumber(node.value or attrs.value) or 0,
				onChange = function(value)
					web:setInput(node, value)
				end,
			})
		end
		return Components.input({
			key = "i" .. node.id,
			width = width,
			height = height,
			position = position,
			value = node.value or attrs.value or "",
			placeholder = attrs.placeholder or "",
			onInput = function(value)
				web:setInput(node, value)
			end,
			onSubmit = function(value)
				web:submit(node, value)
			end,
			onFocus = function()
				node.state.focus = true
				web:invalidate()
			end,
			onBlur = function()
				node.state.focus = false
				web:invalidate()
			end,
			style = {
				bg = style.background or Color3.fromHex("#121218"),
				bgAlpha = 1 - (style.backgroundAlpha or 1),
				fg = style.color,
				fontSize = math.max(1, math.floor(style.fontSize)),
				font = fontToken(style),
				radius = radius,
				border = borderFor(style),
				pad = { 10, 6 },
			},
		})
	end

	local children = {}
	for _, child in box.children do
		children[#children + 1] = Render.box(child, box.x, box.y, web)
	end

	local gradient = style.gradient
	local props = {
		key = "b" .. node.id,
		width = width,
		height = height,
		position = position,
		clip = box.scroll or style.overflow == "hidden",
		zIndex = math.floor(style.zIndex or 0) + 1,
		style = paint(style, width, height),
	}
	if gradient then
		props.__gradient = gradient
	end
	local hover = hoverHandler(node, web)
	if hover then
		props.onHover = hover
	end

	if isInteractive(node) then
		props.onClick = function()
			web:click(node)
		end
		props.onPress = function()
			web:setActive(node, true)
		end
		props.onRelease = function()
			web:setActive(node, false)
		end
		if attrs["data-drag"] then
			props.onInputBegan = function(input)
				web:beginDrag(node, input)
			end
		end
		return Components.button(props, children)
	end

	if box.scroll then
		return Components.scroll({
			key = "s" .. node.id,
			width = width,
			height = height,
			position = position,
			clip = true,
			canvasSize = UDim2.fromOffset(0, math.max(0, box.scrollHeight or height)),
			automaticCanvasSize = "none",
			scrollBarThickness = 3,
			style = paint(style, width, height),
			onHover = hover,
		}, children)
	end

	return Components.frame(props, children)
end

return Render
