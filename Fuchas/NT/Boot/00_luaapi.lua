function string.toCharArray(s)
	local chars = {}
	for i = 1, #s do
		table.insert(chars, s:sub(i, i))
	end
	return chars
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