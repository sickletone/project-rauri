--!nolint
-- CSS/layout tests for the newer engine features: flex-wrap, grid, calc(),
-- nth-child/:not/sibling selectors, media queries, aspect-ratio and the
-- HTML controls (select, radio, details, table, br).

local Rauri = require(ReplicatedStorage.Rauri)

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
	height = 480,
	html = [[
<div id="wrap" class="wrap">
  <div class="item" id="a"></div>
  <div class="item" id="b"></div>
  <div class="item" id="c"></div>
</div>
<div id="grid" class="grid">
  <div class="cell" id="g1"></div>
  <div class="cell" id="g2"></div>
</div>
<div id="calc" class="calc"></div>
<div id="ratio" class="ratio"></div>
<ul id="list"><li id="li1"></li><li id="li2"></li><li id="li3"></li></ul>
<div id="sib"><span id="s1"></span><span id="s2" class="target"></span></div>
<table id="table"><tr id="row1"><td id="c1">A</td><td id="c2">B</td></tr></table>
<details id="details"><summary id="sum">More</summary><p id="hidden">Body</p></details>
<select id="sel"><option value="a">Alpha</option><option value="b">Beta</option><option value="c">Gamma</option></select>
<input id="r1" type="radio" name="grp" />
<input id="r2" type="radio" name="grp" />
<div id="br"><span>one</span><br /><span>two</span></div>
]],
	css = [[
body { margin: 0; padding: 0; }
ul { margin: 0; padding: 0; }
.wrap { display: flex; flex-wrap: wrap; gap: 10px; width: 220px; }
.item { width: 100px; height: 20px; background: #333333; }
.grid { display: grid; grid-template-columns: 1fr 2fr; gap: 10px; width: 360px; }
.cell { height: 20px; background: #333333; }
.calc { width: calc(100% - 40px); height: 10px; background: #333333; }
.ratio { width: 160px; aspect-ratio: 2 / 1; background: #333333; }
li { height: 10px; }
li:nth-child(2) { height: 20px; }
li:not(:first-child) { margin-top: 5px; }
#s1 { width: 20px; height: 10px; }
.target { height: 12px; width: 10px; }
#s1 + .target { height: 24px; }
@media (min-width: 300px) { #s2 { width: 50px; } }
#sel { width: 140px; height: 30px; }
#r1, #r2 { width: 20px; height: 20px; }
]],
	onLog = function(message)
		logs[#logs + 1] = message
	end,
})

web:start()
web:view()
check(#logs == 0, "stylesheet parses and runs: " .. table.concat(logs, " | "))

local Dom = Rauri.web.dom
local function node(id)
	return Dom.query(web.document, "#" .. id)
end
local function box(id)
	return web:boxOf(node(id))
end

local a, b, c = box("a"), box("b"), box("c")
check(a ~= nil and b ~= nil and c ~= nil, "wrap items lay out")
check(math.abs(a.y - b.y) < 1, "flex-wrap keeps two items on the first line")
check(c.y > a.y + a.height, "flex-wrap moves the third item to a second line")

local g1, g2 = box("g1"), box("g2")
check(g1 ~= nil and g2 ~= nil, "grid items lay out")
check(math.abs(g1.y - g2.y) < 1, "grid places cells on one row")
check(math.abs(g2.width - g1.width * 2) < 2, "grid 1fr / 2fr distributes space")

local calcBox = box("calc")
check(calcBox ~= nil and math.abs(calcBox.width - 320) < 1, "calc() resolves percentages and pixels")

local ratio = box("ratio")
check(ratio ~= nil and math.abs(ratio.height - 80) < 1, "aspect-ratio derives the height")

local li1, li2 = box("li1"), box("li2")
check(li1 ~= nil and li2 ~= nil and math.abs(li2.height - 20) < 1, ":nth-child sets the second row height")
check(math.abs(li2.y - (li1.y + li1.height) - 5) < 1, ":not() + margin applies to later rows")

local s2 = box("s2")
check(s2 ~= nil and math.abs(s2.height - 24) < 1, "adjacent sibling selector applies")
check(math.abs(s2.width - 50) < 1, "media query applies at this width")

local c1, c2 = box("c1"), box("c2")
check(c1 ~= nil and c2 ~= nil and math.abs(c1.y - c2.y) < 1, "table cells share a row")
check(c1.width > 140 and c2.width > 140, "table cells split the row")

check(box("hidden") == nil, "closed details hides its body")
web:click(node("sum"))
web:view()
check(box("hidden") ~= nil, "clicking summary opens details")

local select = node("sel")
check(select.value == "a", "select starts on the first option")
web:click(select)
check(select.value == "b", "clicking select cycles to the next option")
web:click(select)
check(select.value == "c", "clicking select cycles again")

local r1, r2 = node("r1"), node("r2")
web:click(r2)
check(r2.checked == true and r1.checked == false, "radio selects itself")
web:click(r1)
check(r1.checked == true and r2.checked == false, "radio unchecks the rest of the group")

local brBox = box("br")
check(brBox ~= nil and brBox.height > 28, "br splits inline text into two lines")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d css tests failed", failed))
end
