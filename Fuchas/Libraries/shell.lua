--- Shell library
-- @module shell
-- @alias lib
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
	["edit"] = "quack",
	["fsh"] = "A:/Fuchas/Interfaces/Fushell/main.lua",
	["sh"] = "A:/Fuchas/Interfaces/Fushell/main.lua",
	["concert"] = "A:/Fuchas/Interfaces/Concert/main.lua"
}

local fs = require("filesystem")
local driver = require("driver")
local clipboard = require("clipboard")
local globalHistory = {}


local ESC = string.char(0x1B)
local CSI = ESC .. "%["

--- Return the standard output
-- @treturn stream standard output
-- @see io.stdout
function lib.stdout()
	return io.stdout
end

--- Return the cursor X position
-- @treturn int cursor X position
function lib.getX()
	return io.stdout.x or 1
end

--- Return the cursor Y position
-- @treturn int cursor Y position
function lib.getY()
	return io.stdout.y or 1
end

--- Set the cursor X position
-- @tparam int x cnew ursor X position
function lib.setX(x)
	if io.stdout.x then io.stdout.x = x end
end

--- Set the cursor Y position
-- @tparam int y new cursor Y position
function lib.setY(y)
	if io.stdout.y then io.stdout.y = y end
end

--- Return the cursor position
-- @treturn int x cursor X position
-- @treturn int y cursor Y position
function lib.getCursor()
	return io.stdout.x or 1, io.stdout.y or 1
end

--- Returns true if the standard output is a TTY and supports VT100 escape sequences
-- @treturn bool whether stdout is a tty
function lib.isTTY()
	if io.stdout.tty then
		return io.stdout.tty
	else
		return false
	end
end

--- Returns the width of the underlying terminal
-- @treturn int terminal width
function lib.getWidth()
	return io.stdout.w
end

--- Returns the height of the underlying terminal
-- @treturn int terminal height
function lib.getHeight()
	return io.stdout.h
end

--- Set the cursor position
-- @tparam int x new cursor X position
-- @tparam int y new cursor Y position
function lib.setCursor(x, y)
	if io.stdout.x and io.stdout.y then
		io.stdout.x = x
		io.stdout.y = y
	end
end

--- Clear the terminal and set cursor position to 1, 1
-- @raise not a terminal
function lib.clear()
	if lib.isTTY() then
		io.stdout:write(ESC .. "c")
	elseif lib.getHeight() then
		io.stdout:write(('\n'):rep(lib.getHeight()))
	else
		error("not a terminal")
	end
end

--- Clear the current line
function lib.clearLine()
	driver.gpu.fill(1, lib.getY(), 160, 1, 0)
end

--- Return the keyboard address the terminal is listening from
-- @treturn[opt] string keyboard address
function lib.getKeyboard()
	local screen = lib.getScreen()
	if screen then
		local proxy = component.proxy(screen)
		return proxy.getKeyboards()[1]
	else
		return nil -- unknown
	end
end

--- Return the screen address the terminal is printing to
-- @treturn[opt] string screen address
function lib.getScreen()
	local gpu = io.stdout.gpu
	if not gpu then
		return nil
	else
		return gpu.getScreen()
	end
end

--- Internal function used to create a standard output from a GPU object
-- @tparam driver gpu GPU driver
-- @treturn stream standard output
function lib.createStdOut(gpu)
	local stream = {}
	local sh = require("shell")
	stream.gpu = gpu
	stream.x = 1
	stream.y = 1
	stream.tty = true
	stream.close = function(self)
		return false -- unclosable stream
	end
	local colorTable = {
		0x0,
		0x800000,
		0x008000,
		0x808000,
		0x000080,
		0x800080,
		0x008080,
		0xC0C0C0
	}
	local brightColorTable = {
		0x555555,
		0xFF0000,
		0x00FF00,
		0xFFFF00,
		0x0000FF,
		0xFF00FF,
		0x00FFFF,
		0xFFFFFF
	}
	local w, h = gpu.getResolution()
	stream.w = w
	stream.h = h
	require("event").listen("screen_resized", function(_, nw, nh)
		w, h = gpu.getResolution() -- getResolution() returns viewport on purpose and that's what we want
		stream.w = w
		stream.h = h
	end)
	stream.write = function(self, val)
		if val:find("\t") then
			local s = val:find("\t")
			self:write(unicode.sub(val, 1, s-1))
			sh.setX(sh.getX() + 4 - ((sh.getX()-1) % 4))
			val = val:sub(s+1)
			return self:write(val)
		end
		if sh.getX() >= w then
			sh.setX(1)
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
				return self:write(unicode.sub(val, ptrE+1))
			end
		end
		ptr, ptrE = val:find(ESC .. "c") -- clear
		if ptr then
			self:write(unicode.sub(val, 1, ptr-1))
			self.gpu.fill(1, 1, w, h)
			lib.setCursor(1, 1)
			return self:write(unicode.sub(val, ptrE+1))
		end
		ptr, ptrE = val:find(CSI .. "%?25h")
		if ptr then
			self:write(val:sub(1, ptr-1))
			-- TODO: show cursor
			return self:write(unicode.sub(val, ptrE+1))
		end
		ptr, ptrE = val:find(CSI .. "%?25l")
		if ptr then
			self:write(val:sub(1, ptr-1))
			-- TODO: hide cursor
			return self:write(unicode.sub(val, ptrE+1))
		end
		ptr, ptrE, ptrC = val:find(CSI .. "([%d;]+)m")
		if ptr then
			self:write(unicode.sub(val, 1, ptr-1))
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
			 -- no risk at using string.sub as we only cut \n, and since string.find isn't utf-8 aware, it avoids problems
			self:write(string.sub(val, 1, s-1))
			sh.setX(1)
			sh.setY(sh.getY() + 1)
			if sh.getY() >= h then
				gpu.copy(1, 2, w, h - 1, 0, -1)
				gpu.fill(1, h, w, 1)
				sh.setY(sh.getY() - 1)
			end
			return self:write(string.sub(val, e+1)) -- same as above
		else
			if sh.getX()+unicode.len(val) > w+1 then
				self:write(unicode.sub(val, 1, w-sh.getX()+1))
				return self:write(unicode.sub(val, w+1))
			end
			if sh.getY() >= h then
				gpu.copy(1, 2, w, h - 1, 0, -1)
				gpu.fill(1, h, w, 1)
				sh.setY(sh.getY() - 1)
			end
			gpu.drawText(sh.getX(), sh.getY(), val)
			sh.setX(sh.getX() + unicode.wlen(val))
		end
		return true
	end
	stream.read = function(self, len)
		return nil -- cannot read stdOUT
	end
	return stream
end

--- Function used for parsing command line arguments
-- @tab tab arguments list
-- @return arguments
-- @return options
function lib.parse(tab)
	local ntab = {}
	local options = {}
	for _, v in pairs(tab) do
		if v:len() > 0 then
			if unicode.sub(v, 1, 2) == "--" then
				local pos = string.find(v, "=")
				if pos then
					local key = unicode.sub(v, 3, pos-1)
					local val = unicode.sub(v, pos+1)
					options[key] = val
				else
					options[unicode.sub(v, 3, unicode.len(v))] = true
				end
			elseif unicode.sub(v, 1, 1) == "-" then
				for _, ch in pairs(string.toCharArray(unicode.sub(v, 2))) do
					options[ch] = true
				end
			else
				table.insert(ntab, v)
			end
		end
	end
	return ntab, options
end

--- Resolve a local or absolute file using PATH, PWD and PATHEXT. This shouldn't be used by CLI programs.
-- @string path Path to a file to resolve
-- @boolean alwaysResolve Whether it should resolve even if the path is not found
function lib.resolve(path, alwaysResolve)
	checkArg(1, path, "string")
	local paths = string.split(os.getenv("PATH"), ";")
	table.insert(paths, 1, os.getenv("PWD"))
	local exts = string.split(os.getenv("PATHEXT"), ";")
	table.insert(exts, "")

	if fs.exists(path) then
		return path
	end

	for _, pt in pairs(paths) do
		pt = fs.canonical(pt)
		for _, ext in pairs(exts) do
			local np = pt .. "/" .. path .. ext
			if fs.exists(np) then
				return np
			end
		end
	end

	if alwaysResolve then
		local pwd = os.getenv("PWD")
		if path:sub(2, 3) == ":/" then
			return path
		else
			return fs.concat(pwd, path)
		end
	end
	return nil
end

--- Resolve to PWD. If the path exists, returns it, otherwise checks if it exists in the
-- PWD. This method should be preferred for CLI programs.
-- @string path Path to be resolved
function lib.resolveToPwd(path)
	if fs.exists(path) then
		return path
	end

	local pwd = os.getenv("PWD")
	if path:sub(2, 3) == ":/" then
		return path
	else
		return fs.concat(pwd, path)
	end
end

--- Write an object to terminal
-- @param obj Object to write
-- @see io.write
function lib.write(obj)
	io.write(tostring(obj))
end

--- If given, return the aliases corresponding to the given command, otherwise return all aliases.
-- @string[opt] cmd
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

--- Get command corresponding to an alias
function lib.getCommand(alias)
	return aliases[alias]
end

--- Add an alias to the given command
function lib.addAlias(alias, cmd)
	aliases[alias] = cmd
end

--- Internal function used for implementing shells.
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
		if istr then
			error("parse error: long-argument not ended with double-quote (\")")
		end
		if arg ~= "" then
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
	driver.gpu.drawText(lib.getX(), lib.getY(), "_")
end

local function hideCursor()
	driver.gpu.fill(lib.getX(), lib.getY(), 1, 1, 0x000000)
end

--- Autocompleter using filesystem
function lib.fileAutocomplete(s, sp)
	local path = os.getenv("PWD")
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

--- Compute the available autocomplete options from current input and autocompleter.
-- @string input
-- @func autocompleter
function lib.autocompleteFor(input, autocompleter)
	if input:len() == 0 then
		return {}
	end
	local sp = string.split(input, " ")
	local plus = autocompleter(input, sp)
	return plus
end

--- Read from standard input
-- @tab[opt] options options
-- @tab[opt=global history] options.history The shell history to use
-- @param[opt] options.ontype
-- @func[opt] options.autocomplete
-- @func[opt] options.autocompleteHandler
-- @param[opt] options.pwchar
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
					lib.setX(lib.getX() - unicode.len(inp))
					io.write((" "):rep(unicode.len(inp)))
					lib.setX(lib.getX() - unicode.len(inp))
					io.write(history[historyIndex])
					inp = history[historyIndex]
					displayCursor()
				end
			elseif code == 208 then -- down arrow
				if historyIndex < #history then
					historyIndex = historyIndex + 1
					hideCursor()
					lib.setX(lib.getX() - unicode.len(inp))
					io.write(history[historyIndex])
					inp = history[historyIndex]
					displayCursor()
				end
			elseif d ~= 0 then
				c = unicode.char(d)
				if c ~= '\r' then
					if d == 8 or d == 0x0E or d == 0xD3 then -- backspace
						if unicode.len(inp) > 0 then
							hideCursor()
							inp = unicode.sub(inp, 1, unicode.len(inp) - 1)
							lib.setX(lib.getX() - 1)
							io.write(" ")
							lib.setX(lib.getX() - 1)
							displayCursor()
							if options.onType then
								options.onType(inp, unicode.len(inp))
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
								local complete = true
								if options.autocompleteHandler then
									complete = options.autocompleteHandler(plus, inp:len(), inp)
								end

								if complete then
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
	hideCursor()
	table.insert(history, inp)
	return inp
end

return lib
