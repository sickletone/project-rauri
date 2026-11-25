--!nolint
-- Exercises the executor example (examples/WebHub.lua) end to end: mount,
-- search filtering, commands from JS, theme swatches, tab switching.

local Rauri = require(ReplicatedStorage.Rauri)
local buildHub = require(Examples.WebHub)

local Dom = Rauri.web.dom
local Html = Rauri.web.html

local passed = 0
local failed = 0
local function check(condition, message)
	if condition then
		passed += 1
		print("ok   " .. message)
	else
		failed += 1
		print("FAIL " .. message)
	end
end

Mock.resetWarnings()
local logs = {}
local app = buildHub(Rauri, {
	parent = game:GetService("Players").LocalPlayer.PlayerGui,
	onLog = function(message)
		logs[#logs + 1] = message
	end,
})
app.window:flush()

check(#logs == 0, "example javascript runs cleanly: " .. table.concat(logs, " | "))
check(#app.gui:GetChildren() > 0, "example mounts into a ScreenGui")
check(Dom.query(app.web.document, ".card") ~= nil, "example cards exist")

local search = Dom.query(app.web.document, "#search")
app.web:setInput(search, "farm")
app.window:flush()
local cards = Dom.querySelectorAll(app.web.document, ".card")
check(#cards == 3, "all example cards stay in the dom")
local hidden = 0
for _, card in cards do
	if Dom.getStyle(card, "display") == "none" then
		hidden += 1
	end
end
check(hidden == 2, "search filters two cards")

local runButton = Dom.query(app.web.document, ".run")
app.web:click(runButton)
app.window:flush()
check(
	Html.flattenText(Dom.query(app.web.document, "#console-line")) == "Queued Auto Farm",
	"run buttons call core commands from javascript"
)

local consoleNav = Dom.querySelectorAll(app.web.document, ".nav")[2]
app.web:click(consoleNav)
app.window:flush()
local consolePage = Dom.query(app.web.document, "#page-console")
check(not Html.hasClass(consolePage, "hidden"), "tab navigation removes hidden")
check(
	Html.flattenText(Dom.query(app.web.document, "#heading")) == "Console",
	"tab navigation updates the heading"
)

local swatch = Dom.querySelectorAll(app.web.document, ".swatch")[2]
app.web:click(swatch)
app.window:flush()
check(app.web:var("accent") == "#22d3a7", "theme swatches update css variables")

app:close()
check(#Mock.warnings == 0, "no warnings in the example: " .. table.concat(Mock.warnings, " | "))

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d example tests failed", failed))
end
