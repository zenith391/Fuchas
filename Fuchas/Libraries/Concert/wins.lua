local lib = {}
local ui = require("OCX/OCUI")
local draw = require("OCX/OCDraw")
local gpu = component.gpu
local windows = {}
local desktop = {}
local config = {
	COPY_WINDOW_OPTI = false,
	DIRTY_WINDOW_OPTI = false
}

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

function lib.moveWindow(win, x, y)
	local ox = win.x
	local oy = win.y
	local rw, rh = gpu.getViewport()
	
	local tx, ty = x - win.x, y - win.y
	if ox+win.width+1 > rw or oy+win.height+1 > rh then
		win.x = x
		win.y = y
		lib.drawWindow(win)
	else
		gpu.setForeground(0x000000)
		gpu.set(1, 1, tostring(ox))
		gpu.copy(ox, oy, win.width+1, win.height+1, tx, ty)
	end
	gpu.setBackground(0xAAAAAA)
	if tx > 0 then
		gpu.fill(ox, oy, tx, win.height+1, " ")
	else
		gpu.fill(ox+win.width, oy, -tx, win.height+1, " ")
	end
	if ty > 0 then
		gpu.fill(ox, oy-1, win.width, ty, " ")
	else
		gpu.fill(ox, oy+win.height, win.width+1, -ty, " ")
	end
	win.x = x
	win.y = y
end

function lib.drawWindow(win)
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
end

function lib.drawDesktop()
	for _, win in pairs(desktop) do
		if win.dirty then
			lib.drawWindow(win)
			if config.DIRTY_WINDOW_OPTI then win.dirty = false end
		end
	end
end

return lib