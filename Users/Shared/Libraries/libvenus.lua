-- Libvenus is a simple version manager for projects
local lib = {}
local filesystem = require("filesystem")

function lib.newKey()
	local key = string.format("%x", math.floor(math.random() * 999999999999)) -- max 12 len
	if key:len() < 12 then
		key = key .. string.rep("0", 12-key:len())
	end
	return key
end

function lib.readObject(dir, key)

end

function lib.writeObjects(dir, objs)
	for _, v in pairs(objs) do
		lib.writeObject(dir, v)
	end
end

function lib.writeObject(dir, obj)
	if obj.type == "branch" then
		if not filesystem.exists(dir .. "/branches") then
			filesystem.makeDirectory(dir .. "/branches")
		end
		local stream, err = io.open(dir .. "/branches/" .. obj.name, "w")
		if not stream then
			error(err)
		end
		stream:write(obj.key)
		stream:write(string.char(obj.type:len()))
		stream:write(obj.type)
		stream:write(obj.content)
		stream:write(string.char(#obj.childrens))
		for _, v in pairs(obj.childrens) do
			stream:write(v)
		end
		stream:close()
	else
		local subdir = "/objects/"
		if obj.type == "commit" then
			subdir = "/commits/"
		end
		if not filesystem.exists(dir .. subdir .. obj.key:sub(1, 2)) then
			filesystem.makeDirectory(dir .. subdir .. obj.key:sub(1, 2))
		end
		print(dir .. subdir .. obj.key:sub(1, 2) .. "/" .. obj.key)
		local stream, err = io.open(dir .. subdir .. obj.key:sub(1, 2) .. "/" .. obj.key, "w")
		if not stream then
			error(err)
		end
		stream:write(string.char(obj.type:len()))
		stream:write(obj.type)
		stream:write(obj.content)
		if obj.type == "tree" then
			stream:write(string.char(#obj.childrens))
			for _, v in pairs(obj.childrens) do
				stream:write(v)
			end
		end
		stream:close()
	end
end

function lib.object(key, text)
	local obj = {
		key = key,
		content = text,
		type = "blob"
	}
	return obj
end

-- Files are objects capable of having a parent
function lib.file(key, name, parent, text)
	local str = parent.key .. string.char(name:len()) .. name .. text
	local obj = lib.object(key, str)
	obj.type = "file"
	return obj
end

-- Trees are objects capable of containing childrens and having a parent
-- Althought it can have a parent this isn't a file
function lib.tree(key, name, parent)
	local str = ""
	if parent then
		str = parent.key
	end
	str = str .. name
	local obj = lib.object(key, str)
	obj.type = "tree"
	obj.childrens = {}
	obj.name = name
	if parent then
		table.insert(parent.childrens, obj.key)
	end
	return obj
end

-- Branches are trees stored as their name in the branches/ folder instdead of objects/
function lib.branch(key, name)
	local obj = lib.tree(key, name)
	obj.type = "branch"
	return obj
end

-- Commits are objects containing their name and what objects they pushed
function lib.commit(key, name, objects)
	local str = string.char(name:len()) .. name
	str = str .. string.char(#objects)
	for _, o in pairs(objects) do
		str = str .. o.key
	end
	local obj = lib.object(key, str)
	obj.type = "commit"
	return obj
end

return lib