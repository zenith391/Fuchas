-- Compatibility shortcuts (it is prefered to use shin32 library)
function os.getenv(name)
	return shin32.getenv(name)
end

function os.setenv(name, value)
	shin32.setenv(name, value)
end