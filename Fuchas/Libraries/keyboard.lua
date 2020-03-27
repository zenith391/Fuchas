local keyboard = {}

local isCtrl = false
local isAlt = false
local isShift = false
local pressedKeys = {}

function keyboard.isPressed(ch)
	if pressedKeys[ch] then
		return true
	else
		return false
	end
end

function keyboard.getchar(value)
	return keyboard.keys[value]
end

function keyboard.isAltPressed()
	return isAlt
end

function keyboard.isCtrlPressed()
	return isCtrl
end

function keyboard.isShiftPressed()
	return isShift
end

function keyboard.resetInterrupted()
	isAlt = false
	isShift = false
	isCtrl = false
end

require("event").listen("key_down", function(_, _,  ch, code, player)
	pressedKeys[code] = true
	if code == 29 then -- ctrl left/right
		isCtrl = true
	elseif code == 42 then -- shift left/right
		isShift = true
	elseif code == 56 then -- alt left/right
		isAlt = true
	end
end)

require("event").listen("key_up", function(_, _,  ch, code, player)
	pressedKeys[code] = false
	if code == 29 then -- ctrl left/right
		isCtrl = false
	elseif code == 42 then -- shift left/right
		isShift = false
	elseif code == 56 then -- alt left/right
		isAlt = false
	end
end)

return keyboard
