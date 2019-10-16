local drv = {}
local cp, comp = ...
comp = cp.proxy(comp)

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

function drv.getColors()
	if getTier() == 1 then
		return 2
	elseif getTier() == 2 then
		return 16
	elseif getTier() == 3 then
		return 256
	end
end

function drv.getPalettedColors()
	if getTier() == 1 then
		return 2
	else
		return 16
	end
end

function drv.getResolution()
	return comp.getViewport()
end

function drv.setResolution(w, h)
	comp.setViewport(w, h)
end

function drv.maxResolution()
	return comp.maxResolution()
end

function drv.fillChar(x, y, w, h, ch)
	comp.fill(x, y, w, h, ch)
end

function drv.fill(x, y, w, h, fg)
	if fg then
		comp.setForeground(fg)
	end
	drv.fillChar(x, y, w, h, ' ')
end

function drv.get(x, y)
	return comp.get(x, y)
end

function drv.setForeground(rgb, paletted)
	comp.setForeground(rgb, paletted)
end

function drv.drawText(x, y, text, fg)
	if fg then
		comp.setForeground(fg)
	end
	comp.set(x, y, tostring(text))
end

function drv.getColor()
	return comp.getBackground(), comp.getForeground()
end

function drv.setColor(rgb, paletted)
	comp.setBackground(rgb, paletted)
end

drv.palette = setmetatable({}, {
	__index = function(table, key)
		if type(key) == "number" then
			if key > 0 and key <= drv.getColors() then
				return comp.getPaletteColor(key)
			end
		end
	end,
	__newindex = function(table, key, value)
		if type(key) == "number" then
			if key > 0 and key <= drv.getPalettedColors() then
				comp.setPaletteColor(key, value)
			end
		end
	end
})


function drv.getRank() -- used by "driver" library to choose best driver
	return 1
end

function drv.isCompatible()
	return comp.type == "gpu"
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

return drv