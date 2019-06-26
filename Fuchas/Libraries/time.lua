local lib = {}
local _time = os.time

lib.TIMEUNITS = {
	NANOSECONDS = {
		type = "ns",
		ms = 0.001
	},
	MILLISECONDS = {
		type = "ms",
		ms = 1, -- how much ms equals 1ms, used as arbitraty conversion point
	},
	SECONDS = {
		type = "s",
		ms = 1000
	},
	MINUTES = {
		type = "m",
		ms = 60000
	},
	HOURS = {
		type = "h",
		ms = 3600000
	},
	DAYS = {
		type = "d",
		ms = 86400000
	}
}

function lib.createTimeUnit(shortName, ms)
	return {
		type = shortName,
		ms = ms
	}
end

function lib.getShortName(unit)
	return unit.type
end

function lib.duration(unit, value)
	if not unit.ms then
		error("invalid time unit")
	end
	return {
		time = value * unit.ms,
		unit = unit
	}
end

function lib.convert(src, srcUnit, dstUnit)
	return src * srcUnit.ms / dstUnit.ms
end

function lib.convertDuration(src, dstUnit)
	return src.time / dstUnit.ms
end

function lib.currentTime(unit)
	if unit == nil then
		unit = lib.TIMEUNITS.SECONDS
	end
	local sec = _time()
	return sec / 1000 * unit.ms
end

return lib