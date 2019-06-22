-- LON = Lua Object Notation
local lib = {}

function lib.loadlon(obj)
	if obj.read then -- if is stream
		obj = obj:read("a")
	end
	local lcode = "return " .. obj
	local tab, err = load(lcode, "=(lonfile)", "bt", {}) -- no access to global environment
	if tab == nil then
		error("parse error: " .. err)
	end
	return tab()
end

local function formatVal(v)
	if type(v) == "string" then
		return '"' .. v .. '"'
	end
	
	return tostring(v)
end

--- Serializes a table to LON string, includes indentation
function lib.sertable(tab, depth)
	depth = depth or 1
	local str = "{"
	local i = 1
	for k, v in pairs(tab) do
		if type(v) == "table" then
			if type(k) == "number" then
				str = str .. "\n" .. string.rep("\t", depth) .. lib.sertable(v)
			else
				str = str .. "\n" .. string.rep("\t", depth) .. k .. " = " .. lib.sertable(v, depth+1)
			end
		else
			if type(k) == "number" then
				str = str .. "\n" .. string.rep("\t", depth) .. formatVal(v)
			else
				str = str .. "\n" .. string.rep("\t", depth) .. k .. " = " .. formatVal(v)
			end
		end
		if i < table.getn(tab) then
			str = str .. ","
		end
		i = i + 1
	end
	str = str .. "\n" .. string.rep("\t", depth-1) .. "}"
	return str
end

return lib