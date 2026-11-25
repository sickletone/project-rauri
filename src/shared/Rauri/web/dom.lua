--!nolint
-- Rauri :: web/dom
-- DOM operations shared by the JS bindings and Luau callers: queries,
-- attributes, classes, inline styles, children and listeners. Mutations
-- notify the document so the web view re-renders.

local Html = require(script.Parent.html)
local Css = require(script.Parent.css)

local Dom = {}

function Dom.newDocument(htmlText)
	local document = Html.parse(htmlText)
	document.onChange = function() end
	return document
end

function Dom.documentOf(node)
	local current = node
	while current and current.parent do
		current = current.parent
	end
	return current
end

function Dom.changed(node)
	local document = Dom.documentOf(node)
	if document and document.onChange then
		document.onChange()
	end
end

function Dom.querySelectorAll(root, selector, out)
	out = out or {}
	local document = Dom.documentOf(root)
	local scopeRoot = document and document.body or root
	for _, child in root.children do
		if child.type == "element" then
			if Css.matches(child, selector, scopeRoot) then
				out[#out + 1] = child
			end
			Dom.querySelectorAll(child, selector, out)
		end
	end
	return out
end

function Dom.querySelector(root, selector)
	local results = Dom.querySelectorAll(root, selector)
	return results[1]
end

function Dom.query(root, selector)
	if root.type == "element" and Css.matches(root, selector, Dom.documentOf(root).body) then
		return root
	end
	return Dom.querySelector(root, selector)
end

function Dom.create(tag)
	return Html.create(tag)
end

function Dom.append(parent, child)
	if child.parent then
		Dom.remove(child)
	end
	Html.addChild(parent, child)
	Dom.changed(parent)
	return child
end

function Dom.remove(node)
	local parent = node.parent
	if not parent then
		return
	end
	for index, child in parent.children do
		if child == node then
			table.remove(parent.children, index)
			break
		end
	end
	node.parent = nil
	Dom.changed(parent)
end

function Dom.getText(node)
	return Html.flattenText(node)
end

function Dom.setText(node, text)
	text = tostring(text or "")
	node.children = {}
	if text ~= "" then
		local textNode = Html.text(text)
		textNode.parent = node
		node.children[1] = textNode
	end
	Dom.changed(node)
end

function Dom.setHTML(node, html)
	node.children = {}
	for _, child in Html.fragment(html) do
		child.parent = node
		node.children[#node.children + 1] = child
	end
	Dom.changed(node)
end

function Dom.setAttribute(node, name, value)
	name = tostring(name):lower()
	if value == nil or value == false then
		node.attrs[name] = nil
	else
		node.attrs[name] = tostring(value)
	end
	if name == "class" then
		node.classList = Html.splitClasses(node.attrs.class)
	elseif name == "style" then
		node.inlineStyle = node.attrs.style
		node.styleTable = nil
	elseif name == "value" then
		node.value = tostring(value)
	elseif name == "checked" then
		node.checked = value ~= false and value ~= "false"
	end
	Dom.changed(node)
end

function Dom.getAttribute(node, name)
	return node.attrs[tostring(name):lower()]
end

function Dom.hasClass(node, className)
	return Html.hasClass(node, className)
end

function Dom.addClass(node, className)
	if Html.hasClass(node, className) then
		return
	end
	local classes = node.attrs.class
	node.attrs.class = classes and (classes .. " " .. className) or className
	node.classList = Html.splitClasses(node.attrs.class)
	Dom.changed(node)
end

function Dom.removeClass(node, className)
	local kept = {}
	for class in tostring(node.attrs.class or ""):gmatch("[^%s]+") do
		if class ~= className then
			kept[#kept + 1] = class
		end
	end
	node.attrs.class = table.concat(kept, " ")
	node.classList = Html.splitClasses(node.attrs.class)
	Dom.changed(node)
end

function Dom.toggleClass(node, className, force)
	local has = Html.hasClass(node, className)
	local nextValue = force
	if nextValue == nil then
		nextValue = not has
	end
	if nextValue then
		Dom.addClass(node, className)
	else
		Dom.removeClass(node, className)
	end
	return nextValue
end

local function camelToKebab(prop)
	return (tostring(prop):gsub("(%u)", function(letter)
		return "-" .. letter:lower()
	end))
end

function Dom.setStyle(node, prop, value)
	prop = camelToKebab(prop)
	node.styleTable = node.styleTable or {}
	if value == nil or value == "" then
		node.styleTable[prop] = nil
	else
		node.styleTable[prop] = tostring(value)
	end
	local parts = {}
	for name, current in node.styleTable do
		parts[#parts + 1] = name .. ":" .. current
	end
	table.sort(parts)
	node.inlineStyle = table.concat(parts, ";")
	Dom.changed(node)
end

function Dom.getStyle(node, prop)
	if node.styleTable == nil and node.inlineStyle then
		local table_ = {}
		for _, declaration in Css.parseDeclarations(node.inlineStyle) do
			table_[declaration.prop] = declaration.value
		end
		node.styleTable = table_
	end
	return node.styleTable and node.styleTable[camelToKebab(prop)] or nil
end

function Dom.setCSSText(node, text)
	node.inlineStyle = tostring(text or "")
	node.styleTable = nil
	Dom.changed(node)
end

function Dom.addListener(node, eventType, fn)
	local listeners = node.listeners[eventType]
	if not listeners then
		listeners = {}
		node.listeners[eventType] = listeners
	end
	listeners[#listeners + 1] = fn
	return function()
		for index, listener in listeners do
			if listener == fn then
				table.remove(listeners, index)
				break
			end
		end
	end
end

function Dom.clearListeners(node, eventType)
	node.listeners[eventType] = nil
end

function Dom.attrPrefix(node, prefix)
	local out = {}
	for name, value in node.attrs do
		if name:sub(1, #prefix) == prefix then
			out[name:sub(#prefix + 1)] = value
		end
	end
	return out
end

return Dom
