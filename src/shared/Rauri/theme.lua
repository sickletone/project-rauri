--!nolint
-- Rauri :: theme
-- Design tokens. Style values can reference a token with "$name".
-- Reading tokens during a render subscribes that window to theme changes.

local Signal = require(script.Parent.signal)
local Util = require(script.Parent.util)

local DEFAULT = {
	bg = "#0b0b0f",
	panel = "#121218",
	surface = "#181820",
	surfaceAlt = "#22222c",
	border = "#2c2c3a",
	text = "#ececf3",
	muted = "#8a8a9e",
	accent = "#6d6dfb",
	accentText = "#ffffff",
	danger = "#f0637a",
	success = "#43c78f",
	warn = "#f4b740",
	radius = 10,
	pad = 12,
	gap = 8,
}

local tokens = Signal.new(table.clone(DEFAULT))

local Theme = {}

function Theme.get(name)
	return tokens:get()[name]
end

function Theme.tokens()
	return tokens:get()
end

function Theme.set(values)
	local nextTokens = table.clone(tokens:get())
	for key, value in values do
		nextTokens[key] = value
	end
	tokens:set(nextTokens)
end

function Theme.setToken(name, value)
	Theme.set({ [name] = value })
end

function Theme.reset()
	tokens:set(table.clone(DEFAULT))
end

function Theme.onChanged(fn)
	return tokens:subscribe(fn)
end

-- Resolves "#6d6dfb", "$accent", or a Color3 into a Color3.
function Theme.resolve(value, fallback)
	if type(value) == "string" and value:sub(1, 1) == "$" then
		return Util.color(tokens:get()[value:sub(2)], fallback)
	end
	return Util.color(value, fallback)
end

function Theme.color(name, fallback)
	return Util.color(tokens:get()[name], fallback)
end

Theme.defaults = DEFAULT

return Theme
