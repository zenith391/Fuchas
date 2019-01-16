local lib = {}
local cui = require("OCX/ConsoleUI")
local event = require("event")
local cursor = {
	x = 1,
	y = 1
}

function lib.getCursor()
	return cursor.x, cursor.y
end

function lib.setCursor(col, row)
	cursor.x = col
	cursor.y = row
end

function lib.clear()
	cui.clear(0x000000)
	lib.setCursor(1, 1)
end

function lib.read()
	local c = ""
	while c ~= '\n' do
		print(event.pull())
	end
end

return lib