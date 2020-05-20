local cp = ...
local fullPalette = {0x000000, 0x000040, 0x000080, 0x0000BF, 0x0000FF, 0x002400, 0x002440, 0x002480, 0x0024BF, 0x0024FF, 0x004900, 0x004940, 0x004980, 0x0049BF, 0x0049FF, 0x006D00, 0x006D40, 0x006D80, 0x006DBF, 0x006DFF, 0x009200, 0x009240, 0x009280, 0x0092BF, 0x0092FF, 0x00B600, 0x00B640, 0x00B680, 0x00B6BF, 0x00B6FF, 0x00DB00, 0x00DB40, 0x00DB80, 0x00DBBF, 0x00DBFF, 0x00FF00, 0x00FF40, 0x00FF80, 0x00FFBF, 0x00FFFF, 0x0F0F0F, 0x1E1E1E, 0x2D2D2D, 0x330000, 0x330040, 0x330080, 0x3300BF, 0x3300FF, 0x332400, 0x332440, 0x332480, 0x3324BF, 0x3324FF, 0x334900, 0x334940, 0x334980, 0x3349BF, 0x3349FF, 0x336D00, 0x336D40, 0x336D80, 0x336DBF, 0x336DFF, 0x339200, 0x339240, 0x339280, 0x3392BF, 0x3392FF, 0x33B600, 0x33B640, 0x33B680, 0x33B6BF, 0x33B6FF, 0x33DB00, 0x33DB40, 0x33DB80, 0x33DBBF, 0x33DBFF, 0x33FF00, 0x33FF40, 0x33FF80, 0x33FFBF, 0x33FFFF, 0x3C3C3C, 0x4B4B4B, 0x5A5A5A, 0x660000, 0x660040, 0x660080, 0x6600BF, 0x6600FF, 0x662400, 0x662440, 0x662480, 0x6624BF, 0x6624FF, 0x664900, 0x664940, 0x664980, 0x6649BF, 0x6649FF, 0x666D00, 0x666D40, 0x666D80, 0x666DBF, 0x666DFF, 0x669200, 0x669240, 0x669280, 0x6692BF, 0x6692FF, 0x66B600, 0x66B640, 0x66B680, 0x66B6BF, 0x66B6FF, 0x66DB00, 0x66DB40, 0x66DB80, 0x66DBBF, 0x66DBFF, 0x66FF00, 0x66FF40, 0x66FF80, 0x66FFBF, 0x66FFFF, 0x696969, 0x787878, 0x878787, 0x969696, 0x990000, 0x990040, 0x990080, 0x9900BF, 0x9900FF, 0x992400, 0x992440, 0x992480, 0x9924BF, 0x9924FF, 0x994900, 0x994940, 0x994980, 0x9949BF, 0x9949FF, 0x996D00, 0x996D40, 0x996D80, 0x996DBF, 0x996DFF, 0x999200, 0x999240, 0x999280, 0x9992BF, 0x9992FF, 0x99B600, 0x99B640, 0x99B680, 0x99B6BF, 0x99B6FF, 0x99DB00, 0x99DB40, 0x99DB80, 0x99DBBF, 0x99DBFF, 0x99FF00, 0x99FF40, 0x99FF80, 0x99FFBF, 0x99FFFF, 0xA5A5A5, 0xB4B4B4, 0xC3C3C3, 0xCC0000, 0xCC0040, 0xCC0080, 0xCC00BF, 0xCC00FF, 0xCC2400, 0xCC2440, 0xCC2480, 0xCC24BF, 0xCC24FF, 0xCC4900, 0xCC4940, 0xCC4980, 0xCC49BF, 0xCC49FF, 0xCC6D00, 0xCC6D40, 0xCC6D80, 0xCC6DBF, 0xCC6DFF, 0xCC9200, 0xCC9240, 0xCC9280, 0xCC92BF, 0xCC92FF, 0xCCB600, 0xCCB640, 0xCCB680, 0xCCB6BF, 0xCCB6FF, 0xCCDB00, 0xCCDB40, 0xCCDB80, 0xCCDBBF, 0xCCDBFF, 0xCCFF00, 0xCCFF40, 0xCCFF80, 0xCCFFBF, 0xCCFFFF, 0xD2D2D2, 0xE1E1E1, 0xF0F0F0, 0xFF0000, 0xFF0040, 0xFF0080, 0xFF00BF, 0xFF00FF, 0xFF2400, 0xFF2440, 0xFF2480, 0xFF24BF, 0xFF24FF, 0xFF4900, 0xFF4940, 0xFF4980, 0xFF49BF, 0xFF49FF, 0xFF6D00, 0xFF6D40, 0xFF6D80, 0xFF6DBF, 0xFF6DFF, 0xFF9200, 0xFF9240, 0xFF9280, 0xFF92BF, 0xFF92FF, 0xFFB600, 0xFFB640, 0xFFB680, 0xFFB6BF, 0xFFB6FF, 0xFFDB00, 0xFFDB40, 0xFFDB80, 0xFFDBBF, 0xFFDBFF, 0xFFFF00, 0xFFFF40, 0xFFFF80, 0xFFFFBF, 0xFFFFFF}

local spec = {}

local function getTier(comp)
	local rw, rh = comp.maxResolution()
	if rw == 40 and rh == 16 then
		return 1
	elseif rw == 80 and rh == 25 then
		return 2
	elseif rw == 160 and rh == 50 then
		return 3
	end
end

function spec.getRank() -- used by "driver" library to choose best driver
	return 1
end

function spec.isCompatible(address)
	return cp.proxy(address).type == "gpu"
end

function spec.getName() -- from DeviceInfo
	return "MightyPirates GmbH & Co. KG Driver for MPG GTZ"
end

function spec.new(address)
	local comp = cp.proxy(address)
	local drv = {}
	local buffers = {}
	local fg = -1
	local bg = -1

	function drv.getColors()
		if getTier(comp) == 1 then
			return 2
		elseif getTier(comp) == 2 then
			return 16
		elseif getTier(comp) == 3 then
			return 256
		end
	end

	function drv.getPalettedColors()
		if getTier(comp) == 1 then
			return 2
		else
			return 16
		end
	end

	function drv.getResolution(buffer)
		if buffer then
			return comp.getBufferSize(buffer)
		else
			return comp.getViewport()
		end
	end

	function drv.setResolution(w, h)
		comp.setViewport(w, h)
	end

	function drv.maxResolution()
		return comp.maxResolution()
	end

	function drv.fillChar(x, y, w, h, ch)
		if h == 1 then
			comp.set(x, y, ch:rep(w))
		else
			comp.fill(x, y, w, h, ch)
		end
	end

	function drv.fill(x, y, w, h, bgc)
		if bgc then
			drv.setColor(bgc)
		end
		drv.fillChar(x, y, w, h, ' ')
	end

	function drv.copy(x, y, w, h, tx, ty)
		comp.copy(x, y, w, h, tx, ty)
	end

	function drv.get(x, y)
		return comp.get(x, y)
	end

	function drv.setForeground(rgb, paletted)
		if fg ~= rgb then
			comp.setForeground(rgb, paletted)
			fg = rgb
		end
	end

	function drv.drawText(x, y, text, fgc)
		if fgc then
			drv.setForeground(fgc)
		end
		comp.set(x, y, tostring(text))
	end

	function drv.getColor()
		return comp.getBackground(), comp.getForeground()
	end

	function drv.setColor(rgb, paletted)
		if bg ~= rgb then
			comp.setBackground(rgb, paletted)
			bg = rgb
		end
	end

	drv.palette = setmetatable({}, {
		__index = function(table, key)
			if type(key) == "number" then
				if key >= 0 and key < drv.getPalettedColors() then
					return comp.getPaletteColor(key)
				elseif key >= drv.getPalettedColors() and key <= drv.getColors() then
					return fullPalette[key] -- this can only be the default palette.
				end
			end
		end,
		__newindex = function(table, key, value)
			if type(key) == "number" then
				if key >= 0 and key < drv.getPalettedColors() then
					comp.setPaletteColor(key, value)
				else
					error("editable palette indexes are 0 <= k < 16")
				end
			end
		end
	})

	-- buffer methods
	-- x, y: destination position
	-- sx, sy: source position
	function drv.blit(src, dst, x, y, sx, sy, width, height)
		src:validate()
		dst:validate()
	end

	function drv.screenBuffer()
		local buffer = {}
		buffer.id = comp.allocateBuffer(width, height)
		buffer.size = width*height
		buffer.width = width
		buffer.height = height

		function buffer:free() end

		function buffer:bind()
			comp.setActiveBuffer(0)
		end

		function buffer:unbind() end

		function buffer:validate() end

		setmetatable(buffer, {
			__index = drv
		})
		return buffer
	end

	local function freeUnusedBuffer()
		table.sort(buffers, function (a, b) -- sort buffers by size, to prioritize freeing small buffers
			return a.size < b.size
		end)
		for k, v in pairs(buffers) do
			-- save buffer content to RAM and free it
			if v.onVram and v.purpose ~= drv.BUFFER_I_WM_R_D then
				v:bind()
				v.data = {}
				for x=1, v.width do
					for y=1, v.height do
						data[y*v.width+x] = table.pack(comp.get(x,y))
					end
				end
				v:unbind()
				v:free()
				return true
			end
		end
		return false
	end

	-- Write Once = no gpu operations after first buffer blit
	-- Note that purposes don't disallow operations, so you can still read a WO_NR_D buffer, however it might cause errors as the driver might do optimizations.
	drv.BUFFER_WO_NR_D = 0 -- Write Once, No Read, Draw : the driver can silently move the buffer to RAM if needed
	drv.BUFFER_WM_R_D = 1 -- Write Many, Read, Draw : the driver can silently move the buffer to or from RAM if needed
	drv.BUFFER_I_WM_R_D = 2 -- Important, Write Many, Read, Draw : the buffer will always be in VRAM
	-- About buffers: yup, i'm aware that's an alpha feature that *will* change, i just want to use it on Fuchas
	function drv.newBuffer(width, height, purpose)
		local buffer = {}

		local requiredMemory = width*height
		while comp.freeMemory() < requiredMemory do
			if not freeUnusedBuffer() then
				error("not enough vram free")
			end
		end

		buffer.id = comp.allocateBuffer(width, height)
		buffer.size = requiredMemory
		buffer.width = width
		buffer.height = height
		buffer.purpose = purpose or drv.BUFFER_I_WM_R_D
		buffer.onVram = true
		buffer.proc = require("tasks").getCurrentProcess()

		-- Detach buffer from the process that created it: this operation is
		-- dangerous as it could leave the buffer unclosed until shutdown !
		function buffer:detach()
			for k, v in pairs(self.proc.exitHandlers) do
				if v == self.exitHandler then
					table.remove(self.proc.exitHandlers, k)
					break
				end
			end
		end

		function buffer:free()
			comp.freeBuffer(self.id)
			self:detach()
		end

		function buffer:bind()
			comp.setActiveBuffer(self.id)
		end

		function buffer:unbind()
			comp.setActiveBuffer(0)
		end

		function buffer:validate()
			if t.onVram then
				return
			end
			while comp.freeMemory() < self.size do
				if not freeUnusedBuffer() then
					error("not enough vram free")
				end
			end
			buffer.id = comp.allocateBuffer(self.width, self.height)

			-- repopulate buffer with saved content
			for x=1, self.width do
				for y=1, self.height do
					local t = self.data[y+self.width+x]
					gpu.setForeground(t[2])
					gpu.setForeground(t[3])
					gpu.set(x, y, t[1])
				end
			end
			self.data = nil -- free data from RAM
			table.insert(buffer.proc.exitHandlers, exitHandler) -- re-attach exit handler
			t.onVram = true
		end

		setmetatable(buffer, {
			__index = function(t, key)
				if drv[key] then
					t:validate()
					return drv[key]
				else
					return nil
				end
			end
		})

		buffer.exitHandler = function()
			buffer:free()
		end
		table.insert(buffer.proc.exitHandlers, exitHandler)

		return buffer
	end

	function drv.getStatistics()
		local stats = {
			freeMemory = (comp.freeMemory and comp.freeMemory()) or -1,
			totalMemory = (comp.totalMemory and comp.totalMemory()) or -1
		}
		stats.usedMemory = stats.totalMemory - stats.freeMemory
		return stats
	end

	function drv.getCapabilities()
		local hasBufs = false
		if comp.allocateBuffer then
			hasBufs = true
		end
	    return {
	        paletteSize = drv.getColors(),
	        hasPalette = true,
	        hasEditablePalette = true,
	        editableColors = drv.getPalettedColors(),
	        hardwareText = true,
	        hardwareBuffers = hasBufs
	    }
	end
	return drv
end

return spec