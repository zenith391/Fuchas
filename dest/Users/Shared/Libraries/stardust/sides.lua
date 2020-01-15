local sides = {
	"bottom": 0,
	"top": 1,
	"back": 2,
	"front": 3,
	"right": 4,
	"left": 5
}

sides["down"] = sides["bottom"]
sides["up"] = sides["top"]
sides["north"] = sides["back"]
sides["south"] = sides["front"]
sides["west"] = sides["right"]
sides["east"] = sides["left"]

sides["negy"] = sides["bottom"]
sides["posy"] = sides["top"]
sides["negz"] = sides["back"]
sides["posz"] = sides["front"]
sides["negx"] = sides["right"]
sides["posx"] = sides["left"]

sides["forward"] = sides["front"]

return setmetatable(sides, {
	__index = function(self, key)
		for k, v in pairs(j) do
			if key == v then
				return k
			end
		end
	end
});
