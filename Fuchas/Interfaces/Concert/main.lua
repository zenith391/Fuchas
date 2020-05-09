-- Main UI file for the Operating System frontend UI (optional)
package.loaded["Concert/wins"] = nil
local wins = require("Concert/wins")
local event = require("event")
local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")

wins.clearDesktop()

local ctx = draw.newContext(1, 1, 160, 50)
local canvas = draw.canvas(ctx)
local test = wins.newWindow()
local startMenu = wins.newWindow()
local startMenuEntries = {
	{"Settings", "A:/Fuchas/Interfaces/Concert/csettings.lua"},
	{"Task Manager", "A:/Fuchas/Interfaces/Concert/csysguard.lua"},
	{"Minesweeper", "A:/Fuchas/Interfaces/Concert/minesweeper/minesweeper.lua"}
}
local taskBar = wins.newWindow()
local focusedWin = nil
local selectedWin = nil

do
	startMenu.undecorated = true
	startMenu.y = 35
	startMenu.x = 1
	startMenu.width = 25
	startMenu.height = 15
	do
		local comp = ui.component()
		comp.render = function(self)
			self:initRender()
			self.canvas.fillRect(1, 1, self.width, 1, 0)
			self.canvas.fillRect(1, 2, self.width, self.height-1, 0x222222)
			self.canvas.drawText(10, 1, "Fuchas", 0xFFFFFF)
			for k, v in pairs(startMenuEntries) do
				local name = v[1]
				local y = 2 + k
				self.canvas.drawText(2, y, name, 0xFFFFFF)
			end
			draw.drawContext(self.context)
		end
		comp.listeners["defocus"] = function(name, self, new)
			if startMenu.visible then
				startMenu:hide()
			end
		end
		comp.listeners["touch"] = function(name, _, x, y, button)
			if button == 0 then
				for k, v in pairs(startMenuEntries) do
					local name = v[1]
					local cy = 1 + k
					if x > comp.x+1 and x < comp.x+1+name:len() and y == comp.y+cy then
						dofile(v[2])
					end
				end
			end
		end
		comp.background = 0xFFFFFF
		startMenu.container = comp
	end
end

dofile("A:/Fuchas/Interfaces/Concert/csysguard.lua")

do
	taskBar.undecorated = true
	taskBar.y = 50
	taskBar.x = 1
	taskBar.width = 160
	taskBar.height = 1
	taskBar:show()
	do
		local comp = ui.component()
		comp.render = function(self)
			self:initRender()
			self.canvas.fillRect(1, 1, self.width, self.height, self.background)
			self.canvas.fillRect(1, 1, 8, self.height, 0xBFFBFF)
			self.canvas.drawText(2, 1, "Fuchas", 0)
			self.canvas.drawText(self.width-13, 1, "No Connection", 0xFFFFFF)
			draw.drawContext(self.context) -- finally draw
		end
		comp.listeners["touch"] = function(name, addr, x, y, button)
			if x>comp.x+1 and x<comp.x+7 then
				if y>=comp.y and y<comp.y+comp.height then
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

local function drawBackDesktop(dontDraw)
	canvas.fillRect(1, 1, 160, 50, 0xAAAAAA)
	if not dontDraw then
		draw.drawContext(ctx)
	end
end

local wtx = 0
local function screenEvent(name, addr, x, y, button, player)
	if name == "touch" then
		selectedWin = nil
		focusedWin = nil
		for _, v in pairs(wins.desktop()) do
			v.focused = false
			if x >= v.x and y >= v.y and x < v.x+v.width and y < v.y+v.height then
				focusedWin = v
				focusedWin:focus()
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
			wins.moveWindow(selectedWin, x-wtx, y)
			--selectedWin.x = x - wtx; selectedWin.y = y
			--selectedWin.dirty = true
			--drawBackDesktop()
			--wins.drawDesktop()
		end
	end
end

drawBackDesktop()
wins.drawDesktop()

while true do
	local evt = table.pack(event.pull())
	local name = evt[1]
	local oldfocused = focusedWin
	if name == "touch" or name == "drag" then
		screenEvent(name, evt[2], evt[3], evt[4], evt[5], evt[6])
	end
	if focusedWin ~= nil then
		if focusedWin.container.listeners["*"] then
			focusedWin.container.listeners["*"](table.unpack(evt))
		elseif focusedWin.container.listeners[name] then
			focusedWin.container.listeners[name](table.unpack(evt))
		end
	end
	if oldfocused ~= nil and oldfocused ~= focusedWin then
		if oldfocused.container.listeners["defocus"] then
			oldfocused.container.listeners["defocus"]("defocus", oldfocused, focusedWin)
		end
	end
end
