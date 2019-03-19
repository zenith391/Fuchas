local draw = require("OCX/OCDraw")
local width, height = gpu.getResolution()
local lib = {}

function lib.getWidth()
	return width
end

function lib.getHeight()
	return height
end

function lib.component()
	local comp = {}
	comp.render = function() end
	comp.context = nil
	comp.x = 0
	comp.y = 0
	comp.width = 0
	comp.height = 0
	comp.background = 0x000000
	comp.foreground = 0xFFFFFF
	comp.dirty = true
	comp.dispose = function()
		if comp.context then
			draw.closeContext(comp.context)
		end
	end
	return comp
end

function lib.label(text)
	local comp = lib.component()
	comp.text = text
	comp.render = function()
		if not comp.context then
			comp.context = draw.newContext()
		end
		draw.
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