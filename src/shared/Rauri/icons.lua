--!nolint
-- Rauri :: icons
-- Icon registry adapter for Molto (https://molto.pages.dev).
--
-- Molto publishes one sprite sheet per provider. Its glyphs are white on
-- transparent, so a sprite can be tinted with ImageColor3 like any font glyph.
-- Rauri bundles a curated set of each provider so icons render in Studio and in
-- live games; when the framework runs under an executor (loadstring + HttpGet),
-- the full 64k icon registry is loaded from molto and used instead.

local IconData = require(script.Parent.iconsData)

local Icons = {}

local REMOTE_URL = "https://molto.pages.dev/source.lua"
local DEFAULT_PROVIDER = "lucide"

local current = DEFAULT_PROVIDER
local remote = nil -- nil: not tried, false: unavailable, table: loaded registry
local listeners = {}

local PROVIDER_ORDER = { "lucide", "tabler", "heroicons", "phosphor", "fluent", "solar", "material" }

local function registry()
	if remote ~= nil then
		return remote
	end
	remote = false
	if typeof(loadstring) ~= "function" then
		return false
	end
	local okHttp, httpGet = pcall(function()
		return game.HttpGet
	end)
	if not okHttp or typeof(httpGet) ~= "function" then
		return false
	end
	local ok, result = pcall(function()
		return loadstring(httpGet(game, REMOTE_URL))()
	end)
	if ok and type(result) == "table" and typeof(result.GetAsset) == "function" then
		remote = result
	end
	return remote
end

-- Loads the full icon registry from molto. Requires an executor that provides
-- loadstring and game:HttpGet. Returns true when the registry is available.
function Icons.loadRemote()
	return registry() ~= false
end

function Icons.remoteAvailable()
	return registry() ~= false
end

function Icons.ORDER()
	return table.clone(PROVIDER_ORDER)
end

function Icons.providers()
	local list = {}
	for _, id in PROVIDER_ORDER do
		local data = IconData[id]
		if data then
			table.insert(list, {
				id = id,
				name = data.Name,
				count = data.Count,
				license = data.License,
				bundled = #data.Order,
			})
		end
	end
	return list
end

function Icons.getProvider()
	return current
end

function Icons.setProvider(id)
	local ok = IconData[id] ~= nil
	local reg = registry()
	if reg then
		local success = pcall(reg.SetProvider, id)
		ok = ok or success
		if not success then
			return false
		end
	elseif not ok then
		return false
	end
	current = id
	for listener in listeners do
		local success, err = pcall(listener, id)
		if not success then
			warn("[Rauri] icon provider listener failed: " .. tostring(err))
		end
	end
	return true
end

function Icons.onProviderChanged(fn)
	listeners[fn] = true
	return function()
		listeners[fn] = nil
	end
end

-- Names available for a provider. Full list under an executor, bundled sample otherwise.
function Icons.list(provider)
	provider = provider or current
	local reg = registry()
	if reg then
		local ok, names = pcall(reg.GetIcons, provider)
		if ok and type(names) == "table" then
			return names
		end
	end
	local data = IconData[provider]
	return data and data.Order or {}
end

-- Returns { Name, Provider, Image, RectSize, RectOffset, FontFace, Text } or nil.
function Icons.get(name, provider)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	provider = provider or current

	local reg = registry()
	if reg then
		local ok, asset = pcall(reg.GetAsset, name, provider)
		if ok and type(asset) == "table" and asset.Url then
			return {
				Name = asset.IconName or name,
				Provider = provider,
				Image = asset.Url,
				RectSize = asset.ImageRectSize,
				RectOffset = asset.ImageRectOffset,
				FontFace = asset.FontFace,
				Text = asset.Text,
			}
		end
	end

	local data = IconData[provider]
	if not data then
		return nil
	end
	local resolved = name
	for _ = 1, 8 do
		local alias = data.Aliases and data.Aliases[resolved]
		if not alias then
			break
		end
		resolved = alias
	end
	local entry = data.Icons[resolved]
	if not entry then
		return nil
	end
	return {
		Name = resolved,
		Provider = provider,
		Image = data.Sheets[entry[1]],
		RectSize = Vector2.new(entry[2], entry[3]),
		RectOffset = Vector2.new(entry[4], entry[5]),
	}
end

function Icons.has(name, provider)
	return Icons.get(name, provider) ~= nil
end

function Icons.search(query, limit, provider)
	provider = provider or current
	limit = limit or 60
	local names = Icons.list(provider)
	local needle = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	local results = {}
	if needle == "" then
		for index = 1, math.min(limit, #names) do
			results[index] = names[index]
		end
		return results, #names
	end
	for _, name in names do
		if #results >= limit then
			break
		end
		if name:find(needle, 1, true) then
			table.insert(results, name)
		end
	end
	return results, #names
end

function Icons.info(provider)
	provider = provider or current
	local data = IconData[provider]
	local total = data and data.Count or 0
	local bundled = data and #data.Order or 0
	if data == nil then
		-- Provider only known to the remote registry.
		total = #Icons.list(provider)
	end
	local reg = registry()
	if reg then
		local ok, info = pcall(reg.GetProviderInfo, provider)
		if ok and type(info) == "table" then
			total = info.Count or total
		end
	end
	return {
		id = provider,
		name = data and data.Name or provider,
		count = total,
		bundled = bundled,
		license = data and data.License or "",
		remote = reg ~= false,
	}
end

-- Applies an icon to an ImageLabel (sprite) or TextLabel (font, when the
-- executor registry provides a FontFace).
function Icons.apply(label, name, color)
	local asset = Icons.get(name)
	if not asset then
		if label:IsA("ImageLabel") then
			label.Image = ""
		end
		return false
	end
	if label:IsA("TextLabel") and not label:IsA("TextBox") then
		if asset.FontFace then
			label.Text = asset.Text
			label.FontFace = asset.FontFace
			if color then
				label.TextColor3 = color
			end
			return true
		end
		return false
	end
	if label:IsA("ImageLabel") then
		label.Image = asset.Image
		label.ImageRectSize = asset.RectSize
		label.ImageRectOffset = asset.RectOffset
		if color then
			label.ImageColor3 = color
		end
		return true
	end
	return false
end

function Icons.preload(names)
	local reg = registry()
	if reg and typeof(reg.PreloadAsync) == "function" then
		local ok, ready = pcall(reg.PreloadAsync, names, current)
		if ok then
			return ready
		end
	end
	return 0
end

Icons.DEFAULT_PROVIDER = DEFAULT_PROVIDER
Icons.REMOTE_URL = REMOTE_URL

return Icons
