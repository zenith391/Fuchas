local shell = require("shell")
local filesystem = require("filesystem")
local event = require("event")
local keyboard = require("keyboard")
local gpu = component.getPrimary("gpu")
local rw, rh = gpu.getResolution()
local cx, cy = 1, 1
local ctick, cblink = computer.uptime(), false
local cursor = 1

local args, options = shell.parse(...)
local file = args[1]

if file == nil then
	io.stderr:write("Usage: edit <filename>\n")
	return
end

file = shell.resolve(file)

if not file then
	io.stderr:write(args[1] .. " doesn't exists!\n")
	return
end

if filesystem.isDirectory(file) then
	io.stderr:write("path is directory\n")
	return
end

local lines = nil

local function drawBottomBar()
	gpu.setBackground(0xFFFFFF)
	gpu.setForeground(0x000000)
	gpu.fill(1, rh, rw, 1, " ")
	gpu.set(1, rh, file .. " - Cursor: " .. cx .. ", " .. cy)
	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
end

local function drawText()
	local y = 1
	for _, line in pairs(lines) do
		shell.setCursor(1, y)
		io.stdout:write(line)
		y = y + 1
	end
end

local function dlen(line)
	local len = 0
	for _, ch in pairs(string.toCharArray(line)) do
		if ch == '\t' then
			len = len + 4
		else
			len = len + 1
		end
	end
	return len
end

local function dcx(x)
	local dcx = 1
	local line = lines[cy]
	local i = 1
	for _, ch in pairs(string.toCharArray(line)) do
		if i == x then
			break
		end
		if ch == '\t' then
			dcx = dcx + 4
		else
			dcx = dcx + 1
		end
		i = i + 1
	end
	return dcx
end

local function redrawLine(index)
	for k, line in pairs(lines) do
		if k == index then
			shell.setCursor(1, k)
			io.stdout:write(line)
			break
		end
	end
end

local function drawCursor()
	if computer.uptime() >= ctick then
		cblink = not cblink
		ctick = computer.uptime() + 0.5
	end
	if cblink then
		gpu.setBackground(0xFFFFFF)
		gpu.set(math.min(dcx(cx), dlen(lines[cy])+1), cy, " ")
		gpu.setBackground(0x000000)
	else
		gpu.set(math.min(dcx(cx), dlen(lines[cy])+1), cy, " ")
		redrawLine(cy)
	end
end

---------------------------------------------

do
	local b = io.open(file)
	lines = b:lines()
	b:close()
end

shell.clear()
drawText()
drawCursor()
drawBottomBar()

while true do
	local evt = table.pack(event.pull(0.5))
	if evt[1] ~= nil then
		local name = evt[1]
		if name == "key_down" then
			local ch = evt[3]
			local code = evt[4]
			drawBottomBar()
			gpu.fill(1, cy, 160, 1, " ")
			redrawLine(cy)
			if code == 203 then -- left
				if cx > 1 then
					cx = cx - 1
				else
					if cy > 1 then
						cy = cy - 1
						cx = lines[cy]:len()+1
					end
				end
				cblink = true
				ctick = computer.uptime() + 0.5
			end
			if code == 200 then -- up
				if cy > 1 then
					cy = cy - 1
				end
				cblink = true
				ctick = computer.uptime() + 0.5
			end
			if code == 208 then -- down
				if cy < #lines then
					cy = cy + 1
				end
				cblink = true
				ctick = computer.uptime() + 0.5
			end
			if code == 205 then -- right
				if cx <= lines[cy]:len() then
					cx = cx + 1
				else
					if cy < #lines then
						cy = cy + 1
						cx = 1
					end
				end
				cblink = true
				ctick = computer.uptime() + 0.5
			end
			if ch ~= nil then
				ch = string.char(ch)
				
			end
		end
		if name == "interrupt" then
			break
		end
	end
	drawCursor()
end

shell.clear()