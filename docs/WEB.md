# Rauri Web: HTML, CSS and JS in Roblox

Roblox has no browser, so Rauri ships a small one: an HTML parser, a CSS cascade
with a real box layout engine, and a JavaScript interpreter bound to a DOM. The
result renders through the same Rauri elements as `ui.*`, which means it works
anywhere Rauri runs — **script executors included**, not just Studio.

```lua
local Rauri = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/sickletone/project-rauri/main/dist/rauri.lua"
))()

local app = Rauri.web.app({
    title = "My Hub",
    width = 720,
    height = 480,
    html = [[
        <div class="card">
            <h1 id="title">Hello</h1>
            <button id="go">Run</button>
        </div>
    ]],
    css = [[
        .card { padding: 16px; background: var(--surface); border-radius: 12px; }
        h1 { color: var(--accent); }
    ]],
    js = [[
        document.getElementById("go").addEventListener("click", () => {
            document.getElementById("title").textContent = "Running...";
            rauri.notify("Started");
        });
    ]],
})
```

Every layer is replaceable. `chrome = false` removes the default titlebar so your
HTML owns the whole window; `theme`/`Rauri.web` themes, CSS variables, commands,
events and the DOM are all exposed to Luau as well as JS.

## Quick start

Build a single-file framework (no Rojo, no Studio install needed):

```bash
node scripts/bundle.mjs --entry src/shared/Rauri/init.lua \
  --out dist/rauri.lua --alias ReplicatedStorage=src/shared
```

The repo publishes the built bundle at `dist/rauri.lua`, so an executor can load it directly:

```lua
local Rauri = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/sickletone/project-rauri/main/dist/rauri.lua"
))()

Rauri.web.app({ title = "Hub", html = "<h1>Hi</h1>" })
```

The example hub loads itself (framework + example) in one line:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/sickletone/project-rauri/main/examples/WebHubLoader.lua"
))()
```

Or load the pieces yourself:

```lua
local Rauri = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/sickletone/project-rauri/main/dist/rauri.lua"
))()
local buildHub = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/sickletone/project-rauri/main/examples/WebHub.lua"
))()
buildHub(Rauri) -- returns the mounted app
```

If `raw.githubusercontent.com` is blocked, the same files are on jsDelivr:
replace `https://raw.githubusercontent.com/sickletone/project-rauri/main` with
`https://cdn.jsdelivr.net/gh/sickletone/project-rauri@main`.

Rebuild `dist/rauri.lua` after framework changes so the published bundle matches
the source.

`Rauri.web.app(config)` creates a `ScreenGui`, chooses its parent via the
platform layer (`gethui` → `PlayerGui`), protects it where the
executor supports it, mounts the web view and returns:

| field | meaning |
| --- | --- |
| `app.web` | the `Web` instance (DOM, theme, toasts, events) |
| `app.core` | the Rauri core (commands, events, capabilities) |
| `app.gui` | the created `ScreenGui` |
| `app.window` | the mounting handle (`:flush()`, `:unmount()`, ...) |
| `app:toast(message)` | show a toast |
| `app:close()` | unmount and destroy |

Use `Rauri.web.new(config)` when you want the view without a `ScreenGui`:
`web:start()`, then `web:view()` returns the virtual tree, or mount it yourself
with `core:mount(function() return web:view() end)`.

### Config

| key | default | |
| --- | --- | --- |
| `html` | empty state | HTML source |
| `url` | — | fetch the HTML with `game:HttpGet` (executors) when `html` is absent |
| `css` | — | extra CSS, appended after the default theme |
| `js` | — | source string or array of sources |
| `title` | `"Rauri"` | titlebar text / ScreenGui name |
| `width`, `height` | `760`, `520` | window size in pixels; clamped to the camera viewport |
| `mobile` | auto | touch-device mode; detected from `UserInputService` |
| `mobileFullscreen` | `true` | on touch devices, fill the whole camera viewport with square corners |
| `viewport` | camera size | override the viewport (useful for tests and embedded previews) |
| `chrome` | `true` | wrap HTML in the default titlebar/body |
| `theme` | — | CSS variable overrides (`accent`, `bg`, `radius`, ...) |
| `radius` | `12` | root corner radius |
| `parent` / `gui` | platform parent | where the `ScreenGui` goes |
| `name`, `displayOrder`, `ignoreInset` | — | ScreenGui fields |
| `capabilities`, `core` | — | pass through to the Rauri core |
| `onLog`, `onInput`, `onClose` | — | host hooks |
| `js = { ... }` | — | multiple scripts, run in order |

HTML `<script>` tags run after `config.js` unless they have a `src`; in an
executor, `src` URLs are fetched with `game:HttpGet`, as are `<link
rel="stylesheet">` files. `<style>` tags are added to the stylesheet.
Elsewhere remote scripts and styles are ignored.

On phones and tablets the window defaults to the full camera viewport, drops its
corner radius, and rebuilds when the viewport changes (rotation, split screen).
The small-screen rules in the base stylesheet use a 34px titlebar, 10px body
padding and 34px minimum button height. Set `mobile = false` to keep the desktop
window, or `mobileFullscreen = false` to center a fixed-size window instead.
`Web:resize(width, height)` updates the window at runtime.

## HTML

A forgiving parser: tags, attributes (quoted or not), void elements, comments,
entities (`&amp;`, `&#x1F600;`), raw `<style>`/`<script>`/`<title>`/`<textarea>`.
Unknown tags are block elements by default.

- `<div>`, `<p>`, headings, `<ul>/<li>`, `<section>`, `<article>`, `<details>` and friends are blocks.
- `<span>`, `<a>`, `<b>`, `<strong>`, `<em>`, `<i>`, `<code>`, `<label>` are inline.
- `<button>`, `<input>`, `<img>`, `<select>`, `<textarea>` are inline-block controls.
- `<input type="text|checkbox|radio|range">` render real Rauri controls; a
  `radio` group shares `name` and only one stays checked.
- `<img src="...">` renders an image (Roblox asset ids/URLs; nothing is fetched).
- `<textarea>` is a multi-line input; `<select>`/`<option>` render a control that
  cycles options on click and fires `input` + `change`.
- `<table>`/`<tr>`/`<td>`/`<th>` lay out as equal-width rows.
- `<details>`/`<summary>` collapse their body until the summary is clicked.
- `<progress value max>` renders a bar, `<br>` forces a line break and `<hr>` a divider.
- `<label for="id">` focuses or clicks its target.
- `<canvas width height>` is a 2D surface: `getContext("2d")` supports
  `fillStyle` with `fillRect`/`clearRect`, rendered as frame rectangles.
- `<video poster src>` shows its poster (or a placeholder tile); `<audio src controls>`
  renders a play button that sends `src` to a Roblox `Sound`.

Attributes that drive behaviour:

| attribute | effect |
| --- | --- |
| `id`, `class`, `style` | selectors, CSS classes, inline CSS |
| `data-icon="lucide:zap"` | render a Molto icon instead of a box (tint from `color`) |
| `data-drag` | drag the window from this element |
| `data-action="close"` / `"minimize"` / `"restore"` | built-in window actions |
| `data-*` | available in JS via `dataset`, CSS via `[data-x]` |

## CSS

Selectors: `*`, `tag`, `.class`, `#id`, `[attr]`, `[attr=value]` (`*=`, `^=`,
`$=`, `~=`, `|=`, `!=`), `:hover`, `:active`, `:focus`, `:focus-within`,
`:checked`, `:disabled`, `:enabled`, `:empty`, `:root`, `:first-child`,
`:last-child`, `:only-child`, `:nth-child(an+b)`, `:nth-last-child()`,
`:not(selector)`, `:is()`/`:where()`, `::before`/`::after` pseudo-elements,
descendant, `>`, `+` and `~` combinators, comma groups. Cascade is by specificity then source order, with inline styles
last. `@media (min-width|max-width: Npx) { ... }` is evaluated against the
window width when the stylesheet is built.

Layout properties:

- `display`: `block`, `flex`, `grid`, `inline`, `inline-block`, `none`
- `position`: `static`, `absolute` (with `top`/`right`/`bottom`/`left`/`inset`),
  `fixed` (viewport-anchored) and `sticky` (applies its `top`/`left` at layout time)
- flexbox: `flex-direction` (row/column), `justify-content` (`start`, `center`,
  `end`, `space-between`, `space-around`), `align-items`/`align-self`/
  `align-content` (`start`, `center`, `end`, `stretch`), `flex`/`flex-grow`/
  `flex-shrink`/`flex-basis`, `flex-wrap: wrap`, `order`, `gap`
- grid: `grid-template-columns`/`grid-template-rows` (`px`, `%`, `fr`, `auto`),
  row-major auto-placement, `gap`, `grid-column`/`grid-row` spans
- `float: left|right` (boxes sit at the content edge; following block content
  flows below them)
- `width`, `height`, `min-*`, `max-*`, `aspect-ratio`, `margin`, `padding`,
  `box-sizing`
- `border` (width style color), `border-*`, `border-radius` (px or `%`)
- `overflow` / `overflow-y` (`auto`, `scroll`, `hidden`) become scroll frames
- `opacity` (background alpha), `z-index`

Paint and text:

- `background` / `background-image` (color or `linear-gradient(angle, from, to)`), `color`
- `font-size`, `font-weight` (400–900), `font-family` (`sans`/`mono` only)
- `line-height`, `text-align`, `text-transform`, `white-space: nowrap`
- CSS variables: `--name`, `var(--name, fallback)`

Units: `px`, `%`, `em`, `rem`, `vw`/`vh` and `calc()` (`+ - * /`, parentheses).
`::before`/`::after` render their `content` (quoted string or `attr(...)`) as
inline text that inherits from the element. `@keyframes` are parsed; `animation:
name duration` loops through sampled keyframes while the page repaints, and
`web:animate(node, "name", seconds)` drives one manually. `transition:
color|background|opacity <duration>` animates those properties when hover state
changes (linear interpolation, driven from the existing box snapshot); other
transitioned properties are stored but not tweened. `@supports` and `@import`
are ignored.

Because layout is computed to pixels and rendered on Roblox, text alignment and
wrapping come from `TextService:GetTextSize`; weights map to Gotham faces and
`mono` to Roboto Mono.

## JavaScript

An ES2019-ish interpreter, not a full engine. It supports:

- `let`/`const`/`var`, blocks and function scope
- functions, arrow functions (lexical `this`), closures (per-iteration bindings
  in `for...of`), default/rest parameters, destructured parameters
- `class` with `constructor`, instance/static methods and fields, `extends`,
  `super(...)` and `super.method()`, `new`, `this`, `instanceof`
- destructuring declarations (`const { a, b: c = 1, ...rest } = obj`,
  `const [first, , third, ...tail] = list`)
- spread in arrays, objects and calls; rest parameters
- optional chaining (`a?.b?.[c]?.()`) and nullish coalescing (`??`, `??=`)
- `if`/`else`, `while`, `do...while`, classic `for`, `for...of`, `for...in`,
  `switch`/`case` (with fallthrough), `try`/`catch`/`finally`, `throw`,
  `break`, `continue`, `return`
- ternary, `typeof`, `delete`, `in`, `void`, `&&`/`||`/`??` short-circuiting,
  `+ - * / % **`, comparisons, `===`/`!==`, assignments including `+=`/`??=`,
  `++`/`--`
- strings, numbers, booleans, `null`/`undefined`, arrays, object literals with
  shorthand/methods/computed keys, template strings with `${...}`
- `Math`, `Object.keys/values/entries/assign`, `JSON.parse/stringify` (through
  `HttpService` when available), `parseInt`, `parseFloat`, `isNaN`,
  `setTimeout`, `clearTimeout`, `console`, `localStorage`
- regex literals (`/\d+/gi`) and `new RegExp(source, flags)`: `test`, `exec`,
  `source`, `flags`, `lastIndex`; string `match`, `matchAll`, `search`, regex
  `split`, and `replace`/`replaceAll` with `$1`, `$&` and `$$`
- `async function`, async arrows and `await`, backed by promises (`new Promise`,
  `then`/`catch`/`finally`, `Promise.resolve/reject/all/race`) scheduled with
  `task.defer`
- generators: `function*`, `yield`, `.next()` and `for...of` over generator objects
- array methods: `push`, `pop`, `shift`, `unshift`, `join`, `forEach`, `map`,
  `filter`, `find`, `findIndex`, `some`, `every`, `reduce`, `slice`, `splice`,
  `concat`, `reverse`, `sort`, `flat`, `at`, `indexOf`, `includes`; string
  methods: `trim`, `trimStart`, `trimEnd`, `split`, `replace`, `replaceAll`,
  `includes`, `startsWith`, `endsWith`, `substring`, `slice`, `charAt`,
  `charCodeAt`, `indexOf`, `repeat`, `padStart`, `padEnd`, `concat`,
  `toUpperCase`, `toLowerCase`

Not supported: getters/setters, tagged templates, labels, `with`, BigInt,
`yield*`, async generators, lookaround/named-group/backreference regex syntax.
Script errors go to `onLog` (or `warn`).

### DOM

`document`: `body`, `head`, `documentElement`, `title`, `querySelector`,
`querySelectorAll`, `getElementById`, `createElement`, `createTextNode`.

Elements expose `tagName`, `id`, `className`, `textContent`/`innerText`,
`innerHTML` (set), `value`, `checked`, `style` (camelCase, e.g.
`style.backgroundColor`), `dataset`, `classList.add/remove/toggle/contains`,
`getAttribute`/`setAttribute`/`hasAttribute`/`removeAttribute`, `children`,
`childNodes`, `parentNode`/`parentElement`, `firstChild`/`lastChild`,
`nextSibling`, `appendChild`, `append`, `removeChild`, `remove`,
`addEventListener`/`removeEventListener`, `onclick`/`oninput`/`onchange`/
`onsubmit`, `closest`, `matches`, `click`, `focus`, `blur`,
`getBoundingClientRect`, `clientWidth`/`clientHeight`, `offsetLeft`/`offsetTop`,
and `getContext("2d")` on `<canvas>` (`fillStyle`, `fillRect`, `clearRect`).

Events bubble up the tree: `click`, `input`, `change` (checkbox), `submit`.
The event object has `type`, `target`, `currentTarget`, `value`, `key`,
`action`, `stopPropagation()` and `preventDefault()`.

### `rauri` bridge

```js
rauri.platform          // { executor: boolean }
rauri.notify(message)   // toast
rauri.close()           // close the app
rauri.minimize()
rauri.restore()
rauri.theme.set("accent", "#22d3a7")
rauri.theme.get("accent")
rauri.theme.tokens()
rauri.storage.get(key) / set(key, value) / remove(key) / clear()
rauri.command("script.run", { name: "Auto Farm" }) // calls the core
rauri.on("core.event", (payload) => { ... })
```

`rauri.command` returns the handler's value and throws on unknown/denied
commands (the listener wrapper logs it). Capabilities work exactly as they do
for `ui.*` windows.

## Controlling the UI from Luau

The DOM is the source of truth; mutate it and the next render reflects it:

```lua
local web = app.web
local dom = Rauri.web.dom

local title = dom.query(web.document, "#title")
dom.setText(title, "From Luau")

web:setInput(dom.query(web.document, "#search"), "farm")
web:click(dom.query(web.document, "#go"))
web:setVar("accent", "#22d3a7")       -- updates CSS variables and re-renders
web:notify("Saved")
```

Useful `Web` members: `document`, `version`, `toasts`, `minimized`, `position`, `stylesheet`, `boxOf(node)` (last layout box), `invalidate()`, `view()`,
`start()`, `close()`, and the escape hatches `Rauri.web.dom`, `.css`, `.html`,
`.layout`, `.js`, `.render`.

## Customize everything

- **Look**: override any `--var` through `theme` or `web:setVar`; use
  `linear-gradient`; remove the default chrome and write your own titlebar with
  `data-drag` and `data-action`.
- **Structure**: any HTML tree; render sections dynamically from JS or Luau.
- **Behaviour**: JS listeners plus core commands and events; events from the
  core reach JS with `rauri.on`.
- **Icons**: every Molto provider works in `data-icon`
  (`lucide:zap`, `tabler:bolt`, `heroicons:...`, ...); provider-prefixed names
  fall back to the bundled samples when the full registry is unavailable.
- **Window**: `width`, `height`, `radius`, `displayOrder`, `ignoreInset`,
  `parent`; drag, minimize and restore are built in but optional.
- **Host integration**: `config.onLog`, `config.onInput`, `config.onClose`,
  `web:dispatch(node, type, detail)` for synthetic events.

## Executors

`Rauri.platform` checks for executor-only globals and exposes what they add:

```lua
Rauri.platform.isExecutor()  --> boolean (gethui / clipboard / file globals present)
Rauri.platform.isMobile()    --> boolean (touch screen without a keyboard)
Rauri.platform.viewportSize() --> width, height from the current camera
Rauri.platform.summary()     --> { executor, clipboard, fileIO, http }
Rauri.platform.guiParent()   --> gethui() in executors, PlayerGui otherwise
Rauri.platform.protect(gui)  --> protect_gui when available
Rauri.platform.setClipboard(text)
Rauri.platform.readFile(path) / writeFile(path, data) / fileExists(path)
Rauri.platform.httpGet(url)
Rauri.platform.notify(title, text)  -- StarterGui:SetCore notification
```

`Rauri.web.app` uses `guiParent()` and `protect()` automatically, so the same
code runs in Studio (PlayerGui, visible in Play Solo) and in an executor
(gethui, protected). Icons use Molto sprite sheets, which are ordinary
Roblox asset ids — no executor-only APIs are required for them to render.

## Building the single file

```bash
node scripts/bundle.mjs --entry src/shared/Rauri/init.lua \
  --out dist/rauri.lua --alias ReplicatedStorage=src/shared
```

The output is one Luau file whose `loadstring(...)()` returns the `Rauri` table.
The bundler rewrites every Roblox-style `require` (including `script.Parent.*`
and `ReplicatedStorage.Rauri`) into a module registry, so it works outside a
Rojo place.

To also ship the example app as its own file, bundle it with an alias:

```bash
node scripts/bundle.mjs --entry examples/WebHub.lua \
  --out dist/WebHub.lua --alias ReplicatedStorage=src/shared
```

## Limits

- This is a UI engine, not a browser: no network stack, iframes, form
  submission, navigation or real `<a href>`.
- Canvas records 2D rectangles (`fillStyle`, `fillRect`, `clearRect`) only: no
  paths, text, images or pixel reads. Video shows a poster/placeholder; audio
  playback depends on `SoundService` and the executor allowing `Sound`.
- Layout is single-pass: floats do not wrap text around them, sticky offsets do
  not react to scrolling, fixed boxes are still children of their scroll
  container, and there is no text shaping beyond Roblox's.
- CSS transitions animate `color`, `background` (including alpha) and `opacity`
  on hover with linear timing; other properties are parsed but not interpolated.
  Keyframe animations loop on repaint (or via `web:animate`), pseudo-elements
  are inline text only, and there is no `@supports`/`@import`.
- The JS engine covers the listed syntax; regex lookaround/backreferences,
  getters/setters and modules remain gaps.
- Executor APIs differ between vendors; the platform layer degrades gracefully
  and never requires them.
