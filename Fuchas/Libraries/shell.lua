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
	local s = ""
	while c ~= '\r' do -- '\r' == Enter
		local a, b, d = event.pull()
		if a == "key_down" then
			if d ~= 0 then
				c = string.char(d)
				if c ~= '\r' then
					if d == 8 then
						if s:len() > 0 then
							s = s:sub(1, s:len() - 1)
							x = x - 1
							write(" ")
							x = x - 1
						end
					else
						s = s .. c
						write(c)
					end
				end
			end
		end
	end
	return s
end

return lib