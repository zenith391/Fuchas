local comp = ... -- the "drive" component

local function rc(off) -- read as character
	return string.char(comp.readByte(off))
end

local head = rc(1024) .. rc(1025) .. rc(1026) .. rc(1027)
local isOCFS = head == "OCFS"

local fs = {}



return "OCFS", isOCFS, fs -- used by OS to determine if should use or not
