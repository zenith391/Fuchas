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
	return (string.sub(src, src:len()-s:len()+1, src:len()) == s)
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
