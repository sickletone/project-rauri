--!nolint
-- Rauri Studio :: Home

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rauri = require(ReplicatedStorage.Rauri)
local ui = Rauri.ui
local C = require(script.Parent.Parent.components)

return function(ctx)
	local t = Rauri.theme.tokens()
	local stats = ctx.state.stats:get()
	local info = ctx.state.providerInfo:get()

	local function feature(icon, title, body)
		return ui.column({
			width = { 0.5, -5 },
			height = 108,
			style = { bg = t.panel, radius = 12, border = { 1, t.border }, pad = 14, gap = 6 },
		},
			ui.row({ height = 18, gap = 8, cross = "center" },
				ui.icon(icon, { size = 14, provider = "lucide", style = { fg = t.accent } }),
				ui.text({
					text = title,
					width = 220,
					height = 18,
					style = { fontSize = 12, font = "medium", fg = t.text },
				})
			),
			ui.text({
				text = body,
				width = "fill",
				height = 56,
				style = { fontSize = 11, fg = t.muted, wrap = true },
			})
		)
	end

	return ui.column({ size = "fill", gap = 14 },
		C.PageHeader(ctx, {
			title = "Home",
			subtitle = "A desktop window rendered from Luau — no HTML, no WebView.",
			actions = {
				ui.button({ text = "app.info", onClick = function()
					ctx.actions.showInfo()
				end }),
				ui.button({ text = "Events", onClick = function()
					ctx.actions.navigate("events")
				end }),
			},
		}),
		ui.scroll({ size = UDim2.new(1, 0, 1, -60) },
			ui.column({ width = { 1, -8 }, gap = 12, automaticSize = "y" },
				ui.column({
					width = "fill",
					automaticSize = "y",
					style = { bg = t.panel, radius = 14, border = { 1, t.border }, pad = 22, gap = 10 },
				},
					ui.row({ height = 18, gap = 8, cross = "center" },
						ui.text({
							text = "RAURI",
							width = 60,
							height = 14,
							style = { fontSize = 10, font = "bold", fg = t.accent },
						}),
						ui.frame({ width = 1, height = 12, style = { bg = t.border } }),
						ui.text({
							text = "v" .. Rauri.version .. " · window: main",
							width = 200,
							height = 14,
							style = { fontSize = 10, fg = t.muted },
						}),
						ui.frame({ width = 1, height = 12, style = { bg = t.border } }),
						ui.text({
							text = string.format("%d fps · %dms ping", stats.fps, stats.ping),
							width = 200,
							height = 14,
							style = { fontSize = 10, fg = t.muted },
						})
					),
					ui.text({
						text = "Build Roblox UIs like web apps.",
						width = "fill",
						height = 36,
						style = { fontSize = 26, font = "bold", fg = t.text },
					}),
					ui.text({
						text = "Rauri gives a Roblox GUI the shape of a desktop app: reactive signals, a diffed instance tree, commands behind a capability manifest, and every Molto icon.",
						width = "fill",
						height = 44,
						style = { fontSize = 13, fg = t.muted, wrap = true },
					}),
					ui.row({ height = 34, gap = 8, cross = "center" },
						ui.button({
							text = "Browse " .. info.name .. " icons",
							style = { bg = t.accent, fg = t.accentText, hover = { bg = t.accent, bgAlpha = 0.85 } },
							onClick = function()
								ctx.actions.navigate("icons")
							end,
						}),
						ui.button({ text = "Run app.ping", onClick = function()
							ctx.actions.pingCore()
						end }),
						ui.text({
							text = "signals → diff → instances",
							width = 200,
							height = 20,
							style = { fontSize = 10, fg = t.muted },
						})
					)
				),
				ui.row({ height = 108, gap = 10 },
					feature("zap", "Reactive signals", "The render function reads signals. Reading subscribes, so changing one patches only the props that moved."),
					feature("command", "Commands + events", "Core handlers answer app:invoke(). The core streams state back with app:emit(), no tree access needed.")
				),
				ui.row({ height = 108, gap = 10 },
					feature("shield", "Capability manifest", "Each window declares which commands it may call. admin.* is denied before a handler ever runs."),
					feature("layout-grid", "Molto icons", "Seven providers, 64,517 glyphs. Sprites are white, so ImageColor3 tints them like text.")
				),
				ui.row({
					width = "fill",
					height = 60,
					gap = 12,
					cross = "center",
					style = { bg = t.panel, radius = 12, border = { 1, t.border }, pad = { 16, 10 } },
				},
					ui.icon("shield", { size = 18, provider = "lucide", style = { fg = t.success } }),
					ui.column({ width = { 1, -220 }, height = 38, justify = "center", gap = 1 },
						ui.text({
							text = "Capability manifest active",
							width = "fill",
							height = 17,
							style = { fontSize = 12, font = "medium", fg = t.text },
						}),
						ui.text({
							text = "app.* · icons.* · stats.* · settings.* allowed   admin.* denied",
							width = "fill",
							height = 15,
							style = { fontSize = 10, fg = t.muted },
						})
					),
					ui.chip({ text = "admin.reset", onClick = function()
						ctx.actions.runDenied()
					end })
				)
			)
		)
	)
end
