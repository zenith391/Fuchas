-- String

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

string.rawlen = string.len
string.rawsub = string.sub
string.rawreverse = reverse

function string.startsWith(src, s)
	return (string.sub(src, 1, #s) == s)
end

function string.endsWith(src, s)
	return (string.sub(src, #src-#s+1, #src) == s)
end

function string.trim(s)
	-- trailing spaces
	local ogs = s
	for i=1, #s do
		local c = ogs:sub(i, i)
		if c == " " then
			s = s:sub(2)
		else
			break
		end
	end

	-- ending spaces
	ogs = s
	for i=#s, 1, -1 do
		local c = s:sub(i, i)
		if c == " " then
			s = s:sub(1)
		else
			break
		end
	end
	return s
end

function string.split(str, sep)
	sep = sep or "%s"
	local t,n={},0
	for part in string.gmatch(str, "([^"..sep.."]+)") do
		t[n+1]=part
		n=n+1
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
