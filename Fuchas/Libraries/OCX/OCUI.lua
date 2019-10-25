-- Shared GUI components for any interfaces (Concert and Androoid)

local draw = require("OCX/OCDraw")
local width, height = component.gpu.getResolution()
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
	comp.x = 1
	comp.y = 1
	comp.width = 0
	comp.height = 0
	comp.background = 0x000000
	comp.foreground = 0xFFFFFF
	comp.listeners = {}
	comp.dirty = true
	comp.open = function(self)
		self:dispose()
		self.context = draw.newContext(self.x, self.y, self.width, self.height)
		self.canvas = draw.canvas(self.context)
	end
	comp.dispose = function(self)
		if self.context then
			draw.closeContext(self.context)
			self.context = nil
		end
	end
	return comp
end

function lib.container()
	local comp = lib.component()
	comp.childrens = {}
	
	comp.add = function(self, component)
		table.insert(self.childrens, component)
	end
	
	comp.render = function(self)
		-- container doesn't need a draw context
		if not self.context then -- init context if not yet
			self:open()
		end
		self.canvas.fillRect(1, 1, self.width, self.height, self.background) -- draw text
		draw.drawContext(self.context) -- finally draw
		for _, c in pairs(self.childrens) do
			c:render()
		end
	end
	
	comp.listeners["*"] = function(...)
		local id = select(1, ...)
		for _, c in pairs(comp.childrens) do
			if c.listeners["*"] then
				c.listeners["*"](...)
			end
			if c.listeners[id] then
				c.listeners[id](...)
			end
		end
	end
	return comp
end

function lib.label(text)
	local comp = lib.component()
	comp.text = text or "Label"
	comp.render = function(self)
		if not self.context then -- init context if not yet
			self:open()
		end
		self.canvas.drawText(1, 1, self.text, self.foreground, self.background) -- draw text
		draw.drawContext(self.context) -- finally draw
	end
	return comp
end

function lib.progressBar(maxProgress)
	local pb = lib.component()
	pb.progress = 0
	pb.foreground = 0x00FF00
	pb.render = function(self)
		if not self.context then
			self:open()
		end
		
	end
	return pb
end

return lib