local shell = require("shell")
local filesystem = require("filesystem")
local event = require("event")
local keyboard = require("keyboard")
local gpu = component.getPrimary("gpu")
local rw, rh = gpu.getResolution()

local args, options = shell.parse(...)
local file = args[1]

if file == nil then
	io.stderr:write("Usage: edit <filename>\n")
	return
end

file = shell.resolve(file)

if filesystem.isDirectory(file) then
	io.stderr:write("path is directory\n")
end

local text = ""

local function drawBottomBar()
	gpu.setBackground(0xFFFFFF)
	gpu.setForeground(0x000000)
	gpu.fill(1, rh, rw, 1, " ")
end

---------------------------------------------

do
	local b = io.open(file)
	text = b:read("a")
	b:close()
end

shell.clear()
drawBottomBar()

while true do
	local evt = table.pack(event.pull())
	local name = evt[1]
	gpu.set(1, 1, tostring(keyboard.isShiftPressed()))
	gpu.set(1, 2, tostring(keyboard.isCtrlPressed()))
	gpu.set(1, 3, tostring(keyboard.isAltPressed()))
	if name == "key_down" then
		local ch = evt[3]
		ch = string.char(ch)
		gpu.set(1, 4, tostring(evt[4]))
		if ch == "e" then
			break
		end
	end
	--coroutine.yield()
end

shell.clear()