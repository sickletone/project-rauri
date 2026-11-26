--!nolint
-- Web engine tests: HTML parsing, CSS cascade, layout, JS host bridge,
-- events, theme variables, hover state and ScreenGui mounting.

local Rauri = require(ReplicatedStorage.Rauri)

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

local logs = {}
local web = Rauri.web.new({
	chrome = false,
	width = 360,
	height = 240,
	html = [[
<div id="page" class="page">
  <h1 id="title">Hello</h1>
  <p id="para">Body</p>
  <button id="btn">Click</button>
  <input id="name" placeholder="Name" />
  <input id="toggle" type="checkbox" />
  <i id="zap" data-icon="lucide:zap"></i>
</div>
]],
	css = [[
body { margin: 0; padding: 8px; font-size: 14px; }
.page { background: #202030; padding: 10px; border: 1px solid var(--accent); border-radius: 6px; }
.page:hover { background: #303040; }
h1 { font-size: 20px; color: #ff3366; margin: 0 0 6px 0; }
p { margin: 0 0 6px 0; }
#btn { width: 80px; height: 30px; background: #123456; color: #ffffff; }
#name { width: 120px; height: 28px; }
#toggle { width: 20px; height: 20px; }
#zap { width: 18px; height: 18px; font-size: 18px; }
]],
	js = [[
const btn = document.getElementById("btn");
let clicks = 0;
btn.addEventListener("click", (event) => {
  clicks++;
  document.getElementById("title").textContent = "Clicked " + clicks;
  document.getElementById("para").textContent = "total:" + clicks;
});
document.getElementById("name").addEventListener("input", (event) => {
  document.getElementById("para").textContent = "hi " + event.target.value;
});
document.getElementById("toggle").addEventListener("change", (event) => {
  document.getElementById("title").textContent = event.target.checked ? "on" : "off";
});
let out = "";
for (const item of ["a", "b", "c"]) { out += item; }
document.getElementById("para").textContent = "sum " + out;
]],
	onLog = function(message)
		logs[#logs + 1] = message
	end,
})

web:start()
check(#logs == 0, "javascript runs without errors: " .. table.concat(logs, " | "))

local view = web:view()
check(view ~= nil and view.__rauri == true, "view produces a Rauri tree")

local page = Dom.query(web.document, "#page")
local title = Dom.query(web.document, "#title")
local para = Dom.query(web.document, "#para")
local button = Dom.query(web.document, "#btn")
local name = Dom.query(web.document, "#name")
local toggle = Dom.query(web.document, "#toggle")
local zap = Dom.query(web.document, "#zap")

check(page and title and para and button and name and toggle and zap, "dom queries resolve every element")
check(Html.flattenText(para) == "sum abc", "javascript for-of and string concat")

local pageBox = web:boxOf(page)
local titleBox = web:boxOf(title)
check(pageBox ~= nil and titleBox ~= nil, "layout indexes nodes")
check(math.abs(pageBox.x - 8) < 1, "body padding positions the page")
check(math.abs(pageBox.width - (360 - 16)) < 1, "blocks fill the body content width")
check(math.abs(titleBox.x - 19) < 1, "nested padding cascades")
check(titleBox.style.fontSize == 20, "font-size reaches computed style")
check(math.abs(titleBox.style.color.R - 1) < 0.01 and titleBox.style.color.B < 0.5, "colors reach computed style")
check(pageBox.style.background ~= nil, "background reaches computed style")
check(web:boxOf(zap) ~= nil and web:boxOf(zap).height >= 18, "data-icon boxes keep their font size")
check(pageBox.style.borderRadius ~= nil, "border-radius reaches computed style")
check(pageBox.style.borderColor ~= nil and math.abs(pageBox.style.borderColor.B - 1) < 0.35, "css variables resolve in borders")

web:click(button)
check(Html.flattenText(title) == "Clicked 1", "click events reach javascript listeners")
web:click(button)
check(Html.flattenText(title) == "Clicked 2", "javascript state persists between events")
check(Html.flattenText(para) == "total:2", "multiple dom updates apply")

web:setInput(name, "Rauri")
check(Html.flattenText(para) == "hi Rauri", "input events expose event.target.value")

web:click(toggle)
check(toggle.checked == true, "checkbox click flips checked")
check(Html.flattenText(title) == "on", "change listener reads event.target.checked")
web:click(toggle)
check(toggle.checked == false and Html.flattenText(title) == "off", "checkbox toggles back")

web:view()
local freshPage = web:boxOf(page)
freshPage = web:boxOf(page)
check(freshPage ~= nil, "re-layout after mutations")

local beforeHover = web:boxOf(page).style.background
page.state.hover = true
web:view()
local afterHover = web:boxOf(page).style.background
check(
	math.abs(beforeHover.R - afterHover.R) > 0.01 or math.abs(beforeHover.G - afterHover.G) > 0.01,
	":hover restyles the element"
)
page.state.hover = false
web:view()

web:setVar("accent", "#00ff00")
web:view()
local accented = web:boxOf(page)
check(accented.style.borderColor.G > 0.9, "theme variables update the cascade")
check(web:var("accent") == "#00ff00", "theme variables read back")

-- App mounting -----------------------------------------------------------

Mock.resetWarnings()
local app = Rauri.web.app({
	parent = game:GetService("Players").LocalPlayer.PlayerGui,
	title = "Web Test",
	html = [[<h1 id="app-title">App</h1><button id="app-btn">Go</button>]],
	css = [[h1 { font-size: 18px; }]],
	js = [[
document.getElementById("app-btn").addEventListener("click", () => {
  document.getElementById("app-title").textContent = "Done";
});
]],
	onLog = function(message)
		logs[#logs + 1] = message
	end,
})

app.window:flush()
check(#app.gui:GetChildren() > 0, "app mounts a ScreenGui with instances")
local appButton = Dom.query(app.web.document, "#app-btn")
local appTitle = Dom.query(app.web.document, "#app-title")
app.web:click(appButton)
app.window:flush()
check(Html.flattenText(appTitle) == "Done", "mounted app reacts to click listeners")

app.web.minimized:set(true)
app.window:flush()
local minimizedChildren = app.gui:GetChildren()
check(
	#minimizedChildren == 1 and minimizedChildren[1].ClassName == "TextButton",
	"minimize swaps to the restore pill"
)
app.web.minimized:set(false)
app.window:flush()
local restoredChildren = app.gui:GetChildren()
check(
	#restoredChildren == 1 and restoredChildren[1].ClassName == "Frame",
	"restore rebuilds the window"
)
check(Rauri.platform.isExecutor() == false, "studio detection in the mock")
check(Rauri.platform.guiParent() ~= nil, "platform finds a GUI parent")

local inputService = game:GetService("UserInputService")
inputService.TouchEnabled = true
inputService.KeyboardEnabled = false
check(Rauri.platform.isMobile() == true, "touch devices report mobile")
inputService.KeyboardEnabled = true
check(Rauri.platform.isMobile() == false, "devices with keyboards keep the desktop window")
inputService.TouchEnabled = nil
inputService.KeyboardEnabled = nil
check(app.web:var("border") ~= "", "default theme variables exist")

app:close()
check(#Mock.warnings == 0, "no warnings during web tests: " .. table.concat(Mock.warnings, " | "))

-- Mobile window ---------------------------------------------------------

local mobile = Rauri.web.new({
	mobile = true,
	viewport = { width = 390, height = 844 },
	chrome = false,
	html = [[<div id="mobile-card"></div>]],
	css = [[
#mobile-card { width: 100%; height: 40px; background: #000000; }
@media (max-width: 600px) { #mobile-card { height: 60px; } }
]],
})
mobile:start()
mobile:view()
local mobileCard = mobile:boxOf(Dom.query(mobile.document, "#mobile-card"))
check(mobile.mobile == true and mobile.fullscreen == true, "mobile mode is available through config")
check(mobile.width == 390 and mobile.height == 844 and mobile.radius == 0, "mobile window fills the viewport")
check(mobileCard ~= nil and math.abs(mobileCard.height - 60) < 1, "mobile media queries apply at the viewport width")
mobile:resize(844, 390)
mobile:view()
check(mobile.width == 844 and mobile.height == 390, "resize updates the window and layout")
mobile:close()

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d web tests failed", failed))
end
