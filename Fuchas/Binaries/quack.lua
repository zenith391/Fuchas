local shell = require("shell")
local filesystem = require("filesystem")
local event = require("event")
local keyboard = require("keyboard")
local gpu = require("driver").gpu

local colorScheme = {
	foreground = 0xF8F8F2,
	background = 0x272822,
	comment = 0x75715E,
	number = 0xAE81FF,
	string = 0xE6DB74,
	keyword = 0xF92672,
}

local keywords = {
	"local", "for", "do", "if", "then", "while", "elseif",
	"and", "or", "not", "~", "&", "|", "^",
	">", "<", "<=", ">=", "==", "~="
}

local oldPalette = {}
for i=1, 16 do
	oldPalette[i] = gpu.palette[i]
	--gpu.palette[i] = 
end

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

local function drawBottomBar(state)
	gpu.fill(1, rh, rw, 1, 0xFFFFFF)
	local text = file .. " - Line " .. cy .. ", Column " .. cx
	if state == "save" then
		text = text .. " - Saved"
	end
	gpu.drawText(1, rh, text, 0)
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

local function save()
	local stream = io.open(file, "w")
	for _, line in pairs(lines) do
		stream:write(line .. "\n")
	end
	stream:close()
end

local function drawLine(y, line)
	shell.setCursor(1, y)
	io.stdout:write(line)
end

local function width(line)
	return unicode.wlen(line:gsub("\t", "    "))
end

local function charPosition(line, cx)
	local pos = 0
	local i = 1
	while i <= cx do
		pos = pos + 1
		if line:sub(pos, pos) == "\t" then
			i = i + 4
		else
			i = i + 1
		end
	end
	return pos
end

---------------------------------------------

do
	local b = io.open(file)
	lines = b:lines()
	b:close()
end

gpu.fill(1, 1, 160, 50, colorScheme.background)
shell.setCursor(1, 1)
drawText()
drawBottomBar()

local function eraseCursor()
	gpu.setColor(colorScheme.background)
	gpu.setForeground(colorScheme.foreground)
	gpu.drawText(cx, cy-sy+1, curC)
end

while true do
	local evt = table.pack(event.pull(0.5))
	local name = evt[1]
	if name == "interrupt" then
		break
	end
	if name == "key_down" then
		eraseCursor()
		local keyChar = evt[3]
		local keyCode = evt[4]
		if keyCode == 200 then -- up
			if cy > 1 then
				cy = cy - 1
				cx = math.min(width(lines[cy])+1, cx)
				if cy < sy then
					gpu.copy(1, 1, rw, rh-1, 0, 1)
					gpu.setColor(colorScheme.background)
					gpu.drawText(1, 1, (" "):rep(rw))
					drawLine(1, lines[cy])
					sy = sy - 1
				end
				drawBottomBar()
			end
		elseif keyCode == 203 then -- left
			if cx > 1 then
				local line = lines[cy]
				local idx = charPosition(lines[cy], cx-1)
				if line:sub(idx,idx) == "\t" then
					cx = math.max(1, cx - 4)
				else
					cx = cx - 1
				end
				drawBottomBar()
			end
		elseif keyCode == 205 then -- right
			if cx <= width(lines[cy]) then
				local line = lines[cy]
				local idx = charPosition(lines[cy], cx)
				if line:sub(idx,idx) == "\t" then
					cx = cx + 4
				else
					cx = cx + 1
				end
				drawBottomBar()
			end
		elseif keyCode == 208 then -- down
			if cy < #lines then
				cy = cy + 1
				cx = math.min(width(lines[cy])+1, cx)
				if cy-sy+1 > rh-1 then
					gpu.copy(1, 1, rw, rh-1, 0, -1)
					gpu.setColor(colorScheme.background)
					gpu.drawText(1, rh-1, (" "):rep(rw))
					drawLine(rh-1, lines[cy])
					sy = sy + 1
				end
				drawBottomBar()
			end
		elseif keyCode == 201 then -- PgUp

		elseif keyCode == 209 then -- PgDown

		elseif keyCode == 199 then -- Start
			cx = 1
			drawBottomBar()
		elseif keyCode == 207 then -- End
			cx = width(lines[cy])+1
			drawBottomBar()
		else
			if keyChar == 8 then
				if cx > 1 then
					local pos = charPosition(lines[cy], cx)
					lines[cy] = unicode.sub(lines[cy], 1, pos-2) .. unicode.sub(lines[cy], pos)
					gpu.setColor(colorScheme.background)
					gpu.drawText(1, cy-sy+1, (" "):rep(rw))
					drawLine(cy-sy+1, lines[cy])
					cx = cx - 1
				elseif cx == 1 then
					gpu.copy(1, cy-sy+1, rw, rh-(cy-sy+1), 0, -1)
					local line = lines[cy]
					table.remove(lines, cy)
					cy = cy - 1
					cx = width(lines[cy])+1
					lines[cy] = lines[cy] .. line
					drawLine(cy-sy+1, lines[cy])
				end
			elseif keyChar == 127 then
				lines[cy] = lines[cy]:sub(1,cx-1) .. lines[cy]:sub(cx+1)
				gpu.setColor(colorScheme.background)
				gpu.drawText(1, cy-sy+1, lines[cy] .. (" "):rep(rw-#lines[cy]))
			elseif keyChar == 13 then 
				local p1 = lines[cy]:sub(1, cx-1)
				local p2 = lines[cy]:sub(cx)
				lines[cy] = p1
				gpu.setColor(colorScheme.background)
				gpu.drawText(1, cy-sy+1, (" "):rep(rw))
				drawLine(cy-sy+1, lines[cy])
				cy = cy + 1
				table.insert(lines, cy, p2)
				gpu.copy(1, cy-sy+1, rw, rh-(cy-sy+1), 0, 1)
				gpu.drawText(1, cy-sy+1, (" "):rep(rw))
				drawLine(cy-sy+1, lines[cy])
				drawBottomBar()
				cx = 1
				if cy-sy+1 > rh-1 then
					sy = sy + 1
				end
			elseif keyboard.isCtrlPressed() and keyboard.isPressed(31) then
				save()
				drawBottomBar("save")
			elseif keyChar >= 0x20 then
				local pos = charPosition(lines[cy], cx)
				lines[cy] = unicode.sub(lines[cy], 1, pos-1) .. unicode.char(evt[3]) .. unicode.sub(lines[cy], pos)
				gpu.setColor(colorScheme.background)
				drawLine(cy-sy+1, lines[cy])
				cx = cx + 1
			end
		end
		cur = true
	end
	if name == "key_down" or not name then
		if cur then
			gpu.setColor(0xFFFFFF)
			gpu.setForeground(0)
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
for i=1, 16 do
	gpu.palette[i] = oldPalette[i]
end
