--!nolint
-- Rauri Studio smoke test: boots the real demo app against the mock client.

local Client = require(Client.App)

local ctx = Client.start()
local player = game:GetService("Players").LocalPlayer

local function find(root, name)
	for _, child in root:GetChildren() do
		if child.Name == name then
			return child
		end
		local nested = find(child, name)
		if nested then
			return nested
		end
	end
	return nil
end

local function findText(root, text)
	for _, child in root:GetChildren() do
		if child.ClassName == "TextLabel" and child.Text == text then
			return child
		end
		local nested = findText(child, text)
		if nested then
			return nested
		end
	end
	return nil
end

local gui = player.PlayerGui:FindFirstChild("Rauri: Rauri Studio")
assert(gui ~= nil, "demo ScreenGui missing")

local window = find(gui, "Window")
assert(window ~= nil, "window frame missing")
assert(window:FindFirstChild("__rauriCorner") ~= nil, "window corner missing")
assert(window:FindFirstChild("__rauriStroke") ~= nil, "window border missing")
assert(findText(window, "Rauri") ~= nil, "sidebar brand missing")
assert(findText(window, "Build Roblox UIs like web apps.") ~= nil, "hero missing")

local handle = ctx.core:window("main")
assert(handle ~= nil, "window handle missing")

-- Navigate every page so each render function runs at least once.
for _, page in { "icons", "events", "settings", "home" } do
	ctx.actions.navigate(page)
	handle:flush()
end

-- Icons page: provider switch + search, through the core command.
ctx.actions.navigate("icons")
handle:flush()
ctx.actions.selectProvider("phosphor")
assert(ctx.state.provider:get() == "phosphor", "provider did not change")

local ok, result = ctx.core:invoke("icons.search", { query = "moon", provider = "lucide" })
assert(ok, tostring(result))
assert(#result.names > 0, "lucide should have a moon icon")

local okAll, all = ctx.core:invoke("icons.search", { query = "", provider = "phosphor", limit = 8 })
assert(okAll and #all.names == 8, "phosphor sample search failed")
ctx.actions.setQuery(all.names[1]:sub(1, 4))
handle:flush()
assert(findText(window, "Icons") ~= nil, "icons page header missing")

-- Capability denial is surfaced to the UI, not thrown.
local denied, denial = ctx.core:invoke("admin.reset")
assert(not denied and tostring(denial):find("capability denied") ~= nil, tostring(denial))
ctx.actions.runDenied()
handle:flush()
local latest = ctx.state.logs:get()[1]
assert(latest ~= nil and latest.tone == "danger", "denial was not logged")

-- Stats events from the core reach the window state.
ctx.core:emit("stats", { fps = 144, ping = 12, players = 3, memory = 900 })
assert(ctx.state.stats:get().fps == 144, "stats event did not land")
ctx.actions.navigate("home")
handle:flush()
assert(findText(window, "144 fps · 12ms ping") ~= nil, "stats did not render")

-- Theme change + window scale through the settings command.
ctx.actions.setAccent("#22b3a6")
ctx.actions.setScale(1.15)
handle:flush()
assert(ctx.state.scale:get() == 1.15, "scale command did not clamp/return")

-- Minimize / close / reopen.
ctx.actions.toggleMinimize()
handle:flush()
assert(ctx.state.minimized:get() == true, "minimize failed")
ctx.actions.close()
handle:flush()
assert(ctx.state.closed:get() == true, "close failed")
ctx.actions.reopen()
handle:flush()
assert(ctx.state.closed:get() == false, "reopen failed")

assert(#Mock.warnings == 0, "unexpected warnings: " .. table.concat(Mock.warnings, " | "))
print("ok   demo app boots, navigates and handles core I/O")
print("1 passed, 0 failed")
