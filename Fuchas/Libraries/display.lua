-- Allows multiples interface running on one screen/gpu.
-- They will be switched using Ctrl+Shift+F<1-7>
local event = require("event")
local kbd = require("keyboard")
local gpu = component.proxy(component.list("gpu")())
local lib = {}
local gpus = {}
local active = 1

local function createVirtualGPU()
	return {
		bg = 0x000000,
		fg = 0xFFFFFF,
		active = false,
		bind = function() end,
		getScreen = function()
			return gpu.getScreen()
		end,
		getBackground = function()
			return bg
		end,
		getForeground = function()
			return fg
		end,
		setBackground = function(bg, isPal)
			
		end,
		setForeground = function(fg, isPal)
			
		end,
		switchTo = function()
		end
	}
end

function lib.switch(id)
	for i=1, 7 do
		gpus[i].active = false
	end
	gpus[id].active = true
	gpus[id].switchTo()
end

for i=1, 7 do
	gpus[i] = createVirtualGPU()
end

event.listen("key_down", function()
	if kbd.isCtrlPressed() then
		if kbd.isShiftPressed() then
			for i=1, 7 do
				if kbd.isPressed(0x3A + i) then
					
				end
			end
		end
	end
end)

return lib