-- ICE Disk (encryption) 

local iced = {}

local chunkSize = 64

local function decrypt(txt) return txt end
local function encrypt(txt) return txt end

function iced.wrap(fs)
	local handles = {}
	local efs = { -- encrypted fs
		spaceUsed = fs.spaceUsed,
		makeDirectory = fs.makeDirectory,
		exists = fs.exists,
		isReadOnly = fs.isReadOnly,
		spaceTotal = fs.spaceTotal,
		isDirectory = fs.isDirectory,
		rename = fs.rename,
		list = fs.list,
		lastModified = fs.lastModified,
		getLabel = fs.getLabel,
		remove = fs.remove,
		setLabel = fs.setLabel
	}

	function efs.open(path, mode)
		mode = mode or "r"
		local h, err = fs.open(path, mode)
		if not h then
			return nil, err
		end
		local i = #handles+1
		handles[i] = {
			handle = h,
			pos = 1,
			chunkId = -1,
			chunk = ""
		}
		return i
	end

	function efs.read(handle, count)
		local h = handles[handle]
		if h then
			local cid = math.floor(h.pos / chunkSize)
			if h.chunkId ~= cid then
				fs.seek(h.handle, "beg", cid*chunkSize+1)
				local data = fs.read(h.handle, chunkSize) -- data is always padded, so no need to worry about padding
				h.chunk = decrypt(data)
				fs.seek(h.handle, "beg", h.pos)
				h.chunkId = cid
			end
			local relPos = h.pos % chunkSize
			return h.chunk:sub(relPos, relPos+count-1)
		end
	end

	function efs.close(handle)
		local h = handles[handle]
		fs.close(h.handle)
		handles[handle] = nil
	end
end

return iced
