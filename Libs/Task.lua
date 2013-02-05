local __ = requireUnderscore()


function requireTask()

	local Task = {}
	Task.__index = Task

	local function createNewTask()
		return
		{
			["Character"] = "",
			["Description"] = "",
			["Days"] =
			{
				[1] = true,
				[2] = true,
				[3] = true,
				[4] = true,
				[5] = true,
				[6] = true,
				[7] = true
			},
			["Hours"] = 12,
			["Minutes"] = 0,
			["AmPm"] = 1
		}
	end

	function Task:new(task)
		task = task or createNewTask()
		setmetatable(task, self)
		return task
	end

	function Task:Clone()
		local toReturn = Task:new({})
		Task.Copy(self, toReturn)
		return toReturn
	end

	function Task.Copy(src, dest)
		dest.Character = src.Character
		dest.Description = src.Description
		dest.Days =
		{
			[1] = src.Days[1],
			[2] = src.Days[2],
			[3] = src.Days[3],
			[4] = src.Days[4],
			[5] = src.Days[5],
			[6] = src.Days[6],
			[7] = src.Days[7]
		}
		dest.Hours = src.Hours
		dest.Minutes = src.Minutes
		dest.AmPm = src.AmPm
		dest.id = src.id
	end

	function Task:Validate()
		if self.Description == nil or self.Description == "" then
			return "Please enter a description."
		elseif self.Character == nil or self.Character == "" then
			return "Please enter a character to associate with this task."
		elseif self.AmPm ~= 1 and self.AmPm ~= 2 then
			return "Please choose AM or PM."
		elseif #__.select(self.Days, function (item) return item == true end) == 0 then
			return "Please select at least one day for the task."
		else
			local hours = tonumber(self.Hours)
			local minutes = tonumber(self.Minutes)
			if not hours or hours < 1 or hours > 12  or not minutes or minutes < 0 or minutes > 59 then
				return "Please select a valid time."
			end
			return nil
		end
	end

	return Task

end