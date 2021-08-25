--- Library to handle the system clipboard
-- @module clipboard
-- @alias lib

local lib = {}
local clipboard = {}
local cutted = false
local inserted = false
local event = require("event")

--- This event is emitted to all processes when the external clipboard is
-- pasted using middle mouse button or when Ctrl+V is pressed and the OS clipboard is not empty.
-- @event paste_trigger
-- @number uptime the uptime corresponding to when the event was emitted

--- Cut the given object.
-- This means that when the object is pasted, it will also be removed from the clipboard.
-- @param obj Object to be put in clipboard
-- @string t MIME type of the object
function lib.cut(obj, t)
	cutted = true
	lib.copy(obj, t)
end

--- Copy the given object.
-- @param obj Object to be put in clipboard
-- @string t MIME type of the object
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

--- Returns whether if the user wants to paste the clipboard.
-- This function is the polling equivalent of the `paste_trigger` event.
-- @treturn bool Whether the clipboard should be paster
function lib.pasteTriggered()
	if inserted then
		return true
	end
	return clipboard ~= nil and require("keyboard").isCtrlPressed() and require("keyboard").isPressed(67)
end

--- Get the current content of the clipboard.
-- If the clipboard object was cutted, then this function also removes it from the clipboard.
-- @return clipboard content
function lib.paste()
	local clip = clipboard
	if cutted then
		clipboard = nil
	end
	cutted = false
	inserted = false
	return clip
end

--- Lookup the current clipboard object
-- @return clipboard content
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