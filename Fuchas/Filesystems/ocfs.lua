local function rc(addr, off) -- read as character
	return string.char(component.invoke(addr, "readByte", off))
end

local function readBytes(addr, off, len) -- optimized function for reading bytes
	
end

local function writeBytes(addr, off, data) -- optimized function for writing bytes

end

local fs = {}
local SS = 512
local SO = 1031

local function getName(addr, id)
	local a = id * SS * SO
	local name = readBytes(addr, a + 5, 32)
	local str = ""
	local i = 1
	while i < 32 do
		if name[i] == 0 then
			break
		end
		str = str .. string.char(name[i])
		i = i + 1
	end
	return str
end

local function getChildrens(addr, id)
	local a = id * SS * SO
	local num = shin32.fromunum(readBytes(addr, a + 37, 2), true, 2)
	local i = 1
	while i < num do
		
		i = i + 1
	end
end

function fs.format(addr)
end

function fs.asFilesystem(addr)
end

function fs.isDirectory(addr, path)
end

function fs.isFile(addr, path)
end

function fs.getMaxFileNameLength()
end

function fs.exists(addr, path)
	if path:len() == 0 or path == "/" then
		return true
	end
	
end

function fs.isValid(addr)
	local head = rc(addr, 1024) .. rc(addr, 1025) .. rc(addr, 1026) .. rc(addr, 1027)
	return head == "OCFS"
end

function fs.open(addr, path, mode)
	
end

return "OCFS", fs -- used by OS to determine if should use or not
