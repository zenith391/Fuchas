package.loaded["xml"] = nil
local xml = require("xml")
print("liblon test:")
package.loaded["liblon"] = nil
local lon = require("liblon")
local tab = {
	username = "Zen1th",
	protection = "sha256",
	pwhash = "yozenith",
	usernames = {
		"admin", "zen1th", "shared", "guest"
	}
}
print("table:")
print(tostring(lon.sertable(tab)))

local parsed = xml.parse([[
<ohml lang="fr" version=1.1>
	<text x=4 y=2>
		UPS History
	</text>
	<text x=8 y=3>
		Will come soon!
	</text>
</ohml>
]])

local function exploreTab(tab, level)
	for k, v in pairs(tab) do
		write(string.rep("\t", level))
		if type(v) == "table" then
			print(k .. ":")
			if k == "parent" then
				print(string.rep("\t", level) .. "upper-level")
			else
				exploreTab(v, level + 1)
			end
		else
			print(k .. " = " .. tostring(v))
		end
	end
end

--exploreTab(parsed, 0)