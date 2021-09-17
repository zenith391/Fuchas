-- Concert Settings (CSettings)
local UI = require("OCX/OCUI")
local Concert = require("concert")
local window = require("window").newWindow(50, 16, "Settings")
local config = nil
do
	local file = io.open("A:/Fuchas/Interfaces/Concert/config.cfg", "r")
	if not file then
		io.stderr:write("no config file!")
		return
	end
	config = require("liblon").loadlon(file)
	file:close()
end

function writeConfig()
	local file = io.open("A:/Fuchas/Interfaces/Concert/config.cfg", "w")
	file:write(require("liblon").sertable(config, 1, true))
	file:close()
end

local container = window.container
container.layout = UI.LineLayout({ spacing = 0 })

local useWallpaper = UI.checkBox("Wallpaper", function(component, newValue)
	config.useWallpaper = newValue
	writeConfig()
	if newValue == true then
		Concert.loadWallpaper()
	else
		Concert.unloadWallpaper()
	end
end)
useWallpaper.x = 2
useWallpaper.active = config.useWallpaper
container:add(useWallpaper)

window:show()
while window.visible do
	os.sleep(1)
end
