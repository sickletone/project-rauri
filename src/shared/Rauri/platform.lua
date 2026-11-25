--!nolint
-- Rauri :: platform
-- Exposes the extra capabilities executor environments provide: gethui parents,
-- GUI protection, clipboard and file IO. Everything degrades gracefully in
-- Studio and in games where only the framework ships.

local Players = game:GetService("Players")

local Platform = {}

local function globalFunction(name)
	local value = rawget(_G, name)
	if value == nil then
		value = rawget(getfenv(0), name)
	end
	return typeof(value) == "function"
end

-- True when executor-only globals are present. No vendor sniffing: a plain
-- capability check is enough to pick the right parent and helpers.
function Platform.isExecutor()
	return globalFunction("gethui") or globalFunction("setclipboard") or globalFunction("readfile")
end

-- The safest container for a Rauri UI: gethui when available (executors keep
-- it above the game and outside detection), PlayerGui otherwise so Studio and
-- headless tests keep working.
function Platform.guiParent()
	if globalFunction("gethui") then
		local ok, parent = pcall(gethui)
		if ok and typeof(parent) == "Instance" then
			return parent
		end
	end

	local player = Players and Players.LocalPlayer
	if player then
		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui then
			return playerGui
		end
		local ok, waited = pcall(function()
			return player:WaitForChild("PlayerGui", 5)
		end)
		if ok and waited then
			return waited
		end
	end
	return nil
end

-- Prevents executors and games from destroying the ScreenGui easily.
function Platform.protect(gui)
	if gui == nil or not globalFunction("protect_gui") then
		return false
	end
	return pcall(protect_gui, gui)
end

function Platform.setClipboard(text)
	text = tostring(text or "")
	if globalFunction("setclipboard") then
		return pcall(setclipboard, text)
	end
	if globalFunction("toclipboard") then
		return pcall(toclipboard, text)
	end
	return false
end

function Platform.readFile(path)
	if globalFunction("readfile") then
		local ok, contents = pcall(readfile, tostring(path))
		return ok and contents or nil
	end
	return nil
end

function Platform.writeFile(path, contents)
	if globalFunction("writefile") then
		return pcall(writefile, tostring(path), tostring(contents))
	end
	return false
end

function Platform.fileExists(path)
	if globalFunction("isfile") then
		local ok, exists = pcall(isfile, tostring(path))
		return ok and exists == true
	end
	return false
end

function Platform.listFiles(path)
	if globalFunction("listfiles") then
		local ok, files = pcall(listfiles, tostring(path or ""))
		if ok and type(files) == "table" then
			return files
		end
	end
	return {}
end

function Platform.httpGet(url)
	if typeof(game.HttpGet) == "function" then
		local ok, body = pcall(function()
			return game:HttpGet(tostring(url))
		end)
		if ok then
			return body
		end
	end
	return nil
end

function Platform.notify(title, text)
	local ok, starterGui = pcall(function()
		return game:GetService("StarterGui")
	end)
	if not ok or not starterGui then
		return false
	end
	local success = pcall(function()
		starterGui:SetCore("SendNotification", {
			Title = tostring(title or "Rauri"),
			Text = tostring(text or ""),
			Duration = 3,
		})
	end)
	return success
end

function Platform.summary()
	return {
		executor = Platform.isExecutor(),
		clipboard = globalFunction("setclipboard") or globalFunction("toclipboard"),
		fileIO = (globalFunction("readfile") and globalFunction("writefile")) or false,
		http = typeof(game.HttpGet) == "function",
	}
end

return Platform
