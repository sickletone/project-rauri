--!nolint
-- Rauri web example loader.
--
-- Run this in a Roblox executor:
--
--   loadstring(game:HttpGet(
--     "https://raw.githubusercontent.com/sickletone/project-rauri/main/examples/WebHubLoader.lua"
--   ))()
--
-- It fetches the published single-file framework and examples/WebHub.lua, then
-- mounts the hub. jsDelivr is used as a fallback when raw.githubusercontent.com
-- is blocked.

local RAW = "https://raw.githubusercontent.com/sickletone/project-rauri/main"
local CDN = "https://cdn.jsdelivr.net/gh/sickletone/project-rauri@main"

local function fetch(path)
	local ok, body = pcall(function()
		return game:HttpGet(RAW .. path)
	end)
	if ok and type(body) == "string" and body ~= "" then
		return body
	end
	return game:HttpGet(CDN .. path)
end

local function loadChunk(path)
	local source = fetch(path)
	local chunk, err = loadstring(source)
	if not chunk then
		error("Rauri loader: could not compile " .. path .. ": " .. tostring(err), 0)
	end
	return chunk()
end

local Rauri = loadChunk("/dist/rauri.lua")
local buildHub = loadChunk("/examples/WebHub.lua")
return buildHub(Rauri)
