local shell = require("shell")
local filesystem = require("filesystem")
local event = require("event")
local keyboard = require("keyboard")
local gpu = component.getPrimary("gpu")
local rw, rh = gpu.getResolution()
local cursor = 1

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
	gpu.set(1, rh, file)
	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
end

local function drawText(x, y, text)
	shell.setCursor(x, y)
	io.stdout:write(text)
end

---------------------------------------------

do
	local b = io.open(file)
	_, text = b:read("a")
	b:close()
end

shell.clear()
drawText(1, 1, text)
drawBottomBar()

while true do
	local evt = table.pack(event.pull())
	local name = evt[1]
	if name == "key_down" then
		local ch = evt[3]
		ch = string.char(ch)
		text = text .. ch
		drawText(1, 1, text)
	end
end

shell.clear()