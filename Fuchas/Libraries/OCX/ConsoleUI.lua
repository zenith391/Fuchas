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

function lib.container()
	local comp = lib.component()
	comp.childs = {}
	comp.focus = nil
	comp.add = function(cp)
		table.insert(comp.childs, cp)
		cp.parent = comp
		comp.focus = cp
	end
	comp.remove = function(cp)
		for k, v in pairs(comp.childs) do
			if v == cp then
				v.parent = nil
				table.remove(comp.childs, k)
			end
		end
	end
	comp.render = function()
		for _, v in pairs(comp.childs) do
			v.render()
		end
	end
	comp.event = function(t)
		local id = t[1]
		if id == "touch" then
			comp.focus = nil
		end
		for _, v in pairs(comp.childs) do
			if id == "touch" then
				local x = t[3]
				local y = t[4]
				if x >= v.x and x < v.x + v.width then
					if y >= v.y and y < v.y + v.height then
						comp.focus = v
					end
				end
			end
			v.event(t)
		end
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

function lib.textField()
	local comp = lib.component()
	comp.text = ""
	comp.height = 1
	comp.render = function()
		local focused = true
		if comp.parent then
			if comp ~= comp.parent.focus then
				focused = false
			end
		end
		gpu.setBackground(comp.background)
		gpu.setForeground(comp.foreground)
		if focused then
			gpu.setBackground(0xEEEEEE)
		end
		gpu.fill(comp.x, comp.y, comp.width, 1, " ")
		gpu.set(comp.x, comp.y, comp.text)
	end
	comp.event = function(pack)
		gpu.setForeground(0xFFFFFF)
		local focused = true
		if comp.parent then
			if comp ~= comp.parent.focus then
				focused = false
			end
		end
		local id = pack[1]
		if focused then
			if id == "key_down" then
				local ch = pack[3]
				if ch ~= 0 then
					if ch == 8 then
						if comp.text:len() > 0 then
							comp.text = comp.text:sub(1, comp.text:len() - 1)
						end
					elseif comp.text:len() < comp.width then
						comp.text = comp.text .. string.char(ch)
					end
				end
			end
		end
	end
	return comp
end

function lib.button(text)
	local btn = lib.component()
	btn.text = text
	btn.foreground = 0xFFFFFF
	btn.height = 1
	btn.render = function()
		gpu.setBackground(btn.background)
		gpu.setForeground(0xFFFFFF)
		btn.width = string.len(btn.text)
		gpu.fill(btn.x, btn.y, string.len(btn.text), 1, " ")
		gpu.set(btn.x, btn.y, btn.text)
		btn.dirty = false
	end
	btn.ontouch = nil
	btn.event = function(pack)
		if btn.parent.focus == btn then
			btn.ontouch()
		end
	end
	return btn
end

return lib