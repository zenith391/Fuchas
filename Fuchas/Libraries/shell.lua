local lib = {}
local aliases = {
	["cp"] = "copy",
	["del"] = "delete",
	["rm"] = "delete",
	["ls"] = "dir",
	["ps"] = "pl",
	["reboot"] = "power reboot",
	["shutdown"] = "power off",
	["cls"] = "clear",
	["edit"] = "quack"
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

function lib.clearLine()
	driver.gpu.fill(1, cursor.y, 160, 1, 0)
end

function lib.getKeyboard()
	local screen = lib.getScreen()
	if screen then
		local proxy = component.proxy(screen)
		return proxy.getKeyboards()[1]
	else
		return nil -- unknown
	end
end

function lib.getScreen()
	local gpu = io.stdout.gpu
	if not gpu then
		return nil
	else
		return gpu.getScreen()
	end
end

-- gpu: GPU DRIVER
function lib.createStdOut(gpu)
	local stream = {}
	local sh = require("shell")
	local w, h = gpu.getResolution()
	stream.gpu = gpu
	stream.close = function(self)
		return false -- unclosable stream
	end
	local colorTable = {
		0x0,
		0xAA0000,
		0x00AA00,
		0xAA5500,
		0x0000AA,
		0xAA00AA,
		0x00AAAA,
		0xAAAAAA
	}
	local brightColorTable = {
		0x555555,
		0xFF5555,
		0x55FF55,
		0xFFFF55,
		0x5555FF,
		0xFF55FF,
		0x55FFFF,
		0xFFFFFF
	}
	local ESC = string.char(0x1B)
	local CSI = ESC .. "%["
	stream.write = function(self, val)
		if val:find("\t") then
			val = val:gsub("\t", "    ")
		end
		if sh.getX() >= w then
			sh.setX(0)
			sh.setY(sh.getY() + 1)
		end
		local ptr, ptrE, ptrC = val:find(CSI .. "(.*)H") -- move cursor, in order: pattern start, pattern end, pattern capture
		if ptr then
			self:write(val:sub(1, ptr-1))
			local split = string.split(ptrC, ";")
			if #split >= 2 then
				local y = tonumber(split[1]) or 1
				local x = tonumber(split[2]) or 1
				lib.setCursor(x, y)
				return self:write(val:sub(ptrE+1))
			end
		end
		ptr, ptrE = val:find(ESC .. "c") -- clear
		if ptr then
			self:write(val:sub(1, ptr-1))
			lib.clear()
			return self:write(val:sub(ptrE+1))
		end
		ptr, ptrE = val:find(CSI .. "%?25h")
		if ptr then
			self:write(val:sub(1, ptr-1))
			-- TODO: show cursor
			return self:write(val:sub(ptrE+1))
		end
		ptr, ptrE = val:find(CSI .. "%?25l")
		if ptr then
			self:write(val:sub(1, ptr-1))
			-- TODO: hide cursor
			return self:write(val:sub(ptrE+1))
		end
		ptr, ptrE, ptrC = val:find(CSI .. "([%d;]+)m")
		if ptr then
			self:write(val:sub(1, ptr-1))
			local sgrs = string.split(ptrC, ";")
			for i=1, #sgrs do
				local sgr = tonumber(sgrs[i])
				if sgr and sgr >= 30 and sgr <= 37 then -- foreground
					gpu.setForeground(colorTable[sgr-29])
				elseif sgr == 38 then -- extended foreground color
					if sgrs[i+1] == "2" then -- only supporting RGB extended color
						local r = sgrs[i+2]
						local g = sgrs[i+3]
						local b = sgrs[i+4]
						local hex = bit32.bor(bit32.lshift(r, 16), bit32.lshift(g, 8), b)
						gpu.setForeground(hex)
						i = i + 4
					end
				elseif sgr == 39 then -- default foreground color
					gpu.setForeground(0xFFFFFF)
				elseif sgr and sgr >= 40 and sgr <= 47 then -- background
					gpu.setColor(colorTable[sgr-39])
				elseif sgr == 48 then -- extended background color
					if sgrs[i+1] == "2" then -- only supporting RGB extended color
						local r = sgrs[i+2]
						local g = sgrs[i+3]
						local b = sgrs[i+4]
						local hex = bit32.bor(bit32.lshift(r, 16), bit32.lshift(g, 8), b)
						gpu.setColor(hex)
						i = i + 4
					end
				elseif sgr == 49 then -- default background color
					gpu.setColor(0x000000)
				elseif sgr and sgr >= 90 and sgr <= 97 then -- bright foreground
					gpu.setForeground(brightColorTable[sgr-89])
				elseif sgr and sgr >= 100 and sgr <= 107 then -- bright background
					gpu.setColor(brightColorTable[sgr-99])
				end
			end
			return self:write(val:sub(ptrE+1))
		end
		if val:find("\n") then
			local s, e = val:find("\n")
			gpu.drawText(sh.getX(), sh.getY(), val:sub(1, s-1))
			sh.setX(1)
			sh.setY(sh.getY() + 1)
			if sh.getY() == h then
				gpu.copy(1, 2, w, h - 1, 0, -1)
				gpu.fill(1, h, w, 1)
				sh.setY(sh.getY() - 1)
			end
			return self:write(val:sub(e+1))
		else
			if sh.getY() == h then
				gpu.copy(1, 2, w, h - 1, 0, -1)
				gpu.fill(1, h, w, 1)
				sh.setY(sh.getY() - 1)
			end
			gpu.drawText(sh.getX(), sh.getY(), val)
			sh.setX(sh.getX() + string.len(val))
		end
		return true
	end
	stream.read = function(self, len)
		return nil -- cannot read stdOUT
	end
	return stream
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
	local strs = string.split(cl, "|")
	local commands = {}
	for i=1, #strs do
		local args = {}
		strs[i] = string.trim(strs[i])
		local ca = string.toCharArray(strs[i])
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
		table.insert(commands, args)
	end
	return commands
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
	local historyIndex = #history+1
	displayCursor()
	while c ~= '\r' do -- '\r' == Enter
		local a, b, d, code = event.pullFiltered(1, readEventFilter)
		local sp = string.split(inp, " ")
		if a == "key_down" then
			if code == 200 then -- up arrow
				if historyIndex > 1 then
					historyIndex = historyIndex - 1
					hideCursor()
					cursor.x = cursor.x - string.len(inp)
					io.write((" "):rep(string.len(inp)))
					cursor.x = cursor.x - string.len(inp)
					io.write(history[historyIndex])
					inp = history[historyIndex]
					displayCursor()
				end
			elseif code == 208 then -- down arrow
				if historyIndex < #history then
					historyIndex = historyIndex + 1
					hideCursor()
					cursor.x = cursor.x - string.len(inp)
					io.write(history[historyIndex])
					inp = history[historyIndex]
					displayCursor()
				end
			elseif d ~= 0 then
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
	table.insert(history, inp)
	return inp
end

return lib
