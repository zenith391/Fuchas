local liblon = require("liblon")
local ser = {}

function ser.serialize(value, pretty)
	return liblon.sertable(value) -- liblon currently always prettify the tables.
end

function ser.unserialize(value)
	return liblon.loadlon(value)
end

return ser
