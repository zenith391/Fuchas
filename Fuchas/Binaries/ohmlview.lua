package.loaded["xml"] = nil
local xml = require("xml")
local shell = require("shell")
local gpu = component.gpu
local width, height = gpu.getResolution()
local args, options = shell.parse(...)

--local stream = io.open(shell.resolve(args[1]))
local text = [[
<ohml lang="fr" version=1.1>
	<text x=4 y=2>
		Please note that Fuchas
	</text>
	<text x=4 y=3>
		is made by zenith391.<br></br>
		With the help of AdorableCatgirl for some parts (uncpio)
	</text>
</ohml>
]]

if not text then
    text = stream:read("a")
end
                      
local parsed = xml.parse(text)

local cy = 1
local cx = 1
local objects = {}

local function resolve(tag)
    for _, v in pairs(tag.childrens) do
        if v.attr.x then
            cx = v.attr.x
        end
        if v.attr.y then
            cy = v.attr.y
        end
        if v.name == "#text" then
            if cx + v.content:len() > width then
                cx = 1
                cy = cy + 1
            end
            table.insert(objects, {
                type = "text",
                x = cx,
                y = cy,
                text = v.content
            })
            cx = cx + v.content:len()
        elseif v.name == "br" then
            cx = 1
            cy = cy + 1
        else
            resolve(v)
        end
    end
end

local function render()
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(1, 1, width, height, " ")
    for _, obj in pairs(objects) do
        if obj.type == "text" then
            gpu.set(obj.x, obj.y, obj.text)
        end
    end
end

resolve(parsed)
render()


