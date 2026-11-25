--!nolint
-- Rauri Studio :: window shell

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Rauri = require(ReplicatedStorage.Rauri)
local ui = Rauri.ui
local C = require(script.Parent.components)

local Home = require(script.Parent.views.Home)
local IconsPage = require(script.Parent.views.IconsPage)
local Events = require(script.Parent.views.Events)
local Settings = require(script.Parent.views.Settings)

local VIEWS = {
	home = Home,
	icons = IconsPage,
	events = Events,
	settings = Settings,
}

local NAV = {
	{ id = "home", label = "Home", icon = "house" },
	{ id = "icons", label = "Icons", icon = "layout-grid" },
	{ id = "events", label = "Events", icon = "activity" },
	{ id = "settings", label = "Settings", icon = "settings" },
}

local function beginDrag(ctx, input, titleBar)
	local userInputType = input.UserInputType
	if userInputType ~= Enum.UserInputType.MouseButton1 and userInputType ~= Enum.UserInputType.Touch then
		return
	end
	local window = titleBar.Parent
	if not window then
		return
	end
	local startMouse = UserInputService:GetMouseLocation()
	local startPosition = window.Position

	local changed, ended
	changed = UserInputService.InputChanged:Connect(function(move)
		local moveType = move.UserInputType
		if moveType ~= Enum.UserInputType.MouseMovement and moveType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = UserInputService:GetMouseLocation() - startMouse
		ctx.actions.setWindowPosition(UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		))
	end)
	ended = UserInputService.InputEnded:Connect(function(stop)
		local stopType = stop.UserInputType
		if stopType == Enum.UserInputType.MouseButton1 or stopType == Enum.UserInputType.Touch then
			changed:Disconnect()
			ended:Disconnect()
		end
	end)
end

local function trafficDot(color, onClick)
	return ui.button({
		size = UDim2.fromOffset(11, 11),
		style = { bg = color, radius = 999, pad = 0, hover = { bg = color, bgAlpha = 0.55 } },
		onClick = onClick,
	})
end

local function titleBar(ctx)
	local t = Rauri.theme.tokens()
	local provider = ctx.state.provider:get()
	local minimized = ctx.state.minimized:get()

	return ui.frame({
		width = "fill",
		height = 44,
		active = true,
		style = { bg = t.surface },
		onInputBegan = function(input, self)
			beginDrag(ctx, input, self)
		end,
	},
		ui.row({ position = { 0, 16, 0, 0 }, width = 70, height = 44, gap = 8, cross = "center" },
			trafficDot("#ff5f57", function()
				ctx.actions.close()
			end),
			trafficDot("#febc2e", function()
				ctx.actions.toggleMinimize()
			end),
			trafficDot("#28c840", function()
				ctx.actions.toggleMinimize()
			end)
		),
		ui.text({
			text = "Rauri Studio — main window",
			width = 320,
			height = 44,
			anchor = { 0.5, 0 },
			position = { 0.5, 0, 0, 0 },
			style = { fontSize = 12, fg = t.muted, font = "medium", align = "center" },
		}),
		ui.row({
			anchor = { 1, 0 },
			position = { 1, 0, -12, 0 },
			width = 190,
			height = 44,
			gap = 6,
			justify = "end",
			cross = "center",
		},
			ui.frame({
				width = 74,
				height = 20,
				style = { bg = t.surfaceAlt, radius = 999, border = { 1, t.border } },
			},
				ui.text({
					text = provider,
					width = "fill",
					height = 20,
					align = "center",
					style = { fontSize = 10, font = "medium", fg = t.muted },
				})
			),
			ui.iconButton(minimized and "maximize-2" or "minus", {
				iconSize = 14,
				onClick = function()
					ctx.actions.toggleMinimize()
				end,
			}),
			ui.iconButton("x", {
				iconSize = 14,
				onClick = function()
					ctx.actions.close()
				end,
			})
		)
	)
end

local function navItem(ctx, item, active)
	local t = Rauri.theme.tokens()
	return ui.button({
		width = "fill",
		height = 34,
		text = item.label,
		style = {
			bg = active and t.surfaceAlt or false,
			fg = active and t.text or t.muted,
			radius = 8,
			pad = { left = 34, right = 10, top = 0, bottom = 0 },
			fontSize = 13,
			font = active and "medium" or "regular",
			align = "left",
			hover = { bg = t.surfaceAlt, fg = t.text },
		},
		onClick = function()
			ctx.actions.navigate(item.id)
		end,
	},
		ui.icon(item.icon, {
			size = 15,
			provider = "lucide",
			position = { 0, 11, 0.5, 0 },
			anchor = { 0, 0.5 },
			style = { fg = active and t.accent or t.muted },
		})
	)
end

local function avatar(ctx)
	local t = Rauri.theme.tokens()
	local player = ctx.player
	if player and player.UserId and player.UserId > 0 then
		return ui.image({
			image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", player.UserId),
			size = UDim2.fromOffset(32, 32),
			style = { radius = 999, bg = t.surfaceAlt },
		})
	end
	return ui.frame({ size = UDim2.fromOffset(32, 32), style = { bg = t.surfaceAlt, radius = 999 } },
		ui.text({
			text = string.sub(player and player.DisplayName or "P", 1, 1),
			width = "fill",
			height = 32,
			align = "center",
			style = { fontSize = 13, font = "bold", fg = t.muted },
		})
	)
end

local function sidebar(ctx)
	local t = Rauri.theme.tokens()
	local page = ctx.state.page:get()
	local player = ctx.player

	local items = {}
	for _, item in NAV do
		table.insert(items, navItem(ctx, item, page == item.id))
	end

	return ui.frame({ size = UDim2.new(0, 216, 1, 0), style = { bg = t.panel } },
		ui.column({ position = { 0, 14, 0, 16 }, width = { 1, -28 }, gap = 4, automaticSize = "y" },
			ui.row({ width = "fill", height = 34, gap = 10, cross = "center" },
				ui.frame({ size = UDim2.fromOffset(30, 30), style = { bg = t.accent, radius = 9 } },
					ui.icon("layers", {
						size = 16,
						provider = "lucide",
						anchor = { 0.5, 0.5 },
						position = { 0.5, 0.5 },
						style = { fg = t.accentText },
					})
				),
				ui.column({ width = 130, height = 34, justify = "center", gap = 0 },
					ui.text({
						text = "Rauri",
						width = "fill",
						height = 17,
						style = { fontSize = 15, font = "bold", fg = t.text },
					}),
					ui.text({
						text = "v" .. Rauri.version .. " · studio",
						width = "fill",
						height = 13,
						style = { fontSize = 10, fg = t.muted },
					})
				)
			),
			ui.spacer({ height = 12 }),
			C.SectionLabel("Navigate"),
			ui.spacer({ height = 2 }),
			items
		),
		ui.frame({
			anchor = { 0, 1 },
			position = { 0, 1, 0, -14 },
			width = { 1, -28 },
			height = 54,
			style = { bg = t.surface, radius = 10, border = { 1, t.border }, pad = 10 },
		},
			ui.row({ size = "fill", gap = 10, cross = "center" },
				avatar(ctx),
				ui.column({ width = { 1, -42 }, height = 34, justify = "center", gap = 1 },
					ui.text({
						text = player and player.DisplayName or "Player",
						width = "fill",
						height = 16,
						truncate = true,
						style = { fontSize = 12, font = "medium", fg = t.text },
					}),
					ui.row({ height = 13, gap = 5, cross = "center" },
						ui.frame({ size = UDim2.fromOffset(6, 6), style = { bg = t.success, radius = 999 } }),
						ui.text({
							text = "core connected",
							width = 100,
							height = 12,
							style = { fontSize = 10, fg = t.muted },
						})
					)
				)
			)
		)
	)
end

local function body(ctx)
	local page = ctx.state.page:get()
	local view = VIEWS[page] or VIEWS.home
	return ui.row({
		width = "fill",
		size = UDim2.new(1, 0, 1, -44),
		position = UDim2.new(0, 0, 0, 44),
		gap = 0,
	},
		sidebar(ctx),
		ui.column({ size = UDim2.new(1, -216, 1, 0), pad = { 22, 18 }, gap = 12 }, view(ctx))
	)
end

local function toasts(ctx)
	local t = Rauri.theme.tokens()
	local list = ctx.state.toasts:get()
	if #list == 0 then
		return nil
	end
	local cards = {}
	for _, toast in list do
		local tone = t.accent
		local icon = "info"
		if toast.tone == "success" then
			tone = t.success
			icon = "circle-check"
		elseif toast.tone == "danger" then
			tone = t.danger
			icon = "triangle-alert"
		end
		table.insert(cards, ui.row({
			width = 300,
			height = 46,
			gap = 10,
			cross = "center",
			style = { bg = t.surface, radius = 10, border = { 1, t.border }, pad = { 12, 8 } },
		},
			ui.icon(icon, { size = 15, provider = "lucide", style = { fg = tone } }),
			ui.text({
				text = toast.message,
				width = { 1, -26 },
				height = 30,
				truncate = true,
				style = { fontSize = 12, fg = t.text },
			})
		))
	end
	return ui.column({
		anchor = { 1, 1 },
		position = { 1, -20, 1, -20 },
		width = 300,
		automaticSize = "y",
		gap = 8,
		cross = "end",
	}, cards)
end

local function desktop(ctx)
	local t = Rauri.theme.tokens()
	return ui.frame({ size = "fill", style = { bg = "#050507" } },
		ui.button({
			anchor = { 0.5, 0.5 },
			position = { 0.5, 0.5 },
			size = UDim2.fromOffset(140, 118),
			style = { bg = false, radius = 12, hover = { bg = t.surface }, pad = 12 },
			onClick = function()
				ctx.actions.reopen()
			end,
		},
			ui.column({ size = "fill", gap = 6, justify = "center", cross = "center" },
				ui.icon("layout-grid", { size = 34, provider = "lucide", style = { fg = t.accent } }),
				ui.text({
					text = "Rauri Studio",
					width = 116,
					height = 16,
					align = "center",
					style = { fontSize = 12, font = "medium", fg = t.text },
				}),
				ui.text({
					text = "click to reopen",
					width = 116,
					height = 13,
					align = "center",
					style = { fontSize = 10, fg = t.muted },
				})
			)
		)
	)
end

return function(ctx)
	local t = Rauri.theme.tokens()
	if ctx.state.closed:get() then
		return desktop(ctx)
	end
	local minimized = ctx.state.minimized:get()
	local scale = ctx.state.scale:get()

	return ui.frame({ size = "fill", style = { bg = "#050507" } },
		ui.frame({
			name = "Window",
			anchor = { 0.5, 0.5 },
			position = ctx.state.windowPosition:get(),
			size = UDim2.fromOffset(1080, minimized and 44 or 660),
			scale = scale,
			clip = true,
			style = { bg = t.bg, radius = 14, border = { 1, t.border } },
		},
			titleBar(ctx),
			if not minimized then body(ctx) else nil
		),
		toasts(ctx)
	)
end
