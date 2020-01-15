-- Shared GUI components for any interfaces (Concert and Androad)

local draw = require("OCX/OCDraw")
local width, height = require("driver").gpu.getResolution()
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
	comp.width = 1
	comp.height = 1
	comp.background = 0x000000
	comp.foreground = 0xFFFFFF
	comp.listeners = {}
	comp.dirty = true
	comp.initRender = function(self)
		local mustReupdate = false
		if self.context then
			local x,y,w,h = draw.getContextBounds(self.context)
			if x~=self.x or y~=self.y or w~=self.width or h~=self.height then
				draw.moveContext(self.context, self.x, self.y)
				draw.setContextSize(self.context, self.width, self.height)
			end
		end
		if self.context == nil  then
			self.context = draw.newContext(self.x, self.y, self.width, self.height)
			self.canvas = draw.canvas(self.context)
		end
	end
	comp.dispose = function(self, recursive)
		if self.context then
			draw.closeContext(self.context)
			self.context = nil
		end
		if recursive and self.childrens then
			for k, v in pairs(self.childrens) do
				v:dispose(true)
			end
		end
	end
	return comp
end

function lib.container()
	local comp = lib.component()
	comp.childrens = {}
	
	comp.add = function(self, component)
		if not component then
			error("cannot add null to container")
		end
		component.parent = self
		table.insert(self.childrens, component)
	end
	
	comp.render = function(self)
		self:initRender()
		self.canvas.fillRect(1, 1, self.width, self.height, self.background)
		draw.drawContext(self.context) -- finally draw
		for _, c in pairs(self.childrens) do
			c.x = c.x + self.x - 1
			c.y = c.y + self.y - 1
			c:render()
			c.x = c.x - self.x + 1
			c.y = c.y - self.y + 1
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
		self:initRender()
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
		self:initRender()
	end
	return pb
end

function lib.menuBar()
	local comp = lib.container()
	local super = comp.render
	comp.render = function(self)
		if self.parent then
			self.width = self.parent.width
		end
		super(self)
	end
	comp.background = 0xC2C2C2
	return comp
end

return lib
