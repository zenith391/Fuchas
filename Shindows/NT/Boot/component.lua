function component.isAvailable(type)
	return table.maxn(component.list(type)) ~= 0
end

function component.getPrimary(type)
	return component.proxy(component.list(type)())
end