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

function lib.lerp(t, a, b)
	return t * b + (1 - t) * a
end

function lib.lerpRGB(t, a, b)
	local aR = bit32.band(bit32.rshift(a, 16), 0xFF)
	local aG = bit32.band(bit32.rshift(a, 8), 0xFF)
	local aB = bit32.band(a, 0xFF)

	local bR = bit32.band(bit32.rshift(b, 16), 0xFF)
	local bG = bit32.band(bit32.rshift(b, 8), 0xFF)
	local bB = bit32.band(b, 0xFF)

	local r = lib.lerp(t, aR, bR)
	local g = lib.lerp(t, aG, bG)
	local b = lib.lerp(t, aB, bB)

	return bit32.bor(
		bit32.lshift(r, 16),
		bit32.lshift(g, 8),
		b
	)
end

function lib.component()
	local comp = {}
	comp.context = nil
	comp.x = 1
	comp.y = 1
	comp.width = 1
	comp.height = 1
	comp.background = 0x000000
	comp.foreground = 0xFFFFFF
	comp.listeners = {}
	comp.dirty = true

	-- Returns true if the contetx has been re-created
	function comp:initRender()
		local mustReupdate = false
		if self.context and not draw.isContextOpened(self.context) then
			print(tostring(self.context) .. " doesn't exist!")
			self.context = nil
		end
		if self.context ~= nil then
			local x,y,w,h = draw.getContextBounds(self.context)
			if x~=self.x or y~=self.y or w~=self.width or h~=self.height then
				draw.moveContext(self.context, self.x, self.y)
				if w~=self.width or h~=self.height then
					draw.closeContext(self.context)
					self.context = nil
				end
			end
		end
		if self.context == nil  then
			local parentContext = (self.parent and self.parent.context) or nil
			--[[if config.accelerationMethod == 1 then -- full usage of VRAM
				parentContext = nil
			end]]
			self.context = draw.newContext(self.x, self.y, self.width, self.height, 0, parentContext)
			self.canvas = draw.canvas(self.context)
			return true
		end
		return false
	end

	-- Call this method if you want to draw a component to screen but don't need it to be up-to-date.
	function comp:redraw()
		if self.context == nil or self.dirty == true then -- context has been (re-)created, previous data is lost
			self:_render()
		else
			draw.redrawContext(self.context) -- can benefit of optimization if GPU buffers are present
		end
	end

	function comp:_render()
		self:initRender()
		self:render()
		draw.drawContext(self.context)
	end

	-- This function should not be called directly
	function comp:render()
		error("component should implement the render() function")
	end

	function comp:dispose(recursive)
		if self.context then
			draw.closeContext(self.context)
			self.context = nil
		end
		if recursive == true and self.childrens then
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
		return table.insert(self.childrens, component)
	end
	
	comp._render = function(self)
		self:initRender()
		self.canvas.fillRect(1, 1, self.width, self.height, self.background)
		draw.drawContext(self.context) -- finally draw
		for _, c in pairs(self.childrens) do
			c.x = c.x + self.x - 1
			c.y = c.y + self.y - 1
			c:_render()
			c.x = c.x - self.x + 1
			c.y = c.y - self.y + 1
		end
	end
	
	comp.listeners["*"] = function(self, ...)
		local id = select(1, ...)
		for _, c in pairs(comp.childrens) do
			if c.listeners[id] then
				c.listeners[id](c, ...)
				goto continue
			end
			if c.listeners["*"] then
				c.listeners["*"](c, ...)
			end
			::continue::
		end
	end
	return comp
end

function lib.label(text)
	local comp = lib.component()
	comp.text = text or "Label"
	comp.render = function(self)
		self.canvas.drawText(1, 1, self.text, self.foreground, self.background) -- draw text
	end
	return comp
end

function lib.progressBar(maxProgress)
	local pb = lib.component()
	pb.progress = 0
	pb.foreground = 0x00FF00
	pb.render = function(self)

	end
	return pb
end

function lib.tabBar()
	local comp = lib.container()
	comp.currentTab = 1
	comp.tabNames = {}

	function comp:addTab(tab, name)
		checkArg(1, tab, "table")
		checkArg(2, name, "string")

		local idx = #self.childrens + 1
		self:add(tab)
		self.tabNames[idx] = name
	end

	function comp:switchTo(index)
		self.currentTab = index
		self.dirty = true
		self:_render() -- TODO: request redraw instead
	end

	function comp:_render()
		-- Draw tab bar
		local oldHeight = self.height
		--self.height = 1

		self:initRender()
		self.canvas.fillRect(1, 1, self.width, 1, self.background)
		local x = 1
		for k, v in ipairs(comp.tabNames) do
			local color = lib.lerpRGB(0.6, self.background, self.foreground)
			if self.currentTab == k then
				color = self.foreground
			end

			self.canvas.drawText(x, 1, v, color)
			x = x + v:len() + 1
		end
		draw.drawContext(self.context)

		--self.height = oldHeight

		if not self.childrens[self.currentTab] then
			self.currentTab = 1
		end

		local tab = self.childrens[self.currentTab]
		if tab then
			tab.x = self.x
			tab.y = self.y + 1
			tab.width = self.width
			tab.height = self.height - 1
			tab:_render()
			tab.x = 1
			tab.y = 1
		end
	end

	comp.listeners["touch"] = function(self, _, screenAddress, x, y, button, playerName)
		if y == 1 then -- tab bar
			local tx = 1
			for k, v in ipairs(self.tabNames) do
				if x >= tx and x < tx + v:len() then
					self.currentTab = k
					self:_render() -- TODO: request redraw instead
					break
				end
				tx = tx + v:len() + 1
			end
		end
	end

	return comp
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
