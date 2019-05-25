local lib = {}

lib.TIMEUNITS = {
	"MILLISECONDS" = {
		type = "ms",
		ms = 1, -- how much ms equals 1ms, used as arbitraty conversion point
	},
	"SECONDS" = {
		type = "s",
		ms = 1000
	},
	"MINUTES" = {
		type = "m",
		ms = 60000
	},
	"HOURS" = {
		type = "h",
		ms = 3600000
	},
	"DAYS" = {
		type = "h",
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
	if not unit.msmul then
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

function lib.currentTime()
	
end

return lib