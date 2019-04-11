local drv = require("driver")
local c = require("OCX/ConsoleUI")
local REPO_URL = "https://raw.githubusercontent.com/zenith391/Fuchas/master/"
local BACKGROUND = 0x000000

local p = c.progressBar(5)
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
status("Getting filelist..")

local list = load("return {" .. int.readFully(REPO_URL .. "INSTALL1.LST") .. "}", "=list", "bt", _G)()