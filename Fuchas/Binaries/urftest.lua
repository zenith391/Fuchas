package.loaded["liburf"] = nil
print("Launching..")
print("Importing liburf..")
local liburf = require("liburf")
print("Opening A:/Temporary/test.urf as write")
if not require("filesystem").exists("A:/Temporary") then
	require("filesystem").makeDirectory("A:/Temporary")
end
local s = io.open("A:/Temporary/test.urf", "w")
print("Creating new archive..")
local arc = liburf.newArchive()

print("Creating child entry \"main.lua\"")
local f = arc.root.childEntry("main.lua", false)
f.content = [[
local args = ...
print("An Example (Fuchas Portable Executable)")
if args[1] == nil then
	args[1] = "Fuchas"
end
print("Hello " ... args[1])
]]
print("Creating child entry \".manifest\"")
local m = arc.root.childEntry(".manifest", false)
m.content = [[
{
	"main-file" = "main.lua",
	"name" = "Hello FPE",
	"description" = "This is an example FPE file! Uncompressed of course",
	-- Yo reading this? Anyways it will be parsed internally by liblon when FPE is released,
	-- can't wait for it!
}
]]

print("Writing archive..")
liburf.writeArchive(arc, s)
print("Closing stream..")
s:close()

print("Opening read-only")
s = require("filesystem").open("A:/Temporary/test.urf", "r")
print("Reading archive..")
arc = liburf.readArchive(s)
s:close()