-- An ESSENTIAL program!
-- The tiles are 2x1 characters
-- With braille this allow 4x4 art

local tasks = require("tasks")
local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")
local win = require("Concert/wins").newWindow(30, 17, "Minesweeper")

local flag = {
	0, 1, 1, 0,
	1, 1, 1, 0,
	0, 1, 1, 0,
	0, 0, 1, 0
}

do
	local sweeper = ui.component()
	sweeper.render = function(self)
		self:initRender()
		self.canvas.fillRect(1, 1, self.width, self.height, self.background)
		draw.drawContext(self.context)
	end
	sweeper.background = 0xFFFFFF
	sweeper.width = 30
	sweeper.height = 15
	sweeper.x = 1
	sweeper.y = 2
	win.container:add(sweeper)
end

local menuBar = ui.menuBar()
win.container:add(menuBar)
win.container.background = 0x2D2D2D
win:show()
