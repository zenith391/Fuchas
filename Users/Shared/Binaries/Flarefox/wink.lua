-- Wink HTML layout engine
local wink = {}

for k, v in pairs(dofile("A:/Users/Shared/Binaries/Flarefox/wink/dom.lua")) do
	wink[k] = v
end

wink.html = loadfile("A:/Users/Shared/Binaries/Flarefox/wink/html.lua")(wink)

return wink
