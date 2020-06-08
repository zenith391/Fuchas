local cpio = {}

-- This only reads "Old" binary format
function cpio.parse(stream)
	local littleEndian = true -- todo: from magic
	local archive = {}

	-- read the "unsigned short[2]" type
	local function readStrangeInt()
		local msb = io.fromunum(stream:read(2), littleEndian)
		local lsb = io.fromunum(stream:read(2), littleEndian)
		return bit32.bor(bit32.lshift(msb, 16), lsb)
	end

	local function readShort()
		return io.fromunum(stream:read(2), littleEndian)
	end

	while true do
		local magic = io.fromunum(stream:read(4), true)
		if magic ~= tonumber("070707", 8) then
			error("not a cpio file: invalid magic bytes")
		end
		stream:read(4) -- skip dev and ino
		local mode = readShort()
		local uid = readShort()
		local gid = readShort()

		local isFile = bit32.band(mode, tonumber("0100000", 8)) == tonumber("0100000", 8)
		local isDir = bit32.band(mode, tonumber("0040000", 8)) == tonumber("0040000", 8)

		local nlink = readShort()
		local rdev = readShort()
		local mtime = readStrangeInt()
		local nameSize = readShort()
		local fileSize = readStrangeInt()

		local path = stream:read(nameSize):sub(1, nameSize-1)
		if nameSize % 2 ~= 0 then
			stream:seek(1)
		end
		if path == "TRAILER!!!" then
			break
		end
		local data = stream:read(fileSize)
		if fileSize % 2 ~= 0 then
			stream:seek(1)
		end

		table.insert(archive, {
			mode = mode,
			uid = uid,
			gid = gid,
			isFile = isFile,
			isDirectory = isDir,
			nlink = nlink,
			rdev = rdev,
			mtime = mtime,
			name = path,
			data = data
		})
	end
	return archive
end

-- Write a parsed archive file to a stream
function cpio.write(arc, stream)
	local inc = 3 -- increment counter used for "ino" fields

	local function writeStrangeInt(int)
		local msb = bit32.rshift(bit32.band(int, 0xFFFF0000), 16)
		local lsb = bit32.band(int, 0x0000FFFF)
		stream:write(io.tounum(msb, 2, true, true))
		stream:write(io.tounum(lsb, 2, true, true))
	end
	table.insert(arc, {
		data = "",
		name = "TRAILER!!!",
		mode = 0
	})
	for _, entry in pairs(arc) do
		local path = entry.name
		stream:write(io.tounum(tonumber("070707", 8), 2, true, true)) -- magic
		stream:write(io.tounum(entry.dev or 0x800, 2, true, true)) -- dev
		stream:write(io.tounum(entry.ino or inc, 2, true, true)) -- ino
		local mode = entry.mode
		if not entry.mode then
			if entry.isDirectory then
				mode = tonumber("0040000", 8)
			elseif entry.isFile then
				mode = tonumber("0100000", 8)
			else
				error("cannot write non-file and non-directory entry, use \"mode\" field to do so.")
			end
		end
		if entry.isDirectory then
			if not entry.nlink then
				entry.nlink = 2
			elseif entry.nlink < 2 then
				entry.nlink = 2
			end
		end
		mode = bit32.bor(mode, tonumber("0000777", 8)) -- all permissions
		stream:write(io.tounum(mode, 2, true, true)) -- mode
		stream:write(io.tounum(entry.uid or 0, 2, true, true)) -- uid
		stream:write(io.tounum(entry.gid or 0, 2, true, true)) -- gid
		stream:write(io.tounum(entry.nlink or 1, 2, true, true)) -- nlink
		stream:write(io.tounum(entry.rdev or 0, 2, true, true)) -- rdev
		writeStrangeInt(entry.mtime or 0) -- mtime
		stream:write(io.tounum(path:len()+1, 2, true, true)) -- namesize
		writeStrangeInt(entry.data:len()) -- filesize

		stream:write(path .. "\0")
		if (path:len() + 1) % 2 ~= 0 then
			stream:write("\0")
		end
		stream:write(entry.data)
		if entry.data:len() % 2 ~= 0 then
			stream:write("\0")
		end
		
		inc = inc + 1
	end
end

return cpio