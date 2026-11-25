--!nolint
-- Rauri :: web/css
-- Stylesheet parsing, selectors, specificity/cascade, custom properties and
-- computed styles for the HTML renderer. Supports a practical CSS subset:
--   selectors: *, tag, .class, #id, [attr], [attr="v"], :hover, :active,
--             :focus, :root, :first-child, :last-child, descendant, >
--   layout: display block/flex/inline/inline-block/none, position, flex,
--           width/height/min/max, margin, padding, gap, box-sizing
--   paint: background (color or linear-gradient), color, border,
--          border-radius, opacity, z-index, overflow
--   text: font-size, font-weight, font-family, line-height, text-align
--   variables: --name, var(--name, fallback)

local Html = require(script.Parent.html)

local Css = {}

local NAMED_COLORS = {
	transparent = { 0, 0, 0, 0 },
	black = { 0, 0, 0, 1 },
	white = { 1, 1, 1, 1 },
	red = { 1, 0.27, 0.27, 1 },
	green = { 0.3, 0.78, 0.45, 1 },
	blue = { 0.3, 0.55, 1, 1 },
	yellow = { 1, 0.86, 0.3, 1 },
	orange = { 1, 0.62, 0.25, 1 },
	purple = { 0.62, 0.4, 1, 1 },
	pink = { 1, 0.45, 0.7, 1 },
	teal = { 0.2, 0.72, 0.68, 1 },
	cyan = { 0.25, 0.85, 0.9, 1 },
	magenta = { 0.9, 0.3, 0.85, 1 },
	indigo = { 0.42, 0.42, 0.98, 1 },
	silver = { 0.75, 0.75, 0.78, 1 },
	gray = { 0.5, 0.5, 0.55, 1 },
	grey = { 0.5, 0.5, 0.55, 1 },
	slate = { 0.33, 0.37, 0.45, 1 },
	navy = { 0.1, 0.15, 0.35, 1 },
}

local TAG_DISPLAY = {
	div = "block",
	p = "block",
	h1 = "block",
	h2 = "block",
	h3 = "block",
	h4 = "block",
	h5 = "block",
	h6 = "block",
	ul = "block",
	ol = "block",
	li = "block",
	section = "block",
	article = "block",
	header = "block",
	footer = "block",
	nav = "block",
	main = "block",
	aside = "block",
	form = "block",
	fieldset = "block",
	table = "block",
	hr = "block",
	pre = "block",
	blockquote = "block",
	span = "inline",
	a = "inline",
	b = "inline",
	strong = "inline",
	em = "inline",
	i = "inline",
	u = "inline",
	s = "inline",
	small = "inline",
	code = "inline",
	label = "inline",
	br = "inline",
	button = "inline-block",
	input = "inline-block",
	img = "inline-block",
	select = "inline-block",
	textarea = "inline-block",
	style = "none",
	script = "none",
	head = "none",
	title = "none",
	meta = "none",
	link = "none",
	template = "none",
}

local INHERITED = {
	color = true,
	fontSize = true,
	fontWeight = true,
	fontFamily = true,
	lineHeight = true,
	textAlign = true,
	letterSpacing = true,
}

local SIDE_NAMES = { "Top", "Right", "Bottom", "Left" }

local FONT_WEIGHTS = {
	normal = 400,
	medium = 500,
	semibold = 600,
	bold = 700,
	black = 900,
}

-- Utilities -------------------------------------------------------------

local function clamp01(value)
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

local function parseHexColor(hex)
	hex = hex:gsub("#", "")
	if #hex == 3 then
		hex = hex:gsub(".", "%0%0")
	end
	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	local a = 255
	if #hex >= 8 then
		a = tonumber(hex:sub(7, 8), 16) or 255
	end
	if not r or not g or not b then
		return nil
	end
	return { r / 255, g / 255, b / 255, a / 255 }
end

-- Returns Color3, alpha.
function Css.color(value)
	value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local named = NAMED_COLORS[value:lower()]
	if named then
		return Color3.new(named[1], named[2], named[3]), named[4]
	end
	if value:sub(1, 1) == "#" then
		local rgba = parseHexColor(value)
		if rgba then
			return Color3.new(rgba[1], rgba[2], rgba[3]), rgba[4]
		end
	end
	local numbers = value:match("^rgba?%s*%(([^)]*)%)$")
	if numbers then
		local tokens = {}
		for token in numbers:gmatch("[^,%s]+") do
			tokens[#tokens + 1] = tonumber(token)
		end
		if #tokens >= 3 then
			local alpha = tokens[4]
			if alpha and alpha > 1 then
				alpha = alpha / 255
			end
			return Color3.new(tokens[1] / 255, tokens[2] / 255, tokens[3] / 255), clamp01(alpha or 1)
		end
	end
	return nil, nil
end

-- Returns { value = number, unit = "px"|"%" } or nil ("auto").
function Css.length(value, fontSize, rootFontSize)
	if value == nil then
		return nil
	end
	value = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
	if value == "" or value == "auto" or value == "none" then
		return nil
	end
	local number, unit = value:match("^([%-%d%.]+)([%%%a]*)$")
	if not number then
		return nil
	end
	number = tonumber(number)
	if not number then
		return nil
	end
	unit = unit:lower()
	if unit == "%" then
		return { value = number, unit = "%" }
	elseif unit == "em" then
		return { value = number * (fontSize or 14), unit = "px" }
	elseif unit == "rem" then
		return { value = number * (rootFontSize or 16), unit = "px" }
	elseif unit == "vw" or unit == "vh" then
		return { value = number, unit = unit }
	end
	return { value = number, unit = "px" }
end

local function resolveLength(length, base, fallback)
	if length == nil then
		return fallback
	end
	if length.unit == "%" then
		return (base or 0) * length.value / 100
	elseif length.unit == "vw" or length.unit == "vh" then
		return (base or 0) * length.value / 100
	end
	return length.value
end

function Css.resolve(length, base, fallback)
	return resolveLength(length, base, fallback)
end

local function splitTopLevel(text, separator)
	local parts = {}
	local depth = 0
	local quote = nil
	local start = 1
	for index = 1, #text do
		local ch = text:sub(index, index)
		if quote then
			if ch == quote then
				quote = nil
			end
		elseif ch == '"' or ch == "'" then
			quote = ch
		elseif ch == "(" or ch == "[" then
			depth += 1
		elseif ch == ")" or ch == "]" then
			depth -= 1
		elseif ch == separator and depth == 0 then
			parts[#parts + 1] = text:sub(start, index - 1)
			start = index + 1
		end
	end
	parts[#parts + 1] = text:sub(start)
	return parts
end

local function splitSides(value)
	local parts = splitTopLevel(value, " ")
	local clean = {}
	for _, part in parts do
		if part ~= "" then
			clean[#clean + 1] = part
		end
	end
	if #clean == 1 then
		return clean[1], clean[1], clean[1], clean[1]
	elseif #clean == 2 then
		return clean[1], clean[2], clean[1], clean[2]
	elseif #clean == 3 then
		return clean[1], clean[2], clean[3], clean[2]
	end
	return clean[1], clean[2], clean[3], clean[4]
end

local function resolveVars(text, vars, depth)
	if not text:find("var%(") then
		return text
	end
	depth = depth or 0
	if depth > 12 then
		return text
	end
	local replaced = text:gsub("var%(%s*(%-%-[%w_%-]+)%s*,?%s*([^()]*)%)", function(name, fallback)
		local value = vars and vars[name]
		if value == nil or value == "" then
			value = fallback
		end
		return value or ""
	end)
	if replaced ~= text then
		return resolveVars(replaced, vars, depth + 1)
	end
	return replaced
end

-- Declarations ----------------------------------------------------------

local function parseDeclarations(text)
	local out = {}
	if not text then
		return out
	end
	for _, chunk in splitTopLevel(text, ";") do
		local prop, value = chunk:match("^%s*([%w_%-]+)%s*:%s*(.-)%s*$")
		if prop then
			local important = false
			if value:find("!important") then
				important = true
				value = value:gsub("%s*!important%s*", "")
			end
			out[#out + 1] = {
				prop = prop:lower(),
				value = value,
				important = important,
			}
		end
	end
	return out
end

-- Selectors -------------------------------------------------------------

local function parseCompound(text)
	local compound = {
		tag = nil,
		id = nil,
		classes = {},
		attrs = {},
		pseudos = {},
	}
	local index = 1
	local length = #text
	while index <= length do
		local ch = text:sub(index, index)
		local nextIndex
		if ch == "*" then
			compound.tag = "*"
			nextIndex = index + 1
		elseif ch == "#" then
			local name
			name, nextIndex = text:match("^#([%w_%-]+)()", index)
			if name then
				compound.id = name
			end
		elseif ch == "." then
			local name
			name, nextIndex = text:match("^%.([%w_%-]+)()", index)
			if name then
				compound.classes[#compound.classes + 1] = name
			end
		elseif ch == "[" then
			local close = text:find("]", index, true)
			if close then
				local body = text:sub(index + 1, close - 1)
				local name, operator, value = body:match("^%s*([%w_:%-]+)%s*([%*%^%$~=]?=?)%s*(.-)%s*$")
				if name then
					value = value:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
					compound.attrs[#compound.attrs + 1] = {
						name = name:lower(),
						operator = operator ~= "" and operator or nil,
						value = value ~= "" and value or nil,
					}
				end
				nextIndex = close + 1
			end
		elseif ch == ":" then
			local name
			name, nextIndex = text:match("^:([%w_%-]+)()", index)
			if name then
				compound.pseudos[#compound.pseudos + 1] = name:lower()
			end
		else
			local name
			name, nextIndex = text:match("^([%w_%-]+)()", index)
			if name then
				compound.tag = name:lower()
			end
		end
		if not nextIndex or nextIndex <= index then
			nextIndex = index + 1
		end
		index = nextIndex
	end
	return compound
end

local function parseComplex(text)
	local tokens = {}
	local buffer = ""
	local depth = 0
	local function flush()
		if buffer ~= "" then
			tokens[#tokens + 1] = { kind = "compound", text = buffer }
			buffer = ""
		end
	end
	for index = 1, #text do
		local ch = text:sub(index, index)
		if ch == "[" or ch == "(" then
			depth += 1
			buffer ..= ch
		elseif ch == "]" or ch == ")" then
			depth -= 1
			buffer ..= ch
		elseif depth == 0 and ch == ">" then
			flush()
			tokens[#tokens + 1] = { kind = ">" }
		elseif depth == 0 and ch:match("%s") then
			flush()
			if #tokens > 0 and tokens[#tokens].kind ~= " " then
				tokens[#tokens + 1] = { kind = " " }
			end
		else
			buffer ..= ch
		end
	end
	flush()

	local parts = {}
	for index, token in tokens do
		if token.kind == "compound" then
			local combinator = nil
			local previous = tokens[index - 1]
			if previous then
				if previous.kind == ">" then
					combinator = ">"
				elseif previous.kind == " " then
					combinator = " "
				end
			end
			parts[#parts + 1] = {
				compound = parseCompound(token.text),
				combinator = combinator,
			}
		end
	end
	return parts
end

local function specificityOf(parts)
	local ids, classes, tags = 0, 0, 0
	for _, part in parts do
		local compound = part.compound
		if compound.id then
			ids += 1
		end
		classes += #compound.classes + #compound.attrs + #compound.pseudos
		if compound.tag and compound.tag ~= "*" then
			tags += 1
		end
	end
	return ids * 100 + classes * 10 + tags
end

local function matchCompound(node, compound, root)
	if compound.tag and compound.tag ~= "*" and node.tag ~= compound.tag then
		return false
	end
	if compound.id and (node.attrs.id or "") ~= compound.id then
		return false
	end
	for _, className in compound.classes do
		if not Html.hasClass(node, className) then
			return false
		end
	end
	for _, attr in compound.attrs do
		local value = node.attrs[attr.name]
		if value == nil then
			return false
		end
		if attr.operator and attr.value then
			if attr.operator == "=" then
				if value ~= attr.value then
					return false
				end
			elseif attr.operator == "*=" then
				if not value:find(attr.value, 1, true) then
					return false
				end
			elseif attr.operator == "^=" then
				if value:sub(1, #attr.value) ~= attr.value then
					return false
				end
			elseif attr.operator == "$=" then
				if value:sub(-#attr.value) ~= attr.value then
					return false
				end
			end
		end
	end
	for _, pseudo in compound.pseudos do
		if pseudo == "hover" then
			if not node.state.hover then
				return false
			end
		elseif pseudo == "active" then
			if not node.state.active then
				return false
			end
		elseif pseudo == "focus" then
			if not node.state.focus then
				return false
			end
		elseif pseudo == "checked" then
			if not node.checked then
				return false
			end
		elseif pseudo == "root" then
			if node ~= root then
				return false
			end
		elseif pseudo == "first-child" then
			local siblings = node.parent and node.parent.children or {}
			local first
			for _, sibling in siblings do
				if sibling.type == "element" then
					first = sibling
					break
				end
			end
			if first ~= node then
				return false
			end
		elseif pseudo == "last-child" then
			local siblings = node.parent and node.parent.children or {}
			local last
			for _, sibling in siblings do
				if sibling.type == "element" then
					last = sibling
				end
			end
			if last ~= node then
				return false
			end
		else
			return false
		end
	end
	return true
end

local function matchParts(node, parts, index, root)
	if not matchCompound(node, parts[index].compound, root) then
		return false
	end
	if index == 1 then
		return true
	end
	local combinator = parts[index].combinator
	if combinator == ">" then
		local parent = node.parent
		return parent ~= nil and parent.type == "element" and matchParts(parent, parts, index - 1, root)
	end
	local ancestor = node.parent
	while ancestor and ancestor.type == "element" do
		if matchParts(ancestor, parts, index - 1, root) then
			return true
		end
		ancestor = ancestor.parent
	end
	return false
end

function Css.matchesParts(node, parts, root)
	return matchParts(node, parts, #parts, root or node)
end

function Css.parseSelector(text)
	local selectors = {}
	for _, chunk in splitTopLevel(text, ",") do
		local parts = parseComplex(chunk)
		if #parts > 0 then
			selectors[#selectors + 1] = {
				parts = parts,
				specificity = specificityOf(parts),
				text = chunk,
			}
		end
	end
	return selectors
end

function Css.matches(node, selector, root)
	if node.type ~= "element" then
		return false
	end
	for _, parsed in Css.parseSelector(selector) do
		if Css.matchesParts(node, parsed.parts, root or node) then
			return true
		end
	end
	return false
end

-- Stylesheet ------------------------------------------------------------

function Css.parse(source)
	local rules = {}
	local order = 0
	local text = tostring(source or ""):gsub("/%*.-%*/", "")

	local index = 1
	while index <= #text do
		local open = text:find("{", index, true)
		if not open then
			break
		end
		local selectorText = text:sub(index, open - 1):gsub("^%s+", ""):gsub("%s+$", "")
		-- Find the matching closing brace (rules do not nest except at-rules).
		local depth = 1
		local cursor = open + 1
		while cursor <= #text and depth > 0 do
			local ch = text:sub(cursor, cursor)
			if ch == "{" then
				depth += 1
			elseif ch == "}" then
				depth -= 1
			end
			cursor += 1
		end
		local body = text:sub(open + 1, cursor - 2)
		index = cursor

		if selectorText:sub(1, 1) ~= "@" then
			order += 1
			rules[#rules + 1] = {
				selectors = Css.parseSelector(selectorText),
				declarations = parseDeclarations(body),
				order = order,
			}
		end
	end
	return { rules = rules }
end

-- Computed styles -------------------------------------------------------

local DEFAULT_STYLE = {
	display = "block",
	position = "static",
	boxSizing = "content-box",
	overflow = "visible",
	textAlign = "left",
	fontSize = 14,
	fontWeight = 400,
	fontFamily = "sans",
	lineHeight = 1.3,
	opacity = 1,
	zIndex = 0,
	flexDirection = "row",
	justifyContent = "start",
	alignItems = "stretch",
	flexGrow = 0,
	gap = nil,
	marginTop = nil,
	marginRight = nil,
	marginBottom = nil,
	marginLeft = nil,
	paddingTop = nil,
	paddingRight = nil,
	paddingBottom = nil,
	paddingLeft = nil,
	borderWidth = nil,
	borderColor = nil,
	borderStyle = "none",
	borderRadius = nil,
	background = nil,
	backgroundAlpha = 1,
	gradient = nil,
	width = nil,
	height = nil,
	minWidth = nil,
	maxWidth = nil,
	minHeight = nil,
	maxHeight = nil,
	top = nil,
	right = nil,
	bottom = nil,
	left = nil,
}

local function parseGradient(value)
	local inner = value:match("^linear%-gradient%s*%((.*)%)$")
	if not inner then
		return nil
	end
	local parts = splitTopLevel(inner, ",")
	if #parts < 2 then
		return nil
	end
	local angle = 180
	local first = parts[1]:gsub("^%s+", ""):gsub("%s+$", "")
	local startIndex = 1
	if first:find("deg") then
		angle = tonumber(first:match("([%-%d%.]+)deg")) or 180
		startIndex = 2
	elseif first:find("to ") then
		if first:find("right") then
			angle = 90
		elseif first:find("left") then
			angle = 270
		elseif first:find("top") then
			angle = 0
		end
		startIndex = 2
	end
	local from = Css.color(parts[startIndex])
	local to = Css.color(parts[startIndex + 1] or parts[startIndex])
	if not from or not to then
		return nil
	end
	return { angle = angle, from = from, to = to }
end

local function applyDeclaration(style, declaration, context)
	local prop = declaration.prop
	local rawValue = declaration.value
	if prop:sub(1, 2) == "--" then
		return
	end
	local value = resolveVars(rawValue, context.vars)
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	local fontSize = context.parentStyle and context.parentStyle.fontSize or 14
	local rootFontSize = context.rootFontSize or 16

	if prop == "display" then
		style.display = value
	elseif prop == "position" then
		style.position = value
	elseif prop == "box-sizing" then
		style.boxSizing = value
	elseif prop == "overflow" or prop == "overflow-y" or prop == "overflow-x" then
		if value ~= "visible" then
			style.overflow = value
		end
	elseif prop == "width" then
		style.width = Css.length(value, fontSize, rootFontSize)
	elseif prop == "height" then
		style.height = Css.length(value, fontSize, rootFontSize)
	elseif prop == "min-width" then
		style.minWidth = Css.length(value, fontSize, rootFontSize)
	elseif prop == "max-width" then
		style.maxWidth = Css.length(value, fontSize, rootFontSize)
	elseif prop == "min-height" then
		style.minHeight = Css.length(value, fontSize, rootFontSize)
	elseif prop == "max-height" then
		style.maxHeight = Css.length(value, fontSize, rootFontSize)
	elseif prop == "margin" or prop == "padding" then
		local top, right, bottom, left = splitSides(value)
		local prefix = prop
		style[prefix .. "Top"] = Css.length(top, fontSize, rootFontSize)
		style[prefix .. "Right"] = Css.length(right, fontSize, rootFontSize)
		style[prefix .. "Bottom"] = Css.length(bottom, fontSize, rootFontSize)
		style[prefix .. "Left"] = Css.length(left, fontSize, rootFontSize)
	elseif prop:match("^margin%-") or prop:match("^padding%-") then
		local prefix, side = prop:match("^(%a+)%-(%a+)$")
		local key = prefix .. side:sub(1, 1):upper() .. side:sub(2)
		style[key] = Css.length(value, fontSize, rootFontSize)
	elseif prop == "gap" or prop == "column-gap" or prop == "row-gap" then
		style.gap = Css.length(value, fontSize, rootFontSize)
	elseif prop == "border" then
		if value == "none" or value == "0" then
			style.borderStyle = "none"
			style.borderWidth = nil
		else
			local width = value:match("([%d%.]+)px")
			local color = value:gsub("^%s*[%d%.]+px", ""):gsub("^%s*%a+", ""):gsub("^%s+", "")
			style.borderWidth = Css.length(width and (width .. "px") or "1px", fontSize, rootFontSize)
			style.borderColor = Css.color(color ~= "" and color or "#ffffff")
			style.borderStyle = "solid"
		end
	elseif prop == "border-width" then
		style.borderWidth = Css.length(value, fontSize, rootFontSize)
	elseif prop == "border-color" then
		style.borderColor = Css.color(value)
	elseif prop == "border-style" then
		style.borderStyle = value
	elseif prop == "border-radius" then
		local first = splitSides(value)
		style.borderRadius = Css.length(first, fontSize, rootFontSize)
	elseif prop == "background" or prop == "background-color" then
		local gradient = parseGradient(value)
		if gradient then
			style.gradient = gradient
			style.background = nil
		else
			local color, alpha = Css.color(value)
			if color then
				style.background = color
				style.backgroundAlpha = alpha or 1
				style.gradient = nil
			end
		end
	elseif prop == "color" then
		local color = Css.color(value)
		if color then
			style.color = color
		end
	elseif prop == "font-size" then
		style.fontSize = resolveLength(Css.length(value, fontSize, rootFontSize), fontSize, fontSize) or fontSize
	elseif prop == "font-weight" then
		local numeric = tonumber(value)
		style.fontWeight = numeric or FONT_WEIGHTS[value:lower()] or 400
	elseif prop == "font-family" then
		if value:lower():find("mono") or value:lower():find("code") then
			style.fontFamily = "mono"
		else
			style.fontFamily = "sans"
		end
	elseif prop == "line-height" then
		if value == "normal" then
			style.lineHeight = 1.3
		else
			local numeric = tonumber(value)
			if numeric then
				style.lineHeight = numeric
			else
				local length = Css.length(value, fontSize, rootFontSize)
				style.lineHeight = length and (length.value / math.max(1, style.fontSize)) or 1.3
			end
		end
	elseif prop == "text-align" then
		style.textAlign = value
	elseif prop == "letter-spacing" then
		style.letterSpacing = Css.length(value, fontSize, rootFontSize)
	elseif prop == "flex-direction" then
		style.flexDirection = value
	elseif prop == "flex-wrap" then
		style.flexWrap = value
	elseif prop == "justify-content" then
		style.justifyContent = value
	elseif prop == "align-items" then
		style.alignItems = value
	elseif prop == "flex" then
		local numeric = tonumber(value:match("([%d%.]+)"))
		style.flexGrow = numeric or 1
	elseif prop == "flex-grow" then
		style.flexGrow = tonumber(value) or 0
	elseif prop == "z-index" then
		style.zIndex = tonumber(value) or 0
	elseif prop == "opacity" then
		style.opacity = tonumber(value) or 1
	elseif prop == "top" then
		style.top = Css.length(value, fontSize, rootFontSize)
	elseif prop == "right" then
		style.right = Css.length(value, fontSize, rootFontSize)
	elseif prop == "bottom" then
		style.bottom = Css.length(value, fontSize, rootFontSize)
	elseif prop == "left" then
		style.left = Css.length(value, fontSize, rootFontSize)
	elseif prop == "cursor" then
		style.cursor = value
	end
end

local function inheritedStyle(parentStyle)
	local style = {}
	for key, value in DEFAULT_STYLE do
		style[key] = value
	end
	if parentStyle then
		for key in INHERITED do
			style[key] = parentStyle[key]
		end
	end
	return style
end

local function collectDeclarations(node, stylesheet, inlineCache)
	local matched = {}
	for _, rule in stylesheet.rules do
		local best = -1
		for _, selector in rule.selectors do
			if matchParts(node, selector.parts, #selector.parts, stylesheet.root) then
				if selector.specificity > best then
					best = selector.specificity
				end
			end
		end
		if best >= 0 then
			matched[#matched + 1] = {
				rule = rule,
				specificity = best,
				order = rule.order,
			}
		end
	end
	table.sort(matched, function(a, b)
		if a.specificity == b.specificity then
			return a.order < b.order
		end
		return a.specificity < b.specificity
	end)

	local declarations = {}
	for _, entry in matched do
		for _, declaration in entry.rule.declarations do
			declarations[#declarations + 1] = declaration
		end
	end

	if node.inlineStyle and node.inlineStyle ~= "" then
		local cached = inlineCache[node.inlineStyle]
		if not cached then
			cached = parseDeclarations(node.inlineStyle)
			inlineCache[node.inlineStyle] = cached
		end
		for _, declaration in cached do
			declarations[#declarations + 1] = declaration
		end
	end
	return declarations
end

function Css.compute(document, stylesheet, options)
	options = options or {}
	local rootFontSize = options.rootFontSize or 16
	local computed = {}
	local inlineCache = {}
	stylesheet.root = document.body

	local function walk(node, parentStyle, parentVars)
		local declarations = collectDeclarations(node, stylesheet, inlineCache)

		local vars = table.clone(parentVars or {})
		for _, declaration in declarations do
			if declaration.prop:sub(1, 2) == "--" then
				vars[declaration.prop] = resolveVars(declaration.value, vars)
			end
		end

		local style = inheritedStyle(parentStyle)
		style.display = TAG_DISPLAY[node.tag] or "block"
		style.color = parentStyle and parentStyle.color or Color3.fromHex("#ececf3")
		if node.value ~= nil and node.tag == "input" then
			style.display = "inline-block"
		end

		local context = {
			vars = vars,
			parentStyle = parentStyle,
			rootFontSize = rootFontSize,
		}
		for _, declaration in declarations do
			applyDeclaration(style, declaration, context)
		end
		computed[node.id] = style

		for _, child in node.children do
			if child.type == "element" then
				walk(child, style, vars)
			end
		end
	end

	if document.body then
		walk(document.body, nil, {})
	end
	return computed
end

Css.DEFAULT_STYLE = DEFAULT_STYLE
Css.TAG_DISPLAY = TAG_DISPLAY
Css.parseDeclarations = parseDeclarations
Css.splitSides = splitSides

return Css
