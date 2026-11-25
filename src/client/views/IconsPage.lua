--!nolint
-- Rauri Studio :: Icons
-- The gallery is a live view of the Molto registry: seven providers, search,
-- sprite tiles tinted with ImageColor3, and a detail card.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rauri = require(ReplicatedStorage.Rauri)
local ui = Rauri.ui
local Util = Rauri.util
local C = require(script.Parent.Parent.components)

return function(ctx)
	local t = Rauri.theme.tokens()
	local state = ctx.state
	local provider = state.provider:get()
	local info = state.providerInfo:get() or Rauri.icons.info(provider)
	local query = state.query:get()
	local showNames = state.showNames:get()

	local names, total = Rauri.icons.search(query, 60, provider)
	local selected = state.selectedIcon:get()
	if not Rauri.icons.has(selected, provider) then
		selected = names[1] or selected
	end

	local providerChips = {}
	for _, entry in Rauri.icons.providers() do
		local active = entry.id == provider
		table.insert(providerChips, ui.button({
			text = entry.name,
			height = 28,
			style = {
				bg = active and t.accent or t.panel,
				fg = active and t.accentText or t.muted,
				radius = 999,
				pad = { 12, 4 },
				fontSize = 11,
				font = "medium",
				hover = {
					bg = active and t.accent or t.surfaceAlt,
					fg = active and t.accentText or t.text,
				},
			},
			onClick = function()
				ctx.actions.selectProvider(entry.id)
			end,
		}))
	end

	local tiles = {}
	for _, name in names do
		local active = name == selected
		table.insert(tiles, ui.button({
			size = UDim2.fromOffset(112, 94),
			style = {
				bg = active and t.surfaceAlt or t.panel,
				radius = 10,
				border = { 1, active and t.accent or t.border },
				pad = 0,
				hover = { bg = t.surfaceAlt },
			},
			onClick = function()
				ctx.actions.selectIcon(name)
			end,
		},
			ui.column({ size = "fill", gap = 6, justify = "center", cross = "center" },
				ui.icon(name, {
					size = 26,
					provider = provider,
					style = { fg = active and t.accent or t.text },
				}),
				if showNames then
					ui.text({
						text = Util.truncate(name, 15),
						width = 100,
						height = 12,
						align = "center",
						style = { fontSize = 9, fg = t.muted },
					})
				else
					nil
			)
		))
	end

	local detail = ui.column({
		size = UDim2.new(0, 240, 1, 0),
		style = { bg = t.panel, radius = 12, border = { 1, t.border }, pad = 14, gap = 10 },
	},
		ui.frame({ width = "fill", height = 126, style = { bg = t.surface, radius = 10, border = { 1, t.border } } },
			ui.icon(selected, {
				size = 54,
				provider = provider,
				anchor = { 0.5, 0.5 },
				position = { 0.5, 0.5 },
				style = { fg = t.text },
			})
		),
		ui.text({
			text = selected,
			width = "fill",
			height = 20,
			truncate = true,
			style = { fontSize = 15, font = "bold", fg = t.text },
		}),
		ui.row({ height = 22, gap = 6, cross = "center" },
			ui.chip({ text = info.name, height = 22 }),
			ui.text({
				text = info.license,
				width = 90,
				height = 14,
				style = { fontSize = 10, fg = t.muted },
			})
		),
		ui.frame({
			width = "fill",
			height = 38,
			style = { bg = t.bg, radius = 8, border = { 1, t.border }, pad = 10 },
		},
			ui.text({
				text = string.format('ui.icon("%s")', selected),
				width = "fill",
				height = 18,
				style = { font = "mono", fontSize = 10, fg = t.accent },
			})
		),
		ui.text({
			text = string.format("%s glyphs · %s bundled", Util.truncate(tostring(info.count), 12), tostring(info.bundled)),
			width = "fill",
			height = 14,
			style = { fontSize = 10, fg = t.muted },
		}),
		ui.text({
			text = "Sprite sheet, tinted with ImageColor3. Works in Studio and live games; the full registry loads under an executor.",
			width = "fill",
			height = 40,
			style = { fontSize = 10, fg = t.muted, wrap = true },
		}),
		ui.button({
			text = "Use in this app",
			width = "fill",
			style = { bg = t.accent, fg = t.accentText, hover = { bg = t.accent, bgAlpha = 0.85 } },
			onClick = function()
				ctx.actions.toast(string.format('%s · %s', selected, provider), "success")
			end,
		})
	)

	return ui.column({ size = "fill", gap = 12 },
		C.PageHeader(ctx, {
			title = "Icons",
			subtitle = "Molto icon registry · sprite mode, 24×24 cells",
			actions = {
				ui.button({ text = "Reset search", onClick = function()
					ctx.actions.setQuery("")
				end }),
			},
		}),
		ui.row({ height = 28, gap = 6, cross = "center" }, providerChips),
		ui.row({ height = 34, gap = 10, cross = "center" },
			ui.input({
				width = 300,
				text = query,
				placeholder = "Search " .. info.name .. "…",
				onInput = function(value)
					ctx.actions.setQuery(value)
				end,
			}),
			ui.text({
				text = string.format("%d of %s icons · %d bundled", #names, Util.truncate(tostring(total), 12), info.bundled),
				width = 320,
				height = 20,
				style = { fontSize = 11, fg = t.muted },
			}),
			ui.row({ width = { 1, -660 }, height = 34, gap = 8, justify = "end", cross = "center" },
				ui.text({
					text = "names",
					width = 44,
					height = 16,
					style = { fontSize = 11, fg = t.muted },
				}),
				ui.switch({
					checked = showNames,
					onChange = function(value)
						ctx.actions.setShowNames(value)
					end,
				})
			)
		),
		ui.row({ size = UDim2.new(1, 0, 1, -144), gap = 12 },
			ui.scroll({ size = UDim2.new(1, -252, 1, 0) },
				ui.grid({ cell = 112, cellHeight = 94, gap = 8 }, tiles)
			),
			detail
		)
	)
end
