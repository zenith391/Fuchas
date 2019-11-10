local lib = {}
local clipboard = {}
local cutted = false
local event = require("event")

function lib.cut(obj, t)
	cutted = true
	lib.copy(obj, t)
end

function lib.copy(obj, t)
	if not t then
		t = "text/txt"
		if type(obj) == "string" then
			t = "text/txt"
		elseif type(obj) == "table" then
			t = "application/lua-table"
		elseif type(obj) == "function" then
			t = "application/lua"
		end
	end
	if t == "text/txt" then obj = tostring(obj) end
	clipboard = {
		object = obj,
		type = t
	}
end

-- Lookup the current clipboard object, if it was cutted, then also removes it.
function lib.paste()
	local clip = clipboard
	if cutted then
		cutted = false
		clipboard = nil
	end
	return clip
end

-- Lookup the current clipboard object
function lib.retrieve()
	return clipboard
end

event.listen("shutdown", function()
	-- TODO: save to file
end)

return lib