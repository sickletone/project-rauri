--!nolint
-- Rauri Studio :: shared widgets
-- These are ordinary Rauri components: functions of props that return elements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rauri = require(ReplicatedStorage.Rauri)
local ui = Rauri.ui
local Util = Rauri.util

local C = {}

function C.Card(props, ...)
	props = Util.merge({ width = "fill", automaticSize = "y" }, props or {})
	props.style = Util.merge({
		bg = "$panel",
		radius = 12,
		border = { 1, "$border" },
		pad = 16,
		gap = 10,
	}, props.style)
	return ui.column(props, ...)
end

function C.PageHeader(_, options)
	local t = Rauri.theme.tokens()
	return ui.row({ height = 46, gap = 10, cross = "center" },
		ui.column({ width = { 1, -220 }, height = 46, justify = "center", gap = 2 },
			ui.text({
				text = options.title,
				width = "fill",
				height = 24,
				style = { fontSize = 20, font = "bold", fg = t.text },
			}),
			ui.text({
				text = options.subtitle or "",
				width = "fill",
				height = 15,
				style = { fontSize = 12, fg = t.muted },
			})
		),
		ui.row({ width = 210, height = 46, gap = 8, justify = "end", cross = "center" }, options.actions or {})
	)
end

function C.SectionLabel(text)
	return ui.text({
		text = string.upper(text),
		width = "fill",
		height = 14,
		style = { fontSize = 10, font = "bold", fg = "$muted" },
	})
end

function C.StatCard(_, options)
	local t = Rauri.theme.tokens()
	local tone = options.tone and t[options.tone] or t.text
	return ui.column({
		width = { 0.25, -9 },
		height = 86,
		style = { bg = t.panel, radius = 12, border = { 1, t.border }, pad = 14, gap = 6 },
		justify = "center",
	},
		ui.row({ height = 16, gap = 6, cross = "center" },
			ui.icon(options.icon, { size = 13, provider = "lucide", style = { fg = t.muted } }),
			ui.text({
				text = options.label,
				width = 120,
				height = 14,
				style = { fontSize = 10, fg = t.muted, font = "medium" },
			})
		),
		ui.text({
			text = tostring(options.value),
			width = "fill",
			height = 26,
			style = { fontSize = 21, font = "bold", fg = tone },
		})
	)
end

function C.SettingRow(props, ...)
	local t = Rauri.theme.tokens()
	local height = props.height or 46
	return ui.row({ width = "fill", height = height, gap = 12, cross = "center" },
		ui.column({ width = { 1, -340 }, height = height, justify = "center", gap = 2 },
			ui.text({
				text = props.title,
				width = "fill",
				height = 17,
				style = { fontSize = 13, font = "medium", fg = t.text },
			}),
			ui.text({
				text = props.description or "",
				width = "fill",
				height = 14,
				style = { fontSize = 11, fg = t.muted },
			})
		),
		ui.row({ width = 330, height = height, gap = 8, justify = "end", cross = "center" }, ...)
	)
end

function C.CapabilityRow(props)
	local t = Rauri.theme.tokens()
	local allowed = props.allowed
	return ui.row({ width = "fill", height = 28, gap = 10, cross = "center" },
		ui.text({
			text = props.command,
			width = { 1, -100 },
			height = 18,
			style = { font = "mono", fontSize = 11, fg = t.text },
		}),
		ui.text({
			text = allowed and "allowed" or "denied",
			width = 90,
			height = 16,
			align = "right",
			style = { fontSize = 10, font = "bold", fg = allowed and t.success or t.danger },
		})
	)
end

return C
