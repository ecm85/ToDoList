function requireTaskDataBridge()

	local __ = requireUnderscore()
	local Task = requireTask()

	local function SetUpDefaultCharValues(TDL_Database)
		print("Setting up defaults")
		TDL_Database.char.hasDefaults = true
		TDL_Database.char.showTrackingFrame = false
		TDL_Database.char.minimapIcon =
		{
			["minimapPos"] = 220,
			["radius"] = 80
		}
		TDL_Database.char.TrackingFramePos =
		{
			[1] = 0,
			[2] = 0,
			[3] = "CENTER"
		}
		TDL_Database.char.lockTrackingFrame = false
	end

	local taskDataBridge = {}
	local TDL_Database = {}

	function taskDataBridge.Initialize()
		TDL_Database = LibStub("AceDB-3.0"):New("ToDoListDB",defaults)
		if (not TDL_Database.char.hasDefaults) then
			SetUpDefaultCharValues(TDL_Database)
		end
		if (not TDL_Database.global.Tasks) then
			TDL_Database.global.Tasks = {}
			TDL_Database.global.nextId = 0
		end
	end

	function taskDataBridge.DeleteTask(id)
		TDL_Database.global.Tasks = __.reject(TDL_Database.global.Tasks, function (task) return task["id"] == id end)
	end

	function taskDataBridge.AddTask(task)
		local errorMsg = task:Validate()
		if (errorMsg) then
			return errorMsg
		end
		local newTask = task:Clone()
		task.Hours = tonumber(task.Hours)
		task.Minutes = tonumber(task.Minutes)
		task.id = TDL_Database.global.nextId
		table.insert(TDL_Database.global.Tasks, task:Clone())
		TDL_Database.global.nextId = TDL_Database.global.nextId + 1
		return nil
	end

	function taskDataBridge.SaveChangesToTask(task, statusTextLabel)
		local result = task:Validate()
		if (result) then
			return result
		end
		local taskToUpdate = __.first(__.select(TDL_Database.global.Tasks, function (item) return item.id == task.id end))
		Task.Copy(task, taskToUpdate)
		taskToUpdate.Hours = tonumber(task.Hours)
		taskToUpdate.Minutes = tonumber(task.Minutes)
		return nil
	end

	function taskDataBridge.GetRemainingTasks()
		return __.each(__.select(TDL_Database.global.Tasks, function(task) return not task["LastCompleted"] end), function (task) return Task:new(task) end)
	end

	function taskDataBridge.GetCompletedTasks()
		return __.each(__.select(TDL_Database.global.Tasks, function(task) return task["LastCompleted"] end), function (task) return Task:new(task) end)
	end

	function taskDataBridge.GetAllTasks()
		return __.each(TDL_Database.global.Tasks, function (task) return Task:new(task) end)
	end

	function taskDataBridge.ResetDB()
		TDL_Database:ResetDB()
	end

	function taskDataBridge.GetCharInfo()
		return TDL_Database.char
	end

	function taskDataBridge.GetDataConnection()
		return TDL_Database
	end

	return taskDataBridge

end
