function component.isAvailable(type)
	return component.list(type)() ~= nil
end

function component.getPrimary(type)
	return component.proxy(component.list(type)())
end