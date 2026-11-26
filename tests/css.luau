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
<div id="pseudo">Hello</div>
<div id="floatWrap"><div id="fl" class="fl"></div><div id="after"></div></div>
<div id="fixed"></div>
<div id="sticky">sticky</div>
<div id="spanGrid" class="spangrid"><div id="sp1" class="span2"></div><div id="sp2" class="cell"></div><div id="sp3" class="cell"></div></div>
<div id="anim"></div>
<div id="hoverBtn"></div>
<canvas id="paint" width="100" height="50"></canvas>
<video id="vid" poster="rbxassetid://1"></video>
<audio id="aud" src="rbxassetid://2" controls></audio>
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
#pseudo::before { content: ">> "; color: #ff0000; }
#floatWrap { width: 200px; }
.fl { float: left; width: 40px; height: 20px; background: #333333; }
#after { height: 10px; background: #333333; }
#fixed { position: fixed; right: 10px; top: 10px; width: 30px; height: 10px; background: #333333; }
#sticky { position: sticky; top: 5px; height: 10px; background: #333333; }
.spangrid { display: grid; grid-template-columns: 100px 100px 100px; gap: 0; width: 300px; }
.span2 { grid-column: span 2; height: 20px; background: #333333; }
#vid { height: 60px; }
#aud { height: 20px; }
@keyframes fade { from { opacity: 0; } to { opacity: 1; } }
#anim { width: 10px; height: 10px; animation: fade 2s; }
#hoverBtn { width: 40px; height: 20px; background: #000000; color: #ffffff; opacity: 1; transition: background 1s, color 1s, opacity 1s; }
#hoverBtn:hover { background: #ff0000; color: #00ff00; opacity: 0.5; }
]],
	animations = false,
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

local pseudoBox = box("pseudo")
local foundPseudo = false
for _, child in pseudoBox and pseudoBox.children or {} do
	if child.kind == "text" and child.text:find(">>", 1, true) then
		foundPseudo = true
	end
end
check(foundPseudo, "::before content renders a text box")

local floatBox, afterBox = box("fl"), box("after")
check(floatBox ~= nil and math.abs(floatBox.x - afterBox.x) < 1, "float: left sits at the content edge")
check(afterBox.y >= floatBox.y + floatBox.height - 1, "block content flows below a float")

local fixedBox = box("fixed")
check(fixedBox ~= nil and math.abs(fixedBox.x - (360 - 30 - 10)) < 1 and math.abs(fixedBox.y - 10) < 1, "position: fixed anchors to the viewport")

local stickyBox = box("sticky")
check(stickyBox ~= nil and stickyBox.y >= 5, "position: sticky applies its top offset")

local sp1, sp2, sp3 = box("sp1"), box("sp2"), box("sp3")
check(sp1 ~= nil and math.abs(sp1.width - 200) < 1, "grid-column: span 2 widens the cell")
check(sp2.x >= sp1.x + 199, "a spanning cell pushes the next cell to the following column")
check(sp3.y > sp1.y, "the row after a spanning cell starts below it")

local sampled = Rauri.web.css.sampleKeyframes(web.stylesheet, "fade", 0.5)
check(sampled ~= nil and math.abs((tonumber(sampled.opacity) or 0) - 0.5) < 0.01, "@keyframes sample and interpolate values")
local animated = Rauri.web.css.compute(web.document, web.stylesheet, { animationTime = 0.5 })
local animStyle = animated[node("anim").id]
check(animStyle ~= nil and math.abs(animStyle.opacity - 0.25) < 0.01, "animation: fade 2s applies the keyframe at elapsed time")

local hoverNode = node("hoverBtn")
local baseHover = box("hoverBtn")
check(baseHover.style.background.R < 0.05, "hover transition starts from the base background")
web:setHover(hoverNode, true)
web:view()
local startHover = box("hoverBtn")
check(startHover.style.background.R < 0.05, "hover transition does not jump at t=0")
local hoverEntries = web.transitions[hoverNode.id]
check(hoverEntries ~= nil and hoverEntries.background ~= nil, "hover creates a background transition")
for _, entry in hoverEntries or {} do
	entry.start = os.clock() - 0.5
end
web:view()
local midHover = box("hoverBtn")
check(midHover.style.background.R > 0.3 and midHover.style.background.R < 0.7, "hover background blends toward the target")
check(midHover.style.opacity > 0.6 and midHover.style.opacity < 0.9, "hover opacity blends toward the target")
for _, entry in web.transitions[hoverNode.id] or {} do
	entry.start = os.clock() - 2
end
web:view()
local endHover = box("hoverBtn")
check(endHover.style.background.R > 0.9 and endHover.style.opacity < 0.55, "hover transition finishes at the hover style")
check(web.transitions[hoverNode.id] == nil, "finished transitions are cleared")

local canvasBox, videoBox, audioBox = box("paint"), box("vid"), box("aud")
check(canvasBox ~= nil and math.abs(canvasBox.width - 100) < 1 and math.abs(canvasBox.height - 50) < 1, "canvas uses its width/height attributes")
web:view()
check(videoBox ~= nil and videoBox.width > 0, "video elements lay out")
check(audioBox ~= nil and audioBox.width > 0, "audio elements lay out")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d css tests failed", failed))
end
