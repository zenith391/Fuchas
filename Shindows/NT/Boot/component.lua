function component.isAvailable(type)
	return table.getn(component.list(type)) ~= 0
end

function component.getPrimary(type)
	return component.proxy(component.list(type)())
end