--!nolint
-- Rauri :: web/layout
-- Turns a computed-style DOM into absolutely positioned boxes.
-- Supports block flow, flexbox (row/column, wrap, grow/shrink/align), CSS grid,
-- inline flow, relative/absolute positioning, padding/margins/borders,
-- aspect ratios and scrolling.

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

local function displayText(text, style)
	local transform = style and style.textTransform
	if transform == "uppercase" then
		return text:upper()
	elseif transform == "lowercase" then
		return text:lower()
	elseif transform == "capitalize" then
		return (text:gsub("(%a)([%w']*)", function(first, rest)
			return first:upper() .. rest
		end))
	end
	return text
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
	return style.display == "block" or style.display == "flex" or style.display == "grid"
end

local function naturalContentWidth(node, style, computed, maxWidth)
	maxWidth = math.max(0, maxWidth)
	if node.type == "text" then
		local text = normalizeText(node.text)
		if text == "" then
			return 0
		end
		return math.min(measure(displayText(text, style), style, 1e6), maxWidth)
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
				inner = math.max(inner, measure(displayText(text, style), style, 1e6))
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
		return math.min(measure(displayText(text, style), style, 1e6), maxWidth)
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
				inner = math.max(inner, measure(displayText(text, style), style, 1e6))
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

	local nowrap = containerStyle.whiteSpace == "nowrap"

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
		local text = displayText(table.concat(parts, " "), containerStyle)
		if text == "" then
			return {}, 0
		end
		local limit = nowrap and 1e6 or contentWidth
		local width, height = measure(text, containerStyle, limit)
		if nowrap then
			width = math.min(width, 1e6)
		end
		return {
			textBox(textNode, containerStyle, contentX, contentY, width, height, text),
		}, height
	end

	local items = {}
	for _, entry in entries do
		local child = entry.child
		if child.type == "text" then
			local text = normalizeText(child.text)
			if text ~= "" then
				local shown = displayText(text, containerStyle)
				local width, height = measure(shown, containerStyle, 1e6)
				items[#items + 1] = {
					kind = "text",
					node = child,
					text = shown,
					width = width,
					height = height,
				}
			end
		elseif child.tag == "br" then
			items[#items + 1] = {
				kind = "break",
				width = 0,
				height = containerStyle.fontSize * (containerStyle.lineHeight or 1.3),
			}
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
		if item.kind == "break" then
			lines[#lines + 1] = current
			current = { items = {}, width = 0, height = item.height }
		else
			if not nowrap and current.width > 0 and current.width + item.width > contentWidth then
				lines[#lines + 1] = current
				current = { items = {}, width = 0, height = 0 }
			end
			current.items[#current.items + 1] = item
			current.width += item.width
			current.height = math.max(current.height, item.height)
		end
	end
	if #current.items > 0 or current.height > 0 then
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
			elseif item.kind == "element" then
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

-- Flexbox ----------------------------------------------------------------

local function buildFlexItems(entries, style, computed, contentWidth, contentHeight, row)
	local absolute = {}
	local items = {}
	local counter = 0

	for _, entry in entries do
		local child, childStyle = entry.child, entry.style
		if child.type == "text" then
			local text = normalizeText(child.text)
			if text ~= "" then
				local shown = displayText(text, style)
				local width, height = measure(shown, style, 1e6)
				counter += 1
				items[#items + 1] = {
					kind = "text",
					node = child,
					style = style,
					text = shown,
					width = width,
					height = height,
					grow = 0,
					shrink = 1,
					order = 0,
					index = counter,
				}
			end
		elseif childStyle.position == "absolute" then
			absolute[#absolute + 1] = entry
		elseif child.tag == "br" then
			-- line breaks do not participate in flex flow
		else
			counter += 1
			local width = Css.resolve(childStyle.width, contentWidth, nil)
			local height = Css.resolve(childStyle.height, contentHeight, nil)
			local basis = childStyle.flexBasis and Css.resolve(childStyle.flexBasis, row and contentWidth or contentHeight, nil) or nil
			if row then
				if not width then
					width = basis or (intrinsicContentWidth(child, childStyle, computed, contentWidth) + horizontalInsets(childStyle))
				end
			else
				if not width then
					width = contentWidth
				end
				if not height then
					height = basis
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
				shrink = childStyle.flexShrink or 1,
				order = childStyle.order or 0,
				alignSelf = childStyle.alignSelf,
				index = counter,
				box = probe,
			}
		end
	end

	table.sort(items, function(a, b)
		if a.order == b.order then
			return a.index < b.index
		end
		return a.order < b.order
	end)
	return items, absolute
end

local function mainSizeOf(items, row, gap)
	local total = gap * math.max(0, #items - 1)
	for _, item in items do
		total += row and item.width or item.height
	end
	return total
end

local function distributeLine(items, limit, row, gap)
	local total = mainSizeOf(items, row, gap)
	local free = limit - total
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
					item.width += extra
				end
			end
			free = 0
		end
	elseif free < 0 then
		local shrinkTotal = 0
		for _, item in items do
			shrinkTotal += (item.shrink or 1) * math.max(1, row and item.width or item.height)
		end
		if shrinkTotal > 0 then
			for _, item in items do
				local weight = (item.shrink or 1) * math.max(1, row and item.width or item.height)
				local reduction = math.min(row and item.width or item.height, -free * weight / shrinkTotal)
				if row then
					item.width -= reduction
				else
					item.height -= reduction
				end
			end
		end
		free = math.min(0, limit - mainSizeOf(items, row, gap))
	end
	return free
end

local function placeLine(items, style, row, x0, y0, contentWidth, contentHeight, lineCross, gap, limit)
	local free = distributeLine(items, limit, row, gap)
	local cursor = alignOffset(style.justifyContent, math.max(0, free))
	local spacing = 0
	if style.justifyContent == "space-between" and #items > 1 and free > 0 then
		spacing = free / (#items - 1)
		cursor = 0
	elseif style.justifyContent == "space-around" and #items > 0 and free > 0 then
		spacing = free / #items
		cursor = spacing / 2
	end

	local boxes = {}
	for _, item in items do
		local align = item.alignSelf
		if align == nil or align == "auto" then
			align = style.alignItems
		end
		local childWidth, childHeight = item.width, item.height
		if align == "stretch" then
			if row and Css.resolve(item.style.height, contentHeight, nil) == nil then
				childHeight = math.max(childHeight, lineCross)
			elseif not row and Css.resolve(item.style.width, contentWidth, nil) == nil then
				childWidth = math.max(childWidth, lineCross)
			end
		end

		local x = x0 + (row and cursor or 0)
		local y = y0 + (row and 0 or cursor)
		if row then
			local offset = 0
			if align == "center" then
				offset = (lineCross - childHeight) / 2
			elseif align == "end" then
				offset = lineCross - childHeight
			end
			y += offset
		else
			local offset = 0
			if align == "center" then
				offset = (lineCross - childWidth) / 2
			elseif align == "end" then
				offset = lineCross - childWidth
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
	return boxes, cursor - gap - spacing
end

local function layoutFlex(node, entries, style, computed, contentX, contentY, contentWidth, contentHeight)
	local row = (style.flexDirection or "row") ~= "column"
	local gap = Css.resolve(style.gap, row and contentWidth or contentHeight, 0) or 0
	local items, absolute = buildFlexItems(entries, style, computed, contentWidth, contentHeight, row)
	if #items == 0 then
		return {}, 0, absolute
	end

	local wrap = style.flexWrap == "wrap" or style.flexWrap == "wrap-reverse"
	local limit = row and contentWidth or contentHeight
	local lines = {}

	if wrap and limit then
		local current = {}
		local used = 0
		for _, item in items do
			local size = row and item.width or item.height
			if #current > 0 and used + gap + size > limit then
				lines[#lines + 1] = current
				current = {}
				used = 0
			end
			used += size + (#current > 0 and gap or 0)
			current[#current + 1] = item
		end
		if #current > 0 then
			lines[#lines + 1] = current
		end
	else
		lines[1] = items
	end

	local lineCross = {}
	local totalCross = 0
	for index, line in lines do
		local cross = 0
		for _, item in line do
			cross = math.max(cross, row and item.height or item.width)
		end
		lineCross[index] = cross
		totalCross += cross
	end
	if #lines > 1 then
		totalCross += gap * (#lines - 1)
	end

	-- align-content only matters when there is extra cross space (wrap).
	local startOffset = 0
	local lineSpacing = gap
	local extra = (contentHeight and wrap) and (contentHeight - totalCross) or 0
	if extra > 0 and #lines > 0 then
		local align = style.alignContent or "start"
		if align == "center" then
			startOffset = extra / 2
		elseif align == "end" then
			startOffset = extra
		elseif align == "space-between" and #lines > 1 then
			lineSpacing = gap + extra / (#lines - 1)
		elseif align == "space-around" then
			lineSpacing = gap + extra / #lines
			startOffset = extra / (#lines * 2)
		elseif align == "stretch" then
			for index in lineCross do
				lineCross[index] += extra / #lines
			end
		end
	end

	local boxes = {}
	local y = contentY + startOffset
	for index, line in lines do
		local placed, _ = placeLine(
			line,
			style,
			row,
			contentX,
			y,
			contentWidth,
			contentHeight,
			lineCross[index],
			gap,
			row and contentWidth or (contentHeight or mainSizeOf(line, row, gap))
		)
		for _, box in placed do
			boxes[#boxes + 1] = box
		end
		y += lineCross[index] + lineSpacing
	end

	if #lines > 0 then
		y -= lineSpacing
	end
	return boxes, y - contentY, absolute
end

-- Grid -------------------------------------------------------------------

local function resolveTracks(tracks, available, gap)
	local columns = {}
	if not tracks or #tracks == 0 then
		tracks = { { kind = "fr", value = 1 } }
	end
	local fixed = 0
	local frTotal = 0
	local autoCount = 0
	for _, track in tracks do
		if track.kind == "fixed" then
			fixed += Css.resolve(track.length, available, 0) or 0
		elseif track.kind == "fr" then
			frTotal += track.value
		else
			autoCount += 1
		end
	end
	local free = math.max(0, available - fixed - gap * math.max(0, #tracks - 1))
	local perFr = frTotal > 0 and free / frTotal or 0
	local perAuto = autoCount > 0 and free / autoCount or 0
	for _, track in tracks do
		if track.kind == "fixed" then
			columns[#columns + 1] = Css.resolve(track.length, available, 0) or 0
		elseif track.kind == "fr" then
			columns[#columns + 1] = perFr * track.value
		else
			columns[#columns + 1] = perAuto
		end
	end
	return columns
end

local function layoutGrid(node, entries, style, computed, contentX, contentY, contentWidth, contentHeight)
	local gap = Css.resolve(style.gap, contentWidth, 0) or 0
	local columns = resolveTracks(style.gridTemplateColumns, contentWidth, gap)
	local absolute = {}
	local flow = {}
	for _, entry in entries do
		if entry.child.type == "element" and entry.style.position == "absolute" then
			absolute[#absolute + 1] = entry
		elseif entry.child.type == "element" and entry.child.tag == "br" then
			-- ignore
		elseif entry.child.type == "text" and normalizeText(entry.child.text) == "" then
			-- whitespace between cells is not a grid item
		else
			flow[#flow + 1] = entry
		end
	end

	local rows = {}
	local cursor = 1
	while cursor <= #flow do
		local row = {}
		local height = 0
		for column = 1, #columns do
			local entry = flow[cursor]
			if not entry then
				break
			end
			cursor += 1
			local child = entry.child
			local childStyle = entry.style
			if child.type == "text" then
				local text = normalizeText(child.text)
				if text ~= "" then
					local shown = displayText(text, style)
					local width, measured = measure(shown, style, columns[column])
					row[#row + 1] = { kind = "text", node = child, style = style, text = shown, width = math.min(width, columns[column]), height = measured, column = column }
					height = math.max(height, measured)
				end
			else
				local width = Css.resolve(childStyle.width, columns[column], nil) or columns[column]
				local box = layoutElement(child, childStyle, 0, 0, width, nil, width, nil)
				row[#row + 1] = { kind = "element", box = box, width = width, height = box.height, column = column }
				height = math.max(height, box.height)
			end
		end
		rows[#rows + 1] = { items = row, height = height }
	end

	local boxes = {}
	local y = 0
	for index, row in rows do
		local rowHeight = row.height
		local explicit = style.gridTemplateRows and style.gridTemplateRows[index]
		if explicit then
			local size = Css.resolve(explicit.length, contentHeight, rowHeight) or rowHeight
			rowHeight = math.max(rowHeight, size)
		end
		local x = 0
		for _, cell in row.items do
			if cell.kind == "text" then
				boxes[#boxes + 1] = textBox(cell.node, cell.style, contentX + x, contentY + y, cell.width, cell.height, cell.text)
			else
				local box = cell.box
				if math.abs(box.height - rowHeight) > 0.01 and Css.resolve(box.style.height, contentHeight, nil) == nil then
					box = layoutElement(box.node, box.style, 0, 0, cell.width, rowHeight, cell.width, rowHeight)
				end
				shiftBox(box, contentX + x, contentY + y)
				boxes[#boxes + 1] = box
			end
			x += columns[cell.column] + gap
		end
		y += rowHeight + gap
	end

	return boxes, math.max(0, y - gap), absolute
end

-- Block flow -------------------------------------------------------------

local function layoutBlock(entries, containerStyle, computed, contentX, contentY, contentWidth, contentHeightAvailable)
	local boxes = {}
	local absolute = {}
	local cursorY = 0

	for _, entry in entries do
		local child, childStyle = entry.child, entry.style
		if child.type == "text" then
			local text = normalizeText(child.text)
			if text ~= "" then
				local shown = displayText(text, containerStyle)
				local limit = containerStyle.whiteSpace == "nowrap" and 1e6 or contentWidth
				local width, height = measure(shown, containerStyle, limit)
				boxes[#boxes + 1] = textBox(child, containerStyle, contentX, contentY + cursorY, width, height, shown)
				cursorY += height
			end
		elseif child.tag == "br" then
			cursorY += containerStyle.fontSize * (containerStyle.lineHeight or 1.3)
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
	elseif style.display == "grid" then
		local entries = visibleEntries(node, computedRef)
		children, contentHeight, absolute = layoutGrid(
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
	if not heightSpec and style.aspectRatio and style.aspectRatio > 0 then
		local ratioHeight = borderBoxWidth / style.aspectRatio
		heightSpec = style.boxSizing == "border-box" and ratioHeight or (ratioHeight - vertical)
	end
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
