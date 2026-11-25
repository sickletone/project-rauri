--!nolint
-- Rauri Studio :: Settings

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rauri = require(ReplicatedStorage.Rauri)
local ui = Rauri.ui
local C = require(script.Parent.Parent.components)

return function(ctx)
	local t = Rauri.theme.tokens()
	local accent = ctx.state.accent:get()
	local scale = ctx.state.scale:get()
	local showNames = ctx.state.showNames:get()
	local info = ctx.state.providerInfo:get()

	local swatches = {}
	for _, entry in ctx.accents do
		local active = entry.value == accent
		table.insert(swatches, ui.button({
			size = UDim2.fromOffset(30, 30),
			style = {
				bg = entry.value,
				radius = 999,
				border = active and { 2, t.text } or { 1, t.border },
				pad = 0,
				hover = { bg = entry.value, bgAlpha = 0.8 },
			},
			onClick = function()
				ctx.actions.setAccent(entry.value)
			end,
		}))
	end

	local capabilityRows = {}
	for _, command in ctx.core:commands() do
		table.insert(capabilityRows, C.CapabilityRow({
			command = command,
			allowed = ctx.core:allowed("main", command),
		}))
	end

	return ui.column({ size = "fill", gap = 14 },
		C.PageHeader(ctx, {
			title = "Settings",
			subtitle = "Theme tokens, window scale and the capability manifest",
			actions = {
				ui.button({ text = "Reset appearance", onClick = function()
					ctx.actions.resetTheme()
				end }),
			},
		}),
		ui.scroll({ size = UDim2.new(1, 0, 1, -60) },
			ui.column({ width = { 1, -8 }, gap = 12, automaticSize = "y" },
				C.Card({ gap = 12 },
					C.SectionLabel("Appearance"),
					C.SettingRow({ title = "Accent", description = "Re-themes every token consumer instantly." }, swatches),
					ui.divider({ width = "fill" }),
					C.SettingRow({ title = "Window scale", description = "UIScale on the window frame, clamped by the core." },
						ui.slider({
							width = 240,
							min = 0.85,
							max = 1.2,
							step = 0.05,
							value = scale,
							onChange = function(value)
								ctx.actions.setScale(value)
							end,
						}),
						ui.text({
							text = string.format("%d%%", math.floor(scale * 100 + 0.5)),
							width = 54,
							height = 18,
							align = "right",
							style = { fontSize = 12, fg = t.muted },
						})
					),
					ui.divider({ width = "fill" }),
					C.SettingRow({ title = "Icon names", description = "Show the Molto name under each gallery tile." },
						ui.switch({
							checked = showNames,
							onChange = function(value)
								ctx.actions.setShowNames(value)
							end,
						})
					)
				),
				C.Card({ gap = 6 },
					C.SectionLabel("Capability manifest"),
					ui.text({
						text = 'capabilities.default grants app.*, icons.*, stats.* and settings.*; deny blocks admin.*.',
						width = "fill",
						height = 20,
						style = { fontSize = 11, fg = t.muted },
					}),
					capabilityRows
				),
				C.Card({ gap = 6 },
					C.SectionLabel("About"),
					ui.text({
						text = string.format("Rauri v%s · provider %s (%s, %s glyphs) · %s",
							Rauri.version,
							info.name,
							info.license,
							tostring(info.count),
							Rauri.icons.remoteAvailable() and "molto remote registry loaded" or "bundled icon samples"
						),
						width = "fill",
						height = 34,
						style = { fontSize = 11, fg = t.muted, wrap = true },
					}),
					ui.row({ height = 28, gap = 8, cross = "center" },
						ui.chip({ text = "signal runtime", height = 22 }),
						ui.chip({ text = "keyed reconciler", height = 22 }),
						ui.chip({ text = "capabilities", height = 22 }),
						ui.chip({ text = "molto icons", height = 22 })
					)
				)
			)
		)
	)
end
