local gpu = require("driver").gpu
local logger = require("log")("OCDraw")
local caps = gpu.getCapabilities()
local rw, rh = gpu.getResolution()
local lib = {}
local contexts = {} -- Draw Contexts

local doDebug = OSDATA.DEBUG -- warning costs a lot of GPU call budget

-- Will remove double buffer of any context
function lib.requestMemory()
	
end

function lib.redrawContext(ctxn)
	local ctx = contexts[ctxn]
	if ctx.buffer then
		gpu.blit(ctx.buffer, gpu.screenBuffer(), ctx.x, ctx.y)
	else
		ctx.drawBuffer = ctx.oldDrawBuffer
		lib.drawContext(ctxn)
	end
end

function lib.drawContext(ctxn)
	local ctx = contexts[ctxn]
	local g = gpu
	if doDebug then
		gpu.setColor(0xFFFFFF)
		local concat = ""
		for k, v in pairs(contexts) do
			concat = concat .. tostring(k) .. ","
		end
		gpu.drawText(1, 1, "Active Draw Contexts: " .. concat .. (" "):rep(10), 0)
		--gpu.drawText(1, 2, "Active Processes: " .. #require("tasks").getPIDs(), 0)
		local usedMem = math.floor((computer.totalMemory() - computer.freeMemory()) / 1024)
		local totalMem = math.floor(computer.totalMemory() / 1024)
		--gpu.drawText(1, 3, "RAM: " .. usedMem .. "/" .. totalMem .. " KiB")
		local stats = gpu.getStatistics()
		if caps.hardwareBuffers then
			local usedVMem = math.floor(stats.usedMemory / 1000)
			local totalVMem = math.floor(stats.totalMemory / 1000)
			--gpu.drawText(1, 4, "VRAM: " .. usedVMem .. "/" .. totalVMem .. " KB")
		end
	end
	if ctx.buffer then
		ctx.buffer:bind()
	end
	for k, v in pairs(ctx.drawBuffer) do
		local t = v.type
		local x = v.x
		local y = v.y
		if not ctx.buffer and x and y then
			x = ctx.x + x - 1
			y = ctx.y + y - 1
		end
		local width = v.width
		local height = v.height
		local color = v.color
		if t == "fillRect" and x <= rw and y <= rh then
			g.setColor(color)
			g.fill(x, y, width, height)
		elseif t == "drawText" and x <= rw and y <= rh then
			local back = v.color2
			if not back and x >= 1 then
				_, _, back = g.get(x, y)
			end
			if back then
				g.setColor(back)
			end
			g.drawText(x, y, v.text, color)
		elseif t == "copy" then
			local x2, y2 = i.x2, i.y2
			g.copy(x, y, width, height, x2 - x, y2 - y)
		elseif t == "drawOval" then
			g.setColor(color)
			x=math.ceil(x+width/2)
			local cos, sin = math.cos, math.sin
			local lx, ly = 0,0
			for i=0,180 do
				local sx, sy = cos(i) * width, sin(i) * height / 2
				sx=math.floor(sx); sy=math.floor(sy);
				if lx ~= sx or ly ~= sy then
					lx = sx; ly = sy
					g.fill(x+sx, y+sy, 1, 1)
				end
			end
		else
			g[t](table.unpack(v.args))
		end
	end
	if ctx.buffer then
		gpu.blit(ctx.buffer, gpu.screenBuffer(), ctx.x, ctx.y)
		ctx.buffer:unbind()
	end
	ctx.oldDrawBuffer = ctx.drawBuffer
	ctx.drawBuffer = {}
end

local function pushToBuf(ctx, func, x, y, ...)
	if ctx.buffer then
		ctx.buffer:bind()
		gpu[func](x, y, ...)
		ctx.buffer:unbind()
	else
		if x and y then
			table.insert(ctx.drawBuffer, {type=func,args={ctx.x+x, ctx.y+y, ...}})
		else
			table.insert(ctx.drawBuffer, {type=func,args={x, y, ...}})
		end
	end
end

function lib.gpuWrapper(ctxn)
	return setmetatable({}, {
		__index = function(t, key)
			if gpu[key] then
				return function(...)
					pushToBuf(contexts[ctxn], key, ...)
				end
			end
		end
	})
end

function lib.newContext(x, y, width, height, braille)
	checkArg(1, x, "number")
	checkArg(2, y, "number")
	checkArg(3, y, "number")
	checkArg(4, y, "number")

	local ctx = {}
	ctx.x = x
	ctx.y = y
	ctx.width = width
	ctx.height = height
	ctx.braille = braille or 0
	-- braille=0 - No braille, same default lame size as OC, full color: fastest
	-- braille=1 - Vertical braille, allows a max resolution (T3) of 160x100, full color: faster
	-- braille=2 - Horizontal braille, allows a max resolution (T3) of 320x50, full color: faster
	-- braille=3 - Full braille, allows a max resolution (T3) of 320x200, monochrome: slower
	-- braille=4 - Full braille, allows a max resolution (T3) of 320x200, averaged colors: slowest
	ctx.drawBuffer = {}
	if caps.hardwareBuffers then
		ctx.buffer = gpu.newBuffer(width, height, gpu.BUFFER_WM_R_D)
	end
	local idx = 0
	for k, _ in pairs(contexts) do
		idx = math.max(idx, k)
	end
	idx = idx + 1
	contexts[idx] = ctx
	logger.debug("Open context #" .. tostring(idx) .. " at " .. x .. "x" .. y .. " of size " .. width .. "x" .. height)
	logger.debug(debug.traceback(1))
	return idx
end

function lib.isContextOpened(ctx)
	return contexts[ctx] ~= nil
end

function lib.closeContext(ctx)
	logger.debug("Close context #" .. tostring(ctx))
	logger.debug(debug.traceback(1))
	if not contexts[ctx] then
		return
	end
	if contexts[ctx].buffer then
		contexts[ctx].buffer:free()
	end
	contexts[ctx] = nil
end

function lib.getContextBounds(ctx)
	local c = contexts[ctx]
	if not c then
		error("no such context: " .. tostring(ctx))
	end
	return c.x, c.y, c.width, c.height
end

function lib.moveContext(ctx, x, y)
	logger.debug("Move context #" .. tostring(ctx) .. " to " .. tostring(x) .. "x" .. tostring(y))
	logger.debug(debug.traceback(1))
	local c = contexts[ctx]
	c.x = x
	c.y = y
end

function lib.canvas(ctxn)
	local cnv = {}
	local vgpu = lib.gpuWrapper(ctxn)
	cnv.fillRect = function(x, y, width, height, color)
		local ctx = contexts[ctxn]
		if x + width > ctx.width+1 then
			width = ctx.width - x+1
		end
		if y + height > ctx.height+1 then
			height = ctx.height - y+1
		end
		vgpu.setColor(color)
		vgpu.fill(x, y, width, height)
	end
	cnv.copy = function(x, y, width, height, x2, y2)
		local ctx = contexts[ctxn]
		if x > ctx.width then
			x = ctx.width
		end
		if y > ctx.height then
		y = ctx.height
		end
		x = x + ctx.x
		y = y + ctx.y
		local draw = {}
		draw.x = x
		draw.y = y
		draw.color = 0
		draw.width = width
		draw.height = height
		draw.type = "copy"
		draw.x2 = x2
		draw.y2 = y2
		table.insert(ctx.drawBuffer, draw)
	end
	cnv.drawText = function(x, y, text, fore, back)
		if x > 160 or y > 50 then
			return
		end
		local ctx = contexts[ctxn]
		if x > ctx.width then
			x = ctx.width
		end
		if y > ctx.height then
			y = ctx.height
		end
		local draw = {}
		draw.x = x
		draw.y = y
		draw.color = fore
		if back then
			draw.color2 = back
		end
		draw.width = -1
		draw.height = -1
		draw.type = "drawText"
		draw.text = text
		table.insert(ctx.drawBuffer, draw)
	end
	cnv.drawOval = function(x, y, width, height, color)
		local ctx = contexts[ctxn]
		if x + width > ctx.width+1 then
			width = ctx.width - x+1
		end
		if y + height > ctx.height+1 then
			height = ctx.height - y+1
		end
		x = x + ctx.x
		y = y + ctx.y
		local draw = {}
		draw.x = x
		draw.y = y
		draw.width = width
		draw.height = height
		draw.color = color
		draw.type = "drawOval"
		table.insert(ctx.drawBuffer, draw)
	end
	cnv.renderTarget = function(x, y, img)
		local ctx = contexts[ctxn]
		if x + img.width > ctx.width+1 then
			x = ctx.width - img.width
		end
		if y + img.height > ctx.height+1 then
			y = ctx.height - img.height
		end
		x = x + ctx.x
		y = y + ctx.y
		local draw = {}
		draw.x = x
		draw.y = y
		draw.img = img
		draw.type = "renderTarget"
		table.insert(ctx.drawBuffer, draw)
	end
	cnv.drawCircle = function(x, y, radius, color)
		cnv.drawOval(x, y, radius, radius, color)
	end
	return cnv
end

return lib