local xml = {}

function xml.parse(str)
	local chars = string.toCharArray(str)
	local rootTag = {
		name = nil,
		attr = nil,
		parent = nil,
		childrens = {}
	}
	local currentTag = rootTag
	
	local i = 1
	local _st = false
	local _sta = false
	local _te = false
	local _tn = ""
	local _tap = ""
	local _tav = ""
	local _tt = ""
	local _itap = false
	local _ta = {}
	while i < #chars do
		local ch = chars[i]
		if ch == '/' then
			i = i + 1
			ch = chars[i] -- skip "/"
			_te = true
		end
		if _sta then
			if _itap then
				if ch == '=' then
					_itap = false
				elseif ch ~= " " then
					_tap = _tap .. ch
				end
			else
				if ch ~= ' ' and ch ~= '>' then
					_tav = _tav .. ch
				end
			end
		end
		if _st then
			if ch == '>' then
				_st = false
				_sta = false
				if _te then
					currentTag = currentTag.parent
				else
					if _tap ~= "" then
						_ta[_tap] = load("return " .. _tav)() -- value conversion, insecure
						_tap = ""
						_tav = ""
					end
					local tag = {
						name = _tn,
						attr = _ta,
						childrens = {},
						parent = currentTag
					}
					table.insert(currentTag.childrens, tag)
					currentTag = tag
				end
			elseif ch == ' ' and not _te then
				if _tap ~= "" then
					_ta[_tap] = load("return " .. _tav)() -- value conversion, insecure
				end
				_tap = ""
				_tav = ""
				_sta = true
				_itap = true
			elseif not _sta then
				_tn = _tn .. ch
			end
		end
		if ch == '<' then
			if _tt ~= "" then
				local textTag = {
					name = "#text",
					content = _tt,
					attr = {},
					childrens = {},
					parent = currentTag
				}
				table.insert(currentTag.childrens, textTag)
			end
			_st = true
			_sta = false
			_te = false
			_tn = ""
			_tt = ""
			_ta = {}
		end
		if not _st and ch ~= ">" then
			if ch ~= "\r" and ch ~= "\n" and ch ~= "\t" then
				_tt = _tt .. ch
			end
		end
		i = i + 1
	end
	
	return rootTag
end

return xml