local gpu = component.proxy(component.list("gpu")())
local width, height = gpu.getResolution()
local lib = {}

function lib.clear(color)
	gpu.setBackground(color)
	gpu.fill(1, 1, width, height, " ")
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
		gpu.set(comp.x, comp.y, "╔")
		gpu.set(comp.x + comp.width, comp.y, "╗")
		gpu.fill(comp.x + 1, comp.y, comp.width - 1, 1, "═")
		gpu.fill(comp.x + 1, comp.y + comp.height, comp.width - 1, 1, "═")
		gpu.set(comp.x, comp.y + comp.height, "╚")
		gpu.set(comp.x + comp.width, comp.y + comp.height, "╝")
		gpu.fill(comp.x, comp.y + 1, 1, comp.height - 1, "║")
		gpu.fill(comp.x + comp.width, comp.y + 1, 1, comp.height - 1, "║")
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
		gpu.fill(pb.x + 1, pb.y + 1, (pb.progress / maxProgress) * pb.width - 1, pb.height - 1, "█")
	end
	return pb
end

return lib