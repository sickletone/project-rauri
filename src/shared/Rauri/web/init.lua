--!nolint
-- Rauri :: web
-- Bring the web to Roblox: parse HTML/CSS, lay it out, render it with Rauri
-- elements and run JavaScript against a DOM. This is what lets script
-- developers write UI once in HTML/CSS/JS and load it in an executor.
--
--   local Rauri = loadstring(game:HttpGet(".../rauri.lua"))()
--   Rauri.web.app({ title = "My Hub", html = [[ ... ]], css = [[ ... ]], js = [[ ... ]] })

local Html = require(script.html)
local Css = require(script.css)
local Dom = require(script.dom)
local Layout = require(script.layout)
local Render = require(script.render)
local Js = require(script.js)
local Bindings = require(script.bindings)

local Signal = require(script.Parent.signal)
local App = require(script.Parent.app)
local Components = require(script.Parent.components)
local Platform = require(script.Parent.platform)

local Web = {}
Web.__index = Web

Web.version = "0.2.0"

local BASE_CSS = [[
* { box-sizing: border-box; }
:root {
  --bg: #0b0b0f;
  --panel: #121218;
  --surface: #181820;
  --surface-alt: #22222c;
  --border: #2c2c3a;
  --text: #ececf3;
  --muted: #8a8a9e;
  --accent: #6d6dfb;
  --accent-text: #ffffff;
  --danger: #f0637a;
  --success: #43c78f;
  --radius: 12px;
}
body {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  background: var(--bg);
  color: var(--text);
  font-size: 13px;
  font-family: sans-serif;
  overflow: hidden;
}
h1 { font-size: 22px; font-weight: 700; margin: 0 0 8px 0; }
h2 { font-size: 17px; font-weight: 600; margin: 0 0 8px 0; }
h3 { font-size: 14px; font-weight: 600; margin: 0 0 6px 0; }
p { margin: 0 0 8px 0; }
a { color: var(--accent); }
code { font-family: mono; background: var(--surface); color: var(--text); }
button {
  border-radius: 8px;
  background: var(--surface-alt);
  color: var(--text);
  padding: 7px 12px;
  font-size: 13px;
  font-weight: 500;
}
button:hover { background: var(--border); }
button:active { background: var(--surface); }
input {
  background: var(--panel);
  color: var(--text);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 7px 10px;
  font-size: 13px;
}
input::placeholder { color: var(--muted); }
.rauri-window {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  background: var(--bg);
  border-radius: var(--radius);
  overflow: hidden;
}
.rauri-titlebar {
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
  height: 38px;
  padding: 0 12px;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
}
.rauri-title {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 8px;
  color: var(--text);
  font-size: 12px;
  font-weight: 600;
}
.rauri-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--accent);
}
.rauri-controls {
  display: flex;
  flex-direction: row;
  gap: 4px;
}
.rauri-controls button {
  width: 24px;
  height: 20px;
  border-radius: 5px;
  background: transparent;
  color: var(--muted);
  font-size: 13px;
  padding: 0;
}
.rauri-controls button:hover { background: var(--surface-alt); color: var(--text); }
.rauri-close:hover { background: var(--danger); color: white; }
.rauri-body {
  flex: 1;
  overflow-y: auto;
  padding: 14px;
}
.rauri-empty {
  color: var(--muted);
  font-size: 13px;
}
]]

local DEFAULT_VARS = {
	["--bg"] = "#0b0b0f",
	["--panel"] = "#121218",
	["--surface"] = "#181820",
	["--surface-alt"] = "#22222c",
	["--border"] = "#2c2c3a",
	["--text"] = "#ececf3",
	["--muted"] = "#8a8a9e",
	["--accent"] = "#6d6dfb",
	["--accent-text"] = "#ffffff",
	["--danger"] = "#f0637a",
	["--success"] = "#43c78f",
	["--radius"] = "12px",
}

local function chromeMarkup(title, body)
	return string.format([[
<div class="rauri-window">
  <div class="rauri-titlebar" data-drag="true">
    <div class="rauri-title"><span class="rauri-dot"></span><span>%s</span></div>
    <div class="rauri-controls">
      <button class="rauri-min" data-action="minimize" title="Minimize">-</button>
      <button class="rauri-close" data-action="close" title="Close">x</button>
    </div>
  </div>
  <div class="rauri-body">%s</div>
</div>]], tostring(title or "Rauri"), body)
end

local function toCssValue(value, isRadius)
	if type(value) == "number" then
		return tostring(value) .. "px"
	end
	return tostring(value)
end

function Web.new(config)
	config = config or {}
	local self = setmetatable({}, Web)
	self.config = config
	self.width = config.width or 760
	self.height = config.height or 520
	self.radius = config.radius or 12
	self.version = Signal.new(0)
	self.position = Signal.new(UDim2.new(0.5, 0, 0.5, 0))
	self.minimized = Signal.new(false)
	self.toasts = Signal.new({})
	self.storage = {}
	self.boxById = {}
	self.toastCounter = 0
	self.closed = false
	self.vars = {}

	for name, value in DEFAULT_VARS do
		self.vars[name] = value
	end
	self.vars["--radius"] = tostring(self.radius) .. "px"
	for name, value in config.theme or {} do
		name = tostring(name)
		if name:sub(1, 2) ~= "--" then
			name = "--" .. name
		end
		self.vars[name] = toCssValue(value)
	end

	self:build(config)
	return self
end

function Web:build(config)
	local html = config.html
	if not html and config.url then
		html = Platform.httpGet(config.url)
		if not html then
			html = '<div class="rauri-empty">Could not load ' .. tostring(config.url) .. '</div>'
		end
	end
	html = html or '<div class="rauri-empty">Rauri web</div>'
	if config.chrome ~= false then
		html = chromeMarkup(config.title or "Rauri", html)
	end

	self.document = Dom.newDocument(html)
	self.document.onChange = function()
		self:invalidate()
	end

	self.scripts = {}
	for _, scriptNode in Dom.querySelectorAll(self.document, "script") do
		local source = Html.flattenText(scriptNode)
		local src = scriptNode.attrs.src
		if src and src ~= "" then
			if Platform.isExecutor() then
				local body = Platform.httpGet(src)
				if body then
					self.scripts[#self.scripts + 1] = body
				end
			end
		elseif source ~= "" then
			self.scripts[#self.scripts + 1] = source
		end
	end

	self.styleTags = ""
	for _, styleNode in Dom.querySelectorAll(self.document, "style") do
		self.styleTags = self.styleTags .. "\n" .. Html.flattenText(styleNode)
	end
	-- Remote stylesheets are fetched in executors (game:HttpGet); elsewhere
	-- they are ignored, like an offline browser.
	for _, linkNode in Dom.querySelectorAll(self.document, "link") do
		local href = linkNode.attrs.href
		local rel = (linkNode.attrs.rel or ""):lower()
		if href and rel == "stylesheet" and Platform.isExecutor() then
			local body = Platform.httpGet(href)
			if body then
				self.styleTags = self.styleTags .. "\n" .. body
			end
		end
	end

	self:rebuildStyles()
end

function Web:themeCss()
	local parts = { ":root {" }
	for name, value in self.vars do
		if name:sub(1, 2) == "--" then
			parts[#parts + 1] = name .. ": " .. tostring(value) .. ";"
		end
	end
	parts[#parts + 1] = "}"
	return table.concat(parts, "\n")
end

function Web:rebuildStyles()
	local css = BASE_CSS .. "\n" .. self:themeCss() .. "\n" .. self.styleTags .. "\n" .. (self.config.css or "")
	self.stylesheet = Css.parse(css)
	self.hoverable = css:find(":hover", 1, true) ~= nil
end

function Web:invalidate()
	self.version:update(function(value)
		return value + 1
	end)
end

function Web:log(message)
	message = tostring(message)
	if self.config.onLog then
		pcall(self.config.onLog, message)
	else
		warn("[Rauri web] " .. message)
	end
end

function Web:var(name)
	name = tostring(name or "")
	if name:sub(1, 2) ~= "--" then
		name = "--" .. name
	end
	return self.vars[name] or DEFAULT_VARS[name] or ""
end

function Web:setVar(name, value)
	name = tostring(name or "")
	if name:sub(1, 2) ~= "--" then
		name = "--" .. name
	end
	self.vars[name] = toCssValue(value)
	self:rebuildStyles()
	self:invalidate()
end

function Web:boxOf(node)
	if not node then
		return nil
	end
	return self.boxById[node.id]
end

function Web:start()
	if self.started then
		return
	end
	self.started = true

	self.host, self.wrap, self.unwrap = Bindings.create(self)

	local sources = {}
	local configJs = self.config.js
	if type(configJs) == "table" then
		for _, source in configJs do
			sources[#sources + 1] = source
		end
	elseif configJs then
		sources[#sources + 1] = configJs
	end
	for _, source in self.scripts do
		sources[#sources + 1] = source
	end

	for _, source in sources do
		local ok, err = Js.run(source, self.host)
		if not ok then
			self:log(err)
		end
	end
end

function Web:notify(message, duration)
	self.toastCounter += 1
	local id = self.toastCounter
	local list = table.clone(self.toasts:get())
	list[#list + 1] = { id = id, message = tostring(message or "") }
	self.toasts:set(list)

	task.delay(duration or 2.6, function()
		local current = {}
		for _, toast in self.toasts:get() do
			if toast.id ~= id then
				current[#current + 1] = toast
			end
		end
		self.toasts:set(current)
	end)
end

function Web:setHover(node, hovered)
	if node.state.hover == hovered then
		return
	end
	node.state.hover = hovered
	self:invalidate()
end

function Web:setActive(node, active)
	if node.state.active == active then
		return
	end
	node.state.active = active
	self:invalidate()
end

function Web:dispatch(node, eventType, detail)
	detail = detail or {}
	local wrap = self.wrap or function(value)
		return value
	end
	local event = {
		type = eventType,
		target = wrap(node),
		currentTarget = wrap(node),
		value = detail.value,
		key = detail.key,
		action = detail.action,
	}
	function event.stopPropagation()
		event.propagationStopped = true
	end
	function event.preventDefault()
		event.defaultPrevented = true
	end

	local current = node
	while current do
		event.currentTarget = wrap(current)
		local listeners = current.listeners[eventType]
		if listeners then
			for _, listener in table.clone(listeners) do
				local ok, err = pcall(listener, event)
				if not ok then
					self:log("listener error: " .. tostring(err))
				end
			end
		end
		if event.propagationStopped then
			break
		end
		current = current.parent
	end
end

function Web:action(name)
	if name == "close" then
		self:close()
	elseif name == "minimize" then
		self.minimized:set(true)
	elseif name == "restore" then
		self.minimized:set(false)
	else
		self:dispatch(self.document.body, "action", { action = name })
	end
end

function Web:click(node)
	local action = node.attrs["data-action"]
	if action then
		self:action(action)
	end
	if node.tag == "input" and (node.attrs.type or "text"):lower() == "checkbox" then
		node.checked = not node.checked
		self:invalidate()
		self:dispatch(node, "input")
		self:dispatch(node, "change")
	end
	self:dispatch(node, "click")
end

function Web:setInput(node, value)
	node.value = tostring(value)
	self:dispatch(node, "input", { value = node.value })
	if self.config.onInput then
		pcall(self.config.onInput, node, node.value)
	end
end

function Web:submit(node, value)
	if value ~= nil then
		node.value = tostring(value)
	end
	self:dispatch(node, "submit", { value = node.value })
end

function Web:beginDrag(node, input)
	if not input or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local userInputService = game:GetService("UserInputService")
	local startMouse = userInputService:GetMouseLocation()
	local start = self.position:get()
	local changedConnection
	local endedConnection

	changedConnection = userInputService.InputChanged:Connect(function(changed)
		if changed.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local mouse = userInputService:GetMouseLocation()
		self.position:set(UDim2.new(
			start.X.Scale,
			start.X.Offset + (mouse.X - startMouse.X),
			start.Y.Scale,
			start.Y.Offset + (mouse.Y - startMouse.Y)
		))
	end)

	endedConnection = userInputService.InputEnded:Connect(function(finished)
		local isMouse = finished == input or (finished and finished.UserInputType == Enum.UserInputType.MouseButton1)
		if isMouse then
			if changedConnection then
				changedConnection:Disconnect()
			end
			if endedConnection then
				endedConnection:Disconnect()
			end
		end
	end)
end

function Web:close()
	if self.closed then
		return
	end
	self.closed = true
	if self.handle then
		self.handle:unmount()
	end
	if self.gui then
		self.gui:Destroy()
	end
	if self.config.onClose then
		pcall(self.config.onClose)
	end
end

function Web:indexBoxes(box)
	self.boxById[box.node.id] = box
	for _, child in box.children do
		self:indexBoxes(child)
	end
end

function Web:view()
	local version = self.version:get()
	local minimized = self.minimized:get()
	local position = self.position:get()
	local toasts = self.toasts:get()

	if minimized then
		return Components.button({
			key = "rauri-restore",
			width = 168,
			height = 34,
			anchor = { 0.5, 0.5 },
			position = UDim2.new(0.5, 0, 0.5, 0),
			text = "Rauri - restore",
			style = {
				bg = self:var("surface-alt"),
				fg = self:var("text"),
				font = "medium",
				fontSize = 12,
				radius = 999,
				border = { 1, self:var("border") },
				pad = { 14, 7 },
			},
			onClick = function()
				self.minimized:set(false)
			end,
		})
	end

	self.boxById = {}
	local computed = Css.compute(self.document, self.stylesheet, {})
	local root = Layout.build(self.document, computed, self.width, self.height)
	self:indexBoxes(root)

	local page = Render.box(root, root.x, root.y, self)
	local toastNodes = {}
	for index, toast in toasts do
		toastNodes[#toastNodes + 1] = Components.frame({
			key = "toast-" .. tostring(toast.id),
			width = 260,
			height = 34,
			anchor = { 1, 1 },
			position = UDim2.new(1, -14, 1, -14 - (#toastNodes * 42)),
			zIndex = 200,
			style = {
				bg = self:var("surface-alt"),
				radius = 8,
				border = { 1, self:var("border") },
				pad = 0,
			},
		}, {
			Components.text({
				key = "toast-text-" .. tostring(toast.id),
				width = 260,
				height = 34,
				text = toast.message,
				style = {
					fg = self:var("text"),
					fontSize = 12,
					font = "medium",
					valign = "center",
					align = "center",
				},
			}),
		})
	end

	return Components.frame({
		key = "rauri-window",
		width = self.width,
		height = self.height,
		anchor = { 0.5, 0.5 },
		position = position,
		clip = true,
		zIndex = 10,
		style = {
			bg = self:var("bg"),
			radius = self.radius,
			border = { 1, self:var("border") },
		},
	}, {
		page,
		Components.frame({
			key = "rauri-toasts",
			width = self.width,
			height = self.height,
			position = UDim2.fromOffset(0, 0),
			style = { bg = false },
			zIndex = 150,
		}, toastNodes),
	})
end

-- Creates a ScreenGui and mounts the web view into a Rauri core.
function Web.app(config)
	config = config or {}
	local self = Web.new(config)
	local parent = config.parent or config.gui or Platform.guiParent()
	if not parent then
		error("[Rauri web] no GUI parent available")
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = config.name or ("Rauri: " .. tostring(config.title or "Web"))
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = config.ignoreInset ~= false
	gui.DisplayOrder = config.displayOrder or 60
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Platform.protect(gui)
	gui.Parent = parent
	self.gui = gui

	self:start()

	local core = config.core or App.new({
		name = config.title or "Rauri web app",
		capabilities = config.capabilities,
	})
	self.core = core

	local handle = core:mount(function()
		return self:view()
	end, { container = gui })
	self.handle = handle

	local api = {
		web = self,
		core = core,
		gui = gui,
		window = handle,
	}
	function api:close()
		self.web:close()
	end
	function api:toast(message)
		self.web:notify(message)
	end
	function api:destroy()
		self.web:close()
	end
	return api
end

function Web.mount(config)
	return Web.app(config)
end

Web.BASE_CSS = BASE_CSS
Web.DEFAULT_VARS = DEFAULT_VARS

-- Escape hatches for app developers who want the same engine pieces.
Web.dom = Dom
Web.css = Css
Web.html = Html
Web.layout = Layout
Web.js = Js
Web.render = Render

return Web
