-- LON = Lua Object Notation
local lib = {}

function lib.loadlon(obj)
	if type(obj) ~= "string" then
		if obj.read then -- if is stream
			obj = obj:read("a")
		end
	end
	local lcode = "return " .. obj
	local tab, err = load(lcode, "=(lonfile)", "bt", {}) -- no access to global environment
	if tab == nil then
		error("parse error: " .. err)
	end
	return tab()
end
lib.unserialize = lib.loadlon

local function formatVal(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

--- Serializes a table to LON string, includes indentation
function lib.sertable(tab, depth, pretty)
	if pretty == nil then
		pretty = true
	end
	depth = depth or 1
	local str = "{"
	local i = 1
	local tabStr = (pretty and string.rep("\t", depth)) or ""
	local newLine = (pretty and "\n") or ""
	local equalsStr = (pretty and " = ") or "="
	for k, v in pairs(tab) do
		if type(v) == "table" then
			if type(k) == "number" then
				str = str .. newLine .. tabStr .. lib.sertable(v, pretty)
			else
				str = str .. newLine .. tabStr .. "[\"" .. k .. "\"]" .. equalsStr .. lib.sertable(v, depth+1, pretty)
			end
		else
			if type(k) == "number" then
				str = str .. newLine .. tabStr .. formatVal(v)
			else
				str = str .. newLine .. tabStr .. "[\"" .. k .. "\"]" .. equalsStr .. formatVal(v)
			end
		end
		if i < table.getn(tab) then
			str = str .. ","
		end
		i = i + 1
	end
	str = str .. newLine .. ((pretty and string.rep("\t", depth-1)) or "") .. "}"
	return str
end
lib.serialize = lib.sertable

return lib