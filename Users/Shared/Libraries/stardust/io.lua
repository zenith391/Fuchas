local fs = require("stardust/filesystem")
local io = {}

function io.open(filename, mode)
	if not fs.isDirectory(filename) then
		local h, err = fs.open(filename, mode)
		if not h then
			return nil, err
		end
		return require("buffer").from(h)
	end
	return nil, "is directory"
end

function io.input(file)
	if not file then
		return io.stdin
	else
		if type(file) == "string" then -- file name
			io.input(io.open(file, "r"))
		else
			local proc = require("tasks").getCurrentProcess()
			proc.io.stdin = file
		end
	end
end

function io.output(file)
	if not file then
		return io.stdout
	else
		if type(file) == "string" then -- file name
			io.input(io.open(file, "w"))
		else
			local proc = require("tasks").getCurrentProcess()
			proc.io.stdout = file
			proc.io.stderr = io.createStdErr() -- recreate stderr to be matching stdout
		end
	end
end

function io.flush()
	if io.stdout.flush then -- if the stream is buffered
		io.stdout:flush()
	end
end

function io.read()
	return io.stdin:read()
end

function io.close(file)
	if file then
		file:close()
	else
		io.stdout:close()
	end
end

function io.type(obj)
	if type(obj) == "table" then
		if obj.closed then
			return "closed file"
		elseif (obj.read or obj.write) and obj.close then
			return "file"
		end
	end
	return nil
end

function io.write(msg)
	io.stdout:write(tostring(msg))
end

io.stdin = _G.io.stdin
io.stdout = _G.io.stdout
io.stderr = _G.io.stderr

return io