local lib = {}
local clipboard = {}
local cutted = false
local inserted = false
local event = require("event")

function lib.cut(obj, t)
	cutted = true
	lib.copy(obj, t)
end

function lib.copy(obj, t)
	if not t then
		t = "text/string"
		if type(obj) == "string" then
			t = "text/string"
		elseif type(obj) == "table" then
			t = "application/lua-table"
		elseif type(obj) == "function" then
			t = "application/lua"
		end
	end
	if t == "text/string" then obj = tostring(obj) end
	clipboard = {
		object = obj,
		type = t
	}
end

function lib.pasteTriggered()
	if inserted then
		return true
	end
	return clipboard ~= nil and require("keyboard").isCtrlPressed() and require("keyboard").isPressed(67)
end

-- Lookup the current clipboard object, if it was cutted, then also removes it.
function lib.paste()
	local clip = clipboard
	if cutted then
		clipboard = nil
	end
	cutted = false
	inserted = false
	return clip
end

-- Lookup the current clipboard object
function lib.retrieve()
	return clipboard
end

event.listen("key_down", function()
	if clibpoard ~= nil and require("keyboard").isCtrlPressed() and require("keyboard").isPressed(65) then
		computer.pushSignal("paste_trigger", computer.uptime())
	end
end)

event.listen("clipboard", function(_, _, value)
	lib.copy(value)
	inserted = true
	computer.pushSignal("paste_trigger", computer.uptime())
end)

return lib