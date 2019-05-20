local drv = require("driver")
local c = require("OCX/ConsoleUI")
local filesystem = require("filesystem")
local REPO_URL = "https://raw.githubusercontent.com/zenith391/Fuchas/master/"
local BACKGROUND = 0x000000

local p = c.progressBar(2)
local det = c.label("...")

local function render()
	c.clear(BACKGROUND)
	p.dirty = true
	p.render()
	det.dirty = true
	det.render()
end

local function status(text)
	det.x = 80 - text:len() / 2
	det.text = text
	p.progress = p.progress + 1
	render()
end

p.background = BACKGROUND
p.x = 55
p.y = 45
p.width = 50
p.height = 2
det.background = BACKGROUND
det.y = 42

status("Loading internet driver..")
drv.changeDriver("internet", "internet")

local int = drv.getDriver("internet")
status("Preparing installation..")
local listCode = "return {" .. int.readFully(REPO_URL .. "INSTALL2.LST") .. "}"
local list = load(listCode, "=list", "bt", _G)()
p.progress = 0
p.maxProgress = #list
render()
for k, v in pairs(list) do
	status("Downloading " .. v)
	local path = filesystem.path("A:/" .. v)
	if not filesystem.exists(path) then
		filesystem.makeDirectory(path)
	end
	int.httpDownload(REPO_URL .. v, "A:/" .. v)
end

require("filesystem").remove("A:/installing")