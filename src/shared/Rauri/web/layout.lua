--!nolint
-- Rauri :: web/layout
-- Turns a computed-style DOM into absolutely positioned boxes.
-- Supports block flow, a single-line flexbox, inline flow with wrapping,
-- relative/absolute positioning, padding/margins/borders, and scrolling.

local Css = require(script.Parent.css)

local Layout = {}

local TextService = game:GetService("TextService")
local FALLBACK_CHAR = 0.56

local function fontFor(style)
	if style.fontFamily == "mono" then
		return Enum.Font.RobotoMono
	end
	local weight = style.fontWeight or 400
	if weight >= 900 then
		return Enum.Font.GothamBlack
	elseif weight >= 700 then
		return Enum.Font.GothamBold
	elseif weight >= 600 then
		return Enum.Font.GothamSemibold
	elseif weight >= 500 then
		return Enum.Font.GothamMedium
	end
	return Enum.Font.Gotham
end

local function measure(text, style, maxWidth)
	if text == nil or text == "" then
		return 0, 0
	end
	maxWidth = math.max(1, maxWidth or 1e6)
	local ok, result = pcall(function()
		return TextService:GetTextSize(
			text,
			math.max(1, math.floor(style.fontSize)),
			fontFor(style),
			Vector2.new(maxWidth, 1e6)
		)
	end)
	if ok and result then
		return result.X, math.max(result.Y, style.fontSize)
	end
	local perChar = style.fontSize * FALLBACK_CHAR
	local natural = #text * perChar
	local lines = math.max(1, math.ceil(natural / maxWidth))
	return math.min(natural, maxWidth), lines * style.fontSize * 1.3
end

local function normalizeSpace(text)
	return (tostring(text or ""):gsub("%s+", " "))
end

local function normalizeText(text)
	return normalizeSpace(text):gsub("^%s+", ""):gsub("%s+$", "")
end

local function borderWidth(style)
	return Css.resolve(style.borderWidth, 1, 0) or 0
end

local function sidePadding(style, side, base)
	return Css.resolve(style["padding" .. side], base, 0) or 0
end

local function sideMargin(style, side, base)
	return Css.resolve(style["margin" .. side], base, 0) or 0
end

local function horizontalInsets(style)
	return sidePadding(style, "Left", 0) + sidePadding(style, "Right", 0) + borderWidth(style) * 2
end

local function verticalInsets(style)
	return sidePadding(style, "Top", 0) + sidePadding(style, "Bottom", 0) + borderWidth(style) * 2
end

local function isBlockLevel(style)
	return style.display == "block" or style.display == "flex"
end

local function naturalContentWidth(node, style, computed, maxWidth)
	maxWidth = math.max(0, maxWidth)
	if node.type == "text" then
		local text = normalizeText(node.text)
		if text == "" then
			return 0
		end
		return math.min(measure(text, style, 1e6), maxWidth)
	end
	if node.attrs and node.attrs["data-icon"] then
		return math.min(style.fontSize, maxWidth)
	end
	local inner = 0
	for _, child in node.children do
		if child.type == "element" then
			local childStyle = computed[child.id]
			if childStyle and childStyle.display ~= "none" then
				if isBlockLevel(childStyle) then
					return maxWidth
				end
				inner = math.max(inner, naturalContentWidth(child, childStyle, computed, maxWidth))
			end
		elseif child.type == "text" then
			local text = normalizeText(child.text)
			if text ~= "" then
				inner = math.max(inner, measure(text, style, 1e6))
			end
		end
	end
	return math.min(inner, maxWidth)
end

-- Width a flex item asks for when it has no explicit width: block children
-- contribute their own content width (they do not fill the flex line).
local function intrinsicContentWidth(node, style, computed, maxWidth)
	maxWidth = math.max(0, maxWidth)
	if node.type == "text" then
		local text = normalizeText(node.text)
		if text == "" then
			return 0
		end
		return math.min(measure(text, style, 1e6), maxWidth)
	end
	if node.attrs and node.attrs["data-icon"] then
		return math.min(style.fontSize, maxWidth)
	end
	local inner = 0
	for _, child in node.children do
		if child.type == "element" then
			local childStyle = computed[child.id]
			if childStyle and childStyle.display ~= "none" then
				inner = math.max(inner, intrinsicContentWidth(child, childStyle, computed, maxWidth) + horizontalInsets(childStyle))
			end
		elseif child.type == "text" then
			local text = normalizeText(child.text)
			if text ~= "" then
				inner = math.max(inner, measure(text, style, 1e6))
			end
		end
	end
	return math.min(inner, maxWidth)
end

local function shiftBox(box, dx, dy)
	box.x += dx
	box.y += dy
	box.contentX += dx
	box.contentY += dy
	for _, child in box.children do
		shiftBox(child, dx, dy)
	end
end

Layout.shiftBox = shiftBox

local function textBox(node, style, x, y, width, height, text)
	return {
		node = node,
		kind = "text",
		style = style,
		text = text,
		x = x,
		y = y,
		width = width,
		height = height,
		contentX = x,
		contentY = y,
		contentWidth = width,
		contentHeight = height,
		children = {},
		zIndex = style.zIndex or 0,
	}
end

local layoutElement
local computedRef

local function visibleEntries(node, computed)
	local entries = {}
	for _, child in node.children do
		if child.type == "element" then
			local style = computed[child.id]
			if style and style.display ~= "none" then
				entries[#entries + 1] = { child = child, style = style }
			end
		elseif child.type == "text" then
			local text = normalizeSpace(child.text)
			if text ~= "" then
				entries[#entries + 1] = { child = child, style = nil }
			end
		end
	end
	return entries
end

local function alignOffset(align, free)
	if align == "center" then
		return free / 2
	elseif align == "right" or align == "end" then
		return free
	end
	return 0
end

local function layoutInline(entries, containerStyle, computed, contentX, contentY, contentWidth)
	local allText = true
	for _, entry in entries do
		if entry.child.type ~= "text" then
			allText = false
			break
		end
	end

	if allText then
		local parts = {}
		local textNode
		for _, entry in entries do
			local text = normalizeText(entry.child.text)
			if text ~= "" then
				parts[#parts + 1] = text
				textNode = entry.child
			end
		end
		local text = table.concat(parts, " ")
		if text == "" then
			return {}, 0
		end
		local _, height = measure(text, containerStyle, contentWidth)
		return {
			textBox(textNode, containerStyle, contentX, contentY, contentWidth, height, text),
		}, height
	end

	local items = {}
	for _, entry in entries do
		local child = entry.child
		if child.type == "text" then
			local text = normalizeText(child.text)
			if text ~= "" then
				local width, height = measure(text, containerStyle, 1e6)
				items[#items + 1] = {
					kind = "text",
					node = child,
					text = text,
					width = width,
					height = height,
				}
			end
		else
			local style = entry.style
			local width = Css.resolve(style.width, contentWidth, nil)
			local height = Css.resolve(style.height, nil, nil)
			local icon = child.attrs and child.attrs["data-icon"]
			if icon and not width then
				width = style.fontSize
			end
			if not width then
				width = naturalContentWidth(child, style, computed, contentWidth) + horizontalInsets(style)
			end
			local probe
			if not height then
				probe = layoutElement(child, style, 0, 0, width, nil, width, nil)
				height = probe.height
			end
			items[#items + 1] = {
				kind = "element",
				node = child,
				style = style,
				width = width,
				height = height,
				box = probe,
			}
		end
	end

	local lines = {}
	local current = { items = {}, width = 0, height = 0 }
	for _, item in items do
		if current.width > 0 and current.width + item.width > contentWidth then
			lines[#lines + 1] = current
			current = { items = {}, width = 0, height = 0 }
		end
		current.items[#current.items + 1] = item
		current.width += item.width
		current.height = math.max(current.height, item.height)
	end
	if #current.items > 0 then
		lines[#lines + 1] = current
	end

	local boxes = {}
	local cursorY = 0
	for _, line in lines do
		local offset = alignOffset(containerStyle.textAlign, contentWidth - line.width)
		for _, item in line.items do
			if item.kind == "text" then
				boxes[#boxes + 1] = textBox(
					item.node,
					containerStyle,
					contentX + offset,
					contentY + cursorY,
					item.width,
					item.height,
					item.text
				)
			else
				local box = item.box
				if box then
					shiftBox(box, contentX + offset, contentY + cursorY)
				else
					box = layoutElement(item.node, item.style, 0, 0, item.width, item.height, item.width, item.height)
					shiftBox(box, contentX + offset, contentY + cursorY)
				end
				boxes[#boxes + 1] = box
			end
			offset += item.width
		end
		cursorY += line.height
	end
	return boxes, cursorY
end

local function layoutFlex(node, entries, style, computed, contentX, contentY, contentWidth, contentHeight)
	local row = (style.flexDirection or "row") ~= "column"
	local gap = Css.resolve(style.gap, contentWidth, 0) or 0
	local absolute = {}
	local items = {}

	for _, entry in entries do
		local child, childStyle = entry.child, entry.style
		if child.type == "text" then
			local text = normalizeText(child.text)
			if text ~= "" then
				local width, height = measure(text, style, 1e6)
				items[#items + 1] = {
					kind = "text",
					node = child,
					style = style,
					text = text,
					width = width,
					height = height,
					grow = 0,
				}
			end
		elseif childStyle.position == "absolute" then
			absolute[#absolute + 1] = entry
		else
			local width = Css.resolve(childStyle.width, contentWidth, nil)
			local height = Css.resolve(childStyle.height, contentHeight, nil)
			if row then
				if not width then
					width = intrinsicContentWidth(child, childStyle, computed, contentWidth) + horizontalInsets(childStyle)
				end
			else
				if not width then
					width = contentWidth
				end
			end
			local probe
			if not height or not width then
				probe = layoutElement(child, childStyle, 0, 0, width or contentWidth, nil, width, height)
				width = probe.width
				height = probe.height
			end
			items[#items + 1] = {
				kind = "element",
				node = child,
				style = childStyle,
				width = width or 0,
				height = height or 0,
				grow = childStyle.flexGrow or 0,
				box = probe,
			}
		end
	end

	local total = 0
	for _, item in items do
		total += row and item.width or item.height
	end
	total += gap * math.max(0, #items - 1)

	local mainSize = row and contentWidth or (contentHeight or total)
	local free = mainSize - total
	if free > 0 then
		local growTotal = 0
		for _, item in items do
			if (item.grow or 0) > 0 then
				growTotal += item.grow
			end
		end
		if growTotal > 0 then
			for _, item in items do
				if (item.grow or 0) > 0 then
					local extra = free * item.grow / growTotal
					if row then
						item.width += extra
					else
						item.height += extra
					end
				end
			end
			free = 0
		end
	elseif free < 0 then
		-- flex-shrink: growable children (flex: 1) give space back first.
		local shrinkTotal = 0
		for _, item in items do
			if (item.grow or 0) > 0 then
				shrinkTotal += 1
			end
		end
		if shrinkTotal > 0 then
			for _, item in items do
				if (item.grow or 0) > 0 then
					local reduction = -free / shrinkTotal
					if row then
						item.width = math.max(0, item.width - reduction)
					else
						item.height = math.max(0, item.height - reduction)
					end
				end
			end
			free = 0
		end
	end

	local cursor = alignOffset(style.justifyContent, math.max(0, free))
	local spacing = 0
	if style.justifyContent == "space-between" and #items > 1 and free > 0 then
		spacing = free / (#items - 1)
		cursor = 0
	end

	local crossSize
	if row then
		crossSize = contentHeight
		if not crossSize then
			crossSize = 0
			for _, item in items do
				crossSize = math.max(crossSize, item.height)
			end
		end
	else
		crossSize = contentWidth
	end

	local boxes = {}
	for _, item in items do
		local childWidth, childHeight = item.width, item.height
		if style.alignItems == "stretch" then
			if row and Css.resolve(item.style.height, contentHeight, nil) == nil then
				childHeight = crossSize
			elseif not row and Css.resolve(item.style.width, contentWidth, nil) == nil then
				childWidth = crossSize
			end
		end

		local x = contentX + (row and cursor or 0)
		local y = contentY + (row and 0 or cursor)
		if row then
			local offset = 0
			if style.alignItems == "center" then
				offset = (crossSize - childHeight) / 2
			elseif style.alignItems == "end" then
				offset = crossSize - childHeight
			end
			y += offset
		else
			local offset = 0
			if style.alignItems == "center" then
				offset = (crossSize - childWidth) / 2
			elseif style.alignItems == "end" then
				offset = crossSize - childWidth
			end
			x += offset
		end

		if item.kind == "text" then
			boxes[#boxes + 1] = textBox(item.node, item.style, x, y, item.width, item.height, item.text)
		else
			local box = item.box
			if box and math.abs(box.width - childWidth) < 0.01 and math.abs(box.height - childHeight) < 0.01 then
				shiftBox(box, x, y)
			else
				box = layoutElement(item.node, item.style, 0, 0, childWidth, childHeight, childWidth, childHeight)
				shiftBox(box, x, y)
			end
			boxes[#boxes + 1] = box
		end

		cursor += (row and childWidth or childHeight) + gap + spacing
	end

	local height
	if row then
		height = crossSize
	else
		height = cursor - gap - spacing
	end
	return boxes, height, absolute
end

local function layoutBlock(entries, containerStyle, computed, contentX, contentY, contentWidth, contentHeightAvailable)
	local boxes = {}
	local absolute = {}
	local cursorY = 0

	for _, entry in entries do
		local child, childStyle = entry.child, entry.style
		if child.type == "text" then
			local text = normalizeText(child.text)
			if text ~= "" then
				local _, height = measure(text, containerStyle, contentWidth)
				boxes[#boxes + 1] = textBox(child, containerStyle, contentX, contentY + cursorY, contentWidth, height, text)
				cursorY += height
			end
		elseif childStyle.position == "absolute" then
			absolute[#absolute + 1] = entry
		else
			local marginTop = sideMargin(childStyle, "Top", contentWidth)
			local marginBottom = sideMargin(childStyle, "Bottom", contentWidth)
			local marginLeft = sideMargin(childStyle, "Left", contentWidth)
			local marginRight = sideMargin(childStyle, "Right", contentWidth)
			cursorY += marginTop
			local available = math.max(0, contentWidth - marginLeft - marginRight)
			local remaining = contentHeightAvailable and math.max(0, contentHeightAvailable - cursorY) or nil
			local box = layoutElement(
				child,
				childStyle,
				contentX + marginLeft,
				contentY + cursorY,
				available,
				remaining
			)
			boxes[#boxes + 1] = box
			cursorY = box.y + box.height - contentY + marginBottom
		end
	end
	return boxes, cursorY, absolute
end

local function layoutAbsolute(parentBox, absolute, computed)
	for _, entry in absolute do
		local child, style = entry.child, entry.style
		local width = Css.resolve(style.width, parentBox.contentWidth, nil)
		local height = Css.resolve(style.height, parentBox.contentHeight, nil)
		local left = Css.resolve(style.left, parentBox.contentWidth, nil)
		local right = Css.resolve(style.right, parentBox.contentWidth, nil)
		local top = Css.resolve(style.top, parentBox.contentHeight, nil)
		local bottom = Css.resolve(style.bottom, parentBox.contentHeight, nil)
		if not width then
			width = naturalContentWidth(child, style, computed, parentBox.contentWidth) + horizontalInsets(style)
		end
		local box = layoutElement(child, style, 0, 0, width, height, width, height)
		if not height then
			height = box.height
		end
		local x = parentBox.contentX + (left or (right and (parentBox.contentWidth - width - right) or 0))
		local y = parentBox.contentY + (top or (bottom and (parentBox.contentHeight - height - bottom) or 0))
		shiftBox(box, x, y)
		parentBox.children[#parentBox.children + 1] = box
	end
end

layoutElement = function(node, style, x, y, availableWidth, availableHeight, forcedWidth, forcedHeight)
	local border = borderWidth(style)
	local padLeft = sidePadding(style, "Left", availableWidth)
	local padRight = sidePadding(style, "Right", availableWidth)
	local padTop = sidePadding(style, "Top", availableWidth)
	local padBottom = sidePadding(style, "Bottom", availableWidth)
	local horizontal = padLeft + padRight + border * 2
	local vertical = padTop + padBottom + border * 2

	local widthSpec = forcedWidth or Css.resolve(style.width, availableWidth, nil)
	local contentWidth
	local borderBoxWidth
	if widthSpec then
		if style.boxSizing == "border-box" then
			borderBoxWidth = widthSpec
			contentWidth = math.max(0, widthSpec - horizontal)
		else
			contentWidth = widthSpec
			borderBoxWidth = widthSpec + horizontal
		end
	elseif isBlockLevel(style) or node.type == "document" then
		borderBoxWidth = math.max(0, availableWidth)
		contentWidth = math.max(0, borderBoxWidth - horizontal)
	else
		local natural = naturalContentWidth(node, style, computedRef, math.max(0, availableWidth - horizontal))
		contentWidth = natural
		borderBoxWidth = natural + horizontal
	end

	local maxWidth = Css.resolve(style.maxWidth, availableWidth, nil)
	if maxWidth then
		borderBoxWidth = math.min(borderBoxWidth, maxWidth)
		contentWidth = math.max(0, borderBoxWidth - horizontal)
	end
	local minWidth = Css.resolve(style.minWidth, availableWidth, nil)
	if minWidth then
		borderBoxWidth = math.max(borderBoxWidth, minWidth)
		contentWidth = math.max(0, borderBoxWidth - horizontal)
	end

	local contentX = x + border + padLeft
	local contentY = y + border + padTop

	local children = {}
	local contentHeight = 0
	local absolute = {}

	if node.attrs and node.attrs["data-icon"] then
		-- An icon has no children; its font-size is its box size.
		contentHeight = style.fontSize
	elseif style.display == "flex" then
		local entries = visibleEntries(node, computedRef)
		children, contentHeight, absolute = layoutFlex(
			node,
			entries,
			style,
			computedRef,
			contentX,
			contentY,
			contentWidth,
			forcedHeight and math.max(0, forcedHeight - vertical) or nil
		)
	else
		local entries = visibleEntries(node, computedRef)
		local hasBlock = false
		for _, entry in entries do
			if entry.style and isBlockLevel(entry.style) then
				hasBlock = true
				break
			end
		end
		if not hasBlock then
			children, contentHeight = layoutInline(entries, style, computedRef, contentX, contentY, contentWidth)
		else
			children, contentHeight, absolute = layoutBlock(
				entries,
				style,
				computedRef,
				contentX,
				contentY,
				contentWidth,
				forcedHeight and math.max(0, forcedHeight - vertical) or nil
			)
		end
	end

	local heightSpec = forcedHeight or Css.resolve(style.height, availableHeight, nil)
	local borderBoxHeight
	if heightSpec then
		borderBoxHeight = style.boxSizing == "border-box" and heightSpec or heightSpec + vertical
	else
		borderBoxHeight = contentHeight + vertical
	end
	local maxHeight = Css.resolve(style.maxHeight, availableHeight, nil)
	if maxHeight then
		borderBoxHeight = math.min(borderBoxHeight, maxHeight)
	end
	local minHeight = Css.resolve(style.minHeight, availableHeight, nil)
	if minHeight then
		borderBoxHeight = math.max(borderBoxHeight, minHeight)
	end

	local box = {
		node = node,
		kind = "box",
		style = style,
		x = x,
		y = y,
		width = borderBoxWidth,
		height = borderBoxHeight,
		contentX = contentX,
		contentY = contentY,
		contentWidth = contentWidth,
		contentHeight = math.max(0, borderBoxHeight - vertical),
		children = children,
		zIndex = style.zIndex or 0,
	}

	if #absolute > 0 then
		layoutAbsolute(box, absolute, computedRef)
	end

	if style.overflow == "auto" or style.overflow == "scroll" then
		box.scroll = true
		local maxBottom = 0
		for _, child in box.children do
			maxBottom = math.max(maxBottom, child.y + child.height - contentY)
		end
		box.scrollHeight = math.max(maxBottom, box.contentHeight)
	end

	return box
end

function Layout.build(document, computed, width, height)
	computedRef = computed
	local body = document.body
	local style = computed[body.id]
	local root = layoutElement(body, style, 0, 0, width, height, width, nil)
	return root
end

Layout.measure = measure
Layout.fontFor = fontFor
Layout.naturalContentWidth = naturalContentWidth

return Layout
