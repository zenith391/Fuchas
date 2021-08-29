local imaging = require("OCX/OCImage")
local rasterImage = imaging.loadRaster("A:/Fuchas/Interfaces/Concert/logo.bmp")
local gpu = component.proxy(component.list("gpu", true)())
local rw, rh = gpu.getResolution()
if rw > 90 then
	local factor = 2
	rasterImage = imaging.scale(rasterImage, rasterImage.width * factor, rasterImage.height * factor)
end
local image = imaging.convertFromRaster(rasterImage, {})

gpu.setBackground(0x000000)
gpu.fill(1, 1, 160, 50, " ")

local ix, iy = math.floor(rw / 2 - image.width / 2), math.floor(rh / 2 - image.height)
local ty = iy + math.ceil(image.height)
imaging.drawGPU(image, gpu, ix, iy)

return function(step, maxStep, text)
	local tx = math.floor(rw / 2 - unicode.wlen(text) / 2)
	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
	gpu.fill(1, ty, 160, 1, " ")
	gpu.set(tx, ty, text)
end
