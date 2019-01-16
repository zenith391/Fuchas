local fs = require("filesystem")

function io.open(filename, mode)
	if not mode then
		mode = "r"
	end
	if fs.exists(filename) and not fs.isDirectory(filename) then
		local file = {}
		file.h = fs.open(filename, mode)
		file.read = function(f)
			if not f then
				f = "a"
			end
			
			if f == "a" then
				local s = ""
				while true do
					local r = file.h:read()
					if r == nil then
						break
					end
					s = s .. r
				end
				return s
			end
			
			if f == "l" then
				local s = ""
				while true do
					local r = file.h:read()
					if r == nil then
						return nil
					elseif r:find("\n") ~= nil or r:find("\r") ~= nil then -- support for unix, mac and windows EOL
						return s
					end
					s = s .. r
				end
				return s
			end
			return nil
		end
	end
	return nil
end