--Mod todos:
--js lint equiv
--unit tests
--feature todos:
--validation
--tracking pane
--reset tasks at correct time and onload
--change remaining task view to show 'next reset time/day' in # hours?
--pretty-up completed task view - times/format, show  reset time?

--Future features:
--Allow time zone changing (enter task in one tz, then log in while in another)
--Allow to recant 'completion' if misclick etc




TDL = LibStub("AceAddon-3.0"):NewAddon("TDL", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

local QTip = LibStub('LibQTip-1.0')
local AceGUI = LibStub("AceGUI-3.0")
TDL.LDBIcon = LibStub("LibDBIcon-1.0")

local TDLLauncher = LibStub("LibDataBroker-1.1", true):NewDataObject("TDL", {
	type = "launcher",
	icon = "Interface\\Icons\\inv_scroll_09",
	OnClick = function(_,button) -- fires when a user clicks on the minimap icon
			if button == "RightButton" then
				TDL_Database.char.showTrackingFrame = not TDL_Database.char.showTrackingFrame
				if TDL_Database.char.showTrackingFrame then
					TDL.TrackingFrame:Show()
				else
					TDL.TrackingFrame:Hide()
				end
			else
				TDL:InitUI()
			end
		end,
	OnTooltipShow = function(tt) -- tooltip that shows when you hover over the minimap icon
			local cs = "|cffffffcc"
			local ce = "|r"
			tt:AddLine("To-Do List")
			tt:AddLine(string.format("%sLeft-Click%s to open the configuration window", cs, ce))
			tt:AddLine(string.format("%sRight-Click%s to hide/show the tracking window", cs, ce))
			tt:AddLine(string.format("%sDrag%s to move this button", cs, ce))
		end,
	})

function TDL:CreateLabel(text, width)
	local label = AceGUI:Create("Label")
	label:SetText(text)
	label:SetWidth(width)
	return label
end

function TDL:CreateButton(text, width, cb)
	local button = AceGUI:Create("Button")
	button:SetText(text)
	button:SetWidth(width)
	button:SetCallback("OnClick", cb)
	return button
end

function TDL:CreateTextBox(text, width, cbMethod, cb, buttonDisabled)
	local textBox = AceGUI:Create("EditBox")
	textBox:SetText(text)
	textBox:SetWidth(width)
	textBox:SetCallback(cbMethod, cb)
	textBox:DisableButton(buttonDisabled)

	return textBox
end

function TDL:CreateCheckbox(text, width, defaultValue, cb)
	local checkbox = AceGUI:Create("CheckBox")
	checkbox:SetLabel(text)
	checkbox:SetWidth(width)
	checkbox:SetValue(defaultValue)
	checkbox:SetCallback("OnValueChanged", cb)
	return checkbox
end

function TDL:CreateDropdown(values, width, cb)
	local dropDown = AceGUI:Create("Dropdown")
	dropDown:SetList(values)
	dropDown:SetWidth(width)
	dropDown:SetCallback("OnValueChanged", cb)
	return dropDown
end

--TODO: MOve all data access out
--TODO: Consolidate id's on login
--TODO: Move all task-related things to Task

function TDL:CreateColoredLabel (text, width, colorArg1, colorArg2, colorArg3)
	local label = TDL:CreateLabel(text, width)
	label:SetColor(colorArg1, colorArg2, colorArg3)
	return label
end


local windowOpen = false
local tab = 1
local __ = requireUnderscore()

local ToDoList_UpdateInterval = 1.0
local ToDoList_TimeSinceLastUpdate = 0.0

local ToDoList_WidgetWidth = 675

local ToDoList_TaskPage_PageWidth = ToDoList_WidgetWidth
local ToDoList_TaskPage_CharacterColumnWidth = 75
local ToDoList_TaskPage_DescriptionColumnWidth = 200
local ToDoList_TaskPage_DateTimeColumnWidth = 125
local ToDoList_TaskPage_ButtonColumnWidth = 200
local ToDoList_TaskPage_ButtonWidth = 125
local ToDoList_TaskPage_ButtonExtenderWidth = ToDoList_TaskPage_ButtonColumnWidth - ToDoList_TaskPage_ButtonWidth

local ToDoList_EditPage_PageWidth = ToDoList_WidgetWidth
local ToDoList_EditPage_DailyResetNoteWidth = ToDoList_EditPage_PageWidth - 75
local ToDoList_EditPage_CheckboxGroupWidth = 200
local ToDoLIst_EditPage_TimePickerWidth = 75
local ToDoList_EditPage_CharacterColumnWidth = 75
local ToDoList_EditPage_DescriptionColumnWidth = 200
local ToDoList_EditPage_DateTimeColumnWidth = ToDoList_EditPage_CheckboxGroupWidth + ToDoLIst_EditPage_TimePickerWidth
local ToDoList_EditPage_ButtonWidth = 125
local ToDoList_EditPage_DayCheckboxWidth = 48
local ToDoList_EditPage_HourTextboxWidth = 30
local ToDoList_EditPage_MinutesTextboxWidth = 30
local ToDoList_EditPage_ColonLabelWidth = 10
local ToDoList_EditPage_AmPmDropdownWidth = 60
local ToDoList_EditPage_AddButtonsExtenderWidth = ToDoList_EditPage_PageWidth - ToDoList_EditPage_ButtonWidth
local ToDoList_EditPage_EditButtonsExtenderWidth = ToDoList_EditPage_PageWidth - (ToDoList_EditPage_ButtonWidth * 2)
local ToDoList_EditPage_TaskSelectionDropdownWidth = 400

local ToDoList_TaskPage = 1
local ToDoList_EditPage = 2

local TDL_DayInitials =
{
	[1] = "Su",
	[2] = "Mo",
	[3] = "Tu",
	[4] = "We",
	[5] = "Th",
	[6] = "Fr",
	[7] = "Sa"
}

local TDL_AmPmLiterals =
{
	[1] = "AM",
	[2] = "PM"
}

---------------------------------------------------------------------------------
--Time zone helpers

-- Compute the difference in seconds between local time and UTC.
local function get_timezone()
  local now = time()
  return difftime(now, time(date("!*t", now)))
end

-- Return a timezone string in ISO 8601:2000 standard form (+hhmm or -hhmm)
local function SecondsToHoursMinutes (timezone)
  local h, m = math.modf(timezone / 3600)
  return h, 60 * m
end

local function CurrentTimeZoneString()
	local timezoneDiff = get_timezone(time())
	local hourDiff, minuteDiff = SecondsToHoursMinutes(timezoneDiff)
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

local function AddDays(currentDay, currentMonth, currentYear, daysToAdd)
	if (currentDay > maxMonthLength or currentMonth > #monthLengths or currentYear < 1) then
		return -1, -1, -1
	end
	newDay = currentDay + daysToAdd
	newMonth = currentMonth
	newYear = currentYear
	if daysToAdd > 0 then
		while (newDay > monthLengths[newMonth]) do
			newDay = newDay - month.monthLengths[newMonth]
			newMonth = newMonth + 1
			if (newMonth > yearLength) then
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

--------------------------------------------------------------------------

TDL:RegisterChatCommand("tdl","InitUI")
TDL:RegisterChatCommand("todo","InitUI")
TDL:RegisterChatCommand("todolist","InitUI")
TDL:RegisterChatCommand("tdl-reset", "ResetTrackingFrame")
TDL:RegisterChatCommand("todo-reset", "ResetTrackingFrame")
TDL:RegisterChatCommand("todolist-reset", "ResetTrackingFrame")

function TDL:SetUpDefaultCharValues()
	TDL_Database.char.hasDefaults = true
	TDL_Database.char.showMinimapIcon = true
	TDL_Database.char.showTrackingFrame = true
	TDL_Database.char.lockTrackingFrame = false
	TDL_Database.char.announceMethod = 1
	TDL_Database.char.TrackingFramePos =
	{
		[1] = 0,
		[2] = 0,
		[3] = "CENTER"
	}
	TDL_Database.char.minimapIcon =
	{
		["hide"] = false,
		["minimapPos"] = 220,
		["radius"] = 80
	}
end

function TDL:InitializeUncreatedChanges()
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

function TDL:CloneTask(oldTask)
	local toReturn = {}
	TDL:CopyTask(oldTask, toReturn)
	return toReturn
end

function TDL:CopyTask(src, dest)
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


function TDL:OnInitialize()
    -- Called when the addon is loaded
    TDL_Database = LibStub("AceDB-3.0"):New("ToDoListDB",defaults)
    if (not TDL_Database.char.hasDefaults) then
		TDL:SetUpDefaultCharValues()
	end
	if (not TDL_Database.global.Tasks) then
		TDL_Database.global.Tasks = {}
		TDL_Database.global.nextId = 0
	end
    TDL:CreateMinimapButton()
    TDL:CreateTrackingFrame()
end

function TDL:OnEnable()
	-- Called when the addon is enabled
	self:Print("To-Do List enabled. /todo to configure.")
	TDL:ReloadTrackingFrame()
end

function TDL:DrawTaskTab(container)
	container:SetLayout("Fill")

	local ScrollFrame = AceGUI:Create("ScrollFrame")
	ScrollFrame:SetLayout("Flow")
	ScrollFrame:SetWidth(ToDoList_TaskPage_PageWidth)

	local RemainingTasksGroup = TDL:GetRemainingTasksGroup()
	local CompletedTasksGroup = TDL:GetCompletedTasksGroup()
	local RefreshButtonGroup =  TDL:GetRefreshButtonGroup()

	RemainingTasksGroup:SetLayout("Flow")
	CompletedTasksGroup:SetLayout("Flow")
	RefreshButtonGroup:SetLayout("Flow")
	ScrollFrame:AddChild(RemainingTasksGroup)
	ScrollFrame:AddChild(CompletedTasksGroup)
	ScrollFrame:AddChild(RefreshButtonGroup)
	container:AddChild(ScrollFrame)
end

function TDL:DrawAddRemoveTab(container)
	container:SetLayout("Fill")

	local ScrollFrame = AceGUI:Create("ScrollFrame")
	ScrollFrame:SetLayout("Flow")
	ScrollFrame:SetWidth(ToDoList_EditPage_PageWidth)

	local ExistingTasksGroup = TDL:GetExistingTasksGroup()
	local AddTaskGroup = TDL:GetAddTaskGroup()
	local DailyResetTimeNoteGroup = TDL:GetDailyResetTimeNoteGroup()

	ExistingTasksGroup:SetLayout("Flow")
	AddTaskGroup:SetLayout("Flow")
	DailyResetTimeNoteGroup:SetLayout("Flow")
	ScrollFrame:AddChild(AddTaskGroup)
	ScrollFrame:AddChild(ExistingTasksGroup)
	ScrollFrame:AddChild(DailyResetTimeNoteGroup)
	container:AddChild(ScrollFrame)
end

function TDL:GetRemainingTasksGroup()
	local RemainingTasksGroup = AceGUI:Create("InlineGroup")
	RemainingTasksGroup:SetWidth(ToDoList_TaskPage_PageWidth)
	RemainingTasksGroup:SetTitle("Remaining Tasks")

	local CharacterLabel = TDL:CreateColoredLabel("Character", ToDoList_TaskPage_CharacterColumnWidth, 0, 1, 0)
	RemainingTasksGroup:AddChild(CharacterLabel)
	local DescriptionLabel = TDL:CreateColoredLabel("Description", ToDoList_TaskPage_DescriptionColumnWidth, 0, 1, 0)
	RemainingTasksGroup:AddChild(DescriptionLabel)
	local ExpirationLabel = TDL:CreateColoredLabel("Expiration", ToDoList_TaskPage_DateTimeColumnWidth, 0, 1, 0)
	RemainingTasksGroup:AddChild(ExpirationLabel)
	local ButtonLabel = TDL:CreateColoredLabel(" Mark Completed:", ToDoList_TaskPage_ButtonColumnWidth, 0, 1, 0)
	RemainingTasksGroup:AddChild(ButtonLabel)

	local remainingTasks = TDL:GetRemainingTasks()
	for i, task in ipairs(remainingTasks) do
		local characterLabel = TDL:CreateLabel(task["Character"], ToDoList_TaskPage_CharacterColumnWidth)
		local taskLabel = TDL:CreateLabel(task["Description"], ToDoList_TaskPage_DescriptionColumnWidth)
		local expirationGroup = AceGUI:Create("SimpleGroup")
		expirationGroup:SetWidth(ToDoList_TaskPage_DateTimeColumnWidth)
		local expirationDaysLabel = TDL:CreateLabel(TDL:GetExpirationDaysString(task["Days"]), ToDoList_TaskPage_DateTimeColumnWidth)
		local expirationTimeLabel = TDL:CreateLabel(TDL:GetExpirationTimeString(task["Hours"], task["Minutes"], task["AmPm"]), ToDoList_TaskPage_DateTimeColumnWidth)
		expirationGroup:AddChild(expirationDaysLabel)
		expirationGroup:AddChild(expirationTimeLabel)
		local markCompletedButton = TDL:CreateButton(
			"Completed!",
			ToDoList_TaskPage_ButtonWidth,
			function () TDL:SetTaskCompleted(task) end)
		local blankLabel = TDL:CreateLabel("", ToDoList_TaskPage_ButtonExtenderWidth)
		RemainingTasksGroup:AddChild(characterLabel)
		RemainingTasksGroup:AddChild(taskLabel)
		RemainingTasksGroup:AddChild(expirationGroup)
		RemainingTasksGroup:AddChild(markCompletedButton)
		RemainingTasksGroup:AddChild(blankLabel)
	end
	return RemainingTasksGroup
end

function TDL:GetCompletedTasksGroup()
	local CompletedTasksGroup = AceGUI:Create("InlineGroup")
	CompletedTasksGroup:SetWidth(ToDoList_TaskPage_PageWidth)
	CompletedTasksGroup:SetTitle("Completed Tasks")

	local CharacterLabel = TDL:CreateColoredLabel("Character", ToDoList_TaskPage_CharacterColumnWidth, 0, 1, 0)
	local DescriptionLabel = TDL:CreateColoredLabel("Description", ToDoList_TaskPage_DescriptionColumnWidth, 0, 1, 0)
	local ExpirationLabel = TDL:CreateColoredLabel("Last Completed", ToDoList_TaskPage_DateTimeColumnWidth, 0, 1, 0)
	local BlankLabel = TDL:CreateLabel("", ToDoList_TaskPage_ButtonColumnWidth)
	CompletedTasksGroup:AddChild(CharacterLabel)
	CompletedTasksGroup:AddChild(DescriptionLabel)
	CompletedTasksGroup:AddChild(ExpirationLabel)
	CompletedTasksGroup:AddChild(BlankLabel)


	local completedTasks = TDL:GetCompletedTasks()
	for i, task in ipairs(completedTasks) do
		local characterLabel = TDL:CreateLabel(task["Character"], ToDoList_TaskPage_CharacterColumnWidth)
		local taskLabel = TDL:CreateLabel(task["Description"], ToDoList_TaskPage_DescriptionColumnWidth)
		local expirationLabel = TDL:CreateLabel(date("%c", task["LastCompleted"]), ToDoList_TaskPage_DateTimeColumnWidth)
		local blankLabel = TDL:CreateLabel("", ToDoList_TaskPage_ButtonColumnWidth)
		CompletedTasksGroup:AddChild(characterLabel)
		CompletedTasksGroup:AddChild(taskLabel)
		CompletedTasksGroup:AddChild(expirationLabel)
		CompletedTasksGroup:AddChild(blankLabel)
	end
	return CompletedTasksGroup
end

function TDL:GetExistingTasksGroup()
	local existingTasks = TDL:GetAllTasks()
	local existingTasksClone = __.map(existingTasks, function(item) return TDL:CloneTask(item) end)
	local dropDownGroup = AceGUI:Create("DropdownGroup")
	dropDownGroup:SetLayout("Flow")
	dropDownGroup:SetTitle("Choose an existing task to edit:")
	if (existingTasks and #existingTasks > 0) then
		dropDownGroup:SetGroupList(__.map(existingTasksClone, function (task) return task["Description"].." ("..task["Character"]..")" end))
		dropDownGroup:SetCallback("OnGroupSelected", function (dropDownGroup, _, selectedGroup) TDL:ChangeSelectedEditTask(dropDownGroup, existingTasksClone[selectedGroup]) end)
		dropDownGroup:SetGroup(1)
	else
		local emptyList = { [1] = "There are no tasks to edit!" }
		dropDownGroup:SetGroupList(emptyList)
		dropDownGroup:SetGroup(1)
	end
	dropDownGroup:SetWidth(ToDoList_EditPage_PageWidth)
	dropDownGroup:SetDropdownWidth(ToDoList_EditPage_TaskSelectionDropdownWidth)
	return dropDownGroup
end

function TDL:GetAddTaskGroup()
	local uncreatedChanges = TDL:InitializeUncreatedChanges()
	local AddTaskGroup = AceGUI:Create("InlineGroup")
	AddTaskGroup:SetWidth(ToDoList_EditPage_PageWidth)
	AddTaskGroup:SetTitle("Add a task")
	TDL:AddSingleTaskToGroup(uncreatedChanges,
		AddTaskGroup,
		function (statusTextLabel) TDL:AddCreateTaskButtonToGroup(AddTaskGroup, uncreatedChanges, statusTextLabel) end)
	return AddTaskGroup
end

function TDL:GetDailyResetTimeNoteGroup()
	local DailyResetTimeNoteGroup = AceGUI:Create("SimpleGroup")
	local dailyResetTimeNoteText = "Note: The daily reset time for US servers is 3AM, Pacific Time, -08:00 UTC. All times entered will be in your current time zone, which is "..CurrentTimeZoneString().."."
	local dailyResetTimeNote = TDL:CreateLabel(dailyResetTimeNoteText, ToDoList_EditPage_DailyResetNoteWidth)
	DailyResetTimeNoteGroup:AddChild(dailyResetTimeNote)
	return DailyResetTimeNoteGroup
end

function TDL:GetRefreshButtonGroup()
	local RefreshButtonGroup = AceGUI:Create("SimpleGroup")
	local dailyResetTimeNote = TDL:CreateButton("Refresh Tasks", ToDoList_TaskPage_ButtonWidth, function () TDL:ReloadUI(ToDoList_TaskPage) end)
	RefreshButtonGroup:AddChild(dailyResetTimeNote)
	return RefreshButtonGroup
end

function TDL:ChangeSelectedEditTask(dropDownGroup, task)
	dropDownGroup:ReleaseChildren()

	if (task) then
		TDL:AddSingleTaskToGroup(
			task,
			dropDownGroup,
			function (statusTextLabel) TDL:AddEditRemoveButtonsToGroup(dropDownGroup, task, statusTextLabel) end)
	end
end

function TDL:AddEditRemoveButtonsToGroup(group, task, statusTextLabel)

	local DeleteTaskButton = TDL:CreateButton(
		"Delete Task",
		ToDoList_EditPage_ButtonWidth,
		function() TDL:DeleteTask(task["id"]) end)
	local SaveChangesButton = TDL:CreateButton(
		"Save Changes",
		ToDoList_EditPage_ButtonWidth,
		function() TDL:SaveChangesToTask(task, statusTextLabel) end)
	local blankLabel = TDL:CreateLabel("", ToDoList_EditPage_EditButtonsExtenderWidth)
	group:AddChild(SaveChangesButton)
	group:AddChild(DeleteTaskButton)
	group:AddChild(blankLabel)
end

function TDL:AddCreateTaskButtonToGroup(group, task, statusTextLabel)
	local AddTaskButton = TDL:CreateButton(
		"Add Task",
		ToDoList_TaskPage_ButtonWidth,
		function() TDL:AddTask(task, statusTextLabel) end)
	local blankLabel = TDL:CreateLabel("", ToDoList_EditPage_AddButtonsExtenderWidth)
	group:AddChild(AddTaskButton)
	group:AddChild(blankLabel)
end

function TDL:AddSingleTaskToGroup(task, group, buttonSetupCB)

	local CharacterLabel = TDL:CreateColoredLabel("Character", ToDoList_EditPage_CharacterColumnWidth, 0, 1, 0)
	local DescriptionLabel = TDL:CreateColoredLabel("Description", ToDoList_EditPage_DescriptionColumnWidth, 0, 1, 0)
	local ExpirationLabel = TDL:CreateColoredLabel("Reminder day/time", ToDoList_EditPage_DateTimeColumnWidth, 0, 1, 0)
	group:AddChild(CharacterLabel)
	group:AddChild(DescriptionLabel)
	group:AddChild(ExpirationLabel)

	local characterTextBox = TDL:CreateTextBox(
		task["Character"],
		ToDoList_EditPage_CharacterColumnWidth,
		"OnTextChanged",
		function (_, _, newValue) task.Character = newValue end,
		true)
	local descriptionTextBox = TDL:CreateTextBox(
		task["Description"],
		ToDoList_EditPage_DescriptionColumnWidth,
		"OnTextChanged",
		function (_, _, newValue) task.Description = newValue end,
		true)
	group:AddChild(characterTextBox)
	group:AddChild(descriptionTextBox)
	local checkboxGroup = AceGUI:Create("SimpleGroup")
	checkboxGroup:SetLayout("Flow")
	checkboxGroup:SetWidth(ToDoList_EditPage_CheckboxGroupWidth)
	for i, dayInitial in ipairs(TDL_DayInitials) do
		local checkbox = TDL:CreateCheckbox(
			dayInitial,
			ToDoList_EditPage_DayCheckboxWidth,
			task["Days"][i],
			function(_, _, newValue) task.Days[i] = newValue end)
		checkboxGroup:AddChild(checkbox)
	end
	group:AddChild(checkboxGroup)
	local HoursTextbox = TDL:CreateTextBox(
		string.format("%.2d", task["Hours"]),
		ToDoList_EditPage_HourTextboxWidth,
		"OnTextChanged",
		function (_, _, newValue) task.Hours = newValue end,
		true)
	HoursTextbox:SetMaxLetters(2)
	local MinutesTextBox = TDL:CreateTextBox(
		string.format("%.2d", task["Minutes"]),
		ToDoList_EditPage_MinutesTextboxWidth,
		"OnTextChanged",
		function (_, _, newValue) task.Minutes = newValue end,
		true)
	MinutesTextBox:SetMaxLetters(2)
	local AmPmDropdown = TDL:CreateDropdown(TDL_AmPmLiterals,
		ToDoList_EditPage_AmPmDropdownWidth,
		function(_, _, newSelected) task.AmPm = newSelected end)
	AmPmDropdown:SetValue(task["AmPm"])
	local colonLabel = TDL:CreateLabel(":", ToDoList_EditPage_ColonLabelWidth)
	local statusTextLabel = TDL:CreateLabel("", ToDoList_EditPage_PageWidth)

	group:AddChild(HoursTextbox)
	group:AddChild(colonLabel)
	group:AddChild(MinutesTextBox)
	group:AddChild(AmPmDropdown)
	--TODO: Disable edit button until and after changes are made, and create button?
	--TODO: Set dirty upon any changes and clear out status text?
	buttonSetupCB(statusTextLabel)

	group:AddChild(statusTextLabel)

end

function TDL:DeleteTask(id)
	TDL_Database.global.Tasks = __.reject(TDL_Database.global.Tasks, function (task) return task["id"] == id end)
	TDL:ReloadUI(ToDoList_EditPage)
end

function TDL:AddTask(task, statusTextLabel)
	local result = TDL:ValidateTask(task, statusTextLabel)
	if (not result) then
		return
	end
	local newTask = TDL:CloneTask(task)
	task.Hours = tonumber(task.Hours)
	task.Minutes = tonumber(task.Minutes)
	table.insert(TDL_Database.global.Tasks, TDL:CloneTask(task))
	TDL_Database.global.nextId = TDL_Database.global.nextId + 1
	TDL:ReloadUI(ToDoList_EditPage)
end

function TDL:SaveChangesToTask(task, statusTextLabel)
	local result = TDL:ValidateTask(task, statusTextLabel)
	if (not result) then
		return
	end
	local taskToUpdate = __.first(__.select(TDL_Database.global.Tasks, function (item) return item.id == task.id end))
	TDL:CopyTask(task, taskToUpdate)
	taskToUpdate.Hours = tonumber(task.Hours)
	taskToUpdate.Minutes = tonumber(task.Minutes)
	TDL:ReloadUI(ToDoList_EditPage)
end

--TODO
function TDL:ValidateTask(task, statusTextLabel)
	return true
end

function TDL:GetRemainingTasks()
	return __.select(TDL_Database.global.Tasks, function(task) return not task["LastCompleted"] end)
end

function TDL:GetCompletedTasks()
	return __.select(TDL_Database.global.Tasks, function(task) return task["LastCompleted"] end)
end

function TDL:GetAllTasks()
	return TDL_Database.global.Tasks
end

function TDL:GetDaysToCheck(today)
	local toReturn = {}
	for i=today - 1,1, -1 do
		table.insert(toReturn, i)
	end
	for i=7, today + 1,-1 do
		table.insert(toReturn, i)
	end
	return toReturn
end

function TDL:GetMostRecentResetTime(minutes, hours, days)
	local currentTimeTable = date("*t")
	--check if one has elapsed today, then the rest of the week, then a week ago today
	if (days[currentTimeTable.wday] == true and (currentTimeTable.hour > hours or (currentTimeTable.hour == hours and currentTimeTable.min > minutes))) then
		return time{year=currentTimeTable.year, month=currentTimeTable.month, day=currentTimeTable.day, hour=hours, min=minutes}
	else
		local daysToCheck = TDL:GetDaysToCheck(currentTimeTable.wday)
		for i, dayToCheck in ipairs(daysToCheck) do
			if (days[dayToCheck] == true) then
				local day, month, year = AddDays(currentTimeTable.day, currentTimeTable.month, currentTimeTable.year, dayToCheck - currentTimeTable.wday)
				return time{year=year, month=month, day=day, hour=hours, min=minutes}
			end
		end
		local day, month, year = AddDays(currentTimeTable.day, currentTimeTable.month, currentTimeTable.year, -7)
		return time{year=year, month=month, day=day, hour=hours, min=minutes}
	end
end

function TDL:ResetCompletedTasks()
	local completedTasks = TDL:GetCompletedTasks()
	for i, task in ipairs(completedTasks) do
		local hours = task.Hours
		if (task.AmPm == 2) then
			hours = hours + 12
		end
		local mostRecentResetTime = TDL:GetMostRecentResetTime(task.Minutes, hours, task.Days)
		if mostRecentResetTime > task["LastCompleted"] then task["LastCompleted"] = nil end
	end
end

function TDL:SetTaskCompleted (task)
	task["LastCompleted"] = time()
	TDL:ReloadUI(ToDoList_TaskPage)
end

local function SelectTab(container,event,tab)
	TDL:ResetCompletedTasks()
	container:ReleaseChildren()
	if tab == ToDoList_TaskPage then
		TDL:DrawTaskTab(container)
	elseif tab == ToDoList_EditPage then
		TDL:DrawAddRemoveTab(container)
	end
end

function TDL:InitUI(selectedTab)
	if windowOpen then
		TDL.MainWindow:Release()
		windowOpen = false
		collectgarbage()
		return
	end

	TDL:ResetCompletedTasks()
	-- Create a container frame
	-- Called when the user enters the console command
	TDL.MainWindow = AceGUI:Create("Window")
	TDL.MainWindow:SetCallback("OnClose",function(widget)
										windowOpen = false
										AceGUI:Release(widget)
									end)
	TDL.MainWindow:SetTitle("To Do List")
	TDL.MainWindow:SetWidth(ToDoList_WidgetWidth)
	TDL.MainWindow:SetHeight("450")
	TDL.MainWindow:SetLayout("Fill")
	TDL.MainWindow:EnableResize(false)


	TabGroup = AceGUI:Create("TabGroup")
	TabGroup:SetTabs({{value = ToDoList_TaskPage,text="To-Do List"}, {value = ToDoList_EditPage,text="Add/Remove To-Do's"}})
	TabGroup:SetCallback("OnGroupSelected", SelectTab)
	TabGroup:SetWidth(ToDoList_WidgetWidth)
	TabGroup:SetLayout("Fill")
	if (not selectedTab) then selectedTab = ToDoList_TaskPage end
	TabGroup:SelectTab(selectedTab)
	TDL.MainWindow:AddChild(TabGroup)
	windowOpen = true
end

function TDL:ReloadUI(selectedTab)
	TDL:InitUI()
	TDL:InitUI(selectedTab)
end


--
-- Tracker Frame
--
--TODO
function TDL:CreateTrackingFrame()
	TDL.TrackingFrame = CreateFrame("Frame","TrackingFrame",UIParent)
	TDL.TrackingFrame:SetMovable(true)
    TDL.TrackingFrame:EnableMouse(true)
    TDL.TrackingFrame:SetClampedToScreen(true)
    TDL.TrackingFrame:RegisterForDrag("LeftButton")
    TDL.TrackingFrame:SetScript("OnUpdate",TDL_OnUpdate)
    TDL.TrackingFrame:SetScript("OnDragStart", TDL.TrackingFrame.StartMoving)
    TDL.TrackingFrame:SetScript("OnDragStop", TDL.TrackingFrame.StopMovingOrSizing)
	TDL.TrackingFrame:SetBackdropColor(0,0,0,1);
	TDL.TrackingFrame:SetHeight(200)
	TDL.TrackingFrame:SetWidth(300)
	TDL.TrackingFrame:SetAlpha(1.0)

    local lbls = {}
    local lblBtns = {}
    local headers = {}
    local btns = {}
    local ypos = 0


    -- Create title text
    local title = TDL.TrackingFrame:CreateFontString("TitleText",nil,"GameFontNormalLarge")
	title:SetText("|cff7FFF00To-Do List|r")
	title:SetPoint("TOPLEFT",TDL.TrackingFrame,"TOPLEFT",-4,-ypos)
	title:Show()
	ypos = ypos + 18

	--Changed to display the completed quests and countdown time
    TDL.timer = TDL.TrackingFrame:CreateFontString("TimerText",nil,"GameFontNormal")
	--DTD.timer:SetText("|cffFFFFFF ("..GetDailyQuestsCompleted().."/"..GetMaxDailyQuests()..") "..SecondsToTime(GetQuestResetTime()).."|r")
	TDL.timer:SetText("|cffFFFFFF Quests completed ("..GetDailyQuestsCompleted()..") "..SecondsToTime(GetQuestResetTime()).."|r")
	TDL.timer:SetPoint("TOPLEFT",TDL.TrackingFrame,"TOPLEFT",5,-ypos)
	TDL.timer:Show()

	ypos = ypos + 14

    i = 0

	TDL.TrackingFrame:SetHeight(32)
    local xO,yO = TDL_Database.char.TrackingFramePos[1],TDL_Database.char.TrackingFramePos[2]
    TDL.TrackingFrame:SetPoint(TDL_Database.char.TrackingFramePos[3],nil,TDL_Database.char.TrackingFramePos[3],xO,yO-(TDL.TrackingFrame:GetHeight()/2))

    collectgarbage()


    if not TDL_Database.char.showTrackingFrame then
		TDL.TrackingFrame:Hide()
	else
		TDL.TrackingFrame:Show()
	end

	if TDL_Database.char.lockTrackingFrame then
		TDL.TrackingFrame:SetMovable(false)
    	TDL.TrackingFrame:EnableMouse(false)
    else
    	TDL.TrackingFrame:SetMovable(true)
		TDL.TrackingFrame:EnableMouse(true)
    end

end

function TDL:ReloadTrackingFrame()
	-- Reload the onscreen tracking frame
	local point, relativeTo, relativePoint, xOfs, yOfs = TDL.TrackingFrame:GetPoint()
	TDL_Database.char.TrackingFramePos[1] = xOfs
    TDL_Database.char.TrackingFramePos[2] = yOfs+(TDL.TrackingFrame:GetHeight()/2)
	TDL_Database.char.TrackingFramePos[3] = point

	TDL.TrackingFrame:Hide()
	TDL.TrackingFrame = nil
	collectgarbage()

	TDL:CreateTrackingFrame()
end

function TDL:ResetTrackingFrame()
	TDL_Database.char.TrackingFramePos =
	{
		[1] = 0,
		[2] = 0,
		[3] = "CENTER"
	}

	TDL.TrackingFrame:Hide()
	TDL.TrackingFrame = nil
	collectgarbage()

	TDL:CreateTrackingFrame()

end

--
-- Minimap Button
--

function TDL:CreateMinimapButton()
	-- create / register the minimap button
	TDL.LDBIcon:Register("TDL", TDLLauncher, TDL_Database.char.minimapIcon)
end

--
--	QUEST TRACKING
--


function TDL:ResetData()

	TDL_Database:ResetDB()
	collectgarbage()

	TDL.LDBIcon:Show("TDL")
	TDL:ReloadTrackingFrame()
	TDL:CheckPlayerData()
end

--
-- OnUpdate, just for fun
--
function TDL_OnUpdate(self, elapsed)
  ToDoList_TimeSinceLastUpdate = ToDoList_TimeSinceLastUpdate + elapsed;

  if (ToDoList_TimeSinceLastUpdate > ToDoList_UpdateInterval) then
	TDL.timer:SetText("|cffFFFFFF Quests completed ("..GetDailyQuestsCompleted()..") "..SecondsToTime(GetQuestResetTime()).."|r")
    ToDoList_TimeSinceLastUpdate = 0;
    TDL:ResetCompletedTasks()
  end

end

function TDL:GetExpirationDaysString(days)
	local toReturn = ""
	for i, day in ipairs(days) do
		day = days[i]
		if (day) then
			if (toReturn ~= "") then
				toReturn = toReturn.." "
			end
			toReturn = toReturn..TDL_DayInitials[i]
		end
	end
	return toReturn
end

function TDL:GetExpirationTimeString(hours, minutes, ampm)
	return string.format("%.2d", hours)..":"..string.format("%.2d", minutes).." "..TDL_AmPmLiterals[ampm]
end

--breaks if tables are keys to other tables, but not if tables are values in other tables
function TDL:SafelyPrintVariable(var)
	if (type(var) == "table") then
		TDL:SafelyPrintTable(var, 0)
	else
		self:Print(var)
	end
end

function TDL:SafelyPrintTable(var, indentation)
	for k,v in pairs(var) do
		local prefix = ""
		for i=0,indentation do
			prefix = prefix.." "
		end
		if (type(v) == "table") then
			self:Print(prefix..tostring(k))
			TDL:SafelyPrintTable(v, indentation + 1)
		else
			self:Print(prefix..tostring(k).." "..tostring(v))
		end
	end
end