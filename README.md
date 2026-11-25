# Rauri

A Tauri-shaped app framework for Roblox.

Tauri gives you a web frontend, a native core, commands, events and a capability manifest. Roblox has no browser, so Rauri keeps the shape but replaces the WebView with a reactive Luau UI tree: signals in, keyed instance diffing out. The rest of the Tauri contract — a core that owns commands and events, a manifest that gates what a window may call, a bundler — is here too.

Rauri also ships a browser-shaped frontend for script developers: it parses HTML, applies a CSS cascade with a real box layout engine, and runs a small JavaScript interpreter against a DOM — all rendered with Rauri elements. That frontend is what makes the framework usable from **Roblox executors**, not only Studio. See [docs/WEB.md](docs/WEB.md).

```lua
local Rauri = require(ReplicatedStorage.Rauri)
local ui = Rauri.ui

local count = Rauri.signal(0)

local core = Rauri.new({
	name = "Counter",
	capabilities = { default = { "counter.*" } },
})

core:handle("counter.increment", function()
	count:update(function(value) return value + 1 end)
	return count:get()
end)

core:mount(function()
	return ui.column({ size = "fill", pad = 24, gap = 10 },
		ui.text({ text = "Count: " .. count:get(), style = { fontSize = 22, font = "bold" } }),
		ui.button({
			text = "Increment",
			onClick = function()
				core:invoke("counter.increment")
			end,
		})
	)
end, { name = "main" })
```

## Project layout

```
src/shared/Rauri/        the framework (Rojo: ReplicatedStorage.Rauri)
src/client/              Rauri Studio, the demo app (StarterPlayerScripts)
docs/WEB.md              HTML/CSS/JS frontend + executor guide
examples/WebHub.lua      a complete executor hub in HTML/CSS/JS
scripts/bundle.mjs       single-file bundler + test harness loader
tests/                   headless test suite (mock Roblox API)
default.project.json     Rojo mapping
```

## Run it

```bash
rojo serve            # into an open Studio place
rojo build default.project.json -o RauriDemo.rbxlx
```

`default.project.json` puts the framework in `ReplicatedStorage.Rauri` and the demo in `StarterPlayerScripts.Client.main`. Press Play and the window appears.

## UI layer

Elements are plain tables produced by `Rauri.ui`:

- `frame`, `row`, `column`, `grid`, `scroll`, `text`, `button`, `icon`, `image`, `input`, `divider`, `spacer`, `chip`, `switch`, `slider`.
- Components are functions: `local Card = function(props) return ui.column(props, props.children) end` — call `Card({ ... }, child)`.
- `key = "id"` keeps an instance alive across reorders.
- `size = "fill"` (or `width`/`height`) accepts a number, `{ scale, offset }`, or `UDim2`. Fill inside a padded frame means the padded box.
- `style` covers `bg`, `fg`, `radius`, `pad`, `gap`, `border`, `font`, `fontSize`, `align`, `valign`, `wrap`, plus `hover` and `press` variants.
- Color strings may be hex (`"#6d6dfb"`) or theme tokens (`"$accent"`).
- Events: `onClick`, `onPress`, `onRelease`, `onHover`, `onInput`, `onSubmit`, `onFocus`, `onBlur`, `onInputBegan`; handlers receive the event value (when there is one) and the instance.
- Anything not handled as a shorthand is assigned to the instance when that property exists, so `AutomaticSize`, `ClipsDescendants`, `ZIndex` and friends work directly.

Rendering is a full re-render of the render function plus a keyed diff, so signals never touch instances directly:

```lua
local query = Rauri.signal("")
core:mount(function()
	return ui.input({
		text = query:get(),
		onInput = function(value) query:set(value) end,
	})
end, { name = "main" })
```

## HTML, CSS and JS

`Rauri.web` is an embedded browser built on the same primitives: an HTML parser, a CSS cascade and layout engine, and a JavaScript interpreter with a DOM.

```lua
local app = Rauri.web.app({
	title = "My Hub",
	width = 720,
	height = 480,
	html = [[<div class="card"><h1 id="title">Hello</h1><button id="go">Run</button></div>]],
	css = [[.card { padding: 16px; background: var(--surface); border-radius: 12px; }]],
	js = [[
document.getElementById("go").addEventListener("click", () => {
	document.getElementById("title").textContent = "Running...";
	rauri.notify("Started");
});
]],
})
```

- `Rauri.web.app(config)` mounts a `ScreenGui` (gethui under an executor, PlayerGui otherwise) and returns `web`, `core`, `gui` and `window`.
- Layout: block, flex and inline flow, absolute positioning, margins/padding/borders/radius, gradients, CSS variables, hover/focus/checked states, text wrapping, scroll frames and Molto icons via `data-icon`.
- JavaScript: functions and arrows, loops, arrays/objects, template strings, DOM queries and events, `rauri.command/notify/theme/storage/on`, and `localStorage`.
- Customize everything: `chrome = false` for your own titlebar, `theme` variables, any HTML/CSS/JS, Luau DOM access (`Rauri.web.dom`), commands and capabilities, host hooks (`onLog`, `onInput`, `onClose`).

The full supported subset and API are in [docs/WEB.md](docs/WEB.md); `examples/WebHub.lua` is a complete executor hub you can load or copy.

### Executors

```lua
Rauri.platform.isExecutor()
Rauri.platform.guiParent()      -- gethui -> PlayerGui
Rauri.platform.protect(gui)
Rauri.platform.setClipboard("text")
Rauri.platform.notify("Rauri", "Loaded")
```

`Rauri.web.app` already uses `guiParent()` and `protect()`, so the same app runs in Studio and in script executors. Sprite icons are plain Roblox assets, so they need no executor APIs; `game:HttpGet` is only used when an external `<script src>` is present.

## Core: commands, events, capabilities

```lua
core:handle("player.stats", function(payload, ctx)
	return { name = ctx.player.Name, at = os.clock() }
end)

local ok, result = core:invoke("player.stats")   -- (true, table) or (false, message)
core:emit("tick", { fps = 60 })                  -- core -> windows
core:listen("tick", function(payload) ... end)
```

Commands are synchronous: a handler may not yield. Long work belongs in `task.spawn` and reports back with `core:emit`.

Capabilities are checked before dispatch:

```lua
capabilities = {
	default = { "app.*", "icons.*" },       -- every window
	windows = { settings = { "settings.*" } }, -- extra grants for one window
	deny = { "admin.*" },                   -- always wins
}
```

With no `capabilities` table the app is in local-development mode and everything is allowed. A denied or unknown command returns `(false, "...")`; it never throws and never reaches the handler.

`core:mount(render, { name = "main" })` mounts a window into `PlayerGui` (or `container = someFrame`). The returned handle exposes `:flush()`, `:invalidate()`, `:rerender(fn)` and `:unmount()`.

## Icons

Rauri's icon layer is an adapter for [Molto](https://molto.pages.dev), the Roblox icon registry (64,517 glyphs across seven providers):

```lua
Rauri.icons.setProvider("lucide")
local asset = Rauri.icons.get("moon")
-- { Image = "rbxassetid://...", RectSize = Vector2, RectOffset = Vector2, ... }

ui.icon("moon", { size = 18, color = "$accent" })
```

Molto's publishers upload each provider as sprite sheets, and the glyphs are white on transparent — so `ImageColor3` tints them like text. That means icons render in Studio and in live games, not only under an executor.

Two sources:

- **Bundled samples**: `src/shared/Rauri/iconsData.lua` carries 132 Lucide icons (the semantic set the framework and demo use) and 36 real names from each other provider, with their sheet ids and pixel rects. Enough to build and preview with no executor.
- **Full registry**: when `loadstring` and `game:HttpGet` exist (an executor), Rauri loads `https://molto.pages.dev/source.lua` once and serves all 64,517 icons, including Molto's font mode.

`Rauri.icons.search(query, limit)`, `.list()`, `.providers()`, `.info()`, `.apply(label, name)` and `.preload(names)` are available; `ui.icon` uses whichever source is active.

Icon sets carry their upstream licenses (Lucide ISC, Tabler MIT, Heroicons MIT, Phosphor MIT, Fluent MIT, Solar CC BY 4.0, Material Symbols Apache 2.0); `iconsData.lua` keeps them per provider.

## Theme

```lua
Rauri.theme.setToken("accent", "#22b3a6")
Rauri.theme.tokens()   -- reading tokens makes a render reactive to them
Rauri.theme.reset()
```

Tokens are used by style strings (`"$accent"`) and are resolved when a style is applied, so a token change repaints existing instances.

## Bundling

The bundler rewrites Roblox-style `require`s into a small module registry, which is how the tests run the real source headless:

```bash
node scripts/bundle.mjs --entry src/shared/Rauri/init.lua \
  --out dist/rauri.lua --alias ReplicatedStorage=src/shared
```

The output is one Luau file whose return value is the `Rauri` table, ready for an executor:

```lua
local Rauri = loadstring(game:HttpGet("<url to dist/rauri.lua>"))()
Rauri.web.app({ title = "Hub", html = "<h1>Hello</h1>" })
```

## Tests

```bash
node scripts/bundle.mjs --entry tests/spec.luau --prepend tests/mock.luau \
  --alias ReplicatedStorage=src/shared --out dist/spec.luau && luau dist/spec.luau

node scripts/bundle.mjs --entry tests/demo.luau --prepend tests/mock.luau \
  --alias ReplicatedStorage=src/shared --alias Client=src/client --out dist/demo.luau && luau dist/demo.luau

node scripts/bundle.mjs --entry tests/web.luau --prepend tests/mock.luau \
  --alias ReplicatedStorage=src/shared --out dist/webtest.luau && luau dist/webtest.luau

node scripts/bundle.mjs --entry tests/example.luau --prepend tests/mock.luau \
  --alias ReplicatedStorage=src/shared --alias Examples=examples \
  --out dist/example.luau && luau dist/example.luau
```

`tests/mock.luau` implements the slice of the Roblox API Rauri touches (instances, signals, enums, UDim2, Color3, services, task). The demo test boots Rauri Studio, navigates every page, switches icon providers, searches, triggers a capability denial and exercises minimize/close/reopen. The web test covers the parser, cascade, layout, JS events, theme variables and ScreenGui mounting; the example test drives the executor hub end to end.

## Demo

**Rauri Studio** is the reference app: custom window chrome with drag/minimize/close, sidebar navigation, a live Molto icon gallery with provider switch and search, an events page with core-emitted stats and invoke round-trips, and a settings page for theme tokens, window scale and the capability manifest.

## Limits

- Commands are synchronous by design.
- There is no virtual list: the gallery renders a capped page of results.
- Roblox cannot fetch external images, so icons depend on Molto's uploaded sheet ids (or the executor path for fonts).
- The web layer is a UI engine with a CSS/JS subset, not a browser: see [docs/WEB.md](docs/WEB.md) for exactly what is supported.
- Executor support is defensive: APIs differ by vendor, and anything unavailable falls back to Studio behavior (PlayerGui, no protection).
