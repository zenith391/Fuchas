local text = {}

text.trim = string.trim

function text.wrap(value, width, maxWidth)
	-- TODO
	return value
end

function text.tokenize(value)
	return string.split(value, " ")
end

function text.detab(value, tabWidth)
	local str = value:gsub("\t", (" "):rep(tabWidth))
	return str
end

function text.padRight(value, length)
	return value .. (" "):rep(length - unicode.wlen(value))
end

function text.padLeft(value, length)
	return (" "):rep(length - unicode.wlen(value)) .. value
end

return text