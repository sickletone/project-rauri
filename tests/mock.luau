--!nolint
-- Headless Roblox shim for Rauri's tests. Not shipped with the framework.

Mock = { warnings = {}, errors = {} }

local nativeTypeof = typeof

function typeof(value)
	if type(value) == "table" then
		local mockType = rawget(value, "__mockType")
		if mockType then
			return mockType
		end
	end
	return nativeTypeof(value)
end

local function messages(...)
	local parts = {}
	for index = 1, select("#", ...) do
		parts[#parts + 1] = tostring(select(index, ...))
	end
	return table.concat(parts, " ")
end

function warn(...)
	local message = messages(...)
	Mock.warnings[#Mock.warnings + 1] = message
	print("WARN " .. message)
end

local function newSignal()
	local handlers = {}
	local signal = {}

	function signal:Connect(fn)
		local connection
		connection = {
			Connected = true,
			Disconnect = function()
				connection.Connected = false
				for index, handler in handlers do
					if handler == fn then
						table.remove(handlers, index)
						break
					end
				end
			end,
		}
		handlers[#handlers + 1] = fn
		return connection
	end

	function signal:Fire(...)
		for _, fn in table.clone(handlers) do
			local ok, err = pcall(fn, ...)
			if not ok then
				warn("signal handler failed: " .. tostring(err))
			end
		end
	end

	function signal:Wait()
		coroutine.yield()
	end

	return signal
end

-- Vector2 ---------------------------------------------------------------

local Vector2MT = { __mockType = "Vector2" }
Vector2MT.__index = Vector2MT
Vector2MT.__sub = function(a, b)
	return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, __mockType = "Vector2" }, Vector2MT)
end

local function newVector2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0, __mockType = "Vector2" }, Vector2MT)
end

Vector2 = { new = newVector2 }

-- UDim / UDim2 ----------------------------------------------------------

local function newUDim(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0, __mockType = "UDim" }
end

UDim = { new = newUDim }

local function newUDim2(xScale, xOffset, yScale, yOffset)
	return {
		X = newUDim(xScale, xOffset),
		Y = newUDim(yScale, yOffset),
		__mockType = "UDim2",
	}
end

UDim2 = {
	new = newUDim2,
	fromScale = function(xScale, yScale)
		return newUDim2(xScale, 0, yScale, 0)
	end,
	fromOffset = function(xOffset, yOffset)
		return newUDim2(0, xOffset, 0, yOffset)
	end,
}

-- Color3 ----------------------------------------------------------------

local Color3MT = { __mockType = "Color3" }
Color3MT.__index = Color3MT
Color3MT.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3MT.__tostring = function(self)
	return string.format("Color3(%0.3f, %0.3f, %0.3f)", self.R, self.G, self.B)
end

local function newColor3(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0, __mockType = "Color3" }, Color3MT)
end

Color3 = { new = newColor3 }

ColorSequence = {
	new = function(from, to)
		return { __mockType = "ColorSequence", From = from, To = to }
	end,
}

function Color3.fromHex(hex)
	hex = tostring(hex):gsub("#", "")
	if #hex == 3 then
		hex = hex:gsub(".", "%0%0")
	end
	if #hex < 6 then
		return newColor3(0, 0, 0)
	end
	local r = tonumber(hex:sub(1, 2), 16) or 0
	local g = tonumber(hex:sub(3, 4), 16) or 0
	local b = tonumber(hex:sub(5, 6), 16) or 0
	return newColor3(r / 255, g / 255, b / 255)
end

function Color3.fromRGB(r, g, b)
	return newColor3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end

-- Enum ------------------------------------------------------------------

local enumItems = {}
local enumItemMT = {
	__tostring = function(self)
		return "Enum." .. self.Category .. "." .. self.Name
	end,
}
local enumCategoryMT = {
	__index = function(self, name)
		local key = self.Name .. "." .. name
		local item = enumItems[key]
		if not item then
			item = setmetatable({ Category = self.Name, Name = name, Value = 0 }, enumItemMT)
			enumItems[key] = item
		end
		return item
	end,
}

Enum = setmetatable({}, {
	__index = function(_, category)
		return setmetatable({ Name = category }, enumCategoryMT)
	end,
})

-- Instances -------------------------------------------------------------

local EVENTS = {
	MouseButton1Click = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseEnter = true,
	MouseLeave = true,
	InputBegan = true,
	InputChanged = true,
	InputEnded = true,
	FocusLost = true,
	Focused = true,
	Changed = true,
	Event = true,
	Heartbeat = true,
	RenderStepped = true,
	PlayerAdded = true,
	Activated = true,
}

local CLASS_SETS = {
	Frame = { Frame = true, GuiObject = true, GuiBase2d = true },
	TextLabel = { TextLabel = true, GuiObject = true, GuiBase2d = true },
	TextButton = { TextButton = true, GuiObject = true, GuiBase2d = true },
	ImageLabel = { ImageLabel = true, GuiObject = true, GuiBase2d = true },
	ScrollingFrame = { ScrollingFrame = true, Frame = true, GuiObject = true, GuiBase2d = true },
	TextBox = { TextBox = true, TextLabel = true, GuiObject = true, GuiBase2d = true },
	ScreenGui = { ScreenGui = true, LayerCollector = true },
	UIListLayout = { UIListLayout = true, UILayout = true },
	UIGridLayout = { UIGridLayout = true, UILayout = true },
	UIPadding = { UIPadding = true, UIComponent = true },
	UICorner = { UICorner = true, UIComponent = true },
	UIStroke = { UIStroke = true, UIComponent = true },
	UIScale = { UIScale = true, UIComponent = true },
	UIGradient = { UIGradient = true, UIComponent = true },
	BindableEvent = { BindableEvent = true },
}

local METHODS = {}
local INSTANCE_MT = {}

function METHODS:IsA(className)
	local set = CLASS_SETS[self.ClassName]
	if set and set[className] then
		return true
	end
	return self.ClassName == className or className == "Instance"
end

function METHODS:GetChildren()
	return table.clone(rawget(self, "_children"))
end

function METHODS:FindFirstChild(name)
	for _, child in rawget(self, "_children") do
		if child.Name == name then
			return child
		end
	end
	return nil
end

function METHODS:WaitForChild(name)
	local found = self:FindFirstChild(name)
	if not found then
		error(string.format("WaitForChild timed out: %s in %s", tostring(name), tostring(self.Name)))
	end
	return found
end

function METHODS:GetPropertyChangedSignal(property)
	local changed = rawget(self, "_changed")
	local signal = changed[property]
	if not signal then
		signal = newSignal()
		changed[property] = signal
	end
	return signal
end

function METHODS:SetAttribute(name, value)
	rawget(self, "_attributes")[name] = value
end

function METHODS:GetAttribute(name)
	return rawget(self, "_attributes")[name]
end

function METHODS:Destroy()
	local parent = rawget(self, "Parent")
	if parent then
		for index, child in rawget(parent, "_children") do
			if child == self then
				table.remove(rawget(parent, "_children"), index)
				break
			end
		end
	end
	rawset(self, "Parent", nil)
	for _, child in table.clone(rawget(self, "_children")) do
		child:Destroy()
	end
end

INSTANCE_MT.__index = function(self, key)
	local method = METHODS[key]
	if method then
		return method
	end
	if EVENTS[key] then
		local events = rawget(self, "_events")
		local signal = events[key]
		if not signal then
			signal = newSignal()
			events[key] = signal
		end
		return signal
	end
	return nil
end

INSTANCE_MT.__newindex = function(self, key, value)
	if key == "Parent" then
		local previous = rawget(self, "Parent")
		if previous and previous ~= value then
			for index, child in rawget(previous, "_children") do
				if child == self then
					table.remove(rawget(previous, "_children"), index)
					break
				end
			end
		end
		rawset(self, "Parent", value)
		if value then
			table.insert(rawget(value, "_children"), self)
		end
		return
	end
	rawset(self, key, value)
	local changed = rawget(self, "_changed")
	local signal = changed and changed[key]
	if signal then
		signal:Fire(value)
	end
end

local function newInstance(className)
	local self = setmetatable({}, INSTANCE_MT)
	rawset(self, "__mockType", "Instance")
	rawset(self, "ClassName", className)
	rawset(self, "Name", className)
	rawset(self, "Parent", nil)
	rawset(self, "_children", {})
	rawset(self, "_events", {})
	rawset(self, "_changed", {})
	rawset(self, "_attributes", {})
	rawset(self, "Size", newUDim2(0, 0, 0, 0))
	rawset(self, "Position", newUDim2(0, 0, 0, 0))
	rawset(self, "AnchorPoint", newVector2(0, 0))
	rawset(self, "Visible", true)
	rawset(self, "LayoutOrder", 0)
	rawset(self, "ZIndex", 1)
	rawset(self, "Text", "")
	rawset(self, "TextSize", 14)
	rawset(self, "Image", "")
	rawset(self, "ImageRectSize", newVector2(0, 0))
	rawset(self, "ImageRectOffset", newVector2(0, 0))
	rawset(self, "BackgroundTransparency", 0)
	rawset(self, "BackgroundColor3", newColor3(0, 0, 0))
	rawset(self, "BorderSizePixel", 1)
	rawset(self, "AutomaticSize", "None")
	rawset(self, "Scale", 1)
	rawset(self, "CornerRadius", newUDim(0, 0))
	rawset(self, "AbsolutePosition", newVector2(0, 0))
	rawset(self, "AbsoluteSize", newVector2(100, 100))
	return self
end

Instance = { new = newInstance }

local player = newInstance("Player")
player.Name = "Tester"
player.DisplayName = "Tester"
player.UserId = 1
player.PlayerGui = newInstance("PlayerGui")
player.PlayerGui.Name = "PlayerGui"
player.PlayerGui.Parent = player

local playersService = newInstance("Players")
playersService.Name = "Players"
playersService.LocalPlayer = player
playersService.GetPlayers = function()
	return { player }
end

local runService = newInstance("RunService")
runService.Name = "RunService"
runService.Heartbeat = newSignal()
runService.RenderStepped = newSignal()

local userInputService = newInstance("UserInputService")
userInputService.Name = "UserInputService"
userInputService.GetMouseLocation = function()
	return newVector2(0, 0)
end
userInputService.InputChanged = newSignal()
userInputService.InputEnded = newSignal()

local statsService = newInstance("Stats")
statsService.Name = "Stats"
statsService.Network = {
	ServerStatsItem = {
		["Data Ping"] = {
			GetValue = function()
				return 31
			end,
		},
	},
}
statsService.GetTotalMemoryUsageMb = function()
	return 512
end

local textService = newInstance("TextService")
textService.Name = "TextService"
function textService:GetTextSize(text, size, _font, bounds)
	local content = tostring(text or "")
	local charWidth = (size or 14) * 0.56
	local maxWidth = math.max(bounds and bounds.X or 1, 1)
	local width = math.min(#content * charWidth, maxWidth)
	local lines = math.max(1, math.ceil(#content * charWidth / maxWidth))
	return newVector2(width, lines * (size or 14) * 1.3)
end

local replicatedStorage = newInstance("ReplicatedStorage")
replicatedStorage.Name = "ReplicatedStorage"

local services = {
	Players = playersService,
	RunService = runService,
	UserInputService = userInputService,
	Stats = statsService,
	TextService = textService,
	ReplicatedStorage = replicatedStorage,
}

game = {
	GetService = function(_, name)
		local service = services[name]
		if not service then
			service = newInstance(name)
			services[name] = service
		end
		return service
	end,
}

-- task ------------------------------------------------------------------

local deferred = {}
local delayed = {}

task = {}

function task.spawn(fn, ...)
	local thread
	if type(fn) == "thread" then
		thread = fn
		local ok, err = coroutine.resume(thread, ...)
		if not ok then
			warn("task.spawn failed: " .. tostring(err))
		end
		return thread
	end
	thread = coroutine.create(fn)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		warn("task.spawn failed: " .. tostring(err))
	end
	return thread
end

function task.defer(fn, ...)
	deferred[#deferred + 1] = { fn = fn, args = table.pack(...) }
end

function task.delay(seconds, fn, ...)
	delayed[#delayed + 1] = {
		at = os.clock() + (seconds or 0),
		fn = fn,
		args = table.pack(...),
	}
end

function task.wait(seconds)
	coroutine.yield(seconds or 0)
	return seconds or 0
end

function task.cancel()
end

function Mock.drain(limit)
	for _ = 1, limit or 8 do
		local queue = deferred
		deferred = {}
		if #queue == 0 then
			return
		end
		for _, item in queue do
			local ok, err = pcall(item.fn, table.unpack(item.args, 1, item.args.n))
			if not ok then
				warn("deferred failed: " .. tostring(err))
			end
		end
	end
end

function Mock.advance(seconds)
	local now = os.clock() + (seconds or 0)
	local keep = {}
	for _, item in delayed do
		if item.at <= now then
			local ok, err = pcall(item.fn, table.unpack(item.args, 1, item.args.n))
			if not ok then
				warn("delay failed: " .. tostring(err))
			end
		else
			keep[#keep + 1] = item
		end
	end
	delayed = keep
end

function Mock.resetWarnings()
	Mock.warnings = {}
end
