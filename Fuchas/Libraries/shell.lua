local lib = {}
local aliases = {
	["cp"] = "copy",
	["del"] = "delete",
	["rm"] = "delete",
	["ls"] = "dir",
	["ps"] = "pl",
	["reboot"] = "power reboot",
	["shutdown"] = "power off",
	["cls"] = "clear"
}

local fs = require("filesystem")
local driver = require("driver")
local clipboard = require("clipboard")
local stdout = io.stdout
local globalHistory = {}

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
	driver.gpu.fill(1, 1, 160, 50, 0)
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
				print(v)
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
	io.write(tostring(obj))
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

local function readEventFilter(name)
	return name == "key_down" or name == "paste_trigger"
end

local function displayCursor()
	driver.gpu.drawText(cursor.x, cursor.y, "_")
end

local function hideCursor()
	driver.gpu.fill(cursor.x, cursor.y, 1, 1, 0x000000)
end

function lib.fileAutocomplete(s, sp)
	local path = os.getenv("PWD_DRIVE") .. ":/" .. os.getenv("PWD")
	local choices = {}
	--if not fs.exists(path .. sp[#sp]) then
	--	if fs.exists(fs.path(path .. sp[#sp])) then
	--		path = fs.path(path .. sp[#sp])
	--	end
	--end
	local seg = fs.segments(sp[#sp])
	local st = table.remove(seg)
	if #seg > 0 then path = path .. table.concat(seg, "/") end
	seg = fs.segments(sp[#sp])
	for k, v in pairs(fs.list(path)) do
		if string.startsWith(v, seg[#seg]) then
			local _, e = string.find(v, seg[#seg])
			table.insert(choices, v:sub(e+1, v:len()))
		end
	end
	return choices
end

local inp = ""
function lib.appendRead(s)
	inp = inp .. s
end

function lib.autocompleteFor(input, autocompleter)
	if input:len() == 0 then
		return {}
	end
	local sp = string.split(input, " ")
	local plus = autocompleter(input, sp)
	return plus
end

function lib.read(options)
	if not options then
		options = {}
	end
	local c = ""
	inp = ""
	local curVisible = true
	local changeVis = false
	local history = options.history or globalHistory
	local event = require("event")
	displayCursor()
	while c ~= '\r' do -- '\r' == Enter
		local a, b, d = event.pullFiltered(1, readEventFilter)
		local sp = string.split(inp, " ")
		if a == "key_down" then
			if d ~= 0 then
				c = string.char(d)
				if c ~= '\r' then
					if d == 8 then -- backspace
						if string.len(inp) > 0 then
							hideCursor()
							inp = string.sub(inp, 1, string.len(inp) - 1)
							cursor.x = cursor.x - 1
							io.write(" ")
							cursor.x = cursor.x - 1
							displayCursor()
							if options.onType then
								options.onType(inp, inp:len())
							end
						end
					elseif d > 0x1F and d ~= 0x7F then
						hideCursor()
						inp = inp .. c
						if options.pwchar then
							io.write(options.pwchar)
						else
							io.write(c)
						end
						displayCursor()
						if options.onType then
							options.onType(inp, inp:len())
						end
					elseif d == 0x09 and not options.pwchar then -- horizontal tab
						if options.autocomplete then
							if type(options.autocomplete) == "table" then
								-- TODO
							else
								local plus = options.autocomplete(inp, sp)
								if options.autocompleteHandler then
									options.autocompleteHandler(plus, inp:len(), inp)
								else
									if plus[1] then
										hideCursor()
										inp = inp .. plus[1]
										io.write(plus[1])
										displayCursor()
									end
								end
							end
						end
					end
					changeVis = false
				end
			end
		elseif a == "paste_trigger" then
			local clip = clipboard.paste()
			if clip.type == "text/string" then
				hideCursor()
				local txt = clip.object
				inp = inp .. txt
				io.write(txt)
				displayCursor()
				changeVis = false
			end
		end
		if curVisible and changeVis then
			hideCursor()
			curVisible = false
		elseif changeVis then
			displayCursor()
			curVisible = true
		end
		if not changeVis then
			changeVis = true
			curVisible = true
		end
	end
	return inp
end

return lib
