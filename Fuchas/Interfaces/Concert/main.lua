-- Main UI file for the Operating System frontend UI (optional)
local wins = require("Concert/wins")
local event = require("event")
local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")

local ctx = draw.newContext(0, 0, 160, 50)
local canvas = draw.canvas(ctx)
local test = wins.newWindow()
local taskBar = wins.newWindow()

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

local function drawBackDesktop(dontDraw)
	canvas.fillRect(0, 0, 160, 50, 0xAAAAAA)
	if not dontDraw then
		draw.drawContext(ctx)
	end
end

local function screenEvent(name, addr, x, y, button, player)
	if name == "touch" then
		
	end
	if name == "drag" then
		for _, v in pairs(wins.desktop()) do
			
		end
	end
	local wx, wy = test.x, test.y
	local ww, wh = test.width, test.height
	drawBackDesktop()
	test.x = x-1
	test.y = y-1
	test.dirty = true
	draw.drawContext(ctx)
	wins.drawDesktop()
end

drawBackDesktop()
wins.drawDesktop()

while true do
	local name, addr, x, y, button, player = event.pull()
	if name == "touch" or name == "drag" then
		screenEvent(name, addr, x, y, button, player)
	end
end