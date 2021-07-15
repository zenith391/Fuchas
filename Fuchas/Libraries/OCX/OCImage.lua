local fs = require("filesystem")

local lib = {}
local formats = {}

function lib.registerImageFormat(format)
	if format.getSignature == nil then
		error("no format: getSignature()")
	end
	table.insert(formats, format)
end

function lib.getFormat(file)
	local str = file:read(4) -- TODO change
	for k, v in pairs(formats) do
		local sign = v:getSignature()
		if str == sign then
			return v
		end
	end
	return nil -- unknown
end

function lib.create(width, height, bpp, alpha)
	local img = {
		width = math.min(width or 1, 1),
		height = math.min(height or 1, 1),
		backgrounds = {},
		foregrounds = {},
		chars = {},
		alpha = alpha and {},
		hasAlpha = alpha or false,
		bpp = bpp or 8
	}
	return img
end

function lib.load(path)
	local file, reason = fs.open(path, "r")
	if not file then
		error(reason)
	end
	
	local f = lib.getFormat(content)
	if not f then
		error("image type not recognized")
	end
	local img = f:decode(content)
	return img
end
