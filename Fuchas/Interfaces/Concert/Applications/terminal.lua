-- Terminal
local draw = require("OCX/OCDraw")
local ui = require("OCX/OCUI")
local window = require("window").newWindow(70, 25, "Terminal")
local gpu = require("driver").gpu
local shell = require("shell")

local fileName = ...
fileName = fileName or "A:/Fuchas/Interfaces/Concert/editor.lua"

local tabBar = ui.tabBar()
local config = {
	tabWidth = 4
}

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


local ESC = string.char(0x1B)
local CSI = ESC .. "%["

local function createTerminal()
	local terminal = ui.component()
	terminal.background = 0x000000
	terminal.foreground = 0xFFFFFF
	terminal.unbuffered = true
	terminal.text = ""

	local function drawLine(canvas, x, y, line, fg, bg)
		local ptr, ptrE, ptrC = line:find(CSI .. "([%d;]+)m")
		if ptr then
			canvas.drawText(x, y, unicode.sub(line, 1, ptr-1), fg, bg)
			local sgrs = string.split(ptrC, ";")
			for i=1, #sgrs do
				local sgr = tonumber(sgrs[i])
				if sgr and sgr >= 30 and sgr <= 37 then -- foreground
					fg = colorTable[sgr-29]
				elseif sgr == 38 then -- extended foreground color
					if sgrs[i+1] == "2" then -- only supporting RGB extended color
						local r = sgrs[i+2]
						local g = sgrs[i+3]
						local b = sgrs[i+4]
						local hex = bit32.bor(bit32.lshift(r, 16), bit32.lshift(g, 8), b)
						fg = hex
						i = i + 4
					end
				elseif sgr == 39 then -- default foreground color
					fg = 0xFFFFFF
				elseif sgr and sgr >= 40 and sgr <= 47 then -- background
					bg = colorTable[sgr-39]
				elseif sgr == 48 then -- extended background color
					if sgrs[i+1] == "2" then -- only supporting RGB extended color
						local r = sgrs[i+2]
						local g = sgrs[i+3]
						local b = sgrs[i+4]
						local hex = bit32.bor(bit32.lshift(r, 16), bit32.lshift(g, 8), b)
						bg = hex
						i = i + 4
					end
				elseif sgr == 49 then -- default background color
					bg = 0x000000
				elseif sgr and sgr >= 90 and sgr <= 97 then -- bright foreground
					fg = brightColorTable[sgr-89]
				elseif sgr and sgr >= 100 and sgr <= 107 then -- bright background
					bg = brightColorTable[sgr-99]
				end
			end
			return drawLine(canvas, x+ptr-1, y, unicode.sub(line, ptrE+1), fg, bg)
		end

		canvas.drawText(x, y, line, fg, bg)
		return fg, bg
	end

	function terminal:_render()
		self.canvas.fillRect(1, 1, self.width, self.height, self.background)
		local y = 1
		local text = self.text

		local fg, bg = self.foreground, self.background
		for line in text:gmatch("([^\n]*)\n?") do
			line = line:gsub("\t", (" "):rep(config.tabWidth))
			--self.canvas.drawText(1, y, line, self.foreground, self.background)
			fg, bg = drawLine(self.canvas, 1, y, line, fg, bg)
			y = y + 1
		end
	end

	local function count(str, pattern)
		local num = 0
		for line in str:gmatch(pattern) do
			num = num + 1
		end
		return num
	end

	function terminal:getStdOut()
		local stream = {}

		stream.x = 1
		stream.y = 1
		stream.tty = true
		stream.term = self
		stream.close = function(self)
			return false -- unclosable stream
		end

		stream.write = function(self, val)
			local h = self.term.height-1

			--[[local newText = ""
			local lastLine = ""
			local k = 1
			for line in self.term.text:gmatch("([^\n]*)\n?") do
				if k ~= count(self.term.text, "([^\n]*)\n?") then
					newText = newText .. line .. "\n"
				else
					lastLine = line or ""
				end
				k = k + 1
			end--]]

			local ptr, ptrE = val:find(ESC .. "c") -- clear
			if ptr then
				self.term.text = ""
				self.x = 1
				self.y = 1
				self.term.dirty = true
				return self:write(unicode.sub(val, ptrE+1))
			end

			if val:find("\n") then
				local ptr, ptrE = val:find("\n")
				self:write(val:sub(1, ptr-1))
				self.term.text = self.term.text .. "\n"
				self.y = self.y + 1
				self.x = 1
				if self.y >= h then
					local newText = ""
					local numLines = count(self.term.text, "([^\n]*)\n?")

					local k = 1
					for line in self.term.text:gmatch("([^\n]*)\n?") do
						if k > numLines - h + 2 then
							newText = newText .. line .. "\n"
						end
						k = k + 1
					end
					self.term.text = newText
					self.y = h-1
				end
				return self:write(val:sub(ptrE+1))
			else
				self.term.text = self.term.text .. val
				self.x = self.x + #val
			end
			self.term.dirty = true
		end

		stream.read = function(self, len)
			return nil -- cannot read stdout
		end

		return setmetatable(stream, {
			__index = function(t, key)
				if key == "w" then
					return self.width
				elseif key == "h" then
					return self.height
				end
			end
		})
	end

	return terminal
end

local terms = {}
local function openTerminal(name, path)
	checkArg(1, name, "string")
	checkArg(2, path, "string")

	local term = createTerminal()
	local sh = require("tasks").newProcess(name, loadfile(path))
	sh.io.stdout = term:getStdOut()
	table.insert(terms, term)

	tabBar:addTab(term, name)
end

openTerminal("fsh", "A:/Fuchas/Interfaces/Fushell/main.lua")
--openTerminal("kabam", "A:/Fuchas/Interfaces/Kabam/main.lua")
window.container = tabBar
window:show()

while window.visible do
	for _, term in pairs(terms) do
		if term.dirty == true then
			window:update()
			term.dirty = false
		end
	end
	os.sleep(0.05)
end
