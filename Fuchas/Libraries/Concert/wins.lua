local lib = {}
local windows = {}
local nextWinID = 1

function lib.newWindow()
	local obj = {}
	obj.title = ""
	obj.x = 20
	obj.y = 10
	obj.width = 40
	obj.height = 10
	obj.moved = false
	obj.dirty = true
	obj.undecorated = false
	obj.id = nextWinID
	windows[nextWinID] = obj
	nextWinID = nextWinID + 1
	return nextWinID - 1
end

function lib.windowingSystem()
	local sys = {}
	sys.getWindows = function()
		return windows
	end
	sys.setTitle = function(winID, title)
		windows[winID].title = title
	end
	sys.getTitle = function(winID)
		return windows[winID].title
	end
	sys.getSize = function(winID)
		local win = windows[winID]
		return win.width, win.height
	end
	sys.isUndecorated = function(winID)
		return windows[winID]
	end
	sys.setUndecorated = function(winID, undecorated)
		windows[winID].undecorated = undecorated
	end
	sys.setSize = function(winID, width, height)
		local win = windows[winID]
		sys.checkDirty(win)
		win.width = width
		win.height = height
		sys.checkDirty(win)
	end
	sys.getPosition = function(winID)
		local win = windows[winID]
		return win.x, win.y
	end
	sys.setPosition = function(winID, x, y)
		local win = windows[winID]
		sys.checkDirty(win)
		win.x = x
		win.y = y
		sys.checkDirty(win)
	end
	sys.setCanvas = function(c)
		sys.c = c
	end
	sys.checkDirty = function(v)
		for i, k in pairs(windows) do
			if k ~= v then
				if v.x + v.width > k.x and v.x + v.width < k.x + k.width then
					if v.y + v.height > k.y - 1 then
						sys.renderWindow(i, sys.c)
					end
				end
			end
		end
	end
	sys.moveWindow = function(winID, tx, ty, c)
		--c.copy(v.x, v.y, v.width, v.height, v.x, v.y)
		local v = windows[winID]
		sys.renderWindow(winID, c)
		if tx-1 > v.x then
			c.fillRect(v.x, v.y, tx - v.x, v.height, 0xEFEFEF)
		end
	end

	sys.renderWindow = function(winID, c)
		local v = windows[winID]
		--error(debug.traceback())
		c.fillRect(v.x, v.y, v.width, 1, 0xCCCCCC)
		if v.undecorated == false then
			c.fillRect(v.x, v.y + 1, v.width, v.height - 1, 0x2D2D2D)
			c.drawText(v.x + 1, v.y, v.title, 0xFFFFFF)
			c.drawText((v.x + v.width) - 5, v.y, "⣤ ⠶", 0xFFFFFF)
			c.drawText((v.x + v.width) - 1, v.y, "X", 0xFF0000)
		end
		sys.checkDirty(v)
	end
	return sys
end

return lib