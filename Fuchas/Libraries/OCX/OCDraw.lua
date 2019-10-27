local gpu = component.getPrimary("gpu")
local rw, rh = gpu.getResolution()

local lib = {}
local dc = {}

local doDebug = OSDATA.DEBUG -- warning costs a lot of GPU call budget

function lib.closeContext(ctx)
	lib.drawContext(ctx)
	dc[ctx] = nil
end

function lib.drawContext(ctxn)
	local ctx = dc[ctxn]
	if doDebug then
		gpu.setForeground(0x000000)
		gpu.setBackground(0xFFFFFF)
		gpu.set(1, 1, "OCDraw Debug:")
		gpu.set(1, 2, "Active Draw Contexts: " .. #dc)
		gpu.set(1, 3, "Active Processes: " .. require("tasks").getActiveProcesses())
	end
	for k, v in pairs(ctx.drawBuffer) do
		local t = v.type
		local x = v.x
		local y = v.y
		local width = v.width
		local height = v.height
		local color = v.color
		if t == "fillRect" and x <= rw and y <= rh then
			gpu.setBackground(color)
			gpu.fill(x, y, width, height, " ")
		end
		if t == "drawText" and x <= rw and y <= rh then
			local back = v.color2
			if not back then _, _, back = gpu.get(x, y) end
			gpu.setForeground(color)
			gpu.setBackground(back)
			gpu.set(x, y, v.text)
		end
		if t == "copy" then
			local x2, y2 = i.x2, i.y2
			gpu.copy(x, y, width, height, x2 - x, y2 - y)
		end
	end
	ctx.drawBuffer = {}
end

function lib.newContext(x, y, width, height, braille)
	local ctx = {}
	ctx.x = (x or 1)-1
	ctx.y = (y or 1)-1
	ctx.width = width or 160
	ctx.height = height or 50
	ctx.braille = braille
	-- braille=0 - No braille, same default lame size as OC, full color: fastest
	-- braille=1 - Vertical braille, allows a max resolution (T3) of 160x100, full color: faster
	-- braille=2 - Horizontal braille, allows a max resolution (T3) of 320x50, full color: faster
	-- braille=3 - Full braille, allows a max resolution (T3) of 320x200, monochrome: slower
	-- braille=4 - Full braille, allows a max resolution (T3) of 320x200, averaged colors: slowest
	ctx.drawBuffer = {}
	dc[#dc+1] = ctx
	return #dc
end

function lib.setContextSize(ctx, width, height)
	local c = dc[ctx]
	c.width = width
	c.height = height
end

function lib.moveContext(ctx, x, y)
	local c = dc[ctx]
	c.x = x-1
	c.y = y-1
end

function lib.canvas(ctxn)
	local cnv = {}
	cnv.fillRect = function(x, y, width, height, color)
		local ctx = dc[ctxn]
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
		draw.type = "fillRect"
		table.insert(ctx.drawBuffer, draw)
	end
	cnv.copy = function(x, y, width, height, x2, y2)
		local ctx = dc[ctxn]
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
		local ctx = dc[ctxn]
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
	return cnv
end

return lib