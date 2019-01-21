-- WARNING! Fuchas/autorun.lua is different from autorun.lua and should only be used for system variables
-- because it is executed when shin32 library is first loaded (when fuchas is loading).
local sys = require("shin32").getSystemVars()

sys["PATH"] = "C:/;C:/Fuchas;C:/Users/Shared"
sys["PATHEXT"] = ".lua"
sys["LIB_PATH"] = "/Fuchas/Libraries/?.lua;/Users/Shared/Libraries/?.lua;./?.lua;/?.lua"
sys["DRV_PATH"] = "/Fuchas/Drivers/?.lua;/Users/Shared/Drivers/?.lua;./?.lua;/?.lua"