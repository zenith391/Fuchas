local imaging = require("OCX/OCImage")
local gpu = component.proxy(component.list("gpu", true)())
local rw, rh = gpu.getResolution()

local image

local _, err = pcall(function()
	local rasterImage = imaging.loadRaster("A:/Fuchas/Interfaces/Concert/logo.bmp")
	if rw > 90 then
		local factor = 2
		rasterImage = imaging.scale(rasterImage, rasterImage.width * factor, rasterImage.height * factor)
	end
	image = imaging.convertFromRaster(rasterImage, {})
end)

gpu.setBackground(0x000000)
gpu.fill(1, 1, rw, rh, " ")

local ty = math.floor(rh / 2)
if image then
	local ix, iy = math.floor(rw / 2 - image.width / 2), math.floor(rh / 2 - image.height)
	ty = iy + math.ceil(image.height)
	imaging.drawGPU(image, gpu, ix, iy)
else
	local text = "[Could not load image: " .. tostring(err) .. "]"
	local tx = math.floor(rw / 2 - unicode.wlen(text) / 2)
	gpu.set(tx, ty-2, text)
end

return function(step, maxStep, text)
	local tx = math.floor(rw / 2 - unicode.wlen(text) / 2)
	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
	gpu.fill(1, ty, 160, 1, " ")
	gpu.set(tx, ty, text)
end
