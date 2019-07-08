local lib = {}
local ui = require("OCX/OCUI")
local draw = require("OCX/OCDraw")
local windows = {}
local desktop = {}

local function titleBar(win)
	local comp = ui.component()
	comp.render = function(self)
		if not self.context then -- init context if not yet
			self:open()
		end
		self.canvas.fillRect(0, 0, win.width, 1, 0xCCCCCC)
		self.canvas.fillRect(0, 1, win.width, win.height - 1, 0x2D2D2D)
		self.canvas.drawText(1, 0, win.title, 0xFFFFFF)
		self.canvas.drawText(win.width - 5, 0, "⣤ ⠶", 0xFFFFFF)
		self.canvas.drawText(win.width - 1, 0, "X", 0xFF0000)
		draw.drawContext(self.context)
	end
	return comp
end

function lib.newWindow()
	local obj = {
		title = "",
		x = 20,
		y = 10,
		width = 40,
		height = 10,
		moved = false,
		dirty = true,
		focused = false,
		undecorated = false,
		container = ui.container(),
		id = #windows+1,
		show = function(self)
			desktop[self.id] = self
		end,
		hide = function(self)
			desktop[self.id] = self
			self.titleBar:dispose()
			self.container:dispose()
		end
	}
	obj.titleBar = titleBar(obj)
	windows[obj.id] = obj
	return obj
end

function lib.desktop()
	return desktop
end

function lib.drawDesktop()
	for _, win in pairs(desktop) do
		if win.dirty then
			if not win.undecorated then
				win.titleBar.x = win.x
				win.titleBar.y = win.y
				win.titleBar.height = 1
				win.titleBar.width = win.width
				if win.titleBar.context then
					draw.moveContext(win.titleBar.context, win.x, win.y)
					draw.setContextSize(win.titleBar.context, win.width, 1)
				end
				win.titleBar:render()
			end
			
			local cy = win.y+1
			local ch = win.height-1
			if win.undecorated then
				cy = win.y
				ch = win.height
			end
			win.container.x = win.x
			win.container.y = cy
			win.container.height = ch
			win.container.width = win.width
			if win.container.context then
				draw.moveContext(win.container.context, win.x, cy)
				draw.setContextSize(win.container.context, win.width, ch)
			end
			win.container:render()
			
			--win.dirty = false
		end
	end
end

function lib.windowingSystem()
	local sys = {}
	sys.moveWindow = function(win, ox, oy, canvas, drop)
		if drop then
			sys.renderWindow(win, canvas)
		end
	end

	sys.renderWindow = function(win)
		--error(debug.traceback())
		c.fillRect(win.x, win.y, win.width, 1, 0xCCCCCC)
		if win.undecorated == false then
			c.fillRect(win.x, win.y + 1, win.width, win.height - 1, 0x2D2D2D)
			c.drawText(win.x + 1, win.y, win.title, 0xFFFFFF)
			c.drawText((win.x + win.width) - 5, win.y, "⣤ ⠶", 0xFFFFFF)
			c.drawText((win.x + win.width) - 1, win.y, "X", 0xFF0000)
		end
	end
	return sys
end

return lib