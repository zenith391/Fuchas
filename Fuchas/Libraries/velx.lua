--- Implementation of the VELX executable format
-- (made from the documentation at
-- https://github.com/Adorable-Catgirl/Random-OC-Docs/blob/master/formats/velx/v1.md)
-- @module velx
-- @alias velx

local velx = {}
local cpio = require("cpio")

--- Velx file
-- @table Velx
-- @field version
-- @field compressionId
-- @field luaVersion
-- @field osId
-- @field isLibrary
-- @field archiveType
-- @field programSection
-- @field osSection
-- @field signatureSection
-- @field archiveSize
-- @field archive

--- Parse a VELX file from the given stream
-- @tparam stream stream The I/O stream to read from
-- @treturn Velx The parsed VELX file
function velx.parse(stream)
	local magic = stream:read(5)
	if magic ~= "\27VelX" then
		error("not a velx file: invalid magic string")
	end
	local fileVer = string.byte(stream:read(1))
	if fileVer ~= 0 then
		error("this parser can only read first version of velx")
	end
	local compression = string.byte(stream:read(1))
	local luaVer = string.byte(stream:read(1))
	local osId = string.byte(stream:read(1))
	local isLib = bit32.band(osId, 128) == 128
	osId = bit32.band(osId, 127) -- remove library mark
	local arcType = stream:read(4)
	if arcType == ("\0"):rep(4) then
		arcType = "none"
	end
	if compression ~= 0 then
		error("compression not supported")
	end
	if arcType ~= "cpio" and (not arcType == "none") then
		error("archive must be cpio or none")
	end
	if not package.exists("cpio") and arcType == "cpio" then
		error("\"cpio\" library is required to read this VELX file")
	end

	local programSize = io.fromunum(stream:read(3), true)
	local osDepSize = io.fromunum(stream:read(3), true)
	local signatureSize = io.fromunum(stream:read(3), true)
	local archiveSize = io.fromunum(stream:read(4), true)

	local programSection = stream:read(programSize)
	local osSection = stream:read(osDepSize)
	local signatureSection = stream:read(signatureSize)

	local archive = cpio.read(stream)
	return {
		version = fileVer,
		compressionId = compression,
		luaVersion = luaVer,
		osId = osId,
		isLibrary = isLib,
		archiveType = arcType,

		programSection = programSection,
		osSection = osSection,
		signatureSection = signatureSection,
		archiveSize = archiveSize,
		archive = archive
	}
end

--- Write a parsed VELX file to a stream
function velx.write(velx, stream)
	if velx.archiveType ~= "cpio" and (not velx.archiveType == "none") then
		error("archive must be cpio or none")
	end
	if not package.exists("cpio") and velx.archiveType == "cpio" then
		error("\"cpio\" library is required to write this VELX file")
	end
	if velx.compressionId ~= 0 then
		error("compression not supported")
	end
	stream:write("\27VelX")
	stream:write(string.char(velx.version)) -- file version
	stream:write(string.char(velx.compressionId)) -- compression
	stream:write(string.char(velx.luaVersion))
	local osId = velx.osId
	if velx.isLibrary then
		osId = bit32.bor(osId, 128)
	end
	stream:write(string.char(osId))
	if velx.archiveType == "none" then
		stream:write(("\0"):rep(4))
	else
		stream:write(velx.archiveType)
	end

	stream:write(io.tounum(velx.programSection:len(), 3, true, true))
	stream:write(io.tounum(velx.osSection:len(), 3, true, true))
	stream:write(io.tounum(velx.signatureSection:len(), 3, true, true))
	if velx.archiveType == "none" then
		stream:write(io.tounum(0, 4, true, true))
	else
		stream:write(io.tounum(velx.archiveSize, 3, true, true))
	end

	stream:write(velx.programSection)
	stream:write(velx.osSection)
	stream:write(velx.signatureSection)

	if velx.archiveType == "cpio" then
		cpio.write(velx.archive, stream)
	end
end

--- Check the parsed VELX file for execution on Fuchas
function velx.check(velx)
	if velx.osId ~= 69 then
		error("not a fuchas executable!")
	end
	if _VERSION == "Lua 5.2" and velx.luaVersion == 53 then
		error("out of date Lua version: file requires Lua 5.3, computer have Lua 5.2")
	end
end

return velx
