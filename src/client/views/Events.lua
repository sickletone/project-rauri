--!nolint
-- Rauri Studio :: Events
-- Live core -> window events, invoke round-trips and a capability denial.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rauri = require(ReplicatedStorage.Rauri)
local ui = Rauri.ui
local C = require(script.Parent.Parent.components)

return function(ctx)
	local t = Rauri.theme.tokens()
	local stats = ctx.state.stats:get()
	local logs = ctx.state.logs:get()
	local lastPing = ctx.state.lastPing:get()

	local statCards = {
		C.StatCard(ctx, { label = "FPS", value = tostring(stats.fps), icon = "gauge", tone = "success" }),
		C.StatCard(ctx, { label = "PING", value = tostring(stats.ping) .. " ms", icon = "wifi" }),
		C.StatCard(ctx, { label = "PLAYERS", value = tostring(stats.players), icon = "users" }),
		C.StatCard(ctx, { label = "MEMORY", value = tostring(stats.memory) .. " MB", icon = "cpu" }),
	}

	local logRows = {}
	for _, entry in logs do
		local tone = t.text
		if entry.tone == "success" then
			tone = t.success
		elseif entry.tone == "danger" then
			tone = t.danger
		elseif entry.tone == "warn" then
			tone = t.warn
		end
		table.insert(logRows, ui.row({ width = "fill", height = 26, gap = 10, cross = "center" },
			ui.text({
				text = entry.at,
				width = 58,
				height = 16,
				style = { font = "mono", fontSize = 10, fg = t.muted },
			}),
			ui.frame({ size = UDim2.fromOffset(5, 5), style = { bg = tone, radius = 999 } }),
			ui.text({
				text = entry.message,
				width = { 1, -90 },
				height = 18,
				truncate = true,
				style = { fontSize = 11, fg = tone },
			})
		))
	end

	return ui.column({ size = "fill", gap = 14 },
		C.PageHeader(ctx, {
			title = "Events",
			subtitle = "core → window stream, invoke round-trips, capability denial",
			actions = {
				ui.button({ text = "Ping core", onClick = function()
					ctx.actions.pingCore()
				end }),
				ui.button({
					text = "Run denied",
					style = { bg = t.danger, fg = "#ffffff", hover = { bg = t.danger, bgAlpha = 0.85 } },
					onClick = function()
						ctx.actions.runDenied()
					end,
				}),
			},
		}),
		ui.row({ height = 86, gap = 12 }, statCards),
		ui.row({ size = UDim2.new(1, 0, 1, -160), gap = 12 },
			ui.column({
				width = { 0.62, -6 },
				height = "fill",
				style = { bg = t.panel, radius = 12, border = { 1, t.border }, pad = 16, gap = 6 },
			},
				ui.row({ height = 18, gap = 8, cross = "center" },
					ui.icon("activity", { size = 14, provider = "lucide", style = { fg = t.accent } }),
					ui.text({
						text = "Core log",
						width = 260,
						height = 18,
						style = { fontSize = 12, font = "medium", fg = t.text },
					}),
					ui.text({
						text = lastPing and string.format("last invoke: %dms", lastPing) or "no invokes yet",
						width = { 1, -300 },
						height = 16,
						align = "right",
						style = { fontSize = 10, fg = t.muted },
					})
				),
				ui.divider({ width = "fill" }),
				logRows
			),
			ui.column({
				width = { 0.38, -6 },
				height = "fill",
				style = { bg = t.panel, radius = 12, border = { 1, t.border }, pad = 16, gap = 8 },
			},
				ui.text({
					text = "Capabilities",
					width = "fill",
					height = 20,
					style = { fontSize = 12, font = "medium", fg = t.text },
				}),
				ui.text({
					text = "The UI cannot call a command its manifest does not grant. The core checks before dispatch, not after.",
					width = "fill",
					height = 56,
					style = { fontSize = 11, fg = t.muted, wrap = true },
				}),
				C.CapabilityRow({ command = "app.ping", allowed = ctx.core:allowed("main", "app.ping") }),
				C.CapabilityRow({ command = "icons.search", allowed = ctx.core:allowed("main", "icons.search") }),
				C.CapabilityRow({ command = "settings.scale", allowed = ctx.core:allowed("main", "settings.scale") }),
				C.CapabilityRow({ command = "admin.reset", allowed = ctx.core:allowed("main", "admin.reset") }),
				ui.spacer({ height = 2 }),
				ui.text({
					text = "app:invoke returns (ok, result). Denials come back as a second value, not a thrown error.",
					width = "fill",
					height = 32,
					style = { fontSize = 10, fg = t.muted, wrap = true },
				})
			)
		)
	)
end
