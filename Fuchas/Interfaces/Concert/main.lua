--[[
	SPDX-License-Identifier: MIT
	Fuchas's default desktop environment
]]

package.loaded["window"] = nil
package.loaded["OCX/OCUI"] = nil
package.loaded["OCX/OCDraw"] = nil

local windowManager = require("window")
local event = require("event")
local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")
local imaging = require("OCX/OCImage")
local tasks = require("tasks")
local gpu = require("driver").gpu
gpu.setResolution(gpu.maxResolution())

local config = nil
local defaultConfig = {
	useWallpaper = true,
	wallpaperPath = "A:/Fuchas/Interfaces/Concert/wallpaper3.bmp"
}
do
	local file = io.open("A:/Fuchas/Interfaces/Concert/config.cfg", "r")
	if not file then
		config = defaultConfig

		file = io.open("A:/Fuchas/Interfaces/Concert/config.cfg", "w")
		file:write(require("liblon").sertable(config, 1, true))
		file:close()
	else
		local ok
		ok, config = pcall(require("liblon").loadlon, file)
		if ok == false then
			config = defaultConfig

			file = io.open("A:/Fuchas/Interfaces/Concert/config.cfg", "w")
			file:write(require("liblon").sertable(config, 1, true))
			file:close()
		end
		file:close()
	end
end

windowManager.clearDesktop()

local api = {}
function api.loadWallpaper()
	local ok, err = pcall(function()
		--error("no wallpaper")
		local rw, rh = gpu.getResolution()
		local wallpaper = draw.newContext(1, 1, rw, rh)
		-- TODO: convert image to an OC-specific image format which would make the
		-- code lighter, the file size lower and the loading time faster
		local image = imaging.loadRaster(config.wallpaperPath)
		image = imaging.scale(image, rw * 2, rh * 4)
		image = imaging.convertFromRaster(image, { dithering = "floyd-steinberg", advancedDithering = true })

		imaging.drawImage(image, wallpaper)
		draw.drawContext(wallpaper)
		windowManager.setWallpaper(draw.toOwnedBuffer(wallpaper))
		windowManager.forceDrawDesktop()
	end)
	if not ok then return err end
end

function api.unloadWallpaper()
	windowManager.setWallpaper(nil)
	windowManager.forceDrawDesktop()
end

package.loaded.concert = api

local caps = gpu.getCapabilities()
if config.useWallpaper and config.wallpaperPath and caps.hardwareBuffers then
	api.loadWallpaper()
end

local taskBar = windowManager.newWindow()
local startMenu = windowManager.newWindow()
local startMenuEntries = {
	{"Settings", "A:/Fuchas/Interfaces/Concert/Applications/csettings.lua"},
	{"Task Manager", "A:/Fuchas/Interfaces/Concert/Applications/csysguard.lua"},
	{"NeoQuack", "A:/Fuchas/Interfaces/Concert/Applications/editor.lua"},
	{"Minesweeper", "A:/Fuchas/Interfaces/Concert/minesweeper/minesweeper.lua"},
	{"OpenMedia Player", "A:/Fuchas/Interfaces/Concert/Applications/mediaplayer.lua"},
	{"Mario", "A:/Users/Shared/Binaries/subpixeltest.lua"},
	{"Terminal", "A:/Fuchas/Interfaces/Concert/Applications/terminal.lua"},
	{"Flarefox", "A:/Users/Shared/Binaries/flarefox.lua"},
	{"Reboot", ":reboot"}
}

local focusedWin = nil
local selectedWin = nil

tasks.getCurrentProcess().childErrorHandler = function(proc, err)
	local procType = "process"
	if proc.isService then
		procType = "service"
	end
	io.stderr:write("Error from " .. procType .. " \"" .. proc.name .. "\": " .. tostring(err) .. "\n")
end

local taskBarSize = 1
local w, h = require("driver").gpu.getResolution()
do
	startMenu.undecorated = true
	startMenu.y = h - 14 - taskBarSize
	startMenu.x = 1
	startMenu.width = 25
	startMenu.height = 15
	do
		local comp = ui.component()
		comp._render = function(self)
			self.canvas.fillRect(1, 1, self.width, 1, 0)
			self.canvas.fillRect(1, 2, self.width, self.height-1, 0x222222)
			self.canvas.drawText(10, 1, "Fuchas", 0xFFFFFF, 0)
			for k, v in pairs(startMenuEntries) do
				local name = v[1]
				local y = 2 + k
				self.canvas.drawText(2, y, name, 0xFFFFFF, 0x222222)
			end
		end
		comp.listeners["defocus"] = function(self, name, self, new)
			if startMenu.visible then
				startMenu:hide()
			end
		end
		comp.listeners["touch"] = function(self, name, _, x, y, button)
			if button == 0 then
				for k, v in pairs(startMenuEntries) do
					local name = v[1]
					local cy = 2 + k
					if x > 1 and x < 1+name:len() and y == cy then
						if v[2] == ":reboot" then
							computer.shutdown(true)
						end
						local f, err = loadfile(v[2])
						if f then
							require("tasks").newProcess(name, f)
						else
							print(err)
						end
					end
				end
			end
		end
		comp.background = 0xFFFFFF
		startMenu.container = comp
	end
end

do
	taskBar.undecorated = true
	taskBar.y = h + 1 - taskBarSize
	taskBar.x = 1
	taskBar.width = 160
	taskBar.height = taskBarSize
	taskBar:show()
	do
		local comp = ui.component()
		comp.background = 0x000000
		comp._render = function(self)
			self.canvas.fillRect(1, 1, self.width, self.height, self.background)
			self.canvas.fillRect(1, 1, 8, self.height, 0xBFFBFF)
			self.canvas.drawText(2, 1, "Fuchas", 0x000000, 0xBFFBFF)
			local clock = os.date("%T")
			self.canvas.drawText(self.width-#clock, 1, clock, 0xFFFFFF, 0x000000)
		end

		comp.listeners["touch"] = function(self, name, addr, x, y, button)
			if x >= 1 and x < 9 then
				if y == 1 then
					if startMenu.visible then
						startMenu:hide()
					else
						startMenu:show()
						focusedWin = startMenu
					end
				end
			end
		end
		taskBar.container = comp
	end
end

local wtx = 0
local function screenEvent(name, addr, x, y, button, player)
	if name == "touch" then
		selectedWin = nil
		focusedWin = nil
		for _, v in pairs(windowManager.desktop()) do
			v.focused = false
			if x >= v.x and y >= v.y and x < v.x+v.width and y < v.y+v.height then
				focusedWin = v
				focusedWin:focus()
				if not v.undecorated and y == v.y then
					selectedWin = v
					wtx = x - selectedWin.x
					if x == v.x+v.width-4 then
						if not v.maximized then
							-- TODO: send event to owning process that window got maximized
							v.oldPos = {v.x, v.y, v.width, v.height}
							v.x = 1
							v.y = 1
							v.width = 160
							v.height = 49
							v.maximized = true
							v:update()
						else
							v.x = v.oldPos[1]
							v.y = v.oldPos[2]
							v.width = v.oldPos[3]
							v.height = v.oldPos[4]
							v.maximized = false
							windowManager.drawBackground(1, 1, 160, 50)
							windowManager.drawDesktop()
						end
					end
					if x == selectedWin.x+selectedWin.width-2 then
						-- TODO: send event to owning process that window got closed
						selectedWin:hide()
						selectedWin = nil
					end
				end
				break
			end
		end
	end
	if name == "drag" then
		if selectedWin ~= nil and not selectedWin.maximized then
			windowManager.moveWindow(selectedWin, x-wtx, y)
		end
	end
end

windowManager.drawBackground(1, 1, 160, 50)
windowManager.drawDesktop()

while true do
	local evt = table.pack(event.pull())
	if not windowManager.hasExclusiveContext() then
		taskBar:update()
	end

	if evt and not windowManager.hasExclusiveContext() then
		local name = evt[1]
		local oldfocused = focusedWin
		if name == "touch" or name == "drag" then
			screenEvent(name, evt[2], evt[3], evt[4], evt[5], evt[6])
		end
		if focusedWin ~= nil then
			if name == "touch" or name == "drag" or name == "drop" or name == "scroll" then -- translate screen position to component position
				evt[3] = evt[3] - focusedWin.container.x + 1
				evt[4] = evt[4] - focusedWin.container.y + 1
				if evt[3] < 1 or evt[4] < 1 then -- event cancelled: out of component
					goto cancel
				end
			end
			if focusedWin.container.listeners[name] then
				focusedWin.container.listeners[name](focusedWin.container, table.unpack(evt))
			elseif focusedWin.container.listeners["*"] then
				focusedWin.container.listeners["*"](focusedWin.container, table.unpack(evt))
			end
			::cancel::
		end
		if oldfocused ~= nil and oldfocused ~= focusedWin then
			if oldfocused.container.listeners["defocus"] then
				oldfocused.container.listeners["defocus"](oldfocused.container, "defocus", oldfocused, focusedWin)
			end
		end
	end
end
