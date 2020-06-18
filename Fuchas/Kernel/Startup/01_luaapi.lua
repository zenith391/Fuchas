-- String
local _char = string.char
local _len = string.len
local _sub = string.sub
local _reserve = string.reverse
local _lower = string.lower
local _upper = string.upper
local uni = false -- turns out that feature was a bad idea and let to undefined behaviours more than anything else

function string.toCharArray(s)
	local chars = {}
	for i = 1, unicode.len(s) do
		table.insert(chars, unicode.sub(s, i, i))
	end
	return chars
end

function string.toByteArray(s)
	local bytes = {}
	for i = 1, string.rawlen(s) do
		table.insert(bytes, string.byte(string.rawsub(s, i, i)))
	end
	return bytes
end

function string.width(...)
	return unicode.wlen(...)
end

function string.len(str)
	if uni then
		return unicode.len(str)
	else
		return _len(str)
	end
end

function string.rawlen(str)
	return _len(str)
end

function string.sub(str, i, j)
	if uni then
		return unicode.sub(str, i, j)
	else
		return _sub(str, i, j)
	end
end

function string.rawsub(str, i, j)
	return _sub(str, i, j)
end

function string.char(...)
	if uni then
		return unicode.char(...)
	else
		return _char(...)
	end
end

function string.reverse(str)
	if uni then
		return unicode.reverse(str)
	else
		return _reverse(str)
	end
end

function string.rawreverse(str)
	return _reverse(str)
end

function string.upper(str)
	if uni then
		return unicode.upper(str)
	else
		return _upper(str)
	end
end

function string.lower(str)
	if uni then
		return unicode.lower(str)
	else
		return _lower(str)
	end
end

function string.startsWith(src, s)
	return (string.sub(src, 1, s:len()) == s)
end

function string.endsWith(src, s)
	return (string.sub(src, src:len()-s:len()+1, src:len()) == s)
end

function string.trim(s)
	-- trailing spaces
	local ogs = s
	for i=1, #s do
		local c = ogs:sub(i, i)
		if c == " " then
			s = s:sub(2, #s)
		else
			break
		end
	end

	-- ending spaces
	ogs = s
	for i=#s, 1, -1 do
		local c = s:sub(i, i)
		if c == " " then
			s = s:sub(1, #s-1)
		else
			break
		end
	end
	return s
end

function string.split(str, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	for part in string.gmatch(str, "([^"..sep.."]+)") do
		table.insert(t, part)
	end
	return t
end

function table.getn(table)
	local i = 0
	for k, v in pairs(table) do
		if type(k) == "number" then
			i = math.max(i, k)
		else
			i = i + 1
		end
	end
	return i
end

-- "Convenient" Lua extensions (deprecated)

function try(func)
	error("please report this as an issue on Fuchas's github page! try/catch unsupported")
	local fin = function(handler)
		handler()
	end
	local this = {}
	this = {
		catch = function(handler, filter)
			local ok, ex = xpcall(func, function(err)
				local exception = {
					trace = debug.traceback(nil, 2),
					details = err
				}
				return exception
			end)
			if not ok then
				handler(ex)
			end
			this.catch = nil
			return this
		end,
		finally = fin
	}
	return this
end

function ifOr(bool, one, two)
	error("please report this as an issue on Fuchas's github page: ifOr unsupported")
	return (bool and one) or two
end

-- Try/Catch Example:
-- try(function()
--   print("Hello World")
-- end).catch(function(ex)
--   print("Error: " .. ex.details)
-- end).finally(function()
--   print("Function ended")
-- end)

if _VERSION ~= "Lua 5.2" and not OSDATA.CONFIG["NO_52_COMPAT"] then
    load([[
	bit32 = {}
	-- TODO complete
	function bit32.band(...)
		local tab = table.pack(...)
		local num = tab[1] or 0
		for i=2,#tab do
			num = num & tab[i]
		end
		return num
	end
	function bit32.bor(...)
		local tab = table.pack(...)
		local num = tab[1] or 0
		for i=2,#tab do
			num = num | tab[i]
		end
		return num
	end
	function bit32.bxor(...)
		local tab = table.pack(...)
		local num = tab[1] or 0
		for i=2,#tab do
			num = num ~ tab[i]
		end
		return num
	end
	function bit32.bnot(x)
		return ~x
	end
	function bit32.rshift(num, disp)
		return num >> disp
	end
	function bit32.lshift(num, disp)
		return num << disp
	end
	function bit32.btest(...)
		return bit32.band(...) ~= 0
	end
	--math.atan2 = math.atan
          ]])()
end
