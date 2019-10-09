local drv = {}
local comp = component.proxy(...)

local function getTier()
	local rw, rh = comp.maxResolution()
	if rw == 40 and rh == 16 then
		return 1
	elseif rw == 80 and rh == 25 then
		return 2
	elseif rw == 160 and rh == 50 then
		return 3
	end
end

local function getColors()
	if getTier() == 1 then
		return 2
	elseif getTier() == 2 then
		return 16
	elseif getTier() == 3 then
		return 256
	end
end

local function getPalettedColors()
	if getTier() == 1 then
		return 2
	else
		return 16
	end
end

function drv.drawText(x, y, text, fg)
	if fg then
		comp.setForeground(fg)
	end
	comp.set(x, y, tostring(text))
end

function drv.setColor(rgb, palette)
	comp.setBackground(rgb, palette)
end

drv.palette = setmetatable({}, {
	__index = function(table, key)
		if type(key) == "number" then
			if key > 0 and key <= getColors() then
				return comp.getPaletteColor(key)
			end
		end
	end,
	__newindex = function(table, key, value)
		if type(key) == "number" then
			if key > 0 and key <= getPalettedColors() then
				comp.setPaletteColor(key, value)
			end
		end
	end
})


function drv.getRank() -- used by "driver" library to choose best driver
	return 1
end

function drv.getCapabilities()
    return {
        paletteSize = getColors(),
        hasPalette = true,
        hasEditablePalette = true,
        editableColors = getPalettedColors(),
        hardwareText = true
    }
end

function drv.getName() -- from DeviceInfo
	return "MightyPirates GmbH & Co. KG Driver for MPG " .. tostring(getTier()*1000) .. " GTZ"
end

return component.isAvailable("gpu"), "gpu", drv