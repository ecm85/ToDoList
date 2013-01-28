
function requireDateTimeUtil ()

	local dateTimeUtil = {}

	-- Compute the difference in seconds between local time and UTC.
	function dateTimeUtil.get_timezone()
		local now = time()
		return difftime(now, time(date("!*t", now)))
	end

	-- Return a timezone string in ISO 8601:2000 standard form (+hhmm or -hhmm)
	function dateTimeUtil.SecondsToHoursMinutes (timezone)
		local h, m = math.modf(timezone / 3600)
		return h, 60 * m
	end

	function dateTimeUtil.CurrentTimeZoneString()
		local timezoneDiff = dateTimeUtil.get_timezone(time())
		local hourDiff, minuteDiff = dateTimeUtil.SecondsToHoursMinutes(timezoneDiff)
		minuteDiff = math.abs(minuteDiff)
		timeZoneStrings =
		{
			[-8] = "Pacific",
			[-7] = "Mountain",
			[-6] = "Central",
			[-5] = "Eastern"
		}
		local returnString = ""
		if minuteDiff == 0 and timeZoneStrings[hourDiff] then
			returnString = returnString..timeZoneStrings[hourDiff]
		end
		returnString = returnString.." "..string.format("%+.2d", hourDiff)..":"..string.format("%.2d", minuteDiff).." UTC"
		return returnString
	end

	local monthLengths =
	{
		[1] = 31,
		[2] = 28,
		[3] = 31,
		[4] = 30,
		[5] = 31,
		[6] = 30,
		[7] = 31,
		[8] = 31,
		[9] = 30,
		[10] = 31,
		[11] = 30,
		[12] = 31
	}
	local maxMonthLength = 31

	function dateTimeUtil.AddDays(currentDay, currentMonth, currentYear, daysToAdd)
		if (currentDay > maxMonthLength or currentMonth > #monthLengths or currentYear < 1) then
			return -1, -1, -1
		end
		newDay = currentDay + daysToAdd
		newMonth = currentMonth
		newYear = currentYear
		if daysToAdd > 0 then
			while (newDay > monthLengths[newMonth]) do
				newDay = newDay - monthLengths[newMonth]
				newMonth = newMonth + 1
				if (newMonth > #monthLengths) then
					newMonth = 1
					newYear = newYear + 1
				end
			end
		else
			while newDay < 1 do
				newMonth = newMonth - 1
				newDay = newDay + monthLengths[newMonth]
				if newMonth < 0 then
					newMonth = #monthLengths
					newYear = newYear - 1
				end
			end
		end
		return newDay, newMonth, newYear
	end

	return dateTimeUtil
end
