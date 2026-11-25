--!nolint
-- Rauri :: signal
-- Tiny reactive primitives. A render that calls signal:get() subscribes to it,
-- so anything the UI reads is patched automatically when it changes.

local Signal = {}

local activeWatcher = nil

local function notify(watchers)
	for watcher in watchers do
		local ok, err = pcall(watcher)
		if not ok then
			warn("[Rauri] watcher error: " .. tostring(err))
		end
	end
end

function Signal.new(initial)
	local self = {}
	self.value = initial
	self.watchers = {}

	function self:get()
		if activeWatcher then
			self.watchers[activeWatcher] = true
		end
		return self.value
	end

	function self:set(nextValue)
		if self.value == nextValue then
			return nextValue
		end
		self.value = nextValue
		notify(self.watchers)
		return nextValue
	end

	function self:update(transform)
		return self:set(transform(self.value))
	end

	function self:subscribe(watcher)
		self.watchers[watcher] = true
		return function()
			self.watchers[watcher] = nil
		end
	end

	function self:destroy()
		self.watchers = {}
	end

	return self
end

-- Runs fn while every signal read is subscribed to `watcher`.
function Signal.track(fn, watcher)
	local previous = activeWatcher
	activeWatcher = watcher
	local ok, result = pcall(fn)
	activeWatcher = previous
	if not ok then
		error(result, 0)
	end
	return result
end

-- derive(fn, a, b, ...) recomputes whenever one of the dependency signals changes.
function Signal.derive(fn, ...)
	local out = Signal.new(fn())
	for index = 1, select("#", ...) do
		local dependency = select(index, ...)
		if type(dependency) == "table" and dependency.subscribe then
			dependency:subscribe(function()
				out:set(fn())
			end)
		end
	end
	return out
end

function Signal.effect(fn, ...)
	fn()
	for index = 1, select("#", ...) do
		local dependency = select(index, ...)
		if type(dependency) == "table" and dependency.subscribe then
			dependency:subscribe(function()
				fn()
			end)
		end
	end
end

return Signal
