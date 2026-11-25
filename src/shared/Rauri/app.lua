--!nolint
-- Rauri :: app
-- The "core" side of a Rauri app: commands, events, capabilities and windows.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.signal)
local Reconciler = require(script.Parent.reconciler)
local Theme = require(script.Parent.theme)
local Util = require(script.Parent.util)

local App = {}
App.__index = App

local function matches(pattern, command)
	if pattern == "*" then
		return true
	elseif pattern:sub(-1) == "*" then
		return command:sub(1, #pattern - 1) == pattern:sub(1, -2)
	end
	return command == pattern
end

function App.new(config)
	config = config or {}
	return setmetatable({
		name = config.name or "Rauri app",
		version = config.version or "0.1.0",
		capabilities = config.capabilities,
		startedAt = os.clock(),
		_handlers = {},
		_listeners = {},
		_windows = {},
	}, App)
end

function App:handle(command, handler)
	assert(type(command) == "string", "command name must be a string")
	assert(typeof(handler) == "function", "command handler must be a function")
	self._handlers[command] = handler
	return function()
		if self._handlers[command] == handler then
			self._handlers[command] = nil
		end
	end
end

function App:commands()
	local names = {}
	for name in self._handlers do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- A window may call a command when the capability manifest allows it.
-- No manifest means "local development": everything is allowed.
function App:allowed(window, command)
	local caps = self.capabilities
	if caps == nil then
		return true
	end
	for _, pattern in caps.deny or {} do
		if matches(pattern, command) then
			return false
		end
	end
	local allow = {}
	for _, pattern in caps.default or {} do
		table.insert(allow, pattern)
	end
	local scoped = caps.windows and caps.windows[window]
	if scoped then
		for _, pattern in scoped do
			table.insert(allow, pattern)
		end
	end
	for _, pattern in allow do
		if matches(pattern, command) then
			return true
		end
	end
	return false
end

-- Calls a core command. Handlers run synchronously; long work should use
-- task.spawn plus app:emit() to stream results back to the window.
-- Returns (ok, resultOrError).
function App:invoke(command, payload, options)
	options = options or {}
	local window = options.window or "main"
	local handler = self._handlers[command]
	if not handler then
		return false, string.format('unknown command "%s"', command)
	end
	if not self:allowed(window, command) then
		return false, string.format('capability denied: %s (window "%s")', command, window)
	end
	local context = {
		app = self,
		window = window,
		command = command,
		player = options.player or Players.LocalPlayer,
	}
	local ok, result = pcall(handler, payload, context)
	if not ok then
		return false, tostring(result)
	end
	return true, result
end

-- Core -> window event. Listeners are plain callbacks registered by the UI.
function App:emit(event, payload)
	local listeners = self._listeners[event]
	if not listeners then
		return
	end
	for listener in listeners do
		local ok, err = pcall(listener, payload)
		if not ok then
			warn(string.format('[Rauri] "%s" listener failed: %s', event, tostring(err)))
		end
	end
end

function App:listen(event, listener)
	local listeners = self._listeners[event]
	if not listeners then
		listeners = {}
		self._listeners[event] = listeners
	end
	listeners[listener] = true
	return function()
		listeners[listener] = nil
	end
end

function App:uptime()
	return Util.uptime(self.startedAt)
end

-- Mounts a window. The render function is re-run whenever a signal it read
-- changes, then the tree is diffed into Roblox instances.
function App:mount(render, options)
	options = options or {}
	local windowName = options.name or "main"

	local gui
	local createdGui = false
	if options.container then
		gui = options.container
	else
		local parent = options.parent
		if not parent then
			local player = Players.LocalPlayer
			parent = player:WaitForChild("PlayerGui")
		end
		gui = Instance.new("ScreenGui")
		gui.Name = options.guiName or ("Rauri: " .. self.name)
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = options.ignoreInset ~= false
		gui.DisplayOrder = options.displayOrder or 50
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = parent
		createdGui = true
	end
	assert(gui, "[Rauri] mount needs a container or a parent")

	local dirty = false
	local mounted = true
	local markDirty = function()
		dirty = true
	end

	local renderer = Reconciler.mount(gui, function()
		return Signal.track(render, markDirty)
	end)

	local function flush()
		if dirty and mounted then
			dirty = false
			local ok, err = pcall(renderer.draw)
			if not ok then
				warn("[Rauri] render failed: " .. tostring(err))
			end
		end
	end

	local connection
	if RunService then
		connection = RunService.Heartbeat:Connect(flush)
	else
		task.spawn(function()
			while mounted do
				task.wait()
				flush()
			end
		end)
	end

	local unsubscribeTheme = Theme.onChanged(markDirty)

	local handle = {
		name = windowName,
		gui = gui,
		app = self,
	}

	function handle:invalidate()
		dirty = true
	end

	function handle:flush()
		dirty = true
		flush()
	end

	function handle:rerender(fn)
		if fn then
			render = fn
		end
		handle:flush()
	end

	function handle:unmount()
		if not mounted then
			return
		end
		mounted = false
		if connection then
			connection:Disconnect()
		end
		unsubscribeTheme()
		renderer.unmount()
		if createdGui then
			gui:Destroy()
		end
		handle.app._windows[windowName] = nil
	end

	self._windows[windowName] = handle
	return handle
end

function App:window(name)
	return self._windows[name or "main"]
end

function App:destroy()
	for _, window in table.clone(self._windows) do
		window:unmount()
	end
	self._handlers = {}
	self._listeners = {}
end

return App
