--!nolint
-- Rauri :: util
-- Small helpers shared by the runtime. No Roblox services are required.

local Util = {}

function Util.color(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		local hex = value:gsub("^#", "")
		if #hex == 3 then
			hex = hex:gsub(".", "%0%0")
		end
		if #hex == 6 or #hex == 8 then
			local ok, color = pcall(Color3.fromHex, "#" .. hex:sub(1, 6))
			if ok then
				return color
			end
		end
	end
	return fallback or Color3.new(1, 1, 1)
end

-- Accepts a UDim, a number (offset), a { scale, offset } pair, or "fill".
function Util.scaleOffset(value)
	if typeof(value) == "UDim" then
		return value
	end
	if type(value) == "number" then
		return UDim.new(0, value)
	end
	if value == "fill" then
		return UDim.new(1, 0)
	end
	if type(value) == "table" then
		return UDim.new(value[1] or value.scale or 0, value[2] or value.offset or 0)
	end
	return UDim.new(0, 0)
end

-- Accepts a UDim2, a { xScale, xOffset, yScale, yOffset } table, or keywords:
-- "fill", "fillx", "filly".
function Util.size(value)
	if typeof(value) == "UDim2" then
		return value
	end
	if value == "fill" then
		return UDim2.fromScale(1, 1)
	elseif value == "fillx" then
		return UDim2.new(1, 0, 0, 0)
	elseif value == "filly" then
		return UDim2.new(0, 0, 1, 0)
	end
	if type(value) == "table" then
		if value.X ~= nil and value.Y ~= nil then
			return UDim2.new(value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
		end
		return UDim2.new(value[1] or 0, value[2] or 0, value[3] or 0, value[4] or 0)
	end
	return UDim2.new(0, 0, 0, 0)
end

function Util.merge(base, patch)
	local out = {}
	for key, value in base or {} do
		out[key] = value
	end
	for key, value in patch or {} do
		out[key] = value
	end
	return out
end

function Util.shallowEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if b[key] ~= value then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function Util.clamp(value, min, max)
	if value < min then
		return min
	elseif value > max then
		return max
	end
	return value
end

function Util.truncate(text, limit)
	text = tostring(text or "")
	if #text <= limit then
		return text
	end
	return text:sub(1, math.max(1, limit - 1)) .. "…"
end

function Util.now()
	return os.clock()
end

function Util.uptime(startedAt)
	local seconds = math.max(0, os.clock() - startedAt)
	if seconds < 60 then
		return string.format("%ds", math.floor(seconds))
	elseif seconds < 3600 then
		return string.format("%dm %ds", math.floor(seconds / 60), math.floor(seconds % 60))
	end
	return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
end

-- "14:03:22"
function Util.clock()
	local seconds = math.floor(os.clock() % 86400)
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60)
end

return Util
