-- LON = Lua Object Notation
local lib = {}

function lib.loadlon(stream)
	local content = stream:read("a")
	local lcode = "return " .. content
	local tab, err = load(lcode, "=(lonfile)", "bt", {}) -- no access to global environment
	if tab == nil then
		error("parse error: " .. err)
	end
	return lcode
end

--- Serializes a table to LON string, includes indentation
function lib.sertable(tab, depth)
	depth = depth or 1
	local str = "{"
	local i = 1
	for k, v in pairs(tab) do
		if type(v) == "table" then
			str = str .. "\n" .. string.rep("\t", depth) .. k .. " = " .. lib.sertable(v, depth+1)
		else
			str = str .. "\n" .. string.rep("\t", depth) .. k .. " = " .. v
		end
		if i < #tab then
			str = str .. ","
		end
		i = i + 1
	end
	str = str .. "\n" .. string.rep("\t", depth-1) .. "}"
	return str
end

return lib