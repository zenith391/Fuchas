local text = {}

-- Pad text to the left so it has a minimum size of "len"
function text.padLeft(text, len, char)
	char = char or " "
	if unicode.len(text) < len then
		text = char:rep(len-unicode.len(text)) .. text
	end
	return text
end

-- Pad text to the right so it has a minimum size of "len"
function text.padRight(text, len, char)
	char = char or " "
	if #text < len then
		text = text .. char:rep(len-#text)
	end
	return text
end

-- Pad text to the center so it has a minimum size of "len"
function text.padCenter(text, len, char)
	char = char or " "
	len = len - unicode.len(text)

	local halfLen = len / 2
	local leftRep = char:rep(math.ceil(halfLen))
	local rightLen = math.ceil(halfLen)
	local _, fractionalPart = math.modf(halfLen)

	if fractionalPart >= 0.5 then
		rightLen = rightLen - 1
	end

	local rightRep = char:rep(rightLen)
	return leftRep .. text .. rightRep
end

function text.formatTable(t, order)
	local str = ""
	local columnsLength = {}
	local items = {}

	local separatorChar = unicode.char(0x2500) -- was "-"
	local verticalChar = unicode.char(0x2502) -- was '|'
	local cornerChar = {
		topLeft = unicode.char(0x250C),
		topRight = unicode.char(0x2510),
		bottomLeft = unicode.char(0x2514),
		bottomRight = unicode.char(0x2518)
	}
	local intersectChar = {
		top = unicode.char(0x252C),
		left = unicode.char(0x251C),
		right = unicode.char(0x2524),
		bottom = unicode.char(0x2534),
		all = unicode.char(0x253C)
	}

	for _, key in ipairs(order) do
		local values = t[key]
		local columnLength = unicode.len(key) + 2
		for i, value in pairs(values) do
			if not items[i] then items[i] = {} end
			items[i][key] = tostring(value)
			columnLength = math.max(
				columnLength,
				unicode.len(tostring(value)) + 2
			)
		end
		columnsLength[key] = columnLength
	end

	-- Top Border
	for i, key in ipairs(order) do
		local char = cornerChar.topLeft
		if i > 1 then char = intersectChar.top end
		str = str .. char .. separatorChar:rep(columnsLength[key])
	end
	str = str .. cornerChar.topRight .. "\n"

	-- Header
	for i, key in ipairs(order) do
		str = str .. verticalChar .. text.padCenter(key, columnsLength[key])
	end
	str = str .. verticalChar .. "\n"

	-- Separator
	for i, key in ipairs(order) do
		local char = intersectChar.left
		if i > 1 then char = intersectChar.all end
		str = str .. char .. separatorChar:rep(columnsLength[key])
	end
	str = str .. intersectChar.right .. "\n"

	-- Content
	for _, item in ipairs(items) do
		for _, key in ipairs(order) do
			local value = item[key]
			str = str .. verticalChar .. text.padCenter(value, columnsLength[key])
		end
		str = str .. verticalChar .. "\n"
	end

	-- Bottom Border
	for i, key in ipairs(order) do
		local char = cornerChar.bottomLeft
		if i > 1 then char = intersectChar.bottom end
		str = str .. char .. separatorChar:rep(columnsLength[key])
	end
	str = str .. cornerChar.bottomRight
	return str
end

return text
