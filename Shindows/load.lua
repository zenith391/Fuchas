local c = require("OCX/ConsoleUI")
local fs = require("filesystem")
local drv = require("driver")
c.clear(0x000000)
local pu = c.label("Loading Shindows..")
local p = c.progressBar(6)
p.x = 55
p.y = 45
p.width = 50
p.height = 2
p.render()
pu.x = 70
pu.y = 42
pu.foreground = 0xFFFFFF
pu.render()

function updatebar()
	p.progress = p.progress + 1
	p.render()
	coroutine.yield()
end
-- Preload libraries
_G.shin32 = require("shin32")
updatebar()
require("shinamp")
updatebar()
require("keyboard")
updatebar()
require("OCX/OCDraw")
updatebar()
require("OCX/OCUI")
updatebar()
require("shell")
updatebar()

local function httpDownload(url, dest)
	local h = component.getPrimary("internet").request(url)
	--h:finishConnect()
	local file = require("filesystem").open(dest, "w")
	local data = ""
	while data ~= nil do
		file:write(tostring(h:read()))
	end
	file:close()
	h:close()
end

if fs.exists("/installing") then
	c.clear(0xAAAAAA)
	p = c.progressBar(100)
	pu.background = 0xAAAAAA
	p.background = 0xAAAAAA
	p.progress = 20
	p.x = 55
	p.y = 45
	p.width = 50
	p.height = 2
	pu.text = "Installing Shindows.."
	pu.y = 40
	local det = c.label("Loading network driver..")
	det.x = 68
	det.background = 0xAAAAAA
	det.y = 42
	det.render()
	pu.render()
	p.dirty = true
	p.render()
	if drv.isDriverAvailable("internet") or true then
		drv.changeDriver("internet", "internet")
		local int = drv.getDriver("internet")
		httpDownload("https://raw.githubusercontent.com/zenith391/Shindows_OC/master/Shindows/Libraries/filesystem.lua", "/test.lua")
	end
	print(tostring(drv.isDriverAvailable("internet")))
	return
end

local f, err = pcall(function()
	dofile("/Shindows/shindows.lua")
end)
y = 1
if err ~= nil then
	print(err)
end