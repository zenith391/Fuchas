-- WARNING! Fuchas/autorun.lua is different from OpenOS's autorun.lua and should be used for system variables
-- because it is executed when shin32 library is first loaded (when fuchas is loading).
local sys = require("shin32").getSystemVars()

sys["PATH"] = "A:/;A:/Fuchas/;A:/Users/Shared/;A:/Fuchas/Binaries/"
sys["PATHEXT"] = ".lua"
sys["LIB_PATH"] = "A:/Fuchas/Libraries/?.lua;A:/Users/Shared/Libraries/?.lua;./?.lua;A:/?.lua"
sys["DRV_PATH"] = "A:/Fuchas/Drivers/?.lua;A:/Users/Shared/Drivers/?.lua;./?.lua;A:/?.lua"