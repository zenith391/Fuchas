local gpu = component.proxy(component.list("gpu")())

local lib = {}
local dc = {}

local dca = 0
local ctxOp = 0

function lib.closeContext(ctx)
  lib.drawContext(ctx)
  dc[ctx] = nil
  ctxOp = ctxOp - 1
end

function table.getn(table)
  local i = 0
  for k, v in ipairs(table) do
	i = k
  end
  return i
end

function lib.drawContext(ctxn)
  local ctx = dc[ctxn]
  local i0 = 1
  gpu.setForeground(0x000000)
  gpu.setBackground(0xFFFFFF)
  y = 0
  gpu.set(1, 2, "OCDraw Debug:")
  gpu.set(1, 3, "OCDraw Requests : " .. table.getn(ctx.drawBuffer))
  gpu.set(1, 4, "Active Draw Contexts: " .. ctxOp)
  --print("Active Processes: " .. require("shin32").getActiveProcesses())
  while i0 < table.getn(ctx.drawBuffer)+1 do
	local i = ctx.drawBuffer[i0]
	local t = i.type
	local x = i.x
	local y = i.y
	local width = i.width
	local height = i.height
	local color = i.color
	if t == "fillRect" then
	  gpu.setBackground(color)
	  gpu.fill(x, y, width, height, " ")
	end
	if t == "drawText" then
	  local _, _, back = gpu.get(x, y)
	  gpu.setForeground(color)
	  gpu.setBackground(back)
	  gpu.set(x, y, i.text)
	end
	if t == "copy" then
		local x2, y2 = i.x2, i.y2
		gpu.copy(x, y, width, height, x2 - x, y2 - y)
	end
	table.remove(ctx.drawBuffer, 1)
  end
end

function lib.newContext(x, y, width, height)
  local ctx = {}
  ctx.x = x or 1
  ctx.y = y or 1
  ctx.width = width or 160
  ctx.height = height or 50
  ctx.drawBuffer = {}
  dca = dca + 1
  if dca > 1000 then -- Limiting Draw Context Array index
	dca = 0
  end
  dc[dca] = ctx
  ctxOp = ctxOp + 1
  return dca
end

function lib.setContextSize(ctx, width, height)
	local c = dc[ctx]
	c.width = width
	c.height = height
end

function lib.canvas(ctxn)
  local cnv = {}
  cnv.fillRect = function(x, y, width, height, color)
	local ctx = dc[ctxn]
	if x + width - 1 > ctx.width then
	  width = ctx.width - x
	end
	if y + height - 1 > ctx.height then
	  height = ctx.height - y
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
  cnv.drawText = function(x, y, text, fore)
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
	draw.width = -1
	draw.height = -1
	draw.type = "drawText"
	draw.text = text
	table.insert(ctx.drawBuffer, draw)
  end
  return cnv
end

return lib