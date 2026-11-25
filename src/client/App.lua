--!nolint
-- Rauri Studio: the demo app. The "core" below is the equivalent of Tauri's
-- Rust side: it owns commands, emits events and checks the capability manifest.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rauri = require(ReplicatedStorage.Rauri)
local Shell = require(script.Parent.Shell)

local App = {}

local ACCENTS = {
	{ name = "Indigo", value = "#6d6dfb" },
	{ name = "Teal", value = "#22b3a6" },
	{ name = "Rose", value = "#ef5f7a" },
	{ name = "Amber", value = "#f0a13c" },
	{ name = "Green", value = "#49c26a" },
}

function App.start()
	local state = {
		page = Rauri.signal("home"),
		provider = Rauri.signal(Rauri.icons.getProvider()),
		providerInfo = Rauri.signal(Rauri.icons.info()),
		query = Rauri.signal(""),
		selectedIcon = Rauri.signal("sparkles"),
		showNames = Rauri.signal(true),
		toasts = Rauri.signal({}),
		stats = Rauri.signal({ fps = 0, ping = 0, players = 1, memory = 0 }),
		logs = Rauri.signal({}),
		scale = Rauri.signal(1),
		accent = Rauri.signal(ACCENTS[1].value),
		minimized = Rauri.signal(false),
		closed = Rauri.signal(false),
		windowPosition = Rauri.signal(UDim2.new(0.5, 0, 0.5, 0)),
		lastPing = Rauri.signal(nil),
	}

	local core = Rauri.new({
		name = "Rauri Studio",
		version = Rauri.version,
		capabilities = {
			default = { "app.*", "icons.*", "stats.*", "settings.*" },
			deny = { "admin.*" },
		},
	})

	local ctx = {
		rauri = Rauri,
		core = core,
		state = state,
		actions = {},
		accents = ACCENTS,
		player = Players.LocalPlayer,
	}
	local actions = ctx.actions
	local toastId = 0
	local logId = 0

	function actions.toast(message, tone)
		toastId += 1
		local id = toastId
		local toasts = table.clone(state.toasts:get())
		table.insert(toasts, { id = id, message = message, tone = tone or "info" })
		state.toasts:set(toasts)
		task.delay(3.6, function()
			local keep = {}
			for _, toast in state.toasts:get() do
				if toast.id ~= id then
					table.insert(keep, toast)
				end
			end
			state.toasts:set(keep)
		end)
	end

	function actions.log(message, tone)
		logId += 1
		local logs = table.clone(state.logs:get())
		table.insert(logs, 1, {
			id = logId,
			at = Rauri.util.clock(),
			message = message,
			tone = tone or "info",
		})
		while #logs > 8 do
			table.remove(logs)
		end
		state.logs:set(logs)
	end

	function actions.navigate(page)
		state.page:set(page)
	end

	function actions.selectProvider(id)
		local ok, result = core:invoke("icons.provider", { id = id })
		if not ok then
			actions.toast(tostring(result), "danger")
			return
		end
		state.provider:set(result.id)
		state.providerInfo:set(result)
		actions.toast(string.format("%s · %d icons", result.name, result.count), "success")
		actions.log(string.format("icons.provider → %s", result.id), "success")
	end

	function actions.selectIcon(name)
		state.selectedIcon:set(name)
	end

	function actions.setQuery(query)
		state.query:set(query)
	end

	function actions.showInfo()
		local ok, info = core:invoke("app.info")
		if ok then
			actions.toast(string.format("%s · v%s · up %s", info.name, info.version, info.uptime), "info")
		else
			actions.toast(tostring(info), "danger")
		end
	end

	function actions.pingCore()
		local started = os.clock()
		local ok, result = core:invoke("app.ping", { at = started })
		local elapsed = math.floor((os.clock() - started) * 1000 + 0.5)
		if ok then
			state.lastPing:set(elapsed)
			actions.log(string.format("app.ping → %s in %dms", tostring(result.message), elapsed), "success")
		else
			actions.log(tostring(result), "danger")
		end
	end

	function actions.runDenied()
		local ok, result = core:invoke("admin.reset")
		if ok then
			actions.log("admin.reset ran, which should be impossible", "warn")
		else
			actions.log(tostring(result), "danger")
			actions.toast("Capability denied", "danger")
		end
	end

	function actions.setAccent(value)
		state.accent:set(value)
		Rauri.theme.setToken("accent", value)
	end

	function actions.setScale(value)
		local ok, clamped = core:invoke("settings.scale", { scale = value })
		if ok then
			state.scale:set(clamped)
		end
	end

	function actions.setShowNames(value)
		state.showNames:set(value)
	end

	function actions.resetTheme()
		Rauri.theme.reset()
		state.accent:set(ACCENTS[1].value)
		state.scale:set(1)
		actions.toast("Appearance reset", "info")
	end

	function actions.setWindowPosition(position)
		state.windowPosition:set(position)
	end

	function actions.toggleMinimize()
		state.minimized:update(function(value)
			return not value
		end)
	end

	function actions.close()
		state.closed:set(true)
	end

	function actions.reopen()
		state.closed:set(false)
		state.minimized:set(false)
		actions.toast("Window restored", "success")
	end

	-- Core commands -------------------------------------------------------

	core:handle("app.info", function()
		return {
			name = core.name,
			version = core.version,
			uptime = core:uptime(),
			commands = #core:commands(),
			player = ctx.player and ctx.player.DisplayName or "player",
			remoteIcons = Rauri.icons.remoteAvailable(),
		}
	end)

	core:handle("app.ping", function()
		return { at = os.clock(), message = "pong" }
	end)

	core:handle("icons.provider", function(payload)
		local id = payload and payload.id
		if type(id) ~= "string" then
			error("icons.provider needs an id")
		end
		local info = Rauri.icons.info(id)
		if info.count == 0 then
			error(string.format('unknown provider "%s"', id))
		end
		if not Rauri.icons.setProvider(id) then
			error(string.format('provider "%s" is unavailable', id))
		end
		return Rauri.icons.info(id)
	end)

	core:handle("icons.search", function(payload)
		payload = payload or {}
		local names, total = Rauri.icons.search(payload.query, payload.limit or 48, payload.provider)
		return { names = names, total = total }
	end)

	core:handle("settings.scale", function(payload)
		local scale = tonumber(payload and payload.scale) or 1
		return math.clamp(scale, 0.85, 1.2)
	end)

	-- Registered, but the manifest denies "admin.*" before it can run.
	core:handle("admin.reset", function()
		return "reset"
	end)

	-- Events ---------------------------------------------------------------

	local fps = 60
	RunService.RenderStepped:Connect(function(delta)
		if delta and delta > 0 then
			fps = fps + ((1 / delta) - fps) * 0.08
		end
	end)

	local function readPing()
		local ok, ping = pcall(function()
			return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if ok and type(ping) == "number" then
			return math.floor(ping + 0.5)
		end
		return 0
	end

	task.spawn(function()
		while true do
			local memory = 0
			pcall(function()
				memory = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb())
			end)
			core:emit("stats", {
				fps = math.floor(fps + 0.5),
				ping = readPing(),
				players = #Players:GetPlayers(),
				memory = memory,
			})
			task.wait(0.5)
		end
	end)

	core:listen("stats", function(stats)
		state.stats:set(stats)
	end)

	actions.log("core started · capability manifest loaded", "info")
	actions.log("icons: " .. (Rauri.icons.remoteAvailable() and "molto remote registry" or "bundled samples"), "info")

	core:mount(function()
		return Shell(ctx)
	end, { name = "main", displayOrder = 100 })

	return ctx
end

return App
