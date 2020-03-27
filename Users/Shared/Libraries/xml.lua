-- Very very simple XML library, misses a lot of features
local xml = {}

--- Tags are tables as follow:
---   name: Name
---   attr: Attributes
---   parent: Parent
---   childrens: Childrens
--- What this function return is a root tag (just a tag with no name, no attribute and no parent, that have all tags (not nested ones) as childrens)
function xml.parse(str)
	local chars = string.toCharArray(str)
    local line = 1
    local rootTag = {
		name = nil,
		attr = nil,
		parent = nil,
		childrens = {}
	}
    local ok, err = pcall(function()
	local currentTag = rootTag
	
	local i = 1
	local _st = false -- is parsing tag name? (<ohml>)
	local _sta = false -- is parsing attributes?
	local _te = false -- is tag a ending tag? (</ohml>)
	local _tn = "" -- tag name
	local _otn = "" -- old tag name
	local _ott = "" -- old parsing text
	local _tap = "" -- tag attribute propety (name)
	local _tav = "" -- tag attribute value
	local _tt = "" -- currently parsing text
	local _ttcdata = false -- is the current parsing text in a CDATA section? (<![CDATA ]]>)
	local _itap = false -- is parsing attribute property?
	local _ta = {} -- currently parsing attributes
	local _ota = {} -- old parsing attributes
	while i < #chars do
		local ch = chars[i]
		if ch == '/' and not _sta and _tt == "" then
			i = i + 1
			ch = chars[i] -- skip "/"
			_te = true
		end
		if ch == '\n' then
			line = line + 1
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
					_te = false
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
				if string.sub(_tn, string.len(_tn)-7) == "![CDATA[" then -- minus length of <![CDATA[
					_ttcdata = true
					table.remove(currentTag.childrens)
					_st = false
					_sta = false
					_te = false
					_tt = _ott
					_tn = _otn
					_ta = _ota
				end
			end
		end
		if ch == '<' and not _ttcdata then
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
			_otn = _tn
			_tn = ""
			_ott = _tt
			_tt = ""
			_ota = _ta
			_ta = {}
		end
		if not _st then
			if ch ~= "\r" and ch ~= "\n" and ch ~= "\t" then
				_tt = _tt .. ch
			else
				if _ttcdata then
					if string.sub(_tt, string.len(_tt)-2) == "]]>" then -- minus length of ]]>
						_tt = string.sub(_tt, 1, string.len(_tt)-3)
						_ttcdata = false
					else
						_tt = _tt .. ch
					end
				end
			end
			if _tt:sub(1, 1) == ">" then
				_tt = ""
			end
		end
		i = i + 1
	end
	if _ttcdata then
		error("EOF in CDATA section, expected ]]>")
	end
    end) -- end of pcall
    if not ok then
        error("error at line " .. tostring(line) .. ": " .. tostring(err))
    end
	return rootTag
end

return xml
