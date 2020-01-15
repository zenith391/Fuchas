local lib = {}
local ui = require("OCX/OCUI")
local draw = require("OCX/OCDraw")
local gpu = require("driver").gpu
local windows = {}
local desktop = {}
local config = {
	COPY_WINDOW_OPTI = false,
	DIRTY_WINDOW_OPTI = true
}

local function titleBar(win)
	local comp = ui.component()
	comp.render = function(self)
		self:initRender()
		self.canvas.fillRect(1, 1, win.width, 1, 0xCCCCCC)
		self.canvas.drawText(2, 1, win.title, 0xFFFFFF)
		self.canvas.drawText(win.width - 5, 1, "⣤ ⠶", 0xFFFFFF)
		self.canvas.drawText(win.width - 1, 1, "X", 0xFF0000)
		draw.drawContext(self.context)
	end
	return comp
end

function lib.newWindow(width, height, title)
	local obj = {
		title = title or "",
		x = 20,
		y = 10,
		width = width or 40,
		height = height or 10,
		moved = false,
		dirty = false,
		focused = false,
		undecorated = false,
		visible = false,
		container = ui.container(),
		id = #windows+1,
		show = function(self)
			desktop[self.id] = self
			self.visible = true
			self.dirty = true
			lib.drawDesktop()
		end,
		hide = function(self)
			self.visible = false
			self.titleBar:dispose(true)
			self.container:dispose(true)
			gpu.setColor(0xAAAAAA)
			gpu.fill(self.x, self.y, self.width, self.height)
			lib.drawDesktop()
		end
	}
	obj.titleBar = titleBar(obj)
	windows[obj.id] = obj
	return obj
end

function lib.desktop()
	return desktop
end

function lib.clearDesktop()
	for k, v in pairs(desktop) do
		v.visible = false
		if v.titleBar then
			v.titleBar:dispose(true)
		end
		v.container:dispose(true)
	end
	desktop = {}
	windows = {}
end

function lib.moveWindow(win, x, y)
	local ox = win.x
	local oy = win.y
	local rw, rh = gpu.getResolution()
	
	local tx, ty = x - win.x, y - win.y
	if ox+win.width+1 > rw or oy+win.height+1 > rh then
		win.x = x
		win.y = y
		lib.drawWindow(win)
	else
		--gpu.setForeground(0x000000)
		--gpu.set(1, 1, tostring(ox))
		gpu.copy(ox, oy, win.width+1, win.height+1, tx, ty)
	end
	gpu.setColor(0xAAAAAA)
	if tx > 0 then
		gpu.fill(ox, oy, tx, win.height+1)
	else
		gpu.fill(ox+win.width, oy, -tx, win.height+1)
	end
	if ty > 0 then
		gpu.fill(ox, oy-1, win.width, ty)
	else
		gpu.fill(ox, oy+win.height, win.width+1, -ty)
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
	win.container:render()

	for _, w in pairs(desktop) do
		if w.x<win.x+win.width and w.x+w.width>win.x or w.y<win.y+win.height or w.y+w.height>win.y then
			w.dirty = true
		end
	end
end

function lib.drawDesktop()
	for _, win in pairs(desktop) do
		if win.visible and win.dirty then
			print(win.title .. " is title")
			print("draw")
			lib.drawWindow(win)
			if config.DIRTY_WINDOW_OPTI then win.dirty = false end
		else
			print("not draw")
		end
	end
end

return lib