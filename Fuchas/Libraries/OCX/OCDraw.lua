--- Library for managing unbuffered draw contexts
-- @module OCX.OCDraw
-- @alias lib

local gpu = require("driver").gpu
local logger = require("log")("OCDraw")
local caps = gpu.getCapabilities()
local rw, rh = gpu.getResolution()
local lib = {}
local contexts = {} -- Draw Contexts

local doDebug = OSDATA.DEBUG and false -- warning costs a lot of GPU call budget

--- Will remove double buffer of any context
function lib.requestMemory()
	
end

--- Redraw the given draw context. Using this instead of @{drawContext} allows for many optimisation.
-- @tparam int ctxn The ID of the draw context
-- @see drawContext
function lib.redrawContext(ctxn)
	local ctx = contexts[ctxn]
	-- TODO: optimize it such that if no change was made to a parent's buffer it could just blit
	if ctx.buffer and not ctx.parent then
		if ctx.clip then
			for _, region in pairs(ctx.clip) do
				local sx = region.x - ctx.x + 1
				local sy = region.y - ctx.y + 1
				gpu.blit(ctx.buffer, gpu.screenBuffer(), region.x, region.y, region.w, region.h, sx, sy)
			end
		else
			gpu.blit(ctx.buffer, gpu.screenBuffer(), ctx.x, ctx.y)
		end
	else
		ctx.drawBuffer = ctx.oldDrawBuffer
		lib.drawContext(ctxn)
	end
end

--- Draw the given draw context.
-- @tparam int ctxn The ID of the draw context
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
	end
	if ctx.parent then
		if not contexts[ctx.parent] then
			logger.warn("Context #" .. ctxn .. " has parent #" .. ctx.parent .. " but it doesn't exists.")
			return
		end
		ctx.buffer = contexts[ctx.parent].buffer
	end
	if ctx.buffer then
		ctx.buffer:bind()
	end
	logger.debug("Drawing #" .. ctxn)
	for k, v in pairs(ctx.drawBuffer) do
		local t = v.type
		local dx, dy = 0, 0
		if ctx.parent then
			dx = ctx.x - contexts[ctx.parent].x
			dy = ctx.y - contexts[ctx.parent].y
		end
		local x = v.x
		local y = v.y
		if x and y then
			if x > ctx.width then
				goto continue
			end
			if y > ctx.height then
				goto continue
			end
			if not ctx.buffer then
				x = ctx.x + x - 1
				y = ctx.y + y - 1
			end
		end
		x = x + dx
		y = y + dy
		local width = v.width
		local height = v.height
		local color = v.color
		if t == "fillRect" then
			g.setColor(color)
			g.fill(x, y, width, height)
		elseif t == "drawText" then
			local back = v.color2
			if not back and x >= 1 then
				_, _, back = g.get(x, y)
			end
			if back then
				g.setColor(back)
			end
			g.drawText(x, y, v.text, color)
		elseif t == "copy" then
			local x2, y2 = i.x2 + dx, i.y2 + dy
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
			if v.args then
				g[t](table.unpack(v.args))
			end
		end
		::continue::
	end
	if ctx.buffer then
		local parent = (ctx.parent and contexts[ctx.parent]) or nil
		local px = (parent and parent.x) or nil
		local py = (parent and parent.y) or nil
		-- For now, child contexts cannot clip
		if parent then
			if not contexts[ctx.parent].blockChildDraw and false then
				gpu.blit(ctx.buffer, gpu.screenBuffer(), px or ctx.x, py or ctx.y)
			end
		elseif not ctx.clip then
			gpu.blit(ctx.buffer, gpu.screenBuffer(), px or ctx.x, py or ctx.y)
		else
			for _, region in pairs(ctx.clip) do
				local sx = region.x - ctx.x + 1
				local sy = region.y - ctx.y + 1
				gpu.blit(ctx.buffer, gpu.screenBuffer(), region.x, region.y, region.w, region.h, sx, sy)
			end
		end
		ctx.buffer:unbind()
	end
	ctx.oldDrawBuffer = ctx.drawBuffer
	ctx.drawBuffer = {}
end

local function pushToBufEx(ctx, func, ...)
	if ctx.buffer then
		ctx.buffer:bind()
		gpu[func](...)
		ctx.buffer:unbind()
	else
		table.insert(ctx.drawBuffer, {type=func,args={...}})
	end
end

local function pushToBuf(ctx, func, x, y, ...)
	if ctx.buffer then
		ctx.buffer:bind()
		local parent = (ctx.parent and contexts[ctx.parent]) or nil
		if parent then
			x = ctx.x - parent.x + x
			y = ctx.y - parent.y + y
		end
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

--- Wrap the given draw context into a GPU driver.
-- @tparam int ctxn The ID of the draw context
function lib.gpuWrapper(ctxn)
	return setmetatable({}, {
		__index = function(t, key)
			if gpu[key] then
				return function(...)
					local fn = pushToBuf
					if key == "setColor" or key == "setForeground" then
						fn = pushToBufEx
					end
					fn(contexts[ctxn], key, ...)
				end
			end
		end
	})
end

--- Create a draw context
-- @tparam int x The X position of the new draw context
-- @tparam int y The Y position of the new draw context
-- @tparam int width The width of the new draw context
-- @tparam int height The height of the new draw context
-- @tparam[opt=0] int braille The braille pattern of the new draw context (deprecated)
-- @tparam[opt] int parent The ID of the parent of the new draw context
-- @treturn DrawContext
function lib.newContext(x, y, width, height, braille, parent)
	checkArg(1, x, "number")
	checkArg(2, y, "number")
	checkArg(3, width, "number")
	checkArg(4, height, "number")
	if parent then
		checkArg(6, parent, "number")
		if not contexts[parent] then
			logger.warn("Missing parent context #" .. tostring(parent))
			logger.warn(debug.traceback(1))
			error("parent context #" .. parent .. " does not exists")
		end
	end

	local ctx = {}
	ctx.x = x
	ctx.y = y
	ctx.width = width
	ctx.height = height
	ctx.parent = parent
	ctx.clip = nil
	ctx.drawBuffer = {}
	if caps.hardwareBuffers then
		if parent then
			ctx.buffer = contexts[parent].buffer
		else
			ctx.buffer = gpu.newBuffer(width, height, gpu.BUFFER_WM_R_D)
		end
	end
	local idx = 0
	for k, _ in pairs(contexts) do
		idx = math.max(idx, k)
	end
	idx = idx + 1
	contexts[idx] = ctx

	local dbg = "Open context #" .. tostring(idx) .. " at " .. x .. "x" .. y .. " of size " .. width .. "x" .. height
	if parent then
		dbg = dbg .. " with parent " .. tostring(parent)
	end
	logger.debug(debug.traceback(dbg))
	return idx
end

--- Returns whether the draw context is still opened or not
-- @tparam int ctxn The ID of the draw context
-- @treturn boolean
function lib.isContextOpened(ctxn)
	return contexts[ctxn] ~= nil
end

--- Convert the given draw context to a buffer.
--- The context must be backed by a buffer!
-- @tparam int ctxn The ID of the draw context
function lib.toOwnedBuffer(ctxn)
	local ctx = contexts[ctxn]
	if not ctx.buffer then
		error("context #" .. ctxn .. " is not buffered")
	end
	contexts[ctxn] = nil
	return ctx.buffer
end

--- Close the given draw context
-- @tparam int ctx The ID of the draw context
function lib.closeContext(ctx)
	logger.debug("Close context #" .. tostring(ctx))
	logger.debug(debug.traceback(1))
	if not contexts[ctx] then
		return
	end
	if contexts[ctx].buffer and not contexts[ctx].parent then
		local ok, err = pcall(contexts[ctx].buffer.free, contexts[ctx].buffer)
		if not ok then
			logger.warn(debug.traceback("Buffer for context #" .. tostring(ctx) .. " already freed ?! " .. err))
		end
	end
	contexts[ctx] = nil
end

--- Returns the bounds of the given draw context
-- @tparam int ctx The ID of the draw context
-- @treturn int x
-- @treturn int y
-- @treturn int width
-- @treturn int height
function lib.getContextBounds(ctx)
	local c = contexts[ctx]
	if not c then
		error("no such context: " .. tostring(ctx))
	end
	return c.x, c.y, c.width, c.height
end

--- Move the context to the given position
-- @tparam int ctx The ID of the draw context
-- @tparam int x The new X position
-- @tparam int y The new Y position
function lib.moveContext(ctx, x, y)
	logger.debug("Move context #" .. tostring(ctx) .. " to " .. tostring(x) .. "x" .. tostring(y))
	logger.debug(debug.traceback(1))
	local c = contexts[ctx]
	c.x = x
	c.y = y
end

--- Clip the context to the given regions
-- @tparam int ctx The ID of the draw context
-- @tparam region[] A list of regions
function lib.clipContext(ctx, regions)
	local c = contexts[ctx]
	c.clip = regions
end

function lib.setBlockingDraw(ctx, blockDraw)
	local c = contexts[ctx]
	c.blockChildDraw = blockDraw
end

--- Returns a canvas object made associated to the given draw context
-- @tparam int ctxn The ID of the draw context
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
		local ctx = contexts[ctxn]
		local draw = {}
		draw.x = x
		draw.y = y
		draw.color = fore
		if back then
			draw.color2 = back
		end
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