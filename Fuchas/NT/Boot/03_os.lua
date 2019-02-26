-- Compatibility shortcuts (it is prefered to use shin32 library)
function os.getenv(name)
	return shin32.getSystemVar(name)
end

function os.setenv(name, value)
	checkArg(1, "string", name)
	if not value then value = nil end
	shin32.getSystemVars[name] = value
end