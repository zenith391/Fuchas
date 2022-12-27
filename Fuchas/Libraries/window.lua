--- Window library
-- @module window
-- @alias lib

local lib = {}
local ui = require("OCX/OCUI")
local logger = require("log")("Window Manager")
local draw = require("OCX/OCDraw")
local gpu = require("driver").gpu
local tasks = require("tasks")
local desktop = {}
-- The buffer containing the desktop wallpaper
local wallpaperBuffer

local exclusiveContext = nil

local function titleBar()
	local comp = ui.component()
	comp._render = function(self)
		local win = self.parent
		local middle = math.floor(win.width / 2 - win.title:len() / 2)
		self.canvas.fillRect(1, 1, win.width, 1, 0xCCCCCC)
		self.canvas.drawText(middle, 1, win.title, 0xFFFFFF)

		local minimizeChar = '-' -- unicode.char(0x25CB)
		local maximizeChar = unicode.char(0x25A1)
		local closeChar    = unicode.char(0xD7)
		self.canvas.drawText(win.width - 5, 1, minimizeChar .. " " .. maximizeChar, 0xFFFFFF)
		self.canvas.drawText(win.width - 1, 1, closeChar, 0xFFFFFF)
	end
	return comp
end

--- Return a list of rectangles as if B, a part of A, was removed
local function xorRectangle(a, b)
	local rectangles = {}
	if b.y < a.y + a.h and b.y + b.h > a.y then
		if b.x <= a.x and b.x + b.w >= a.x then
			-- -----------
			-- | B |  A  |
			-- -----------
			table.insert(rectangles, { -- TODO: fix algorithm
				x = b.x + b.w,
				y = a.y,
				w = a.w - (b.x + b.w - a.x),
				h = a.h
			})
		end
		if b.x < a.x + a.w and b.x > a.x then
			-- -----------
			-- |  A  | B |
			-- -----------
			table.insert(rectangles, {
				x = a.x,
				y = a.y,
				w = b.x - a.x,
				h = a.h
			})
		end
	end

	if b.x < a.x + a.w and b.x + b.w > a.x then
		if b.y <= a.y and b.y + b.h >= a.y then
			-- -----
			-- | B |
			-- |---|
			-- |   |
			-- | A |
			-- |   |
			-- -----
			table.insert(rectangles, {
				x = a.x,
				y = b.y + b.h,
				w = a.w,
				h = a.h - (b.y + b.h - a.y)
			})
		end
		if b.y < a.y + a.h and b.y > a.y then
			-- -----
			-- |   |
			-- | A |
			-- |   |
			-- |---|
			-- | B |
			-- -----
			table.insert(rectangles, {
				x = a.x,
				y = a.y,
				w = a.w,
				h = b.y - a.y - 1
			})
		end
	end

	if #rectangles > 0 then
		-- TODO: remove duplicates from vertical and horizontal checking
		local final = {}
		for _, rect in pairs(rectangles) do
			if rect.w > 0 and rect.h > 0 then
				table.insert(final, rect)
			end
		end
		return final
	end
	return {a}
end

--- Returns the desktop
function lib.desktop()
	return desktop
end

--- Clear the desktop
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

--- Draw a section of the desktop background.
-- @int x The X position of the background section
-- @int y The Y position of the background section
-- @int width The width of the background section
-- @int height The height of the background section
function lib.drawBackground(x, y, width, height)
	local rw, rh = gpu.getResolution()
	if x+width-1 > rw then
		width = rw-x
	end
	if y+height > rh then
		height = rh-y
	end
	if x < 1 or y < 1 or width < 1 or height < 1 then return end
	if wallpaperBuffer then
		gpu.blit(wallpaperBuffer, gpu.screenBuffer(), x, y, width, height, x, y)
	else
		gpu.setColor(0xAAAAAA)
		gpu.fill(x, y, width, height)
	end
end

--- Move the given window
function lib.moveWindow(win, targetX, targetY)
	if exclusiveContext then
		win.x = targetX
		win.y = targetY
		win.titleBar.x = win.x
		win.titleBar.y = win.y
		win.container.x = win.x
		win.container.y = (win.undecorated and win.y) or (win.y + 1)
		return
	end
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
	win.titleBar.x = win.x
	win.titleBar.y = win.y
	win.container.x = win.x
	win.container.y = (win.undecorated and win.y) or (win.y + 1)

	local idx = 0
	for k, v in pairs(desktop) do
		if v == win then
			idx = k
			break
		end
	end

	local i = idx
	while i < #desktop do
		-- TODO: check if collision before requesting redraw
		if desktop[i] and desktop[i] ~= win then
			desktop[i]:update()
		end
		i = i + 1
	end
end

--- Draw the given window
function lib.drawWindow(win)
	if exclusiveContext then return end
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
	win:update()

	for _, w in pairs(desktop) do
		if w.x<win.x+win.width and w.x+w.width>win.x or w.y<win.y+win.height or w.y+w.height>win.y then
			w.dirty = true
		end
	end
end

--- Returns context if the caller can now use the GPU driver freely by temporarily disabling the window manager
--- This could typically be used for games or fullscreen Fushell programs.
function lib.requestExclusiveContext()
	if exclusiveContext then
		return false
	end

	local context = {
		pid = require("tasks").getCurrentProcess().pid
	}
	function context:release()
		if exclusiveContext == self then
			exclusiveContext = nil
			lib.forceDrawDesktop()
		end
	end

	exclusiveContext = context
	return context
end

function lib.hasExclusiveContext()
	return exclusiveContext ~= nil
end

function lib.setWallpaper(buffer)
	wallpaperBuffer = buffer
end

-- Forcibly redraw all of the desktop, including background
function lib.forceDrawDesktop()
	lib.drawBackground(1, 1, 160, 50)
	for _, win in pairs(desktop) do
		win.dirty = true
	end
	lib.drawDesktop()
end

--- Draw all the windows in the desktop
function lib.drawDesktop()
	for _, win in pairs(desktop) do
		if win.visible and win.dirty and not exclusiveContext then
			lib.drawWindow(win)
			-- win.dirty = false
		end
	end
end

--- Create a new window
-- @tparam int width The width of the new window
-- @tparam int height The height of the new window
-- @tparam[opt] string title The title of the new window
-- @treturn window The newly created window
-- @constructor
function lib.newWindow(width, height, title)

	--- A window object.
	-- @type window
	-- @string name The name
	local window = {
		--- Title of the window
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
	window.container.width = window.width
	window.container.height = window.height
	window.titleBar.parent = window
	window.container.window = window

	--- Focus the window
	-- @function window.focus
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
		self:update()
		self.titleBar:redraw()
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
		lib.drawBackground(self.x, self.y, self.width, self.height)

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
		if self.visible and not exclusiveContext then
			local cy = self.y+1
			local ch = self.height-1
			if self.undecorated then
				cy = self.y
				ch = self.height
			end
			self.container.x = self.x
			self.container.y = cy
			self.container.width = self.width
			self.container.height = ch

			if not self.undecorated and self.titleBar.width ~= self.width then
				self.titleBar.x = self.x
				self.titleBar.y = self.y
				self.titleBar.width = self.width
				self.titleBar:redraw()
			end

			local i = 1
			local aRect = {
				x = self.container.x,
				y = self.container.y,
				w = self.container.width,
				h = self.container.height
			}
			local rectangles = {
				aRect
			}
			while i < #desktop do
				if desktop[i] ~= self then
					local winRect = {
						x = desktop[i].container.x,
						y = desktop[i].container.y,
						w = desktop[i].container.width,
						h = desktop[i].container.height
					}
					local newRects = {}
					for _, rect in pairs(rectangles) do
						local rectList = xorRectangle(rect, winRect)
						for _, r in pairs(rectList) do
							table.insert(newRects, r)
						end
					end
					rectangles = newRects
				end
				i = i + 1
			end
			--if rectangles[1].x ~= aRect.x or rectangles[1].w ~= aRect.w then
				--print("col " .. aRect.x .. " -> " .. rectangles[1].x .. "; " .. aRect.w .. " -> " .. rectangles[1].w)
			--end
			self.container.clip = rectangles
			self.container:redraw()
		end
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

return lib
