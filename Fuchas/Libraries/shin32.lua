-- Author: zenith391
local dll = {}
local windows = {}
local processes = {}
local sysvars = {}
local nextWinID = 2
local currentProc = nil
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

table.maxn = table.getn

function string.split(str, sep)
	if not sep then sep = "%s" end
	local t = {}
	for part in string.gmatch(str, "([^" .. sep .. "]+)") do
		table.insert(t, part)
	end
	return t
end

function io.fromu16(x)
	local b1=string.char(x%256) x=(x-x%256)/256
	local b2=string.char(x%256)
	return {b1, b2}
end

function io.fromu32(x)
	local b1=string.char(x%256) x=(x-x%256)/256
	local b2=string.char(x%256) x=(x-x%256)/256
	local b3=string.char(x%256) x=(x-x%256)/256
	local b4=string.char(x%256)
	return {b1, b2, b3, b4}
end

function io.tou16(arr, off)
	local v1 = arr[off + 1]
	local v2 = arr[off]
	return v1 + (v2*256)
end

function io.tou32(arr, off)
	local v1 = io.tou16(arr, off + 2)
	local v2 = io.tou16(arr, off)
	return v1 + (v2*65536)
end

function dll.getSystemVars() 
	return sysvars
end

function dll.getSystemVar(var)
	return sysvars[var]
end

function dll.setSystemVar(var, value)
	sysvars[var] = value
end

function dll.newProcess(name, func)
	local pid = table.getn(processes) + 1
	local proc = {}
	proc.name = name
	proc.func = func
	proc.pid = pid
	proc.status = "created"
	processes[pid] = proc
end

function dll.scheduler()
	local lastEvent = table.pack(require("event").handlers(0.05)) -- call for a tick
	for k, p in pairs(processes) do
		if p.status == "created" then
			p.thread = coroutine.create(p.func)
			activeProcesses = activeProcesses + 1
			p.status = "ready"
		end
		if coroutine.status(p.thread) == "dead" then
			p.status = "dead"
			activeProcesses = activeProcesses - 1
			table.remove(processes, k)
		else
			if p.status == "wait_event" then
				if lastEvent ~= nil then
					if lastEvent[1] ~= nil then
						p.result = lastEvent
						p.status = "ready"
					end
				end
			end
			if p.status == "ready" then
				p.status = "running"
				local ret, a1, a2, a3
				currentProc = p
				if p.result then
					_, ret, a1, a2, a3 = coroutine.resume(p.thread, p.result)
					p.result = nil
				else
					_, ret, a1, a2, a3 = coroutine.resume(p.thread)
				end
				currentProc = nil
				p.status = "ready"
				if ret then
					if type(ret) == "function" then
						local cont, val = true, nil
						while cont do
							cont, val = a(val)
						end
						p.result = val
					end
					if type(ret) == "string" then
						if ret == "pull event" then
							_pullSignal = a1
							p.arg1 = a2
							p.status = "wait_event"
						end
					end
				end
			end
		end
	end
end

function dll.getCurrentProcess()
	return currentProc
end

function dll.getActiveProcesses()
	return activeProcesses
end

function dll.getProcesses()
	return processes
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