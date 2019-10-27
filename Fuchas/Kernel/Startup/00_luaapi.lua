-- String
local _char = string.char
local _len = string.len
local _sub = string.sub
local _reserve = string.reverse
local _lower = string.lower
local _upper = string.upper
local uni = true -- experiemental feature (automatic unicode support)

function string.setUnicodeEnabled(u)
	uni = u
end

function string.isUnicodeEnabled()
	return uni
end

function string.toggleUnicode()
	uni = not uni
end

function string.toCharArray(s)
	local chars = {}
	for i = 1, #s do
		table.insert(chars, s:sub(i, i))
	end
	return chars
end

function string.width(...)
	return unicode.charWidth(...)
end

function string.len(str)
	if uni then
		return unicode.wlen(str)
	else
		return _len(str)
	end
end

function string.sub(str, i, j)
	if uni then
		return unicode.sub(str, i, j)
	else
		return _sub(str, i, j)
	end
end

function string.char(...)
	if uni then
		return unicode.char(...)
	else
		return _char(...)
	end
end

function string.reserve(str)
	if uni then
		return unicode.reverse(str)
	else
		return _reverse(str)
	end
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
		return _upper(str)
	end
end

function string.startsWith(src, s)
	return (string.sub(src, 1, s:len()) == s)
end

function string.endsWith(src, s)
	return (string.sub(src, src:len()-s:len(), src:len()) == s)
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
table.maxn = table.getn

-- Obsolete I/O methods
function io.fromu16(x)
	local b1=string.char(x%256) x=(x-x%256)/256
	local b2=string.char(x%256)
	return {b1, b2}
end

function io.fromu32(x)
	local b1=string.char(x%256) x=(x-x%256)/256
	local b2=string.char(x%256) x=(x-x%256)/256
	local b3=string.char(x%256) x=(x-x%256)/256
	local b4=string.char(x%256)
	return {b1, b2, b3, b4}
end

function io.tou16(arr, off)
	local v1 = arr[off + 1]
	local v2 = arr[off]
	return v1 + (v2*256)
end

function io.tou32(arr, off)
	local v1 = io.tou16(arr, off + 2)
	local v2 = io.tou16(arr, off)
	return v1 + (v2*65536)
end

-- New I/O methods

-- To unsigned number (max 32-bit)
function io.tounum(number, count, littleEndian)
	local data = {}
	
	if count > 4 then
		error("lua bit32 only supports 32-bit numbers")
	end
	
	if littleEndian then
		local i = count
		while i > 0 do
			data[i] = bit32.band(number, 0x000000FF)
			number = bit32.rshift(number, 8)
			i = i - 1
		end
	else
		local i = 1
		while i < count+1 do
			data[i] = bit32.band(number, 0x000000FF)
			number = bit32.rshift(number, 8)
			i = i + 1
		end
	end
	return data
end

-- From unsigned number (max 32-bit)
function io.fromunum(data, littleEndian, count)
	count = count or 0
	if count == 0 then
		if type(data) == "string" then
			count = data:len()
		else
			count = #data
		end
	end
	
	if count > 4 then
		error("lua bit32 only supports 32-bit numbers")
	end
	
	if count == 1 then
		if data then
			return string.byte(data)
		else
			return nil
		end
	else
		-- use 4 bytes max as Lua's bit32 scale the number between [0, 2^32-1] which makes the number impossible to
		-- go beyond ‭4,294,967,295‬
		local bytes, result = {string.byte(data or "\x00", 1, 4)}, 0
		if littleEndian then
			local i = #bytes -- just do it in inverse order
			while i > 0 do
				result = bit32.bor(bit32.lshift(result, 8), bytes[i])
				i = i - 1
			end
		else
			local i = 1
			while i < #bytes do
				result = bit32.bor(bit32.lshift(result, 8), bytes[i])
				i = i + 1
			end
		end
		return result
	end
end

-- Convenient Lua extensions

function try(func)
	local fin = function(handler)
		handler()
	end
	return {
		catch = function(handler, filter)
			local ok, ex = pcall(func)
			if not ok then
				handler(ex)
			end
			return fin
		end,
		finally = fin
	}
end

function ifOr(bool, one, two)
	if bool then
		return one
	else
		return two
	end
end

-- Try/Catch Example:
-- try(function()
--   print("Hello World")
-- end).catch(function(ex)
--   print("Error: " .. ex.trace)
-- end).finally(function()
--   print("Function ended")
-- end)

if not bit32 then
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
