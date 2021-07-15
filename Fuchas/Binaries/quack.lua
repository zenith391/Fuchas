local shell = require("shell")
local filesystem = require("filesystem")
local event = require("event")
local keyboard = require("keyboard")
local gpu = require("driver").gpu

local defaultForeground = 0xF8F8F2
local defaultBackground = 0x272822

local colorScheme = {
	foreground = { fg = defaultForeground },
	background = { bg = defaultBackground },
	comment = { fg = 0x75715E },
	number = { fg = 0xAE81FF },
	string = { fg = 0xE6DB74 },
	keyword = { fg = 0xF92672 },
	code = { bg = 0x3B3C36 }
}

local keywords = {
	"local ", "for ", "do ", "elseif ", "if ", "else ", "then ", "while ", "in ", "end ", "return ", "break ",
	" and ", " or ", " not ", "~", "&", "|", "^", "+", "-", "*", "//", "/",
	">", "<", "<=", ">=", "==", "~=", "=",
	"nil ", "true ", "false "
}

local syntax = {}

local colorSchemeArray = {}

for _, v in pairs(colorScheme) do
	if v.fg then table.insert(colorSchemeArray, v.fg) end
	if v.bg then table.insert(colorSchemeArray, v.bg) end
end

local oldPalette
if gpu.getColors() == 2 then -- monochrome
	colorScheme.background.bg = 0x000000
	colorScheme.code.bg       = 0x000000
else
	oldPalette = {}
	for i=1, #colorSchemeArray do
		oldPalette[i] = gpu.palette[i]
		gpu.palette[i] = colorSchemeArray[i]
	end
end

local rw, rh = gpu.getResolution()
local cx, cy = 1, 1
local sx, sy = 1, 1
local cur = true
local curC = ""
local curFG, curBG = 0, 0

local args, options = shell.parse(...)
local file = args[1]

if file == nil then
	local doc = io.open("A:/Fuchas/Documentation/commands/quack.od", "r")
	if doc then
		print(doc:read("*a"))
		doc:close()
	else
		print("Usage: quack <filename>")
	end
	return
end

file = shell.resolveToPwd(file)

if filesystem.isDirectory(file) then
	io.stderr:write("path is directory\n")
	return
end

local fileLanguage = options["file-language"]

if not fileLanguage then
	if string.endsWith(file, ".lua") or string.endsWith(file, ".lon") then
		fileLanguage = "lua"
	elseif string.endsWith(file, ".md") then
		fileLanguage = "markdown"
	else
		fileLanguage = "text"
	end
end

if options.n or options["no-syntax-highlighting"] then
	fileLanguage = "text"
end
local lines = nil

local function drawBottomBar(state)
	gpu.fill(1, rh, rw, 1, 0xFFFFFF)
	local text = file .. " - Line " .. cy .. ", Column " .. cx
	if state == "save" then
		text = text .. " - Saved"
	end
	gpu.drawText(1, rh, text, 0)
	gpu.setColor(0x000000)
	gpu.setForeground(0xFFFFFF)
end

local function save()
	local stream = io.open(file, "w")
	for _, line in pairs(lines) do
		stream:write(line .. "\n")
	end
	stream:close()
end

local function syntaxParse(language, lines, lineNo)
	local syntax = {}
	local highlight = "foreground"
	local highlightStart = 1

	local function pushHighlight(k, pos)
		if not syntax[k] then
			syntax[k] = {}
		end
		table.insert(syntax[k], {
			line = k,
			highlight = highlight,
			highlightStart = highlightStart,
			highlightEnd = pos-1
		})
		highlightStart = pos
	end

	if language == "lua" then
		for k, line in pairs(lines) do
			if not lineNo or (k == lineNo) then
				local word = ""
				local pc = nil -- previous char
				local isEscaping = 0
				for pos, c in pairs(string.toCharArray(line)) do
					if isEscaping > 0 then
						isEscaping = isEscaping - 1
					end
					if c == "\"" and isEscaping==0 then
						if highlight == "string" then
							pushHighlight(k, pos+1)
							highlight = "foreground"
						elseif highlight == "foreground" then
							pushHighlight(k, pos)
							highlight = "string"
						end
						word = ""
					elseif c == "\\" then
						if isEscaping==1 then
							isEscaping = 0
						else
							isEscaping = 2
						end
					else
						word = word .. c
						if highlight == "foreground" then
							for _, keyword in pairs(keywords) do
								if keyword:sub(#keyword, #keyword) == " " then
									if pos == #line then
										keyword = keyword:sub(1, #keyword-1)
									end
								end
								if string.endsWith(word, keyword) then
									word = ""
									pushHighlight(k, pos-#keyword+1)
									highlight = "keyword"
									pushHighlight(k, pos+1)
									highlight = "foreground"
								end
							end
							if string.startsWith(word, "--") then
								word = ""
								pushHighlight(k, pos-1)
								highlight = "comment"
								pushHighlight(k, #line+1)
								highlight = "foreground"
								break
							end
						end
					end
					pc = c
				end
				pushHighlight(k, #line+1)
				highlightStart = 1
			end
		end
	elseif language == "markdown" then
		for k, line in pairs(lines) do
			if string.startsWith(line, "#") then
				local len = 1
				while line:sub(len, len) == "#" do
					len = len + 1
				end
				highlight = "keyword"
				pushHighlight(k, len)
				highlight = "foreground"
			end
			for pos, c in pairs(string.toCharArray(line)) do
				if c == "`" then
					if highlight == "code" then
						pushHighlight(k, pos+1)
						highlight = "foreground"
					elseif highlight == "foreground" then
						pushHighlight(k, pos)
						highlight = "code"
					end
				end
			end
			pushHighlight(k, #line+1)
			highlightStart = 1
		end
	else
		for k, line in pairs(lines) do
			pushHighlight(k, #line+1)
			highlightStart = 1
		end
	end

	return syntax
end

local function drawLine(y, line, ly)
	local lineSyntax = syntax[cy]
	if not lineSyntax then
		syntax = syntaxParse(fileLanguage, lines, cy)
		lineSyntax = syntax[cy]
	end

	local x = 1
	for k, hl in pairs(lineSyntax) do
		local part = unicode.sub(line, hl.highlightStart, hl.highlightEnd)
		local formatted = part:gsub("\t", "    ")
		gpu.setColor(colorScheme[hl.highlight].bg or defaultBackground)
		gpu.drawText(x, y, formatted, colorScheme[hl.highlight].fg or defaultForeground)
		x = x + unicode.wlen(formatted)
	end
end

local function drawText()
	local y = sy
	for _, line in pairs(lines) do
		cy = y
		drawLine(y, line)
		y = y + 1
		if y > rh - sy then
			break
		end
	end
	cy = 1
end

local function width(line)
	return unicode.wlen(line:gsub("\t", "    "))
end

local function charPosition(line, cx)
	local pos = 0
	local i = 1
	while i <= cx do
		pos = pos + 1
		if unicode.sub(line, pos, pos) == "\t" then
			i = i + 4
		else
			i = i + 1
		end
	end
	return pos
end

---------------------------------------------

do
	if filesystem.exists(file) then
		local b = io.open(file)
		lines = b:lines()
		b:close()
	else
		lines = { "" }
	end
end

gpu.fill(1, 1, 160, 50, colorScheme.background.bg)
shell.setCursor(1, 1)
syntax = syntaxParse(fileLanguage, lines)
drawText()
drawBottomBar()

local function eraseCursor()
	gpu.setColor(curBG)
	gpu.setForeground(curFG)
	gpu.drawText(cx, cy-sy+1, curC)
end

while true do
	local evt = table.pack(event.pull(0.5))
	local name = evt[1]
	if name == "interrupt" then
		break
	end
	if name == "key_down" then
		eraseCursor()
		local keyChar = evt[3]
		local keyCode = evt[4]
		if keyCode == 200 then -- up
			if cy > 1 then
				cy = cy - 1
				cx = math.min(width(lines[cy])+1, cx)
				if cy < sy then
					gpu.copy(1, 1, rw, rh-1, 0, 1)
					gpu.setColor(colorScheme.background.bg)
					gpu.drawText(1, 1, (" "):rep(rw))
					drawLine(1, lines[cy])
					sy = sy - 1
				end
				drawBottomBar()
			end
		elseif keyCode == 203 then -- left
			if cx > 1 then
				local line = lines[cy]
				local idx = charPosition(lines[cy], cx-1)
				if unicode.sub(line, idx, idx) == "\t" then
					cx = math.max(1, cx - 4)
				else
					cx = cx - 1
				end
				drawBottomBar()
			end
		elseif keyCode == 205 then -- right
			if cx <= width(lines[cy]) then
				local line = lines[cy]
				local idx = charPosition(lines[cy], cx)
				if unicode.sub(line, idx, idx) == "\t" then
					cx = cx + 4
				else
					cx = cx + 1
				end
				drawBottomBar()
			end
		elseif keyCode == 208 then -- down
			if cy < #lines then
				cy = cy + 1
				cx = math.min(width(lines[cy])+1, cx)
				if cy-sy+1 > rh-1 then
					gpu.copy(1, 1, rw, rh-1, 0, -1)
					gpu.setColor(colorScheme.background.bg)
					gpu.drawText(1, rh-1, (" "):rep(rw))
					drawLine(rh-1, lines[cy])
					sy = sy + 1
				end
				drawBottomBar()
			end
		elseif keyCode == 201 then -- PgUp

		elseif keyCode == 209 then -- PgDown

		elseif keyCode == 199 then -- Start
			cx = 1
			drawBottomBar()
		elseif keyCode == 207 then -- End
			cx = math.floor(width(lines[cy])+1)
			drawBottomBar()
		else
			if keyChar == 8 then
				if cx > 1 then
					local pos = charPosition(lines[cy], cx)
					lines[cy] = unicode.sub(lines[cy], 1, pos-2) .. unicode.sub(lines[cy], pos)
					syntax = syntaxParse(fileLanguage, lines, cy)
					gpu.setColor(colorScheme.background.bg)
					gpu.drawText(1, cy-sy+1, (" "):rep(rw))
					drawLine(cy-sy+1, lines[cy])
					cx = cx - 1
				elseif cx == 1 then
					gpu.copy(1, cy-sy+1, rw, rh-(cy-sy+1), 0, -1)
					local line = lines[cy]
					table.remove(lines, cy)
					cy = cy - 1
					cx = width(lines[cy])+1
					lines[cy] = lines[cy] .. line
					syntax = syntaxParse(fileLanguage, lines, cy)
					drawLine(cy-sy+1, lines[cy])
				end
			elseif keyChar == 127 then
				lines[cy] = unicode.sub(lines[cy], 1, cx-1) .. unicode.sub(lines[cy], cx+1)
				syntax = syntaxParse(fileLanguage, lines, cy)
				gpu.setColor(colorScheme.background.bg)
				gpu.drawText(1, cy-sy+1, (" "):rep(rw-#lines[cy]))
				drawLine(1, cy-sy+1, lines[cy])
			elseif keyChar == 13 then 
				local p1 = unicode.sub(lines[cy], 1, cx-1)
				local p2 = unicode.sub(lines[cy], cx)
				lines[cy] = p1
				syntax = syntaxParse(fileLanguage, lines, cy)
				gpu.setColor(colorScheme.background.bg)
				gpu.drawText(1, cy-sy+1, (" "):rep(rw))
				drawLine(cy-sy+1, lines[cy])
				cy = cy + 1
				table.insert(lines, cy, p2)
				gpu.copy(1, cy-sy+1, rw, rh-(cy-sy+1), 0, 1)
				gpu.drawText(1, cy-sy+1, (" "):rep(rw))
				syntax = syntaxParse(fileLanguage, lines, cy)
				drawLine(cy-sy+1, lines[cy])
				drawBottomBar()
				cx = 1
				if cy-sy+1 > rh-1 then
					sy = sy + 1
				end
			elseif keyboard.isCtrlPressed() and keyboard.isPressed(31) then
				save()
				drawBottomBar("save")
			elseif keyChar >= 0x20 then
				local pos = charPosition(lines[cy], cx)
				lines[cy] = unicode.sub(lines[cy], 1, pos-1) .. unicode.char(evt[3]) .. unicode.sub(lines[cy], pos)
				gpu.setColor(colorScheme.background.bg)
				syntax = syntaxParse(fileLanguage, lines, cy)
				drawLine(cy-sy+1, lines[cy])
				cx = cx + 1
			end
		end
		cur = true
	end
	if name == "key_down" or not name then
		if cur then
			gpu.setColor(0xFFFFFF)
			gpu.setForeground(0)
			curC, curFG, curBG = gpu.get(cx, cy-sy+1)
			gpu.drawText(cx, cy-sy+1, " ")
			gpu.setColor(0)
		else
			eraseCursor()
		end
		cur = not cur
	end
end

shell.clear()
if gpu.getColors() > 2 then
	for i=1, #colorSchemeArray do
		gpu.palette[i] = oldPalette[i]
	end
end
