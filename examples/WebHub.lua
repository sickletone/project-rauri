--!nolint
-- Rauri web example: a small executor hub written in HTML, CSS and JS.
--
-- Build the framework into one file:
--   node scripts/bundle.mjs --entry src/shared/Rauri/init.lua \
--     --out dist/rauri.lua --alias ReplicatedStorage=src/shared
--
-- In a Roblox executor, load the published build and this file:
--   local Rauri = loadstring(game:HttpGet(
--     "https://raw.githubusercontent.com/sickletone/project-rauri/main/dist/rauri.lua"
--   ))()
--   local buildHub = loadstring(game:HttpGet(
--     "https://raw.githubusercontent.com/sickletone/project-rauri/main/examples/WebHub.lua"
--   ))()
--   buildHub(Rauri)
--
-- Or run examples/WebHubLoader.lua once and skip both steps.
--
-- Every part of this is replaceable: drop the default chrome (chrome = false),
-- write your own HTML/CSS, swap the theme, add commands or use the DOM from
-- Luau. See docs/WEB.md.

return function(Rauri, options)
	options = options or {}

	local app = Rauri.web.app({
		parent = options.parent,
		title = options.title or "Nebula Hub",
		width = options.width or 740,
		height = options.height or 500,
		onLog = options.onLog,
		capabilities = { default = { "script.*" } },
		theme = {
			accent = "#7c5cff",
			bg = "#0a0a10",
			surface = "#12121c",
			["surface-alt"] = "#1c1c2a",
			border = "#2b2b3d",
			text = "#f2f2fa",
			muted = "#8f8fa8",
			danger = "#ff5d7a",
			radius = 14,
		},
		html = [==[
<div class="hub">
  <aside class="side">
    <div class="brand"><i data-icon="lucide:layers"></i><span>Nebula</span></div>
    <button class="nav active" data-page="scripts">Scripts</button>
    <button class="nav" data-page="console">Console</button>
    <button class="nav" data-page="settings">Settings</button>
    <div class="foot"><span class="pill" id="status">ready</span></div>
  </aside>
  <main class="main">
    <header class="top">
      <h1 id="heading">Scripts</h1>
      <input id="search" placeholder="Search scripts" />
    </header>
    <section id="page-scripts" class="page">
      <div class="cards" id="cards">
        <article class="card" data-name="auto farm">
          <div class="card-top"><i data-icon="lucide:zap"></i><span class="title">Auto Farm</span><span class="tag">popular</span></div>
          <p>Collects nearby drops and keeps the loop alive.</p>
          <button class="run" data-name="Auto Farm"><i data-icon="lucide:play"></i><span>Run</span></button>
        </article>
        <article class="card" data-name="teleport">
          <div class="card-top"><i data-icon="lucide:activity"></i><span class="title">Teleport</span><span class="tag">fast</span></div>
          <p>Jumps to a saved waypoint without touching the camera.</p>
          <button class="run" data-name="Teleport"><i data-icon="lucide:play"></i><span>Run</span></button>
        </article>
        <article class="card" data-name="esp">
          <div class="card-top"><i data-icon="lucide:shield"></i><span class="title">ESP</span><span class="tag">visual</span></div>
          <p>Highlights players through walls with a tinted overlay.</p>
          <button class="run" data-name="ESP"><i data-icon="lucide:play"></i><span>Run</span></button>
        </article>
      </div>
    </section>
    <section id="page-console" class="page hidden">
      <div class="panel">
        <h2>Console</h2>
        <p id="console-line">Ready.</p>
        <button id="toast">Ping</button>
      </div>
    </section>
    <section id="page-settings" class="page hidden">
      <div class="panel">
        <h2>Theme</h2>
        <p>Accent color</p>
        <div class="swatches">
          <button class="swatch" data-accent="#7c5cff"></button>
          <button class="swatch" data-accent="#22d3a7"></button>
          <button class="swatch" data-accent="#ff5d7a"></button>
          <button class="swatch" data-accent="#f4b740"></button>
        </div>
      </div>
      <div class="panel">
        <h2>Window</h2>
        <button id="minimize">Minimize</button>
      </div>
    </section>
  </main>
</div>
]==],
		css = [==[
* { box-sizing: border-box; }
body { margin: 0; padding: 0; }
.hub { display: flex; flex-direction: row; height: 100%; background: var(--bg); }
.side {
  width: 176px;
  height: 100%;
  padding: 14px;
  background: var(--surface);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.brand {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 8px;
  color: var(--text);
  font-size: 14px;
  font-weight: 700;
  margin-bottom: 10px;
}
.brand i { color: var(--accent); font-size: 18px; }
.nav {
  height: 32px;
  padding: 0 10px;
  border-radius: 8px;
  background: transparent;
  color: var(--muted);
  font-size: 12px;
  font-weight: 500;
  text-align: left;
}
.nav:hover { background: var(--surface-alt); color: var(--text); }
.nav.active { background: var(--surface-alt); color: var(--text); border: 1px solid var(--border); }
.foot { flex: 1; display: flex; align-items: flex-end; }
.pill {
  padding: 4px 10px;
  border-radius: 999px;
  background: var(--surface-alt);
  border: 1px solid var(--border);
  color: var(--muted);
  font-size: 11px;
}
.main {
  flex: 1;
  height: 100%;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  background: var(--bg);
}
.top { display: flex; flex-direction: row; align-items: center; justify-content: space-between; gap: 12px; }
h1 { margin: 0; font-size: 20px; font-weight: 700; color: var(--text); }
#search { width: 220px; height: 30px; font-size: 12px; }
.page { flex: 1; overflow-y: auto; }
.cards { display: flex; flex-direction: column; gap: 8px; }
.card { padding: 12px; background: var(--surface); border: 1px solid var(--border); border-radius: 12px; }
.card-top { display: flex; flex-direction: row; align-items: center; gap: 8px; }
.card-top i { color: var(--accent); font-size: 16px; }
.title { color: var(--text); font-size: 13px; font-weight: 600; }
.tag {
  padding: 2px 6px;
  border-radius: 999px;
  border: 1px solid var(--accent);
  color: var(--accent);
  font-size: 10px;
}
.card p { margin: 6px 0 10px 0; color: var(--muted); font-size: 12px; }
.run { width: 88px; height: 28px; display: flex; flex-direction: row; align-items: center; gap: 6px; font-size: 12px; }
.run i { color: var(--accent-text); font-size: 12px; }
.panel { padding: 12px; margin-bottom: 8px; background: var(--surface); border: 1px solid var(--border); border-radius: 12px; }
.panel h2 { margin: 0 0 6px 0; color: var(--text); font-size: 13px; }
.panel p { margin: 4px 0 8px 0; color: var(--muted); font-size: 12px; }
.swatches { display: flex; flex-direction: row; gap: 8px; }
.swatch { width: 26px; height: 26px; padding: 0; border-radius: 999px; border: 1px solid var(--border); }
.swatch:hover { border: 1px solid var(--text); }
#toast, #minimize { font-size: 12px; }
.hidden { display: none; }
]==],
		js = [==[
const navs = document.querySelectorAll(".nav");
const pages = { scripts: "page-scripts", console: "page-console", settings: "page-settings" };

for (const nav of navs) {
  nav.addEventListener("click", () => {
    for (const other of navs) { other.classList.remove("active"); }
    nav.classList.add("active");
    for (const key in pages) {
      const page = document.getElementById(pages[key]);
      if (key === nav.dataset.page) { page.classList.remove("hidden"); }
      else { page.classList.add("hidden"); }
    }
    document.getElementById("heading").textContent = nav.textContent.trim();
  });
}

document.getElementById("search").addEventListener("input", (event) => {
  const query = event.target.value.toLowerCase();
  for (const card of document.querySelectorAll(".card")) {
    card.style.display = card.getAttribute("data-name").includes(query) ? "block" : "none";
  }
});

for (const button of document.querySelectorAll(".run")) {
  button.addEventListener("click", () => {
    const result = rauri.command("script.run", { name: button.getAttribute("data-name") });
    document.getElementById("console-line").textContent = result.message;
    rauri.notify(result.message);
  });
}

document.getElementById("toast").addEventListener("click", () => {
  rauri.notify("Hello from JavaScript");
});

for (const swatch of document.querySelectorAll(".swatch")) {
  swatch.addEventListener("click", () => {
    rauri.theme.set("accent", swatch.getAttribute("data-accent"));
    document.getElementById("console-line").textContent = "Accent updated";
  });
}

document.getElementById("minimize").addEventListener("click", () => {
  rauri.minimize();
});

const platform = rauri.platform;
document.getElementById("status").textContent = platform.executor ? "live" : "Studio preview";
]==],
	})

	app.core:handle("script.run", function(payload)
		local name = type(payload) == "table" and payload.name or tostring(payload)
		return { message = "Queued " .. tostring(name) }
	end)

	app.core:handle("script.list", function()
		return { "Auto Farm", "Teleport", "ESP" }
	end)

	return app
end
