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
	comp.background = 0xFFFFFF
	comp.foreground = 0x000000
	comp.listeners = {}
	comp.clip = nil
	comp.dirty = true
	comp.unbuffered = false

	-- Returns true if the context has been re-created
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
					if self.invalidatedContext then
						self:invalidatedContext()
					end
					self.context = nil
				end
			end
		end
		if self.context == nil  then
			local parentContext = (self.parent and self.parent.context) or nil
			--[[if config.accelerationMethod == 1 then -- full usage of VRAM
				parentContext = nil
			end]]
			self.context = draw.newContext(self.x, self.y, self.width, self.height, self.unbuffered, parentContext)
			self.canvas = draw.canvas(self.context)
			if self.clip then
				draw.clipContext(self.context, self.clip)
			end
			return true
		end
		if self.clip then
			draw.clipContext(self.context, self.clip)
		end
		return false
	end

	-- Call this method if you want to draw a component to screen but don't need it to be up-to-date.
	function comp:redraw()
		if self.dirtyUpdate then -- function for containers so they can set themselves dirty if a child is dirty
			self:dirtyUpdate()
		end
		if self.parent and self.parent.context and not self.parent.rendering and self.dirty then
			self.parent:redraw()
			return
		end
		if self.context ~= nil then
			local x,y,w,h = draw.getContextBounds(self.context)
			if x ~= self.x or y ~= self.y then
				draw.moveContext(self.context, self.x, self.y)
			end
			if w ~= self.width or h ~= self.height then
				draw.closeContext(self.context)
				if self.invalidatedContext then
					self:invalidatedContext()
				end
				self.context = nil
			end
		end
		if self.context == nil or self.dirty == true then -- context has been (re-)created, previous data is lost
			self.dirty = false
			self:render()
		else
			if self.clip then
				draw.clipContext(self.context, self.clip)
			end
			draw.redrawContext(self.context) -- can benefit of optimization if GPU buffers are present
		end
	end

	function comp:render()
		self.rendering = true
		self:initRender()
		self:_render()
		draw.drawContext(self.context)
		self.rendering = false
	end

	-- This function should not be called directly
	function comp:_render()
		error("component should implement the _render() function")
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

-- Each component is on its own line

function lib.LineLayout(opts)
	return function(container)
		local flowY = 1
		for _, child in pairs(container.childrens) do
			child.width = container.width
			child.y = flowY
			flowY = flowY + child.height + (opts.spacing or 0)
		end
		container.height = flowY
	end
end

function lib.container()
	local comp = lib.component()
	comp.childrens = {}
	comp.layout = function(self) end -- no-op = fixed layout
	
	comp.add = function(self, component, pos)
		if not component then
			error("cannot add null to container")
		end
		component.parent = self
		return table.insert(self.childrens, pos or (#self.childrens+1), component)
	end
	
	comp._render = function(self)
		self:layout()
		self.canvas.fillRect(1, 1, self.width, self.height, self.background)
		draw.setBlockingDraw(self.context, true)
		draw.drawContext(self.context) -- just flush the background clear
		for _, c in pairs(self.childrens) do
			c.x = c.x + self.x - 1
			c.y = c.y + self.y - 1
			c:redraw()
			c.x = c.x - self.x + 1
			c.y = c.y - self.y + 1
		end
		draw.setBlockingDraw(self.context, false)
	end

	comp.dirtyUpdate = function(self)
		for _, c in pairs(self.childrens) do
			if c.dirtyUpdate then c:dirtyUpdate() end
			if c.dirty then
				self.dirty = true
			end
		end
	end

	comp.invalidatedContext = function(self)
		for _, c in pairs(self.childrens) do
			if c.context then
				draw.closeContext(c.context)
				if c.invalidatedContext then
					c:invalidatedContext()
				end
				c.context = nil
			end
		end
	end

	comp.listeners["touch"] = function(self, id, addr, x, y, ...)
		local oldFocused = self.focused
		self.focused = nil
		for _, child in pairs(self.childrens) do
			local cx = child.x
			local cy = child.y
			if x >= cx and y >= cy and x < cx + child.width and y < cy + child.height then
				self.focused = child
				break
			end
		end
		if self.focused ~= oldFocused then
			if oldFocused and oldFocused.listeners["defocus"] then
				oldFocused.listeners["defocus"](oldFocused, "defocus")
			end
			if self.focused and self.focused.listeners["focus"] then
				self.focused.listeners["focus"](self.focused, "focus")
			end
		end
	end
	
	comp.listeners["*"] = function(self, ...)
		local id = select(1, ...)
		if self.focused then
			if self.focused.listeners[id] then
				if id == "touch" or id == "drag" or id == "drop" then
					local id, addr, x, y = ...
					self.focused.listeners[id](self.focused, id, addr, x, y)
				else
					self.focused.listeners[id](self.focused, ...)
				end
			end
			if self.focused.listeners["*"] then
				self.focused.listeners["*"](self.focused, ...)
			end
		end
	end
	return comp
end

function lib.label(text)
	local comp = lib.component()
	comp.text = text or "Label"
	comp.width = comp.text:len()
	comp._render = function(self)
		self.canvas.drawText(1, 1, self.text, self.foreground, self.background) -- draw text
	end

	comp.setText = function(self, text)
		self.text = text
		self.width = text:len()
		self.dirty = true
	end
	return comp
end

function lib.listItem(label)
	local comp = lib.component()
	comp.text = label or "List Item"
	comp.width = comp.text:len()
	comp.height = 1
	comp.foreground = 0xFFFFFF
	comp.background = 0x808080
	comp.selected = false
	comp._render = function(self)
		local spaces = self.width - self.text:len()
		local bg = self.background
		if self.selected then bg = 0x2D2D2D end
		self.canvas.drawText(1, 1, self.text .. (" "):rep(spaces), self.foreground, bg) -- draw text
	end

	comp.setText = function(self, text)
		self.text = text
		self.width = text:len()
		self.dirty = true
	end

	comp.listeners["touch"] = function(self, ...)
		if not self.selected then
			self.selected = true
			self.dirty = true
			self:redraw()
		else
			self.selected = false
			self.dirty = true
			self:redraw()
		end
	end

	comp.listeners["defocus"] = function(self, ...)
		self.selected = false
		self.dirty = true
		self:redraw()
	end

	return comp
end

function lib.list()
	local comp = lib.container()
	comp.layout = lib.LineLayout({ spacing = 0})

	function comp:addItem(item)
		checkArg(1, item, "table")
		self:add(item)
	end

	return comp
end

function lib.button(label, onAction)
	local comp = lib.component()
	comp.background = 0x4D4D4D
	comp.foreground = 0xFFFFFF
	comp.label = label or "Button"
	comp.width = comp.label:len()
	comp.onAction = onAction
	comp._render = function(self)
		self.canvas.drawText(1, 1, " " .. self.label .. " ", self.foreground, self.background) -- draw button
	end

	comp.setText = function(self, label)
		self.label = label
		self.dirty = true
	end

	comp.listeners["touch"] = function(self, ...)
		if not self.oldBackground then
			self.oldBackground = self.background
			self.background = 0x2D2D2D
			self.dirty = true
			self:redraw()
		end
	end

	comp.listeners["drop"] = function(self, ...)
		self.background = self.oldBackground
		self.oldBackground = nil
		self.dirty = true
		self:redraw()
		if self.onAction then
			self:onAction()
		end
	end
	return comp
end

function lib.checkBox(label, onChanged)
	local comp = lib.component()
	comp.label = label or "Check Box"
	comp.width = comp.label:len() + 2
	comp.onChanged = onChanged
	comp.active = false
	comp._render = function(self)
		local check = unicode.char(0x2B55)
		if self.active then check = unicode.char(0x2B24) end
		self.canvas.drawText(1, 1, check .. " " .. self.label, self.foreground, self.background)
	end

	comp.setText = function(self, label)
		self.label = label
		self.width = label:len() + 4
		self.dirty = true
	end

	comp.listeners["touch"] = function(self, ...)
		self.active = not self.active
		self.dirty = true
		if self.onChanged then
			self:onChanged(self.active)
		end
		self:redraw()
	end
	return comp
end

function lib.progressBar(maxProgress)
	local pb = lib.component()
	pb.progress = 0
	pb.foreground = 0x00FF00
	pb._render = function(self)

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
		self:redraw()
	end

	function comp:render()
		-- Draw tab bar
		local oldHeight = self.height
		self.height = 1

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

		self.height = oldHeight

		if not self.childrens[self.currentTab] then
			self.currentTab = 1
		end

		local tab = self.childrens[self.currentTab]
		if tab then
			draw.setBlockingDraw(self.context, true)
			tab.x = self.x
			tab.y = self.y + 1
			tab.width = self.width
			tab.height = self.height - 1
			tab.parent = nil
			tab:render()
			tab.parent = self
			tab.x = 1
			tab.y = 1
			draw.setBlockingDraw(self.context, false)
		end
	end

	comp.listeners["touch"] = function(self, _, screenAddress, x, y, button, playerName)
		if y == 1 then -- tab bar
			local tx = 1
			for k, v in ipairs(self.tabNames) do
				if x >= tx and x < tx + v:len() then
					self:switchTo(k)
					self:redraw()
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
	comp._render = function(self)
		if self.parent then
			self.width = self.parent.width
		end
		super(self)
	end
	comp.background = 0xC2C2C2
	return comp
end

function lib.contextMenu(x, y, items)
	local contextMenu = require("window").newWindow()

	local width = 10
	for _, item in pairs(items) do
		width = math.max(item[1]:len() + 2, width)
	end

	contextMenu.undecorated = true
	contextMenu.x = x
	contextMenu.y = y
	contextMenu.width = width
	contextMenu.height = #items
	do
		local comp = lib.component()
		comp._render = function(self)
			self.canvas.fillRect(1, 1, self.width, self.height, 0xFFFFFF)
			for k, v in pairs(items) do
				local name = v[1]
				local y = k
				self.canvas.drawText(2, y, name, 0x000000)
			end
		end
		comp.listeners["defocus"] = function(self, name, self, new)
			if contextMenu.visible then
				contextMenu:hide()
			end
		end
		comp.listeners["touch"] = function(self, name, _, x, y, button)
			if button == 0 then
				for k, v in pairs(items) do
					local name = v[1]
					local cy = 2 + k
					if x > 1 and x < 1+name:len() and y == cy then
						-- TODO
					end
				end
			end
		end
		comp.background = 0xFFFFFF
		contextMenu.container = comp
	end

	return contextMenu
end

return lib
