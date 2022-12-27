-- Program that converts BMP images to OGF images
local shell = require("shell")
local imaging = require("OCX/OCImage")
local args, opts = shell.parse(...)

if #args < 2 then
	print("Usage: convert <src> <dest>")
	return
end

local src = shell.resolve(args[1]) or args[1]
local dst = shell.resolveToPwd(args[2]) or args[2]

local rasterImage = imaging.loadRaster(src)
local displayableImage = imaging.convertFromRaster(rasterImage, { dithering = "floyd-steinberg", advancedDithering = true })

local file = io.open(dst, "w")
imaging.findFormat("ogf"):encode(file, displayableImage)
file:close()
