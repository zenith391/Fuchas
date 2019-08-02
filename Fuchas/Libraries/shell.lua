local lib = {}
local aliases = {
	["cp"] = "copy",
	["del"] = "delete",
	["rm"] = "delete",
	["ls"] = "dir",
	["ps"] = "pl"
}
local fs = require("filesystem")

local cursor = {
	x = 1,
	y = 1
}

function lib.getX()
	return cursor.x
end

function lib.getY()
	return cursor.y
end

function lib.setY(y)
	cursor.y = y
end

function lib.setX(x)
	cursor.x = x
end

function lib.getCursor()
	return cursor.x, cursor.y
end

function lib.setCursor(col, row)
	cursor.x = col
	cursor.y = row
end

function lib.clear()
	require("OCX/ConsoleUI").clear(0x000000)
	lib.setCursor(1, 1)
end

function lib.getKeyboard()
	return component.getPrimary("screen").getKeyboards()[1]
end

function lib.getScreen()
	return component.getPrimary("screen").address
end

function lib.parse(tab)
	local ntab = {}
	local options = {}
	for _, v in pairs(tab) do
		if v:len() > 0 then
			if v:sub(1, 2) == "--" then
				options[v:sub(3, v:len())] = true
			elseif v:sub(1, 1) == "-" then
				options[v:sub(2, 2)] = true
				if v:len() > 3 then
					options[v:sub(2, 2)] = v:sub(4, v:len())
				end
			else
				table.insert(ntab, v)
			end
		end
	end
	return ntab, options
end

function lib.resolve(path)
	local p = path
	local paths = string.split(shin32.getenv("PATH"), ";")
	table.insert(paths, shin32.getenv("PWD_DRIVE") .. ":/" .. shin32.getenv("PWD"))
	local exts = string.split(shin32.getenv("PATHEXT"), ";")
	table.insert(exts, "")
	
	if fs.exists(p) then
		return p
	end
	
	for _, pt in pairs(paths) do
		pt = fs.canonical(pt)
		for _, ext in pairs(exts) do
			local np = pt .. "/" .. p .. ext
			if fs.exists(np) then
				return np
			end
		end
	end
	
	return nil
end

function lib.write(obj)
	write(tostring(obj))
end

function lib.getAliases(cmd)
	if cmd then
		local cmdAliases = {}
		for k, v in pairs(aliases) do
			if v == cmd then
				table.insert(cmdAliases, k)
			end
		end
		return cmdAliases
	else
		return aliases
	end
end

function lib.getCommand(alias)
	return aliases[alias]
end

function lib.addAlias(alias, cmd)
	aliases[alias] = cmd
end

function lib.parseCL(cl)
	local args = {}
	local ca = string.toCharArray(cl)
	
	local istr = false
	local arg = ""
	for i = 1, #ca do
		local c = ca[i]
		if not istr then
			if c == '"' then
				arg = ""
				istr = true
			elseif c == " " then
				table.insert(args, arg)
				arg = ""
			else
				arg = arg .. c
			end
		else
			if c == '"' then
				istr = false
				table.insert(args, arg)
				arg = ""
			else
				arg = arg .. c
			end
		end
	end
	if arg ~= "" then
		if istr then
			error("parse error: long-argument not ended with \"")
		end
		table.insert(args, arg)
	end
	
	return args
end

function lib.read()
	local c = ""
	local s = ""
	local event = require("event")
	while c ~= '\r' do -- '\r' == Enter
		local a, b, d = event.pull("key_down")
		if a == "key_down" then
			if d ~= 0 then
				c = string.char(d)
				if c ~= '\r' then
					if d == 8 then -- backspace
						if s:len() > 0 then
							s = s:sub(1, s:len() - 1)
							cursor.x = cursor.x - 1
							write(" ")
							cursor.x = cursor.x - 1
						end
					else
						s = s .. c
						write(c)
					end
				end
			end
		end
	end
	return s
end

return lib
