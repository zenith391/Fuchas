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
local tasks = require("tasks")

windowManager.clearDesktop()

--local ctx = draw.newContext(1, 1, 160, 50)
--local canvas = draw.canvas(ctx)

local taskBar = windowManager.newWindow()
local startMenu = windowManager.newWindow()
local startMenuEntries = {
	{"Settings", "A:/Fuchas/Interfaces/Concert/csettings.lua"},
	{"Task Manager", "A:/Fuchas/Interfaces/Concert/csysguard.lua"},
	{"Minesweeper", "A:/Fuchas/Interfaces/Concert/minesweeper/minesweeper.lua"}
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

local w, h = require("driver").gpu.getResolution()
do
	startMenu.undecorated = true
	startMenu.y = h - 15
	startMenu.x = 1
	startMenu.width = 25
	startMenu.height = 15
	do
		local comp = ui.component()
		comp.render = function(self)
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
						require("tasks").newProcess("proc", loadfile(v[2]))
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
	taskBar.y = h
	taskBar.x = 1
	taskBar.width = 160
	taskBar.height = 1
	taskBar:show()
	do
		local comp = ui.component()
		comp.render = function(self)
			self.canvas.fillRect(1, 1, self.width, self.height, self.background)
			self.canvas.fillRect(1, 1, 8, self.height, 0xBFFBFF)
			self.canvas.drawText(2, 1, "Fuchas", 0, 0xBFFBFF)
			self.canvas.drawText(self.width-12, 1, "No Connection", 0, 0xBFFBFF)
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
				--focusedWin:focus()
				if not v.undecorated and y == v.y then
					selectedWin = v
					wtx = x - selectedWin.x
					if x == selectedWin.x+selectedWin.width-2 then
						selectedWin:hide()
						selectedWin = nil
					end
					break
				end
			end
		end
	end
	if name == "drag" then
		if selectedWin ~= nil then
			windowManager.moveWindow(selectedWin, x-wtx, y)
		end
	end
end

windowManager.drawBackground(1, 1, 160, 50)
windowManager.drawDesktop()

while true do
	local evt = table.pack(event.pull())
	local name = evt[1]
	local oldfocused = focusedWin
	if name == "touch" or name == "drag" then
		screenEvent(name, evt[2], evt[3], evt[4], evt[5], evt[6])
	end
	if focusedWin ~= nil then
		if name == "touch" or name == "drag" or name == "drop" then -- translate screen position to component position
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
