local gpu = component.proxy(component.list("gpu")())
local width, height = gpu.getResolution()
local lib = {}

function lib.clear(color)
	gpu.setBackground(color)
	gpu.fill(1, 1, width, height, " ")
end

function lib.getWidth()
	local w = gpu.getResolution()
	return w
end

function lib.getHeight()
	local _, h = gpu.getResolution()
	return h
end

function lib.drawBorder(x, y, width, height)
	gpu.set(x, y, "╔")
	gpu.set(x + width, y, "╗")
	gpu.fill(x + 1, y, width - 1, 1, "═")
	gpu.fill(x + 1, y + height, width - 1, 1, "═")
	gpu.set(x, y + height, "╚")
	gpu.set(x + width, y + height, "╝")
	gpu.fill(x, y + 1, 1, height - 1, "║")
	gpu.fill(x + width, y + 1, 1, height - 1, "║")
end

function lib.component()
	local comp = {}
	comp.render = function() end
	comp.x = 0
	comp.y = 0
	comp.width = 0
	comp.height = 0
	comp.renderBorder = function()
		gpu.setBackground(comp.background)
		gpu.setForeground(0xFFFFFF)
		lib.drawBorder(comp.x, comp.y, comp.width, comp.height)
	end
	comp.background = 0x000000
	comp.foreground = 0xFFFFFF
	comp.dirty = true
	return comp
end

function lib.label(text)
	local comp = lib.component()
	comp.text = text
	comp.render = function()
		gpu.setForeground(comp.foreground)
		gpu.setBackground(comp.background)
		gpu.set(comp.x, comp.y, comp.text)
	end
	return comp
end

function lib.progressBar(maxProgress)
	local pb = lib.component()
	pb.progress = 0
	pb.maxProgress = maxProgress
	pb.foreground = 0x00FF00
	pb.render = function()
		gpu.setBackground(pb.background)
		gpu.setForeground(0xFFFFFF)
		gpu.fill(pb.x + 1, pb.y + 1, pb.width - 1, pb.height - 1, " ")
		
		if pb.dirty == true then
			gpu.fill(pb.x, pb.y, pb.width, pb.height, " ")
			pb.renderBorder()
			pb.dirty = false
		end
		
		gpu.setForeground(pb.foreground)
		gpu.fill(pb.x + 1, pb.y + 1, (pb.progress / pb.maxProgress) * pb.width - 1, pb.height - 1, "█")
	end
	return pb
end

function lib.button(text)
	local btn = lib.component()
	btn.text = text
	btn.foreground = 0xFFFFFF
	btn.render = function()
		
	end
	btn.ontouch = nil
	btn.event = function(pack)
		local id = pack[1]
		if id == "touch" then
			if btn.ontouch then
				btn.ontouch()
			end
		end
	end
	return btn
end

return lib