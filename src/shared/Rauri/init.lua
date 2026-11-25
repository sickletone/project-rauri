--!nolint
-- Rauri
-- A Tauri-shaped app framework for Roblox: reactive UI, a core process with
-- commands and events, a capability manifest and a full icon registry.

local App = require(script.app)
local Components = require(script.components)
local Element = require(script.element)
local Icons = require(script.icons)
local Platform = require(script.platform)
local Signal = require(script.signal)
local Style = require(script.style)
local Theme = require(script.theme)
local Util = require(script.util)
local Web = require(script.web)

local Rauri = {
	version = "0.2.0",

	new = App.new,

	-- reactivity
	signal = Signal.new,
	derive = Signal.derive,
	effect = Signal.effect,
	track = Signal.track,

	-- ui
	ui = Components,
	h = Element.new,
	element = Element,

	-- design + icons
	theme = Theme,
	icons = Icons,

	-- html/css/js frontend and executor support
	web = Web,
	platform = Platform,

	-- helpers
	color = Util.color,
	util = Util,
	style = Style,
}

-- Convenience mount without a core: Rauri.mount(container, function() ... end)
function Rauri.mount(container, render)
	local app = App.new({ name = "Rauri" })
	return app:mount(render, { container = container })
end

return Rauri
