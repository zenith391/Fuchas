-- MineScape for Fushell
-- OHML v1.0.1 compliant viewer/browser
-- Partially compatible with OHML v1.0.2

package.loaded["xml"] = nil
local xml = require("xml")
local shell = require("shell")
local event = require("event")
local filesystem = require("filesystem")
local gpu = component.gpu
local width, height = gpu.getResolution()
local args, options = shell.parse(...)

if not args[1] then
	args[1] = "A:/Users/Shared/www/index.ohml"
end

local currentPath = args[1]

local stream = io.open(shell.resolve(args[1]))
local text = stream:read("a")
stream:close()

local parsed = xml.parse(text)

local cy = 3
local cx = 1
local objects = {}

local function resolve(tag)
	for _, v in pairs(tag.childrens) do
		if v.attr.x then
			cx = v.attr.x
		end
		if v.attr.y then
			cy = v.attr.y
		end
		if v.name == "#text" then
			if cx + v.content:len() > width then
				cx = 1
				cy = cy + 1
			end
			if v.parent.name == "a" then
				table.insert(objects, {
					type = "hyperlink",
					x = cx,
					y = cy,
					text = v.content,
					hyperlink = v.parent.attr.href
				})
			else
				table.insert(objects, {
					type = "text",
					x = cx,
					y = cy,
					text = v.content
				})
			end
			cx = cx + v.content:len()
		elseif v.name == "br" then
			cx = 1
			cy = cy + 1
		else
			resolve(v)
			if v.name == "text" or v.name == "h1" or v.name == "h2" or v.name == "h3" or v.name == "h4" or v.name == "h5" then
				cx = 1
				cy = cy + 1
			end
		end
	end
end

local function render()
	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
	local fore = 0xFFFFFF
	gpu.fill(1, 1, width, height, " ")
	gpu.set(width/2-4, 1, "MineScape")
	--gpu.set(2, 2, "|")
	gpu.set(math.floor(width/2-(currentPath:len()/2)), 2, currentPath)
	--gpu.set(width-1, 2, "|")
	gpu.set(1, height, "Ctrl+C: Exit")
	for _, obj in pairs(objects) do
		if obj.type == "text" then
			if fore ~= 0xFFFFFF then
				gpu.setForeground(0xFFFFFF)
				fore = 0xFFFFFF
			end
			gpu.set(obj.x, obj.y, obj.text)
		end
		if obj.type == "hyperlink" then
			if obj.trigerred then
				if fore ~= 0x2020AA then
					gpu.setForeground(0x2020AA)
					fore = 0x2020AA
				end
			else
				if fore ~= 0x2020FF then
					gpu.setForeground(0x2020FF)
					fore = 0x2020FF
				end
			end
			gpu.set(obj.x, obj.y, obj.text)
		end
	end
end

local function go(link)
	if link:sub(1, 1) == "/" then
		currentPath = "A:" .. link
	else
		currentPath = filesystem.path(currentPath) .. link
	end
	stream = io.open(shell.resolve(currentPath))
	text = stream:read("a")
	stream:close()
	parsed = xml.parse(text)
	cx = 1
	cy = 3
	objects = {}
	resolve(parsed)
	render()
end

resolve(parsed)
render()

while true do
	local id, a, b, c = event.pull()
	if id == "interrupt" then
		break
	end
	if id == "touch" then
		local x = b
		local y = c
		for _, obj in pairs(objects) do
			if obj.type == "hyperlink" then
				if x >= obj.x and x < obj.x + obj.text:len() and y == obj.y then
					go(obj.hyperlink)
					break
				end
			end
		end
	end
end

gpu.fill(1, 1, width, height, " ")
