local fs = require("filesystem")

local lib = {}
local formats = {}

function lib.registerImageFormat(format)
	if format.getSignature == nil then
		error("no format:getSignature()")
	end
	table.insert(formats, format)
end

function lib.getFormat(content)
	for k, v in pairs(formats) do
		local sign = v:getSignature()
		if content:sub(1, sign:len()) == sign then
			return v
		end
	end
	return nil -- unknown
end

function lib.load(path)
	local file, reason = io.open(path, "r")
	if not file then
		error(reason)
	end
	
	local content = file:read("a")
	local f = lib.getFormat(content)
	if not f then
		error("image type not recognized")
	end
	local img = f:decode(content)
	return img
end

-- OCIF default format
local ocif = {}

local function bigEndianNumber(str)
	local result = 0
	local i = 1
	while i < #str do
		result = bit32.bor(bit32.lshift(result, 8), string.char(str:sub(i, i)))
		i = i + 1
	end
	return result
end

ocif.getSignature = function(self)
	return "OCIF"
end
ocif.getName = function(self)
	return "OCIF 5/6"
end
ocif.decode = function(self, content)
	local method = string.char(content:sub(5, 6))
	local image = {}
	if method == 5 then
		image.width = bigEndianNumber(content:sub(7, 8))
		image.height = bigEndianNumber(content:sub(9, 10))
	end
	return image
end