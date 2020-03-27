-- MineScape for Fushell
-- Uses Geeko (formely Minescape's engine)

package.loaded["geeko"] = nil
package.loaded["xml"] = nil
local shell = require("shell")
local event = require("event")
local geeko = require("geeko")
local gpu = require("driver").gpu
local width, height = gpu.getResolution()
local args, options = shell.parse(...)
local console = {}
local consoleOpened = false

local xOffset, yOffset = 1, 2

if not args[1] then
	args[1] = "file:///A:/Users/Shared/www/index.ohml"
end

local currentPath = args[1]

local function render()
	gpu.setColor(0x000000)
	gpu.setForeground(0xFFFFFF)
	local fore = 0xFFFFFF
	gpu.fill(1, 1, width, height)
	gpu.drawText(width/2-4, 1, "MineScape")
	gpu.drawText(math.floor(width/2-(currentPath:len()/2)), 2, currentPath)
	gpu.drawText(1, height, "Ctrl+C: Exit")
	gpu.drawText(14, height, "| Ctrl+T: Change URL")
	for _, obj in pairs(geeko.objects) do
		local ox, oy = obj.x + xOffset, obj.y + yOffset
		if oy > 3 - obj.height and ox < width and oy < height then
			if obj.bgcolor and obj.bgcolor ~= -1 then
				gpu.fill(1, 1, obj.width, obj.height, obj.bgcolor)
			end

			if obj.color then
				if fore ~= obj.color then
					gpu.setForeground(obj.color)
					fore = obj.color
				end
			end
			if obj.type == "text" or obj.type == "hyperlink" then
				gpu.drawText(ox, oy, obj.text)
			end
			if obj.type == "canvas" then
				if obj.drawHandler == nil then
					local bg, fg = 0x000000, 0xFFFFFF
					obj.drawHandler = function(...)
						local pack = table.pack(...)
						local op, x, y, width, height = pack[1], pack[2] or 1, pack[3] or 1, pack[4] or 1, pack[5] or 1
						x = x+ox-1
						y = y+oy-1
						if x < ox then x = ox end
						if x > ox+obj.width then x = ox+obj.width end
						if y < oy then y = oy end
						if y > oy+obj.height then y = oy+obj.height end
						if type(width) == "number" then
							if width < 1 then width = 1 end
							--if x+width > obj.width then width = obj.width-x end
						end
						if type(width) == "number" then
							if height < 1 then heigth = 1 end
							--if y+height > obj.height then height = obj.height-y end
						end
						if op == "text" then
							gpu.drawText(x, y, pack[4], fg, bg)
						end
						if op == "fill" then
							gpu.setColor(bg)
							gpu.fillChar(x, y, width, height, pack[6])
						end
						if op == "setbg" then
							bg = pack[2]
						end
						if op == "setfg" then
							fg = pack[2]
						end
					end
				end
			end
		end
	end

	if consoleOpened then
		gpu.fill(1, height-10, width, 10, 0x2D2D2D)
		gpu.setForeground(0xFFFFFF)
		for k, l in ipairs(console) do
			gpu.drawText(2, height-11+k, l)
		end
	end
end

geeko.browser = {"Minescape", "zenith391", "0.9.3"}
geeko.log = function(name, level, text)
	table.insert(console, name .. " [" .. level:upper() .. "] " .. text)
	if #console > 10 then
		table.remove(console, 1)
	end
	if consoleOpened then
		geeko.renderCallback()
	end
end

print("Opening " .. args[1])

geeko.renderCallback = render
geeko.go(args[1])

while true do
	local id, a, b, c = event.pull()
	if id == "interrupt" then
		break
	end
	if id == "touch" then
		local x = b
		local y = c
		for _, obj in pairs(geeko.objects) do
			if obj.type == "hyperlink" then
				if x >= obj.x and x < obj.x + obj.text:len() + xOffset and y == (obj.y+yOffset) then
					geeko.go(obj.hyperlink)
					break
				end
			end
		end
	end
	if id == "key_down" then
		local doRender = false
		if c == 200 then -- up
			yOffset = yOffset + 1
			doRender = true
		end
		if c == 203 then -- left
			xOffset = xOffset - 1
			doRender = true
		end
		if c == 205 then -- right
			xOffset = xOffset + 1
			doRender = true
		end
		if c == 208 then -- down
			yOffset = yOffset - 1
			doRender = true
		end
		if doRender then
			for _, obj in pairs(geeko.objects) do
				if obj.drawHandler then
					obj.drawHandler = nil
				end
			end
			geeko.renderCallback()
		end
	end
	if id == "key_up" then
		if string.char(b) == "k" then
			consoleOpened = not consoleOpened
			geeko.renderCallback()
		end
	end
end

geeko.clean()
gpu.setForeground(0xFFFFFF)
gpu.fill(1, 1, width, height, 0)
