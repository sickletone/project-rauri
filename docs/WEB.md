# Rauri Web: HTML, CSS and JS in Roblox

Roblox has no browser, so Rauri ships a small one: an HTML parser, a CSS cascade
with a real box layout engine, and a JavaScript interpreter bound to a DOM. The
result renders through the same Rauri elements as `ui.*`, which means it works
anywhere Rauri runs — **script executors included**, not just Studio.

```lua
local Rauri = loadstring(game:HttpGet("<url to dist/rauri.lua>"))()

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

Upload `dist/rauri.lua` somewhere reachable and load it from an executor:

```lua
local Rauri = loadstring(game:HttpGet("<url to rauri.lua>"))()
local buildHub = loadstring(game:HttpGet("<url to examples/WebHub.lua>"))()
buildHub(Rauri)
```

Or write the app inline:

```lua
local Rauri = loadstring(game:HttpGet("<url to rauri.lua>"))()
Rauri.web.app({ title = "Hub", html = "<h1>Hi</h1>" })
```

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
| `width`, `height` | `760`, `520` | window size in pixels |
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

## HTML

A forgiving parser: tags, attributes (quoted or not), void elements, comments,
entities (`&amp;`, `&#x1F600;`), raw `<style>`/`<script>`/`<title>`/`<textarea>`.
Unknown tags are block elements by default.

- `<div>`, `<p>`, headings, `<ul>/<li>`, `<section>`, `<article>` and friends are blocks.
- `<span>`, `<a>`, `<b>`, `<strong>`, `<em>`, `<i>`, `<code>`, `<label>` are inline.
- `<button>`, `<input>`, `<img>` are inline-block controls.
- `<input type="text">`, `type="checkbox"` and `type="range"` render real Rauri inputs.
- `<img src="...">` renders an image (Roblox asset ids/URLs; nothing is fetched).

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
`$=`), `:hover`, `:active`, `:focus`, `:checked`, `:root`, `:first-child`,
`:last-child`, descendant and `>` combinators, comma groups. Cascade is by
specificity then source order, with inline styles last.

Layout properties:

- `display`: `block`, `flex`, `inline`, `inline-block`, `none`
- `position`: `static`, `absolute` (with `top`/`right`/`bottom`/`left`)
- flexbox subset: `flex-direction` (row/column), `justify-content`
  (`start`, `center`, `end`, `space-between`), `align-items`
  (`start`, `center`, `end`, `stretch`), `flex`/`flex-grow`, `gap`
- `width`, `height`, `min-*`, `max-*`, `margin`, `padding`, `box-sizing`
- `border` (width style color), `border-*`, `border-radius` (px or `%`)
- `overflow` / `overflow-y` (`auto`, `scroll`, `hidden`) become scroll frames

Paint and text:

- `background` (color or `linear-gradient(angle, from, to)`), `color`
- `font-size`, `font-weight` (400–900), `font-family` (`sans`/`mono` only)
- `line-height`, `text-align`
- `z-index`
- CSS variables: `--name`, `var(--name, fallback)`

Units: `px`, `%`, `em`, `rem`; `vw`/`vh` are resolved against the containing
base. No `calc()`, flex-wrap, grid, transitions, animations, media queries or
pseudo-elements.

Because layout is computed to pixels and rendered on Roblox, text alignment and
wrapping come from `TextService:GetTextSize`; weights map to Gotham faces and
`mono` to Roboto Mono.

## JavaScript

An ES2017-ish interpreter, not a full engine. It supports:

- `let`/`const`/`var`, blocks and function scope
- functions, arrow functions, closures (per-iteration bindings in `for...of`)
- `if`/`else`, `while`, classic `for`, `for...of`, `for...in`,
  `break`, `continue`, `return`
- ternary, `typeof`, `&&`/`||` short-circuiting, `+ - * / %`, comparisons,
  `===`/`!==`, assignments including `+=`, `++`/`--`
- strings, numbers, booleans, `null`/`undefined`, arrays, object literals,
  template strings with `${...}`
- `Math`, `Object.keys/values/assign`, `JSON.parse/stringify` (through
  `HttpService` when available), `parseInt`, `parseFloat`, `isNaN`,
  `setTimeout`, `clearTimeout`, `console`, `localStorage`
- array methods: `push`, `pop`, `shift`, `unshift`, `join`, `forEach`, `map`,
  `filter`, `find`, `some`, `every`, `slice`, `concat`, `reverse`, `indexOf`,
  `includes`; string methods: `trim`, `split`, `replace`, `includes`,
  `startsWith`, `endsWith`, `substring`, `slice`, `charAt`, `indexOf`, `repeat`,
  `toUpperCase`, `toLowerCase`

Not supported: classes/`new`, `async`/promises, regex literals, destructuring,
spread, optional chaining, `this`, `switch`, `try/catch`, `getters/setters`,
generators. Script errors go to `onLog` (or `warn`).

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
`getBoundingClientRect`, `clientWidth`/`clientHeight`, `offsetLeft`/`offsetTop`.

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

- This is a UI engine, not a browser: no network stack, media, forms
  submission, navigation or real `<a href>`.
- Layout is single-pass with a flex subset; there is no text shaping beyond
  Roblox's and no sub-pixel positioning.
- The JS engine is deliberately small; check the list above before relying on a
  modern syntax feature.
- Executor APIs differ between vendors; the platform layer degrades gracefully
  and never requires them.
