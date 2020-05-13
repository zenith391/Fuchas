local term = {}
local event = require("event")
local shell = require("shell")

function term.isAvailable()
	return true
end

function term.getViewport()
	return 160, 50, 1, 1, 1, 1
end

function term.getGlobalArea()
	return 1, 1, 160, 50
end

function term.pull(...)
	-- TODO: blink cursor
	return event.pull(...)
end

function term.setCursorBlink(blink)
	-- TODO!!
end

function term.getCursor()
	return shell.getCursor()
end

function term.setCursor(col, row)
	shell.setCursor(col, row)
end

function term.clear()
	return shell.clear()
end

function term.clearLine()
	shell.setCursor(1, shell.getY())
	-- TODO
end

-- TODO: provide the backward compatibility OpenOS provides
-- TODO: port the rest of options
function term.read(options)
	local dobreak = options.dobreak
	local str = shell.read()
	if dobreak == nil then
		str = str .. "\n"
	end
	return str
end

function term.write(value, wrap)
	-- TODO support false wrap value
	io.stdout:write(require("stardust/text").detab(value, 8))
end

function term.bind(gpu)
	error("cannot re-bind the terminal")
end

function term.screen()
	return require("component").list("screen")()
end

function term.keyboard()
	return require("component").screen.getKeyboards()[0]
end

function term.gpu()
	return require("component").proxy(require("component").list("gpu")())
end

return term
