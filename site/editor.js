(() => {
  "use strict";

  const WIDTH = 720;
  const HEIGHT = 420;
  const SNAP = 10;
  const MIN_SIZE = 20;

  const TYPES = {
    frame: { width: 220, height: 120, background: "#15151b", radius: 10 },
    text: { width: 200, height: 28, text: "Text", color: "#f1f1f4", size: 16 },
    button: { width: 120, height: 36, text: "Button", background: "#ececf3", color: "#101014", radius: 8, size: 13 },
    input: { width: 220, height: 36, text: "Text field", background: "#121218", color: "#ececf3", radius: 8, size: 13 },
    image: { width: 180, height: 110, text: "Image", background: "#1b1b22", radius: 10, size: 11 },
  };

  const initialElements = [
    { id: 1, type: "frame", x: 36, y: 36, w: 300, h: 180, background: "#15151b", radius: 12 },
    { id: 2, type: "text", x: 60, y: 60, w: 190, h: 26, text: "Session", color: "#f1f1f4", size: 18 },
    { id: 3, type: "text", x: 60, y: 92, w: 250, h: 20, text: "Ready", color: "#8f8f9c", size: 12 },
    { id: 4, type: "button", x: 60, y: 150, w: 120, h: 36, text: "Continue", background: "#ececf3", color: "#101014", radius: 8, size: 13 },
    { id: 5, type: "input", x: 368, y: 60, w: 300, h: 36, text: "Search", background: "#121218", color: "#ececf3", radius: 8, size: 13 },
    { id: 6, type: "image", x: 368, y: 116, w: 300, h: 100, text: "Preview", background: "#1b1b22", radius: 10, size: 11 },
  ];

  const state = {
    elements: initialElements.map((element) => ({ ...element })),
    nextId: 7,
    selected: null,
    title: "Untitled window",
    animateId: null,
  };

  const history = [];
  const future = [];

  const elementsLayer = document.getElementById("elements");
  const artboard = document.getElementById("artboard");
  const layersList = document.getElementById("layers");
  const layerCount = document.getElementById("layer-count");
  const fields = document.getElementById("inspector-fields");
  const emptyState = document.getElementById("inspector-empty");
  const deleteButton = document.getElementById("delete");
  const undoButton = document.getElementById("undo");
  const redoButton = document.getElementById("redo");
  const clearButton = document.getElementById("clear");
  const exportButton = document.getElementById("export");
  const titleInput = document.getElementById("project-title");
  const dialog = document.getElementById("export-dialog");
  const exportCode = document.getElementById("export-code");
  const exportNote = document.getElementById("export-note");
  const closeExport = document.getElementById("close-export");
  const copyExport = document.getElementById("copy-export");
  const downloadExport = document.getElementById("download-export");
  const toastNode = document.getElementById("toast");

  let exportTab = "html";
  let fieldBefore = null;
  let titleBefore = null;
  let toastTimer = null;

  const clamp = (value, min, max) => Math.min(Math.max(value, min), max);
  const snap = (value) => Math.round(value / SNAP) * SNAP;
  const selectedElement = () => state.elements.find((element) => element.id === state.selected) || null;

  function snapshot() {
    return JSON.stringify({ elements: state.elements, nextId: state.nextId, title: state.title });
  }

  function restore(json) {
    const data = JSON.parse(json);
    state.elements = data.elements;
    state.nextId = data.nextId;
    state.title = data.title;
    state.selected = null;
    titleInput.value = state.title;
    render();
  }

  function record(before) {
    if (!before || before === snapshot()) {
      return;
    }
    history.push(before);
    if (history.length > 60) {
      history.shift();
    }
    future.length = 0;
    updateToolbar();
  }

  function updateToolbar() {
    undoButton.disabled = history.length === 0;
    redoButton.disabled = future.length === 0;
    deleteButton.disabled = state.selected === null;
  }

  function labelFor(element) {
    if (element.text) {
      return element.text;
    }
    return TYPES[element.type].label || element.type;
  }

  TYPES.frame.label = "Frame";
  TYPES.text.label = "Text";
  TYPES.button.label = "Button";
  TYPES.input.label = "Input";
  TYPES.image.label = "Image";

  function contentFor(element) {
    if (element.type === "frame") {
      return "";
    }
    if (element.text) {
      return element.text;
    }
    return TYPES[element.type].text || element.type;
  }

  function applyNodeStyle(node, element) {
    node.style.left = `${(element.x / WIDTH) * 100}%`;
    node.style.top = `${(element.y / HEIGHT) * 100}%`;
    node.style.width = `${(element.w / WIDTH) * 100}%`;
    node.style.height = `${(element.h / HEIGHT) * 100}%`;
    node.style.background = element.background || "transparent";
    if (element.color) {
      node.style.color = element.color;
    } else {
      node.style.removeProperty("color");
    }
    node.style.borderRadius = `${element.radius || 0}px`;
    node.style.fontSize = `${element.size || 13}px`;
  }

  function makeResizeHandle() {
    const handle = document.createElement("span");
    handle.className = "resize";
    handle.dataset.resize = "true";
    return handle;
  }

  function renderNode(element) {
    const node = document.createElement("div");
    node.className = `node ${element.type}`;
    node.dataset.id = String(element.id);
    applyNodeStyle(node, element);

    const content = document.createElement("span");
    content.className = "node-content";
    content.textContent = contentFor(element);
    node.append(content);

    if (state.animateId === element.id) {
      node.classList.add("node-enter");
    }

    if (state.selected === element.id) {
      node.classList.add("selected");
      node.append(makeResizeHandle());
    }

    return node;
  }

  function render() {
    elementsLayer.replaceChildren();
    for (const element of state.elements) {
      elementsLayer.append(renderNode(element));
    }
    renderLayers();
    renderInspector();
    updateToolbar();
  }

  function syncNode(element) {
    const node = elementsLayer.querySelector(`[data-id="${element.id}"]`);
    if (!node) {
      return;
    }
    applyNodeStyle(node, element);
    const content = node.querySelector(".node-content");
    if (content) {
      content.textContent = contentFor(element);
    }
  }

  function renderLayers() {
    layersList.replaceChildren();
    layerCount.textContent = String(state.elements.length);

    for (const element of state.elements) {
      const item = document.createElement("li");
      item.dataset.id = String(element.id);
      if (element.id === state.selected) {
        item.classList.add("selected");
      }

      const type = document.createElement("span");
      type.className = "layer-type";
      type.textContent = element.type;

      const name = document.createElement("span");
      name.className = "layer-name";
      name.textContent = labelFor(element);

      item.append(type, name);
      layersList.append(item);
    }
  }

  function setSelected(id) {
    state.selected = id;
    render();
  }

  function startPointerEdit(event, element, mode) {
    event.preventDefault();
    event.stopPropagation();

    if (state.selected !== element.id) {
      state.selected = element.id;
      render();
      element = state.elements.find((item) => item.id === state.selected);
    }

    const before = snapshot();
    const bounds = artboard.getBoundingClientRect();
    const scaleX = WIDTH / bounds.width;
    const scaleY = HEIGHT / bounds.height;
    const startX = event.clientX;
    const startY = event.clientY;
    const origin = { x: element.x, y: element.y, w: element.w, h: element.h };

    const onMove = (moveEvent) => {
      const dx = (moveEvent.clientX - startX) * scaleX;
      const dy = (moveEvent.clientY - startY) * scaleY;

      if (mode === "move") {
        element.x = clamp(snap(origin.x + dx), 0, WIDTH - element.w);
        element.y = clamp(snap(origin.y + dy), 0, HEIGHT - element.h);
      } else {
        element.w = clamp(snap(origin.w + dx), MIN_SIZE, WIDTH - element.x);
        element.h = clamp(snap(origin.h + dy), MIN_SIZE, HEIGHT - element.y);
      }

      syncNode(element);
      syncNumberFields(element);
    };

    const finish = () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", finish);
      window.removeEventListener("pointercancel", finish);
      record(before);
      render();
    };

    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", finish);
    window.addEventListener("pointercancel", finish);
  }

  elementsLayer.addEventListener("pointerdown", (event) => {
    const node = event.target.closest(".node");
    if (!node) {
      return;
    }
    const element = state.elements.find((item) => item.id === Number(node.dataset.id));
    if (!element) {
      return;
    }
    const resizing = event.target.dataset.resize === "true";
    startPointerEdit(event, element, resizing ? "resize" : "move");
  });

  artboard.addEventListener("pointerdown", (event) => {
    if (event.target === artboard || event.target === elementsLayer) {
      state.selected = null;
      render();
    }
  });

  layersList.addEventListener("click", (event) => {
    const item = event.target.closest("li");
    if (item) {
      setSelected(Number(item.dataset.id));
    }
  });

  function addElement(type) {
    const spec = TYPES[type];
    if (!spec) {
      return;
    }
    const before = snapshot();
    const offset = (state.elements.length % 6) * 16;
    const width = spec.width;
    const height = spec.height;
    const element = {
      id: state.nextId,
      type,
      x: clamp(48 + offset, 0, WIDTH - width),
      y: clamp(48 + offset, 0, HEIGHT - height),
      w: width,
      h: height,
      text: spec.text || "",
      background: spec.background || "",
      color: spec.color || "",
      radius: spec.radius || 0,
      size: spec.size || 13,
    };
    state.nextId += 1;
    state.elements.push(element);
    state.selected = element.id;
    state.animateId = element.id;
    record(before);
    render();
    state.animateId = null;
  }

  document.querySelectorAll("[data-add]").forEach((button) => {
    button.addEventListener("click", () => addElement(button.dataset.add));
  });

  function deleteSelected() {
    if (state.selected === null) {
      return;
    }
    const before = snapshot();
    state.elements = state.elements.filter((element) => element.id !== state.selected);
    state.selected = null;
    record(before);
    render();
  }

  function undo() {
    if (history.length === 0) {
      return;
    }
    future.push(snapshot());
    restore(history.pop());
  }

  function redo() {
    if (future.length === 0) {
      return;
    }
    history.push(snapshot());
    restore(future.pop());
  }

  deleteButton.addEventListener("click", deleteSelected);
  undoButton.addEventListener("click", undo);
  redoButton.addEventListener("click", redo);

  clearButton.addEventListener("click", () => {
    if (state.elements.length === 0) {
      return;
    }
    const before = snapshot();
    state.elements = [];
    state.selected = null;
    record(before);
    render();
    toast("Canvas cleared");
  });

  titleInput.addEventListener("focus", () => {
    titleBefore = snapshot();
  });

  titleInput.addEventListener("input", () => {
    state.title = titleInput.value;
  });

  titleInput.addEventListener("change", () => {
    if (titleBefore) {
      record(titleBefore);
      titleBefore = null;
    }
  });

  function createField(label, property, value, options = {}) {
    const wrapper = document.createElement("label");
    wrapper.className = `field${options.full ? " full" : ""}`;

    const caption = document.createElement("span");
    caption.textContent = label;

    const input = document.createElement("input");
    input.dataset.property = property;
    input.type = options.type || "text";

    if (input.type === "number") {
      input.min = String(options.min ?? 0);
      input.max = String(options.max ?? 9999);
      input.step = String(options.step || 1);
    }
    if (input.type === "color") {
      input.value = normalizeColor(value, "#101014");
    } else {
      input.value = value ?? "";
    }
    if (options.placeholder) {
      input.placeholder = options.placeholder;
    }

    input.addEventListener("focus", () => {
      fieldBefore = snapshot();
    });

    input.addEventListener("input", () => {
      const element = selectedElement();
      if (!element) {
        return;
      }
      applyFieldValue(element, property, input.value);
      syncNode(element);
      renderLayers();
      syncNumberFields(element);
    });

    input.addEventListener("change", () => {
      if (fieldBefore) {
        record(fieldBefore);
        fieldBefore = null;
      }
    });

    wrapper.append(caption, input);
    return wrapper;
  }

  function applyFieldValue(element, property, rawValue) {
    if (property === "x" || property === "y" || property === "w" || property === "h") {
      const value = Math.round(Number(rawValue));
      if (!Number.isFinite(value)) {
        return;
      }
      if (property === "x") {
        element.x = clamp(value, 0, WIDTH - element.w);
      } else if (property === "y") {
        element.y = clamp(value, 0, HEIGHT - element.h);
      } else if (property === "w") {
        element.w = clamp(value, MIN_SIZE, WIDTH - element.x);
      } else {
        element.h = clamp(value, MIN_SIZE, HEIGHT - element.y);
      }
      return;
    }

    if (property === "radius" || property === "size") {
      const value = Math.round(Number(rawValue));
      if (!Number.isFinite(value)) {
        return;
      }
      element[property] = property === "size" ? clamp(value, 8, 48) : clamp(value, 0, 999);
      return;
    }

    if (property === "background" || property === "color") {
      element[property] = normalizeColor(rawValue, element[property]);
      return;
    }

    element[property] = rawValue;
  }

  function syncNumberFields(element) {
    for (const property of ["x", "y", "w", "h"]) {
      const input = fields.querySelector(`[data-property="${property}"]`);
      if (input && document.activeElement !== input) {
        input.value = String(element[property]);
      }
    }
  }

  function group(title, children) {
    const section = document.createElement("section");
    section.className = "group";
    const heading = document.createElement("h4");
    heading.className = "group-title";
    heading.textContent = title;
    const grid = document.createElement("div");
    grid.className = "field-grid";
    grid.append(...children);
    section.append(heading, grid);
    return section;
  }

  function renderInspector() {
    const element = selectedElement();
    emptyState.classList.toggle("hidden", element !== null);
    fields.classList.toggle("hidden", element === null);
    deleteButton.disabled = element === null;
    fields.replaceChildren();

    if (!element) {
      return;
    }

    fields.append(
      group("Layout", [
        createField("X", "x", element.x, { type: "number", min: 0, max: WIDTH }),
        createField("Y", "y", element.y, { type: "number", min: 0, max: HEIGHT }),
        createField("Width", "w", element.w, { type: "number", min: MIN_SIZE, max: WIDTH }),
        createField("Height", "h", element.h, { type: "number", min: MIN_SIZE, max: HEIGHT }),
      ])
    );

    const contentFields = [];
    if (element.type !== "frame") {
      const label = element.type === "input" ? "Placeholder" : "Text";
      contentFields.push(createField(label, "text", element.text || "", { full: true }));
    }
    if (element.type === "image") {
      contentFields.push(createField("Source", "src", element.src || "", { full: true, placeholder: "rbxassetid://0" }));
    }
    if (contentFields.length > 0) {
      fields.append(group("Content", contentFields));
    }

    const appearance = [];
    if (element.type !== "text") {
      appearance.push(createField("Background", "background", element.background, { type: "color" }));
    }
    if (element.type === "text" || element.type === "button" || element.type === "input") {
      appearance.push(createField("Text color", "color", element.color, { type: "color" }));
    }
    if (element.type !== "text") {
      appearance.push(createField("Radius", "radius", element.radius || 0, { type: "number", min: 0, max: 999 }));
    }
    if (element.type !== "frame") {
      appearance.push(createField("Font size", "size", element.size || 13, { type: "number", min: 8, max: 48 }));
    }
    fields.append(group("Appearance", appearance));
  }

  function normalizeColor(value, fallback) {
    if (typeof value !== "string") {
      return fallback;
    }
    const trimmed = value.trim();
    if (/^#[0-9a-f]{6}$/i.test(trimmed)) {
      return trimmed.toLowerCase();
    }
    if (/^#[0-9a-f]{3}$/i.test(trimmed)) {
      return `#${trimmed[1]}${trimmed[1]}${trimmed[2]}${trimmed[2]}${trimmed[3]}${trimmed[3]}`.toLowerCase();
    }
    return fallback;
  }

  function toast(message) {
    toastNode.textContent = message;
    toastNode.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastNode.classList.remove("show"), 1800);
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;");
  }

  function escapeAttribute(value) {
    return escapeHtml(value).replaceAll('"', "&quot;");
  }

  function luaLongString(value) {
    let level = 0;
    while (value.includes(`]${"=".repeat(level)}]`)) {
      level += 1;
    }
    const separator = "=".repeat(level);
    return `[${separator}[${value}]${separator}]`;
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text).then(
        () => true,
        () => fallbackCopy(text)
      );
    }
    return Promise.resolve(fallbackCopy(text));
  }

  function fallbackCopy(text) {
    const area = document.createElement("textarea");
    area.value = text;
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.append(area);
    area.select();
    let copied = false;
    try {
      copied = document.execCommand("copy");
    } catch {
      copied = false;
    }
    area.remove();
    return copied;
  }

  function elementHtml(element) {
    const className = `el-${element.id}`;
    const content = escapeHtml(element.text || "");
    if (element.type === "text") {
      return `  <p class="${className}">${content}</p>`;
    }
    if (element.type === "button") {
      return `  <button class="${className}" type="button">${content}</button>`;
    }
    if (element.type === "input") {
      return `  <input class="${className}" type="text" placeholder="${escapeAttribute(element.text || "")}">`;
    }
    if (element.type === "image" && element.src) {
      return `  <img class="${className}" src="${escapeAttribute(element.src)}" alt="">`;
    }
    if (element.type === "image") {
      return `  <div class="${className}">${content}</div>`;
    }
    return `  <div class="${className}"></div>`;
  }

  function elementCss(element) {
    const rules = [
      `  position: absolute;`,
      `  left: ${element.x}px;`,
      `  top: ${element.y}px;`,
      `  width: ${element.w}px;`,
      `  height: ${element.h}px;`,
    ];
    const className = `.el-${element.id}`;

    if (element.type === "text") {
      rules.push(`  margin: 0;`, `  color: ${element.color};`, `  font-size: ${element.size}px;`, `  line-height: 1.25;`, `  white-space: pre-wrap;`);
    } else if (element.type === "button") {
      rules.push(
        `  display: flex;`,
        `  align-items: center;`,
        `  justify-content: center;`,
        `  border: 0;`,
        `  padding: 0;`,
        `  background: ${element.background};`,
        `  color: ${element.color};`,
        `  border-radius: ${element.radius}px;`,
        `  font-family: sans-serif;`,
        `  font-size: ${element.size}px;`
      );
    } else if (element.type === "input") {
      rules.push(
        `  background: ${element.background};`,
        `  color: ${element.color};`,
        `  border: 1px solid #2c2c3a;`,
        `  border-radius: ${element.radius}px;`,
        `  padding: 0 10px;`,
        `  font: inherit;`,
        `  font-size: ${element.size}px;`
      );
    } else if (element.type === "image") {
      rules.push(`  background: ${element.background};`, `  border-radius: ${element.radius}px;`, `  object-fit: cover;`);
      if (!element.src) {
        rules.push(
          `  display: flex;`,
          `  align-items: center;`,
          `  justify-content: center;`,
          `  color: #777782;`,
          `  font-size: ${element.size}px;`,
          `  letter-spacing: 0.08em;`,
          `  text-transform: uppercase;`
        );
      }
    } else {
      rules.push(`  background: ${element.background};`, `  border-radius: ${element.radius}px;`);
    }

    return `${className} {\n${rules.join("\n")}\n}`;
  }

  function buildExport() {
    const html = ['<div class="rauri-canvas">', ...state.elements.map(elementHtml), "</div>"].join("\n");
    const css = [
      ".rauri-canvas {",
      "  position: relative;",
      `  width: ${WIDTH}px;`,
      `  height: ${HEIGHT}px;`,
      "  overflow: hidden;",
      "  background: #0b0b0f;",
      "  font-family: sans-serif;",
      "}",
      "",
      ".rauri-canvas * {",
      "  box-sizing: border-box;",
      "}",
      "",
      state.elements.map(elementCss).join("\n\n"),
    ].join("\n");
    const lua = [
      "local Rauri = loadstring(game:HttpGet(",
      '  "https://raw.githubusercontent.com/sickletone/project-rauri/main/dist/rauri.lua"',
      "))()",
      "",
      "Rauri.web.app({",
      `  title = ${JSON.stringify(state.title || "Window")},`,
      `  width = ${WIDTH},`,
      `  height = ${HEIGHT},`,
      "  chrome = false,",
      `  html = ${luaLongString(html)},`,
      `  css = ${luaLongString(css)},`,
      "})",
      "",
    ].join("\n");

    return { html, css, lua };
  }

  function renderExport() {
    const output = buildExport();
    exportCode.textContent = output[exportTab];
    exportNote.textContent =
      exportTab === "html"
        ? "HTML for Rauri web."
        : exportTab === "css"
          ? "CSS for Rauri web."
          : "Lua that mounts the HTML and CSS above.";
    document.querySelectorAll("[data-tab]").forEach((tab) => {
      tab.setAttribute("aria-selected", tab.dataset.tab === exportTab ? "true" : "false");
    });
  }

  exportButton.addEventListener("click", () => {
    renderExport();
    if (!dialog.open) {
      dialog.showModal();
    }
  });

  document.querySelectorAll("[data-tab]").forEach((tab) => {
    tab.addEventListener("click", () => {
      exportTab = tab.dataset.tab;
      renderExport();
    });
  });

  closeExport.addEventListener("click", () => dialog.close());

  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) {
      dialog.close();
    }
  });

  copyExport.addEventListener("click", async () => {
    const copied = await copyText(exportCode.textContent);
    toast(copied ? "Copied" : "Copy failed");
  });

  downloadExport.addEventListener("click", () => {
    const output = buildExport();
    const extension = exportTab === "lua" ? "lua" : exportTab;
    const mime = exportTab === "lua" ? "text/plain" : `text/${exportTab}`;
    const slug = (state.title || "rauri-window")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "") || "rauri-window";
    const blob = new Blob([output[exportTab]], { type: `${mime};charset=utf-8` });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = `${slug}.${extension}`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 1000);
  });

  document.querySelectorAll("[data-copy-target]").forEach((button) => {
    button.addEventListener("click", async () => {
      const target = document.getElementById(button.dataset.copyTarget);
      if (!target) {
        return;
      }
      const copied = await copyText(target.textContent);
      toast(copied ? "Copied" : "Copy failed");
    });
  });

  document.addEventListener("keydown", (event) => {
    const tag = document.activeElement ? document.activeElement.tagName : "";
    const typing = tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT";

    if (dialog.open) {
      if (event.key === "Escape") {
        dialog.close();
      }
      return;
    }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "z") {
      if (typing) {
        return;
      }
      event.preventDefault();
      if (event.shiftKey) {
        redo();
      } else {
        undo();
      }
      return;
    }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "y") {
      if (typing) {
        return;
      }
      event.preventDefault();
      redo();
      return;
    }
    if (!typing && (event.key === "Delete" || event.key === "Backspace")) {
      event.preventDefault();
      deleteSelected();
      return;
    }
  });

  titleInput.value = state.title;
  render();
})();
