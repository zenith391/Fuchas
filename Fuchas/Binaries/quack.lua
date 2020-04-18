local shell = require("shell")
local filesystem = require("filesystem")
local event = require("event")
local keyboard = require("keyboard")
local gpu = require("driver").gpu

local rw, rh = gpu.getResolution()
local cx, cy = 1, 1
local sx, sy = 1, 1
local cur = true
local curC = ""

local args, options = shell.parse(...)
local file = args[1]

if file == nil then
	io.stderr:write("Usage: quack <filename>\n")
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
	gpu.fill(1, rh, rw, 1, 0xFFFFFF)
	gpu.drawText(1, rh, file .. " - Cursor: " .. cx .. ", " .. cy, 0)
	gpu.setColor(0x000000)
	gpu.setForeground(0xFFFFFF)
end

local function drawText()
	local y = sy
	for _, line in pairs(lines) do
		shell.setCursor(1, y)
		io.stdout:write(line)
		y = y + 1
		if y > rh - sy then
			break
		end
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
drawBottomBar()

local function eraseCursor()
	gpu.drawText(cx, cy-sy+1, curC)
end

while true do
	local evt = table.pack(event.pull(0.5))
	local name = evt[1]
	if name == "interrupted" then
		break
	end
	if name == "key_down" then
		eraseCursor()
		local keyChar = evt[3]
		local keyCode = evt[4]
		if keyCode == 200 then -- up
			if cy > 1 then
				cy = cy - 1
				cx = math.min(#lines[cy]+1, cx)
				if cy < sy then
					gpu.copy(1, 1, rw, rh-1, 0, 1)
					gpu.drawText(1, 1, lines[cy] .. (" "):rep(rw-#lines[cy]))
					sy = sy - 1
				end
				drawBottomBar()
			end
		elseif keyCode == 203 then -- left
			if cx > 1 then
				cx = cx - 1
				drawBottomBar()
			end
		elseif keyCode == 205 then -- right
			if cx <= #lines[cy] then
				cx = cx + 1
				drawBottomBar()
			end
		elseif keyCode == 208 then -- down
			if cy < #lines then
				cy = cy + 1
				cx = math.min(#lines[cy]+1, cx)
				if cy > rh-1 then
					gpu.copy(1, 1, rw, rh-1, 0, -1)
					gpu.drawText(1, rh-1, lines[cy] .. (" "):rep(rw-#lines[cy]))
					sy = sy + 1
				end
				drawBottomBar()
			end
		else
			if keyChar == 8 then
				if cx > 1 then
					lines[cy] = lines[cy]:sub(1,cx-2) .. lines[cy]:sub(cx)
					gpu.drawText(1, cy-sy+1, lines[cy] .. (" "):rep(rw-#lines[cy]))
					cx = cx - 1
				end
			elseif keyChar == 127 then
				lines[cy] = lines[cy]:sub(1,cx-1) .. lines[cy]:sub(cx+1)
				gpu.drawText(1, cy-sy+1, lines[cy] .. (" "):rep(rw-#lines[cy]))
			elseif keyChar == 13 then 
				local p1 = lines[cy]:sub(1, cx-1)
				local p2 = lines[cy]:sub(cx)
				lines[cy] = p1
				gpu.drawText(1, cy-sy+1, lines[cy] .. (" "):rep(rw-#lines[cy]))
				cy = cy + 1
				table.insert(lines, cy, p2)
				gpu.copy(1, cy-sy+1, rw, rh-1, 0, 1)
				gpu.drawText(1, cy-sy+1, lines[cy] .. (" "):rep(rw-#lines[cy]))
				drawBottomBar()
			elseif keyChar >= 0x20 then
				lines[cy] = lines[cy]:sub(1,cx-1) .. string.char(evt[3]) .. lines[cy]:sub(cx)
				gpu.drawText(1, cy-sy+1, lines[cy])
				cx = cx + 1
			end
		end
		cur = true
	end
	if name == "key_down" or not name then
		if cur then
			gpu.setColor(0xFFFFFF)
			curC = gpu.get(cx, cy-sy+1)
			gpu.drawText(cx, cy-sy+1, " ")
			gpu.setColor(0)
		else
			eraseCursor()
		end
		cur = not cur
	end
end

shell.clear()
