--!nolint
-- Rauri framework tests. Runs headless through scripts/bundle.mjs + tests/mock.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rauri = require(ReplicatedStorage.Rauri)
local ui = Rauri.ui

local passed = 0
local failed = 0

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("ok   " .. name)
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

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

test("mounts and patches only what changed", function()
	local value = Rauri.signal(0)
	local container = Instance.new("Frame")
	local app = Rauri.new({ name = "test" })
	local window = app:mount(function()
		return ui.column({ size = "fill", gap = 4 },
			ui.text({ text = "value: " .. value:get(), name = "Value" }),
			ui.text({ text = "static", name = "Static" })
		)
	end, { container = container })

	local label = find(container, "Value")
	local static = find(container, "Static")
	assert(label ~= nil and label.Text == "value: 0", "label did not mount")
	assert(static ~= nil, "static sibling missing")
	local column = container:GetChildren()[1]
	assert(column ~= nil and column:FindFirstChild("__rauriLayout") ~= nil, "column layout missing")

	value:set(7)
	window:flush()

	assert(find(container, "Value") == label, "instance was replaced instead of patched")
	assert(label.Text == "value: 7", "text not patched")
	assert(find(container, "Static") == static, "unrelated sibling recreated")
	window:unmount()
	assert(#container:GetChildren() == 0, "unmount left instances")
end)

test("keeps keyed instances when a list reorders", function()
	local items = Rauri.signal({ "alpha", "beta" })
	local container = Instance.new("Frame")
	local app = Rauri.new({})
	local window = app:mount(function()
		local rows = {}
		for _, item in items:get() do
			rows[#rows + 1] = ui.text({ key = item, name = item, text = item, width = 100, height = 20 })
		end
		return ui.column({ size = "fill", gap = 2 }, rows)
	end, { container = container })

	local alpha = find(container, "alpha")
	local beta = find(container, "beta")
	assert(alpha and beta, "rows missing")

	items:set({ "beta", "alpha" })
	window:flush()

	assert(find(container, "alpha") == alpha, "keyed alpha was recreated")
	assert(find(container, "beta") == beta, "keyed beta was recreated")
	assert(alpha.LayoutOrder == 2, "LayoutOrder did not follow the keyed order")
	assert(beta.LayoutOrder == 1, "LayoutOrder did not follow the keyed order")
	window:unmount()
end)

test("resolves Molto sprites, rects and aliases", function()
	local asset = Rauri.icons.get("house", "lucide")
	assert(asset ~= nil, "house icon missing")
	assert(asset.Image == "rbxassetid://118199753695009", tostring(asset.Image))
	assert(asset.RectSize.X == 24 and asset.RectSize.Y == 24, "rect size wrong")
	assert(asset.RectOffset.X == 625 and asset.RectOffset.Y == 475, "rect offset wrong")

	local aliased = Rauri.icons.get("trash-2", "lucide")
	assert(aliased ~= nil and aliased.Name == "trash", "alias not resolved")

	local names = Rauri.icons.search("moon", 50)
	assert(#names > 0, "search returned nothing")
	assert(#Rauri.icons.providers() == 7, "provider list should have 7 entries")

	local container = Instance.new("Frame")
	local app = Rauri.new({})
	local window = app:mount(function()
		return ui.icon("house", { name = "HomeIcon", size = 20 })
	end, { container = container })
	local icon = find(container, "HomeIcon")
	assert(icon ~= nil and icon.Image ~= "", "icon image not applied")
	assert(icon.ImageRectSize.X == 24, "icon rect not applied")
	assert(icon.ImageColor3 ~= nil, "icon tint missing")
	window:unmount()
end)

test("enforces capabilities before dispatch", function()
	local calls = 0
	local core = Rauri.new({
		name = "caps",
		capabilities = {
			default = { "app.*" },
			deny = { "admin.*" },
		},
	})
	core:handle("app.ping", function()
		calls += 1
		return "pong"
	end)
	core:handle("admin.reset", function()
		calls += 1
		return "nope"
	end)

	local ok, result = core:invoke("app.ping")
	assert(ok and result == "pong", "allowed command failed")

	local denied, denial = core:invoke("admin.reset")
	assert(not denied, "denied command ran")
	assert(tostring(denial):find("capability denied") ~= nil, tostring(denial))
	assert(calls == 1, "denied handler should never run")

	local unknown, message = core:invoke("app.nope")
	assert(not unknown and tostring(message):find("unknown command") ~= nil, tostring(message))

	local otherWindowOk, otherMessage = core:invoke("app.ping", nil, { window = "settings" })
	assert(otherWindowOk, "default capabilities should apply to every window: " .. tostring(otherMessage))
end)

test("emits events to listeners", function()
	local core = Rauri.new({})
	local received = {}
	local disconnect = core:listen("stats", function(payload)
		received[#received + 1] = payload
	end)
	core:emit("stats", { fps = 60 })
	core:emit("stats", { fps = 30 })
	assert(#received == 2 and received[2].fps == 30, "event payload missing")
	disconnect()
	core:emit("stats", { fps = 1 })
	assert(#received == 2, "listener not disconnected")
end)

test("theme tokens reach styles and re-apply", function()
	Rauri.theme.reset()
	Rauri.theme.setToken("accent", "#ff0000")
	local container = Instance.new("Frame")
	local app = Rauri.new({})
	local window = app:mount(function()
		local t = Rauri.theme.tokens()
		return ui.frame({ size = UDim2.fromOffset(10, 10), style = { bg = t.accent, radius = 4 } })
	end, { container = container })

	local block = container:GetChildren()[1]
	assert(block ~= nil, "block missing")
	assert(math.abs(block.BackgroundColor3.R - 1) < 0.01, "accent not applied")
	assert(block:FindFirstChild("__rauriCorner") ~= nil, "corner not created")

	Rauri.theme.setToken("accent", "#00ff00")
	window:flush()
	assert(block.BackgroundColor3.G > 0.9, "theme change was not applied")
	window:unmount()
	Rauri.theme.reset()
end)

test("style variants and text shorthands", function()
	local container = Instance.new("Frame")
	local app = Rauri.new({})
	local window = app:mount(function()
		return ui.button({
			name = "Cta",
			text = "Continue",
			style = { bg = "#101010", fg = "#ffffff", hover = { bg = "#ff0000" } },
		})
	end, { container = container })

	local button = find(container, "Cta")
	assert(button ~= nil, "button missing")
	assert(button.Text == "Continue", button.Text)
	assert(button.AutoButtonColor == false, "AutoButtonColor should be off")
	assert(button.AutomaticSize ~= "None", "auto width missing")

	button.MouseEnter:Fire()
	assert(math.abs(button.BackgroundColor3.R - 1) < 0.01, "hover style not applied")
	button.MouseLeave:Fire()
	assert(math.abs(button.BackgroundColor3.G - 0.0627) < 0.02, "base style not restored")
	window:unmount()
end)

test("fill children respect the parent's padding", function()
	local container = Instance.new("Frame")
	local app = Rauri.new({})
	local window = app:mount(function()
		return ui.column({ size = "fill", style = { pad = { 20, 10 } } },
			ui.frame({ width = "fill", height = 40, name = "Child" })
		)
	end, { container = container })
	local child = find(container, "Child")
	assert(child ~= nil, "child missing")
	assert(child.Size.X.Scale == 1 and child.Size.X.Offset == -40, "horizontal fill should subtract padding")
	window:unmount()
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d Rauri tests failed", failed))
end
