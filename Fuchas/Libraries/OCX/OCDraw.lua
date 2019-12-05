local gpu = require("driver").gpu
local rw, rh = gpu.getResolution()

local lib = {}

local dc = {} -- Draw Contexts

local doDebug = OSDATA.DEBUG -- warning costs a lot of GPU call budget

function lib.closeContext(ctx)
	lib.drawContext(ctx)
	dc[ctx] = nil
end

function lib.targetDriver(target)
	local d = {}
	d = {
		fg=0, bg=0,
		get = function(x, y)
			return target.data[(y-1)*target.width+(x-1)]
		end,
		fillChar = function(x, y, w, h, ch)
			for i=x, x+w do
				for j=y, y+h do
					target.data[(y-1)*target.width+(x-1)] = {ch, d.fg, d.bg}
				end
			end
		end,
		drawText = function(x, y, text, f)
			if f then
				d.fg = f
			end
			for i=1, #text do
				target.data[(y-1)*target.width+(x-1)] = {text:sub(i,i), d.fg, d.bg}
			end
		end,
		fill = function(x, y, w, h, f)
			if f then
				d.fg = f
			end
			d.fillChar(x, y, w, h, ' ')
		end,
		getResolution = function()
			return target.width, target.height
		end,
		setForeground = function(rgb)
			d.fg = rgb
		end,
		setColor = function(rgb)
			d.bg = rgb
		end
	}
	return d
end

function lib.drawContext(ctxn)
	local ctx = dc[ctxn]
	if ctx.target then
		local gpu = lib.targetDriver(ctx.target)
	end
	if doDebug then
		gpu.setColor(0xFFFFFF)
		gpu.drawText(1, 1, "OCDraw Debug:", 0)
		gpu.drawText(1, 2, "Active Draw Contexts: " .. #dc, 0)
		gpu.drawText(1, 3, "Active Processes: " .. require("tasks").getActiveProcesses(), 0)
		local usedMem = math.floor((computer.freeMemory() - computer.totalMemory()) / 1024)
		local totalMem = math.floor(computer.totalMemory() / 1024)
		gpu.drawText(1, 4, "RAM: " .. usedMem .. "/" .. totalMem .. " KiB")
	end
	for k, v in pairs(ctx.drawBuffer) do
		local t = v.type
		local x = v.x
		local y = v.y
		local width = v.width
		local height = v.height
		local color = v.color
		if t == "fillRect" and x <= rw and y <= rh then
			gpu.setColor(color)
			gpu.fill(x, y, width, height)
		end
		if t == "drawText" and x <= rw and y <= rh then
			local back = v.color2
			if not back then _, _, back = gpu.get(x, y) end
			gpu.setColor(back)
			gpu.drawText(x, y, v.text, color)
		end
		if t == "renderTarget" then
			local img = v.img
			for j=1, img.height do
				local str = ""
				local bg = -1
				local fg = -1
				local sx = 0
				for i=1, img.width do
					local piece = img.data[(j-1)*img.width+(i-1)]
					str = str .. piece[1]
					local changed = false
					if fg ~= piece[2] then
						fg = piece[2]
						gpu.setForeground(fg)
						changed = true
					end
					if bg ~= piece[3] then
						bg = piece[3]
						gpu.setColor(bg)
						changed = true
					end
					if changed then
						gpu.drawText(x+sx, y+j, str)
						str = ""
						sx = i
					end
				end
				gpu.drawText(x+sx, y+j, str)
			end
		end
		if t == "copy" then
			local x2, y2 = i.x2, i.y2
			gpu.copy(x, y, width, height, x2 - x, y2 - y)
		end
		if t == "drawOval" then
			gpu.setColor(color)
			if gpu.drawOval then
				gpu.drawOval(x, y, width, height)
			else
				x=math.ceil(x+width/2)
				local cos, sin = math.cos, math.sin
				local lx, ly = 0,0
				for i=0,180 do
					local sx, sy = cos(i) * width, sin(i) * height / 2
					sx=math.floor(sx); sy=math.floor(sy);
					if lx ~= sx or ly ~= sy then
						lx = sx; ly = sy
						gpu.fill(x+sx, y+sy, 1, 1)
					end
				end
			end
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

function lib.getTarget(ctx)
	return dc[ctx].target
end

function lib.newTarget(width, height)
	local data = {} -- not storing the data in a map will allow for less memory usage
	for i=1, width do
		for j=1, height do
			data[(j-1)*width+(i-1)] = {' ', 0, 0};
		end
	end
	return {
		width = width,
		height = height,
		data = data
	}
end

function lib.setTarget(ctx, target)
	if target == "display" or target == 0 then
		target = nil
	end
	dc[ctx].target = target
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
	cnv.drawOval = function(x, y, width, height, color)
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
		draw.type = "drawOval"
		table.insert(ctx.drawBuffer, draw)
	end
	cnv.renderTarget = function(x, y, img)
		local ctx = dc[ctxn]
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