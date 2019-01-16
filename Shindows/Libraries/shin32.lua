local dll = {}
local windows = {}
local processes = {}
local sysvars = {}
local nextWinID = 2
local activeProcesses = 0

function table.getn(table)
  local i = 0
  for k, v in pairs(table) do
    if k > i then
      i = k
    end
  end
  return i
end

function io.fromu16(x)
	local b2=string.char(x%256) x=(x-x%256)/256
    local b1=string.char(x%256) x=(x-x%256)/256
	return {b1, b2}
end

function io.fromu32(x)
	local b4=string.char(x%256) x=(x-x%256)/256
    local b3=string.char(x%256) x=(x-x%256)/256
	local b2=string.char(x%256) x=(x-x%256)/256
    local b1=string.char(x%256) x=(x-x%256)/256
	return {b1, b2, b3, b4}
end

function io.tou16(arr, off)
	local v1 = arr[off]
	local v2 = arr[off + 1]
	return v1 + (v2*256)
end

function io.tou32(arr, off)
	local v1 = readu16(off)
	local v2 = readu16(off + 2)
	return v1 + (v2*65536)
end

function dll.getSystemVars() 
	return sysvars
end

function dll.getSystemVar(var)
	return sysvars[var]
end

function dll.newProcess(name, func)
	local pid = table.getn(processes) + 1
	local proc = coroutine.create(function(pid, name)
		activeProcesses = activeProcesses + 1
		func(pid, name)
		activeProcesses = activeProcesses - 1
	end, pid, name)
	processes[pid] = {name, proc}
	coroutine.resume(proc, pid, name)
end

function dll.scheduler()
	for k, p in pairs(processes) do
		if coroutine.status(p[2]) == "dead" then
			table.remove(processes, k)
		else
			coroutine.resume(p[2])
		end
		--print("resoume")
	end
	require("event").pull() -- event yield
	--coroutine.yield()
end

function dll.getActiveProcesses()
	return activeProcesses
end

function dll.newWindow()
  local obj = {}
  obj.title = ""
  obj.x = 20
  obj.y = 20
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

function dll.windowingSystem()
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
  sys.moveWindow = function(v, tx, ty, c)
	  --c.copy(v.x, v.y, v.width, v.height, v.x, v.y)
	  sys.renderWindow(v.id, c)
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

return dll