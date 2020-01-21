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
	local _tap = "" -- tag attribute propety (name)
	local _tav = "" -- tag attribute value
	local _tt = "" -- currently parsing text
	local _utt = "" -- currently (unformated) parsing text
	local _itap = false -- is parsing attribute property?
	local _ta = {} -- currently parsing attributes
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
			end
		end
		if ch == '<' then
			if _tt ~= "" then
				local textTag = {
					name = "#text",
					content = _tt,
					unformattedContent = _utt,
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
			_utt = ""
			_ta = {}
		end
		if not _st then
			_utt = _utt .. ch
			if ch ~= "\r" and ch ~= "\n" and ch ~= "\t" then
				_tt = _tt .. ch
			end
			if _tt:sub(1, 1) == ">" then
				_tt = ""
			end
			if _utt:sub(1, 1) == ">" then
				_utt = ""
			end
		end
		i = i + 1
	end
          end)
    if not ok then
        error("could not parse line " .. tostring(line) .. ": " .. tostring(err))
    end
	return rootTag
end

return xml
