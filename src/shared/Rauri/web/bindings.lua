--!nolint
-- Rauri :: web/bindings
-- The JavaScript host environment: document/element wrappers over the Rauri
-- DOM, console, timers, Math/Object/JSON shims, localStorage and the rauri
-- bridge (notify, theme, commands, events, executor summary).

local Html = require(script.Parent.html)
local Dom = require(script.Parent.dom)
local Css = require(script.Parent.css)
local Js = require(script.Parent.js)
local Platform = require(script.Parent.Parent.platform)

local Bindings = {}

local ELEMENT_MT = {}

local function kebabCase(name)
	return (tostring(name):gsub("(%u)", function(letter)
		return "-" .. letter:lower()
	end))
end

local function joinValues(...)
	local parts = {}
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if value == nil then
			parts[#parts + 1] = "undefined"
		elseif type(value) == "table" then
			parts[#parts + 1] = "[object]"
		else
			parts[#parts + 1] = tostring(value)
		end
	end
	return table.concat(parts, " ")
end

function Bindings.create(web)
	local cache = setmetatable({}, { __mode = "k" })

	local function unwrap(value)
		if type(value) == "table" then
			local node = rawget(value, "__node")
			if node then
				return node
			end
		end
		return value
	end

	local documentWrapper
	local wrap

	local function styleProxy(node)
		return setmetatable({}, {
			__index = function(_, key)
				if key == "cssText" then
					return node.inlineStyle or ""
				end
				return Dom.getStyle(node, key)
			end,
			__newindex = function(_, key, value)
				if key == "cssText" then
					Dom.setCSSText(node, value)
				else
					Dom.setStyle(node, key, value)
				end
			end,
		})
	end

	local function datasetProxy(node)
		return setmetatable({}, {
			__index = function(_, key)
				return node.attrs["data-" .. kebabCase(key)]
			end,
			__newindex = function(_, key, value)
				Dom.setAttribute(node, "data-" .. kebabCase(key), value)
			end,
		})
	end

	local function classListProxy(node)
		return {
			add = function(name)
				Dom.addClass(node, tostring(name))
			end,
			remove = function(name)
				Dom.removeClass(node, tostring(name))
			end,
			toggle = function(name, force)
				return Dom.toggleClass(node, tostring(name), force)
			end,
			contains = function(name)
				return Html.hasClass(node, tostring(name))
			end,
		}
	end

	local function elementChildren(node)
		local list = Js.array({})
		for _, child in node.children do
			if child.type == "element" then
				list[#list + 1] = wrap(child)
			end
		end
		return list
	end

	local function boxOf(node)
		return web:boxOf(node)
	end

	ELEMENT_MT.__index = function(wrapper, key)
		local node = rawget(wrapper, "__node")
		if node == nil then
			return nil
		end

		if key == "node" then
			return node
		elseif key == "tagName" or key == "nodeName" then
			return node.tag and node.tag:upper() or "#TEXT"
		elseif key == "nodeType" then
			return node.type == "element" and 1 or 3
		elseif key == "id" then
			return node.attrs.id or ""
		elseif key == "className" then
			return node.attrs.class or ""
		elseif key == "textContent" or key == "innerText" then
			return Html.flattenText(node)
		elseif key == "innerHTML" then
			return ""
		elseif key == "value" then
			return node.value or node.attrs.value or ""
		elseif key == "checked" then
			return node.checked == true
		elseif key == "style" then
			return styleProxy(node)
		elseif key == "dataset" then
			return datasetProxy(node)
		elseif key == "classList" then
			return classListProxy(node)
		elseif key == "children" then
			return elementChildren(node)
		elseif key == "childNodes" then
			local list = Js.array({})
			for _, child in node.children do
				list[#list + 1] = wrap(child)
			end
			return list
		elseif key == "firstChild" then
			local child = node.children[1]
			return child and wrap(child) or nil
		elseif key == "lastChild" then
			local child = node.children[#node.children]
			return child and wrap(child) or nil
		elseif key == "parentNode" or key == "parentElement" then
			if node.parent == nil then
				return nil
			elseif node.parent.type == "document" then
				return documentWrapper
			end
			return wrap(node.parent)
		elseif key == "nextSibling" then
			local siblings = node.parent and node.parent.children or {}
			for index, sibling in siblings do
				if sibling == node then
					local following = siblings[index + 1]
					return following and wrap(following) or nil
				end
			end
			return nil
		elseif key == "clientWidth" or key == "offsetWidth" then
			local box = boxOf(node)
			return box and box.width or 0
		elseif key == "clientHeight" or key == "offsetHeight" then
			local box = boxOf(node)
			return box and box.height or 0
		elseif key == "offsetLeft" then
			local box = boxOf(node)
			return box and box.x or 0
		elseif key == "offsetTop" then
			local box = boxOf(node)
			return box and box.y or 0
		elseif key == "querySelector" then
			return function(selector)
				local found = Dom.querySelector(node, tostring(selector))
				return found and wrap(found) or nil
			end
		elseif key == "querySelectorAll" then
			return function(selector)
				local found = Dom.querySelectorAll(node, tostring(selector))
				local list = Js.array({})
				for _, item in found do
					list[#list + 1] = wrap(item)
				end
				return list
			end
		elseif key == "getAttribute" then
			return function(name)
				return node.attrs[tostring(name):lower()]
			end
		elseif key == "setAttribute" then
			return function(name, value)
				Dom.setAttribute(node, name, value)
			end
		elseif key == "removeAttribute" then
			return function(name)
				Dom.setAttribute(node, name, nil)
			end
		elseif key == "hasAttribute" then
			return function(name)
				return node.attrs[tostring(name):lower()] ~= nil
			end
		elseif key == "appendChild" then
			return function(child)
				local raw = unwrap(child)
				if type(raw) ~= "table" then
					raw = Html.text(tostring(raw))
				end
				Dom.append(node, raw)
				return child
			end
		elseif key == "append" then
			return function(...)
				for index = 1, select("#", ...) do
					local child = select(index, ...)
					local raw = unwrap(child)
					if type(raw) ~= "table" then
						raw = Html.text(tostring(raw))
					end
					Dom.append(node, raw)
				end
			end
		elseif key == "removeChild" then
			return function(child)
				local raw = unwrap(child)
				if raw and raw.parent then
					Dom.remove(raw)
				end
				return child
			end
		elseif key == "remove" then
			return function()
				Dom.remove(node)
			end
		elseif key == "addEventListener" then
			return function(eventType, fn)
				if type(fn) == "function" then
					Dom.addListener(node, tostring(eventType), fn)
					web:invalidate()
				end
			end
		elseif key == "removeEventListener" then
			return function(eventType, fn)
				local listeners = node.listeners[tostring(eventType)]
				if not listeners then
					return
				end
				for index, listener in listeners do
					if listener == fn then
						table.remove(listeners, index)
						break
					end
				end
			end
		elseif key == "closest" then
			return function(selector)
				local current = node
				local root = Dom.documentOf(node).body
				while current and current.type == "element" do
					if Css.matches(current, tostring(selector), root) then
						return wrap(current)
					end
					current = current.parent
				end
				return nil
			end
		elseif key == "matches" then
			return function(selector)
				return Css.matches(node, tostring(selector), Dom.documentOf(node).body)
			end
		elseif key == "click" then
			return function()
				web:click(node)
			end
		elseif key == "focus" then
			return function()
				node.state.focus = true
				web:invalidate()
			end
		elseif key == "blur" then
			return function()
				node.state.focus = false
				web:invalidate()
			end
		elseif key == "getBoundingClientRect" then
			return function()
				local box = boxOf(node)
				if not box then
					return { x = 0, y = 0, left = 0, top = 0, width = 0, height = 0 }
				end
				return { x = box.x, y = box.y, left = box.x, top = box.y, width = box.width, height = box.height }
			end
		elseif key == "toString" then
			return function()
				return Html.flattenText(node)
			end
		end

		return nil
	end

	ELEMENT_MT.__newindex = function(wrapper, key, value)
		local node = rawget(wrapper, "__node")
		if node == nil then
			rawset(wrapper, key, value)
			return
		end

		if key == "textContent" or key == "innerText" then
			Dom.setText(node, value)
		elseif key == "innerHTML" then
			Dom.setHTML(node, value)
		elseif key == "value" then
			node.value = tostring(value)
			web:invalidate()
		elseif key == "checked" then
			node.checked = Js.truthy(value)
			web:invalidate()
		elseif key == "className" then
			Dom.setAttribute(node, "class", value)
		elseif key == "id" then
			Dom.setAttribute(node, "id", value)
		elseif key == "style" then
			Dom.setCSSText(node, value)
		elseif key == "onclick" or key == "oninput" or key == "onchange" or key == "onsubmit" or key == "onkeydown" then
			local eventType = key:sub(3)
			if type(value) == "function" then
				node.listeners[eventType] = { value }
				web:invalidate()
			else
				node.listeners[eventType] = nil
			end
		elseif key == "disabled" then
			Dom.setAttribute(node, "disabled", value and "true" or nil)
		elseif key == "dataset" then
			rawset(wrapper, key, value)
		else
			rawset(wrapper, key, value)
		end
	end

	wrap = function(node)
		if type(node) ~= "table" then
			return node
		end
		local existing = cache[node]
		if existing then
			return existing
		end
		local wrapper = setmetatable({ __node = node }, ELEMENT_MT)
		cache[node] = wrapper
		return wrapper
	end

	local documentNode = web.document

	documentWrapper = {
		body = wrap(documentNode.body),
		head = documentNode.head and wrap(documentNode.head) or nil,
		documentElement = wrap(documentNode.body),
		title = web.config.title or "Rauri",
		querySelector = function(selector)
			local found = Dom.querySelector(documentNode.body, tostring(selector))
			return found and wrap(found) or nil
		end,
		querySelectorAll = function(selector)
			local found = Dom.querySelectorAll(documentNode.body, tostring(selector))
			local list = Js.array({})
			for _, item in found do
				list[#list + 1] = wrap(item)
			end
			return list
		end,
		getElementById = function(id)
			local found = documentNode.body
			local selector = "#" .. tostring(id)
			if Css.matches(found, selector, documentNode.body) then
				return wrap(found)
			end
			found = Dom.querySelector(found, selector)
			return found and wrap(found) or nil
		end,
		createElement = function(tag)
			return wrap(Dom.create(tostring(tag)))
		end,
		createTextNode = function(text)
			return wrap(Html.text(tostring(text)))
		end,
		addEventListener = function() end,
		removeEventListener = function() end,
	}

	local storage = {
		get = function(key)
			return web.storage[tostring(key)]
		end,
		set = function(key, value)
			web.storage[tostring(key)] = value
		end,
		remove = function(key)
			web.storage[tostring(key)] = nil
		end,
		clear = function()
			web.storage = {}
		end,
	}

	local console = {
		log = function(...)
			web:log(joinValues(...))
		end,
		info = function(...)
			web:log(joinValues(...))
		end,
		warn = function(...)
			web:log(joinValues(...))
		end,
		error = function(...)
			web:log(joinValues(...))
		end,
	}

	local mathHost = {
		PI = math.pi,
		E = math.exp(1),
		abs = math.abs,
		floor = math.floor,
		ceil = math.ceil,
		round = function(value)
			return math.floor(toNumber(value) + 0.5)
		end,
		min = math.min,
		max = math.max,
		pow = function(a, b)
			return a ^ b
		end,
		sqrt = math.sqrt,
		random = function()
			return math.random()
		end,
		sin = math.sin,
		cos = math.cos,
		tan = math.tan,
	}

	local objectHost = {
		keys = function(value)
			local list = Js.array({})
			if type(value) == "table" then
				for key in value do
					list[#list + 1] = key
				end
			end
			return list
		end,
		values = function(value)
			local list = Js.array({})
			if type(value) == "table" then
				for _, item in value do
					list[#list + 1] = item
				end
			end
			return list
		end,
		entries = function(value)
			local list = Js.array({})
			if type(value) == "table" then
				for key, item in value do
					list[#list + 1] = Js.array({ key, item })
				end
			end
			return list
		end,
		fromEntries = function(entries)
			local object = {}
			if type(entries) == "table" then
				for _, pair in entries do
					if type(pair) == "table" then
						object[pair[1]] = pair[2]
					end
				end
			end
			return object
		end,
		freeze = function(value)
			return value
		end,
		assign = function(target, ...)
			for index = 1, select("#", ...) do
				local source = select(index, ...)
				if type(source) == "table" then
					for key, item in source do
						target[key] = item
					end
				end
			end
			return target
		end,
	}

	local jsonHost = {}
	do
		local ok, httpService = pcall(function()
			return game:GetService("HttpService")
		end)
		if ok and httpService then
			if typeof(httpService.JSONDecode) == "function" then
				jsonHost.parse = function(text)
					local success, value = pcall(function()
						return httpService:JSONDecode(text)
					end)
					if not success then
						error("JSON.parse failed: " .. tostring(value), 0)
					end
					return value
				end
			end
			if typeof(httpService.JSONEncode) == "function" then
				jsonHost.stringify = function(value)
					local success, text = pcall(function()
						return httpService:JSONEncode(value)
					end)
					if not success then
						error("JSON.stringify failed: " .. tostring(text), 0)
					end
					return text
				end
			end
		end
	end

	local rauri = {
		version = "0.2.0",
		platform = {
			executor = Platform.isExecutor(),
		},
		notify = function(message)
			web:notify(message)
		end,
		close = function()
			web:close()
		end,
		minimize = function()
			web.minimized:set(true)
		end,
		restore = function()
			web.minimized:set(false)
		end,
		theme = {
			set = function(name, value)
				web:setVar(name, value)
			end,
			get = function(name)
				return web:var(name)
			end,
			tokens = function()
				return table.clone(web.vars)
			end,
		},
		storage = storage,
		command = function(name, payload)
			if not web.core then
				return nil
			end
			local ok, result = web.core:invoke(tostring(name), payload, { window = "main" })
			if not ok then
				error(tostring(result), 0)
			end
			return result
		end,
		on = function(event, fn)
			if web.core and type(fn) == "function" then
				web.core:listen(tostring(event), fn)
			end
		end,
	}

	local arrayHost = {
		isArray = function(value)
			return Js.isArray(value)
		end,
		from = function(value)
			local list = Js.array({})
			if type(value) == "string" then
				for index = 1, #value do
					list[#list + 1] = value:sub(index, index)
				end
			elseif type(value) == "table" then
				for _, item in value do
					list[#list + 1] = item
				end
			end
			return list
		end,
	}

	local numberHost = {
		isInteger = function(value)
			return type(value) == "number" and value % 1 == 0
		end,
		isFinite = function(value)
			return tonumber(value) ~= nil
		end,
		isNaN = function(value)
			return tonumber(value) == nil
		end,
		parseInt = function(value)
			return tonumber(tostring(value):match("^%s*([%-%+]?%d+)")) or 0
		end,
		parseFloat = function(value)
			return tonumber(tostring(value):match("^%s*([%-%+]?%d*%.?%d+)")) or 0
		end,
	}

	local host = {
		document = documentWrapper,
		console = console,
		Math = mathHost,
		Object = objectHost,
		Array = arrayHost,
		Number = numberHost,
		String = {
			fromCharCode = function(...)
				local parts = {}
				for index = 1, select("#", ...) do
					local ok, char = pcall(utf8.char, math.floor(tonumber(select(index, ...)) or 0))
					if ok then
						parts[#parts + 1] = char
					end
				end
				return table.concat(parts)
			end,
		},
		JSON = jsonHost,
		parseInt = function(value)
			local number = tostring(value):match("^%s*([%-%+]?%d+)")
			return tonumber(number) or 0
		end,
		parseFloat = function(value)
			local number = tostring(value):match("^%s*([%-%+]?%d*%.?%d+)")
			return tonumber(number) or 0
		end,
		isNaN = function(value)
			return tonumber(value) == nil
		end,
		setTimeout = function(fn, milliseconds)
			if type(fn) == "function" then
				task.delay(math.max(0, (tonumber(milliseconds) or 0) / 1000), fn)
			end
		end,
		clearTimeout = function() end,
		setInterval = function() end,
		alert = function(message)
			web:notify(message)
		end,
		rauri = rauri,
		localStorage = storage,
	}
	host.window = host
	host.globalThis = host

	return host, wrap, unwrap
end

return Bindings
