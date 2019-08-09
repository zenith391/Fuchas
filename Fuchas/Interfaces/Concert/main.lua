-- Main UI file for the Operating System frontend UI (optional)
local wins = require("Concert/wins")
local event = require("event")
local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")

local ctx = draw.newContext(0, 0, 160, 50)
local canvas = draw.canvas(ctx)
local test = wins.newWindow()
local test2 = wins.newWindow()
local taskBar = wins.newWindow()
local selectedWin = nil

do
	taskBar.undecorated = true
	taskBar.y = 49
	taskBar.x = 0
	taskBar.width = 160
	taskBar.height = 1
	taskBar:show()
	
	do
		local comp = ui.component()
		comp.render = function(self)
			if not self.context then -- init context if not yet
				self:open()
			end
			self.canvas.fillRect(0, 0, self.width, self.height, self.background)
			
			draw.drawContext(self.context) -- finally draw
		end
		taskBar.container = comp
	end
end

do
	test.title = "Test Window"
	test:show()
end

do
	test2.title = "Test Window 2"
	test2.x = 40
	test2.y = 30
	test2:show()
end

local function drawBackDesktop(dontDraw)
	canvas.fillRect(0, 0, 160, 50, 0xAAAAAA)
	if not dontDraw then
		draw.drawContext(ctx)
	end
end

local function screenEvent(name, addr, x, y, button, player)
	if name == "touch" then
		selectedWin = nil
		for _, v in pairs(wins.desktop()) do
			if x >= v.x and y >= v.y and x < v.x+v.width and y < v.y+v.height and not v.undecorated then
				selectedWin = v
			end
		end
	end
	if name == "drag" then
		if selectedWin ~= nil then
			--wins.moveWindow(selectedWin, x-1, y-1)
			drawBackDeesktop()
			wins.drawDesktop()
		end
	end
end

drawBackDesktop()
wins.drawDesktop()

while true do
	local name, addr, x, y, button, player = event.pull()
	if name == "touch" or name == "drag" then
		screenEvent(name, addr, x, y, button, player)
	end
end