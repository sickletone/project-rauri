--!nolint
-- JavaScript language tests: classes and inheritance, this/new, destructuring,
-- spread/rest, optional chaining, nullish coalescing, switch, try/catch,
-- do/while, delete/in/instanceof and the built-in array/string helpers.

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
	width = 320,
	height = 200,
	html = [[<div id="out"></div>]],
	js = [[
const results = [];
function add(name, value) { results.push(name + "=" + value); }

class Animal {
  constructor(name) { this.name = name; }
  speak() { return this.name + "!"; }
  static kind() { return "animal"; }
}
class Dog extends Animal {
  constructor(name, trick) {
    super(name);
    this.trick = trick;
  }
  speak() { return super.speak() + this.trick; }
}
const dog = new Dog("Rex", "sit");
add("class", dog.speak());
add("instanceof", dog instanceof Dog);
add("inherits", dog instanceof Animal);
add("static", Animal.kind());

const { a, b: renamed, missing = 9, ...restObj } = { a: 1, b: 2, c: 3, d: 4 };
add("destructure", a + ":" + renamed + ":" + missing + ":" + (restObj.c + restObj.d));

const [first, , third, ...tail] = [10, 20, 30, 40, 50];
add("arrayPattern", first + ":" + third + ":" + tail.join("-"));

function sum(...values) { return values.reduce((accumulator, value) => accumulator + value, 0); }
add("rest", sum(1, 2, 3, 4));

function describe({ name, size = "m" }) { return name + size; }
add("paramPattern", describe({ name: "shirt" }));

const base = { x: 1 };
const merged = { ...base, y: 2, [":z"]: 3 };
add("spreadObject", merged.x + merged.y + merged[":z"]);

const numbers = [3, 1, 2];
add("spreadCall", Math.max(...numbers));
add("spreadArray", [...numbers, 4].join(""));

const nested = { user: { profile: { name: "Ada" } } };
add("optional", nested?.user?.profile?.name);
add("optionalMissing", nested?.missing?.deep?.());
const nothing = null;
add("nullish", nothing ?? "fallback");

function grade(score) {
  let label = "";
  switch (true) {
    case score > 90:
      label = "A";
      break;
    case score > 80:
      label = "B";
      break;
    default:
      label = "C";
  }
  return label;
}
add("switch", grade(95) + grade(85) + grade(10));

let order = "";
try {
  order += "t";
  throw "boom";
} catch (error) {
  order += "c" + error;
} finally {
  order += "f";
}
add("try", order);

let count = 0;
do { count++; } while (count < 3);
add("doWhile", count);

const removable = { one: 1, two: 2 };
delete removable.one;
add("delete", ("one" in removable) + ":" + ("two" in removable));

const arrowThis = {
  value: 7,
  read() { return (() => this.value)(); },
  method() { return { value: 3, read: this.read }; }
};
add("arrowThis", arrowThis.read());
add("detachedThis", arrowThis.method().read());

const words = ["b", "c", "a"];
words.sort();
add("sort", words.join(""));
add("pad", "5".padStart(3, "0"));
add("replaceAll", "a-b-c".replaceAll("-", "+"));
add("template", `n=${1 + 2}`);
add("arrayApi", Array.isArray([1, 2]) + ":" + Array.from("ab").join(""));
add("objectApi", Object.entries({ a: 1, b: 2 }).length);
add("numberApi", Number.isInteger(3) + ":" + Number.parseInt("12px"));

document.getElementById("out").textContent = results.join(";");
]],
	onLog = function(message)
		logs[#logs + 1] = message
	end,
})

web:start()
check(#logs == 0, "javascript parses and runs: " .. table.concat(logs, " | "))

local out = Rauri.web.dom.query(web.document, "#out")
local text = Rauri.web.html.flattenText(out)

local expected = table.concat({
	"class=Rex!sit",
	"instanceof=true",
	"inherits=true",
	"static=animal",
	"destructure=1:2:9:7",
	"arrayPattern=10:30:40-50",
	"rest=10",
	"paramPattern=shirtm",
	"spreadObject=6",
	"spreadCall=3",
	"spreadArray=3124",
	"optional=Ada",
	"optionalMissing=undefined",
	"nullish=fallback",
	"switch=ABC",
	"try=tcboomf",
	"doWhile=3",
	"delete=false:true",
	"arrowThis=7",
	"detachedThis=3",
	"sort=abc",
	"pad=005",
	"replaceAll=a+b+c",
	"template=n=3",
	"arrayApi=true:ab",
	"objectApi=2",
	"numberApi=true:12",
}, ";")

check(text == expected, "language features produce expected output\n  got:      " .. text .. "\n  expected: " .. expected)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d javascript tests failed", failed))
end
