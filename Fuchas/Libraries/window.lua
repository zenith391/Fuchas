local lib = {}
local ui = require("OCX/OCUI")
local logger = require("log")("Window Manager")
local draw = require("OCX/OCDraw")
local gpu = require("driver").gpu
local tasks = require("tasks")
local desktop = {}
local config = {
	COPY_WINDOW_OPTI = false,
	DIRTY_WINDOW_OPTI = false
}

local function titleBar()
	local comp = ui.component()
	comp.render = function(self)
		local win = self.parent
		self.canvas.fillRect(1, 1, win.width, 1, 0xCCCCCC)
		self.canvas.drawText(2, 1, win.title, 0xFFFFFF)
		self.canvas.drawText(win.width - 5, 1, unicode.char(0x25CB) .. " " .. unicode.char(0x25C9), 0xFFFFFF)
		self.canvas.drawText(win.width - 1, 1, unicode.char(0x25A3), 0xFF0000)
	end
	return comp
end

function lib.newWindow(width, height, title)
	local window = {
		title = title or "",
		x = 30,
		y = 10,
		width = width or 40,
		height = height or 10,
		dirty = false,
		focused = false,
		undecorated = false,
		visible = false,
		titleBar = titleBar(),
		container = ui.container()
	}
	window.titleBar.window = window
	window.container.window = window

	function window:focus()
		local idx = 0
		for k, v in pairs(desktop) do
			if v == self then idx = k end
		end
		if idx == 0 then
			error("window not displayed")
		end
		table.remove(desktop, idx)
		table.insert(desktop, 1, self)
		self.dirty = true
		lib.drawDesktop()
	end

	function window:show()
		table.insert(desktop, 1, self)
		self.visible = true
		self.dirty = true
		lib.drawDesktop()
	end

	function window:hide(disposing)
		self.visible = false
		self.titleBar:dispose(true)
		self.container:dispose(true)
		gpu.setColor(0xAAAAAA)
		gpu.fill(self.x, self.y, self.width, self.height)

		local idx = 0
		for k, v in pairs(desktop) do
			if v == self then
				idx = k
			end
		end
		if idx == 0 then
			return
		end
		table.remove(desktop, idx)
		lib.drawDesktop()
	end

	function window:update()
		self.container:_render()
	end

	function window:dispose()
		local idx = 0
		for k, v in pairs(desktop) do
			if v == self then
				idx = k
			end
		end
		if idx == 0 then
			return
		end
		if self.visible then
			self:hide()
		end
	end

	table.insert(tasks.getCurrentProcess().exitHandlers, function()
		window:dispose()
	end)
	return window
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
end

function lib.drawBackground(x, y, width, height)
	-- TODO: use the background OCDraw context (allows for huge performance boost with GPU buffers)
	gpu.setColor(0xAAAAAA)
	gpu.fill(x, y, width, height)
end

function lib.moveWindow(win, targetX, targetY)
	local rw, rh = gpu.getResolution()
	
	-- delta-X and delta-Y, the change between the last position of the window and the new one.
	local dx, dy = targetX - win.x, targetY - win.y

	if win.x + (win.width + 1) > rw or win.y + (win.height+1) > rh
		or win.x <= 0 or win.y <= 0 then
		win.x = targetX
		win.y = targetY
		lib.drawWindow(win)
	else
		gpu.copy(win.x, win.y, win.width, win.height, dx, dy)
	end

	if dx > 0 then -- moving the window to the right
		lib.drawBackground(win.x, win.y, dx, win.height)
	elseif dx < 0 then -- moving the window to the left
		lib.drawBackground(targetX + win.width, win.y, -dx, win.height)
	end

	if dy > 0 then -- moving the window down
		lib.drawBackground(win.x, win.y, win.width, dy)
	elseif dy < 0 then -- moving the window up
		lib.drawBackground(win.x, targetY + win.height, win.width, -dy)
	end
	
	win.x = targetX
	win.y = targetY
	win.container.x = win.x
	win.container.y = (win.undecorated and win.y) or (win.y + 1)
end

function lib.drawWindow(win)
	if not win.undecorated then
		win.titleBar.x = win.x
		win.titleBar.y = win.y
		win.titleBar.height = 1
		win.titleBar.width = win.width
		win.titleBar.parent = win
		win.titleBar:redraw()
	end
	
	local cy = win.y+1
	local ch = win.height-1
	if win.undecorated then
		cy = win.y
		ch = win.height
	end
	win.container.x = win.x
	win.container.y = cy
	win.container.width = win.width
	win.container.height = ch
	win.container.parent = win
	logger.debug("Draw window at " .. win.x .. "x" .. win.y .. " of size " .. win.width .. "x" .. win.height)
	win.container:redraw()

	for _, w in pairs(desktop) do
		if w.x<win.x+win.width and w.x+w.width>win.x or w.y<win.y+win.height or w.y+w.height>win.y then
			w.dirty = true
		end
	end
end

function lib.drawDesktop()
	for _, win in pairs(desktop) do
		if win.visible and win.dirty then
			lib.drawWindow(win)
			-- win.dirty = false
		end
	end
end

return lib
