--!nolint
-- Rauri :: reconciler
-- Resolves a virtual tree (components included) into concrete elements and
-- patches Roblox instances in place. Children are keyed and diffed, so a
-- signal update only rewrites the props that actually changed.

local Props = require(script.Parent.props)
local Style = require(script.Parent.style)
local Theme = require(script.Parent.theme)

local Reconciler = {}

local CLASS = {
	frame = "Frame",
	text = "TextLabel",
	button = "TextButton",
	image = "ImageLabel",
	icon = "ImageLabel",
	scroll = "ScrollingFrame",
	input = "TextBox",
}

local function newMeta()
	return {
		children = {},
		childMetas = {},
		nodes = {},
		handlers = {},
		connections = {},
		style = nil,
		pseudo = nil,
		styleBound = false,
	}
end

local function pushNode(node, out)
	local nodeType = type(node)
	if node == nil or node == false then
		return
	end
	if nodeType == "string" or nodeType == "number" then
		out[#out + 1] = {
			__rauri = true,
			kind = "text",
			props = { text = tostring(node) },
			children = {},
		}
		return
	end
	if nodeType ~= "table" then
		return
	end
	if node.__rauri then
		if typeof(node.kind) == "function" then
			pushNode(node.kind(node.props, node.children), out)
			return
		end
		local children = {}
		for _, child in node.children do
			pushNode(child, children)
		end
		out[#out + 1] = {
			__rauri = true,
			kind = node.kind,
			props = node.props,
			children = children,
			key = node.key or node.props.key,
		}
		return
	end
	for _, child in node do
		pushNode(child, out)
	end
end

local function createInstance(node, padX, padY)
	local className = CLASS[node.kind] or node.kind
	local ok, instance = pcall(Instance.new, className)
	if not ok or not instance then
		error(string.format('[Rauri] unknown element "%s"', tostring(node.kind)), 0)
	end

	if instance:IsA("GuiObject") then
		instance.BorderSizePixel = 0
	end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		instance.BackgroundTransparency = 1
	end
	if instance:IsA("TextButton") then
		instance.AutoButtonColor = false
		instance.Text = ""
	end
	if instance:IsA("TextBox") then
		instance.ClearTextOnFocus = false
		instance.MultiLine = false
		instance.TextXAlignment = Enum.TextXAlignment.Left
	end
	if node.kind == "scroll" then
		instance.BackgroundTransparency = 1
		instance.BorderSizePixel = 0
		instance.ScrollBarThickness = 4
		instance.ScrollBarImageColor3 = Theme.color("border")
		instance.ScrollingDirection = Enum.ScrollingDirection.Y
		instance.CanvasSize = UDim2.new(0, 0, 0, 0)
		instance.AutomaticCanvasSize = Enum.AutomaticSize.Y
		instance.ClipsDescendants = true
	end
	if node.kind == "icon" then
		instance.BackgroundTransparency = 1
		instance.ScaleType = Enum.ScaleType.Stretch
	end

	local meta = newMeta()
	Props.apply(instance, meta, node.props, node.kind, padX or 0, padY or 0)
	return instance, meta
end

local function nodeKey(node, index)
	return node.key or string.format("%s#%d", tostring(node.kind), index)
end

local diffChildren

local function patchInstance(instance, meta, prevNode, node, padX, padY)
	Props.apply(instance, meta, node.props, node.kind, padX, padY)
	diffChildren(instance, meta, node.children)
end

diffChildren = function(parent, meta, nextNodes)
	local prevNodes = meta.nodes
	local prevInstances = meta.children
	local prevMetas = meta.childMetas

	local existing = {}
	for index, node in prevNodes do
		existing[nodeKey(node, index)] = {
			node = node,
			instance = prevInstances[index],
			meta = prevMetas[index],
			used = false,
		}
	end

	local instances = {}
	local metas = {}
	local padX, padY = Style.paddingSides(meta.style)

	for index, node in nextNodes do
		local record = existing[nodeKey(node, index)]
		local instance, childMeta

		if record and record.node.kind == node.kind and record.instance then
			instance, childMeta = record.instance, record.meta
			record.used = true
			patchInstance(instance, childMeta, record.node, node, padX, padY)
		else
			instance, childMeta = createInstance(node, padX, padY)
			instance.Parent = parent
			diffChildren(instance, childMeta, node.children)
		end

		instances[index] = instance
		metas[index] = childMeta
	end

	for _, record in existing do
		if not record.used and record.instance then
			record.instance:Destroy()
		end
	end

	for index, instance in instances do
		local explicit = nextNodes[index].props.layoutOrder
		if explicit == nil and instance:IsA("GuiObject") then
			instance.LayoutOrder = index
		end
	end

	meta.nodes = nextNodes
	meta.children = instances
	meta.childMetas = metas
end

function Reconciler.mount(container, render)
	local meta = newMeta()

	local function draw()
		local nodes = {}
		pushNode(render(), nodes)
		diffChildren(container, meta, nodes)
	end

	draw()

	return {
		draw = draw,
		unmount = function()
			for _, instance in meta.children do
				instance:Destroy()
			end
			meta.nodes = {}
			meta.children = {}
			meta.childMetas = {}
		end,
	}
end

Reconciler.CLASS = CLASS

return Reconciler
