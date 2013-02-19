function requireTaskDataBridge()

	local __ = requireUnderscore()
	local Task = requireTask()

	local function SetUpDefaultCharValues(TDL_Database)
		local char = TDL_Database.char
		char.showTrackingFrame = char.showTrackingFrame or false
		char.minimapIcon = char.minimapIcon or {}
		char.minimapIcon.minimapPos = char.minimapIcon.minimapPos or 220
		char.minimapIcon.radius = char.minimapIcon.radius or 80
		char.TrackingFramePos = char.TrackingFramePos or {}
		char.TrackingFramePos[1] = char.TrackingFramePos[1] or 0
		char.TrackingFramePos[2] = char.TrackingFramePos[2] or 0
		char.TrackingFramePos[3] = char.TrackingFramePos[3] or "CENTER"
		char.lockTrackingFrame = char.lockTrackingFrame or false
		char.trackerCharacterExpanded = char.trackerCharacterExpanded or {}
	end

	local taskDataBridge = {}
	local TDL_Database = {}

	function taskDataBridge.Initialize()
		TDL_Database = LibStub("AceDB-3.0"):New("ToDoListDB",defaults)
		SetUpDefaultCharValues(TDL_Database)
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
