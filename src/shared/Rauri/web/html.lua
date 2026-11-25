--!nolint
-- Rauri :: web/html
-- A forgiving HTML parser: tags, attributes, void elements, comments,
-- entities, raw <style>/<script> bodies, and a small DOM node model.

local Html = {}

local nextId = 0

local VOID = {
	area = true,
	base = true,
	br = true,
	col = true,
	embed = true,
	hr = true,
	img = true,
	input = true,
	link = true,
	meta = true,
	param = true,
	source = true,
	track = true,
	wbr = true,
}

local RAW = {
	script = true,
	style = true,
	textarea = true,
	title = true,
}

local ENTITIES = {
	amp = "&",
	lt = "<",
	gt = ">",
	quot = '"',
	apos = "'",
	nbsp = " ",
	copy = "©",
	reg = "®",
	hellip = "…",
	mdash = "—",
	ndash = "–",
	times = "×",
	check = "✓",
	arrowright = "→",
}

local function nextNodeId()
	nextId += 1
	return nextId
end

local function newNode(nodeType, tag)
	return {
		id = nextNodeId(),
		type = nodeType,
		tag = tag,
		attrs = {},
		children = {},
		listeners = {},
		state = {},
		value = nil,
		checked = false,
	}
end

local function decodeEntities(text)
	return (text:gsub("&(#?[%w]+);", function(entity)
		if entity:sub(1, 1) == "#" then
			local code
			if entity:sub(2, 2):lower() == "x" then
				code = tonumber(entity:sub(3), 16)
			else
				code = tonumber(entity:sub(2))
			end
			if code then
				local ok, decoded = pcall(utf8.char, code)
				if ok then
					return decoded
				end
			end
			return "&" .. entity .. ";"
		end
		return ENTITIES[entity] or ("&" .. entity .. ";")
	end))
end

local function addChild(parent, child)
	child.parent = parent
	parent.children[#parent.children + 1] = child
end

local function pushText(parent, text)
	if text == "" then
		return
	end
	local node = newNode("text", "#text")
	node.text = decodeEntities(text)
	addChild(parent, node)
end

local function splitClasses(value)
	local set = {}
	for class in tostring(value or ""):gmatch("[^%s]+") do
		set[class] = true
	end
	return set
end

local function parseAttributes(text, node)
	local index = 1
	local length = #text
	while index <= length do
		local skip = text:match("^[%s/]*()", index)
		index = skip
		if index > length then
			break
		end
		local stop = text:find("[%s=/>]", index)
		if not stop then
			stop = length + 1
		end
		local name = text:sub(index, stop - 1):lower()
		if name == "" then
			index += 1
		else
			index = stop
			local skipSpace = text:match("^%s*()", index)
			index = skipSpace
			local value = ""
			if text:sub(index, index) == "=" then
				index += 1
				index = text:match("^%s*()", index)
				local quote = text:sub(index, index)
				if quote == '"' or quote == "'" then
					local close = text:find(quote, index + 1, true)
					if close then
						value = text:sub(index + 1, close - 1)
						index = close + 1
					else
						value = text:sub(index + 1)
						index = length + 1
					end
				else
					local valueStop = text:find("[%s>]", index)
					if valueStop then
						value = text:sub(index, valueStop - 1)
						index = valueStop
					else
						value = text:sub(index)
						index = length + 1
					end
				end
			end
			value = decodeEntities(value)
			node.attrs[name] = value
			if name == "class" then
				node.classList = splitClasses(value)
			elseif name == "style" then
				node.inlineStyle = value
			elseif name == "value" then
				node.value = value
			elseif name == "checked" then
				node.checked = value ~= "false"
			end
		end
	end
end

local function normalize(node)
	for _, child in node.children do
		if child.type == "element" then
			child.classList = splitClasses(child.attrs.class)
			normalize(child)
		end
	end
end

local function findTag(node, tag)
	for _, child in node.children do
		if child.type == "element" then
			if child.tag == tag then
				return child
			end
			local nested = findTag(child, tag)
			if nested then
				return nested
			end
		end
	end
	return nil
end

function Html.create(tag)
	local node = newNode("element", tostring(tag):lower())
	return node
end

function Html.text(value)
	local node = newNode("text", "#text")
	node.text = tostring(value or "")
	node.raw = true
	return node
end

function Html.parse(source)
	source = tostring(source or "")
	local doc = newNode("document", "#document")
	local stack = { doc }
	local index = 1
	local length = #source

	while index <= length do
		local lt = source:find("<", index, true)
		if not lt then
			pushText(stack[#stack], source:sub(index))
			break
		end
		if lt > index then
			pushText(stack[#stack], source:sub(index, lt - 1))
		end
		index = lt

		if source:sub(index, index + 3) == "<!--" then
			local close = source:find("-->", index + 4, true)
			index = close and close + 3 or length + 1
		elseif source:sub(index, index + 1) == "</" then
			local close = source:find(">", index, true)
			local rawName = source:sub(index + 2, (close or length + 1) - 1)
			local name = rawName:match("^%s*([%w:_%-]+)")
			if name then
				name = name:lower()
				for position = #stack, 2, -1 do
					if stack[position].tag == name then
						for pop = #stack, position, -1 do
							stack[pop] = nil
						end
						break
					end
				end
			end
			index = (close or length) + 1
		else
			local cursor = index + 1
			local quote = nil
			local close
			while cursor <= length do
				local ch = source:sub(cursor, cursor)
				if quote then
					if ch == quote then
						quote = nil
					end
				elseif ch == '"' or ch == "'" then
					quote = ch
				elseif ch == ">" then
					close = cursor
					break
				end
				cursor += 1
			end

			local tagText = source:sub(index + 1, (close or length + 1) - 1)
			local name = tagText:match("^%s*([%w:_%-]+)")
			if not name then
				pushText(stack[#stack], "<")
				index += 1
			else
				name = name:lower()
				local selfClosing = tagText:sub(-1) == "/"
				local node = newNode("element", name)
				parseAttributes(tagText:sub(#name + 1), node)
				addChild(stack[#stack], node)
				index = (close or length) + 1

				if RAW[name] and not selfClosing then
					local pattern = "</%s*" .. name .. "%s*>"
					local startIndex, endIndex = source:lower():find(pattern, index)
					local raw
					if startIndex then
						raw = source:sub(index, startIndex - 1)
						index = endIndex + 1
					else
						raw = source:sub(index)
						index = length + 1
					end
					local textNode = newNode("text", "#text")
					textNode.text = raw
					textNode.raw = true
					addChild(node, textNode)
				elseif not VOID[name] and not selfClosing then
					stack[#stack + 1] = node
				end
			end
		end
	end

	return Html.structure(doc)
end

function Html.fragment(source)
	local doc = Html.parse(source)
	local fragment = newNode("element", "#fragment")
	for _, child in table.clone(doc.body.children) do
		child.parent = fragment
		fragment.children[#fragment.children + 1] = child
	end
	return fragment.children
end

-- Normalizes a parsed document into { head, body } and assigns class lists.
function Html.structure(doc)
	local html = findTag(doc, "html")
	local body = html and findTag(html, "body") or nil
	local head = html and findTag(html, "head") or nil

	if not body then
		body = newNode("element", "body")
		local source = html and html.children or doc.children
		for _, child in table.clone(source) do
			if child ~= head then
				addChild(body, child)
			end
		end
	end

	doc.children = {}
	doc.body = body
	body.parent = doc
	addChild(doc, body)
	if head then
		head.parent = doc
		doc.head = head
	end
	body.classList = splitClasses(body.attrs.class)
	normalize(body)
	return doc
end

function Html.classes(node)
	return node.classList or splitClasses(node.attrs.class)
end

function Html.hasClass(node, className)
	return Html.classes(node)[className] == true
end

function Html.flattenText(node)
	local parts = {}
	local function walk(current)
		for _, child in current.children do
			if child.type == "text" then
				parts[#parts + 1] = child.text
			elseif child.type == "element" then
				walk(child)
			end
		end
	end
	walk(node)
	return table.concat(parts)
end

Html.decodeEntities = decodeEntities
Html.splitClasses = splitClasses
Html.addChild = addChild
Html.newNode = newNode

return Html
