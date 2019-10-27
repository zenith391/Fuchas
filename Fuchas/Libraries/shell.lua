local lib = {}
local aliases = {
	["cp"] = "copy",
	["del"] = "delete",
	["rm"] = "delete",
	["ls"] = "dir",
	["ps"] = "pl",
	["reboot"] = "power reboot",
	["shutdown"] = "power off"
}
local fs = require("filesystem")
local stdout = io.stdout

local cursor = {
	x = 1,
	y = 1
}

function lib.enableANSI()
	local ESC = string.char(27)
	local gpu = component.gpu
	local width, height = gpu.getResolution()
	io.stdout.write = function(self, val)
		if val:find("\t") then
			val = val:gsub("\t", "    ")
		end
		if val:find(ESC .. "c") then
			local _, occ = val:find(ESC .. "c")
			gpu.setBackground(0x000000)
			gpu.fill(1, 1, width, height, " ")
			val = val:sub(occ, val:len())
			io.stdout:write(val)
		end
		-- CSI sequences
		if val:find(ESC .. "%[A") then
			local _, occ = val:find(ESC .. "c")
			cursor.y = cursor.y - 1
			if cursor.y < 1 then cursor.y = 1 end
			val = val:sub(occ, val:len())
			io.stdout:write(val)
		end
		if val:find(ESC .. "%[B") then
			local _, occ = val:find(ESC .. "c")
			cursor.y = cursor.y + 1
			val = val:sub(occ, val:len())
			io.stdout:write(val)
		end
		if val:find(ESC .. "%[C") then
			local _, occ = val:find(ESC .. "c")
			cursor.x = cursor.x + 1
			if cursor.x > width then cursor.x = width end
			val = val:sub(occ, val:len())
			io.stdout:write(val)
		end
		if val:find(ESC .. "%[D") then
			local _, occ = val:find(ESC .. "c")
			cursor.x = cursor.x - 1
			if cursor.x < 1 then cursor.x = 1 end
			val = val:sub(occ, val:len())
			io.stdout:write(val)
		end
		if val:find(ESC .. "%[2J") then
			cursor.x = 1
			cursor.y = 1
			gpu.fill(1, 1, 160, 50, " ")
		end
		
		if val:find("\n") then
			for line in val:gmatch("([^\n]+)") do
				if lib.getY() == h then
					gpu.copy(1, 2, w, h - 1, 0, -1)
					gpu.fill(1, h, w, 1, " ")
					lib.setY(lib.getY() - 1)
				end
				gpu.set(lib.getX(), lib.getY(), line)
				lib.setX(1)
				lib.setY(lib.getY() + 1)
			end
		else
			if lib.getY() == h then
				gpu.copy(1, 2, w, h - 1, 0, -1)
				gpu.fill(1, h, w, 1, " ")
				lib.setY(lib.getY() - 1)
			end
			gpu.set(lib.getX(), lib.getY(), val)
			lib.setX(lib.getX() + val:len())
		end
		return true
	end
end

function lib.resetStdout(full) -- disables ANSI
	if full then
		stdout = io.createStdOut()
	end
	io.stdout = stdout
end

function lib.stdout()
	return io.stdout
end

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
	local paths = string.split(os.getenv("PATH"), ";")
	table.insert(paths, os.getenv("PWD_DRIVE") .. ":/" .. os.getenv("PWD"))
	local exts = string.split(os.getenv("PATHEXT"), ";")
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
