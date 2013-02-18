--Mod todos:
--js lint equiv
--unit tests
--Consolidate id's on login
--Move static things into other files
--Move tracking pane, main pane into own files

--feature todos:
--tracking pane
--  On tooltip, for incomplete, show reset time, for completed, show when completed
--  On tooltip, message 'Click to toggle completed/uncompleted'
--  Option: Show tracking frame
--	Option: Lock tracking frame
--	Option: Only show for this character (currently logged in)
--	Option: Only show remaining tasks
--	Add in group by and replace uniq
--	Refresh tracking pane and main app when either changes in a coherent way
--change remaining task view to show 'next reset time/day' in # hours?
--pretty-up completed task view - times/format, show  reset time?
--Disable edit button until and after changes are made, and create button?
--sort tasks/allow sorting by character/name/reset time?
--Set up default tab to be second tab if no tasks created
--Add 'uncompleted' button to main pane

--Future features:
--Allow time zone changing (enter task in one tz, then log in while in another)

TDL = LibStub("AceAddon-3.0"):NewAddon("TDL", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
local QTip = LibStub('LibQTip-1.0')
local AceGUI = LibStub("AceGUI-3.0")
TDL.LDBIcon = LibStub("LibDBIcon-1.0")
local taskDataBridge = requireTaskDataBridge()
ToDoListDB = taskDataBridge.GetDataConnection()
local TDLLauncher = LibStub("LibDataBroker-1.1", true):NewDataObject("TDL", {
	type = "launcher",
	icon = "Interface\\Icons\\inv_scroll_09",
	OnClick = function(_,button) -- fires when a user clicks on the minimap icon
			local char = taskDataBridge.GetCharInfo()
			if button == "RightButton" then
				char.showTrackingFrame = not char.showTrackingFrame
				if char.showTrackingFrame then
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

function TDL:CreateBoundedTextBox(text, width, cbMethod, cb, buttonDisabled, maxWidth)
	local textbox = TDL:CreateTextBox(text, width, cbMethod, cb, buttonDisabled)
	textbox:SetMaxLetters(maxWidth)
	return textbox
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

function TDL:CreateColoredLabel (text, width, colorArg1, colorArg2, colorArg3)
	local label = TDL:CreateLabel(text, width)
	label:SetColor(colorArg1, colorArg2, colorArg3)
	return label
end


local windowOpen = false
local tab = 1
local __ = requireUnderscore()

local DateTimeUtil = requireDateTimeUtil()
local Task = requireTask()

local ToDoList_UpdateInterval = 1.0
local ToDoList_TimeSinceLastUpdate = 0.0

local ToDoList_WidgetWidth = 690

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

local ToDoList_TrackingPane_HeaderHeight = 18
local ToDOList_TrackingPane_MessageHeight = 14

local ToDoList_TaskPage = 1
local ToDoList_EditPage = 2

local TDL_TaskCompleted_Texture = "Interface\\RAIDFRAME\\ReadyCheck-Ready.blp"
local TDL_TaskRemaining_Texture = "Interface\\RAIDFRAME\\ReadyCheck-NotReady.blp"

TDL_DayInitials =
{
	[1] = "Su",
	[2] = "Mo",
	[3] = "Tu",
	[4] = "We",
	[5] = "Th",
	[6] = "Fr",
	[7] = "Sa"
}

TDL_AmPmLiterals =
{
	[1] = "AM",
	[2] = "PM"
}

TDL:RegisterChatCommand("tdl","InitUI")
TDL:RegisterChatCommand("todo","InitUI")
TDL:RegisterChatCommand("todolist","InitUI")
TDL:RegisterChatCommand("tdl-reset", "ResetTrackingFrame")
TDL:RegisterChatCommand("todo-reset", "ResetTrackingFrame")
TDL:RegisterChatCommand("todolist-reset", "ResetTrackingFrame")


function TDL:OnInitialize()
    -- Called when the addon is loaded
    taskDataBridge.Initialize()
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

	local remainingTasks = taskDataBridge:GetRemainingTasks()
	for i, task in ipairs(remainingTasks) do
		local characterLabel = TDL:CreateLabel(task["Character"], ToDoList_TaskPage_CharacterColumnWidth)
		local taskLabel = TDL:CreateLabel(task["Description"], ToDoList_TaskPage_DescriptionColumnWidth)
		local expirationGroup = AceGUI:Create("SimpleGroup")
		expirationGroup:SetWidth(ToDoList_TaskPage_DateTimeColumnWidth)
		local expirationDaysLabel = TDL:CreateLabel(task:GetExpirationDaysString(), ToDoList_TaskPage_DateTimeColumnWidth)
		local expirationTimeLabel = TDL:CreateLabel(task:GetExpirationTimeString(), ToDoList_TaskPage_DateTimeColumnWidth)
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

	local completedTasks = taskDataBridge:GetCompletedTasks()
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
	local existingTasks = taskDataBridge:GetAllTasks()
	local existingTasksClone = __.map(existingTasks, function(item) return item:Clone() end)
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
	local uncreatedChanges = Task:new()
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
	local dailyResetTimeNoteText = "Note: The daily reset time for US servers is 3AM, Pacific Time, -08:00 UTC. All times entered will be in your current time zone, which is "..DateTimeUtil.CurrentTimeZoneString().."."
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
		task["Character"], ToDoList_EditPage_CharacterColumnWidth,
		"OnTextChanged", function (_, _, newValue) task.Character = newValue end, true)
	local descriptionTextBox = TDL:CreateTextBox(
		task["Description"], ToDoList_EditPage_DescriptionColumnWidth,
		"OnTextChanged", function (_, _, newValue) task.Description = newValue end, true)
	group:AddChild(characterTextBox)
	group:AddChild(descriptionTextBox)
	group:AddChild(TDL:CreateDaysCheckboxGroup(task))
	local HoursTextbox = TDL:CreateBoundedTextBox(
		string.format("%.2d", task["Hours"]), ToDoList_EditPage_HourTextboxWidth,
		"OnTextChanged", function (_, _, newValue) task.Hours = newValue end, true, 2)
	local MinutesTextBox = TDL:CreateBoundedTextBox(
		string.format("%.2d", task["Minutes"]), ToDoList_EditPage_MinutesTextboxWidth,
		"OnTextChanged", function (_, _, newValue) task.Minutes = newValue end,  true, 2)
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
	buttonSetupCB(statusTextLabel)

	group:AddChild(statusTextLabel)

end

function TDL:CreateDaysCheckboxGroup(task)
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
	return checkboxGroup
end

function TDL:AddTask(id, statusTextLabel)
	local response = taskDataBridge.AddTask(id)
	if (response) then
		statusTextLabel:SetText(response)
	else
		TDL:ReloadUI(ToDoList_EditPage)
	end
end

function TDL:SaveChangesToTask(task)
	local response = taskDataBridge.SaveChangesToTask(task)
	if (response) then
		statusTextLabel:SetText(errorMsg)
	else
		TDL:ReloadUI(ToDoList_EditPage)
	end
end

function TDL:DeleteTask(id)
	taskDataBridge.DeleteTask(id)
	TDL:ReloadUI(ToDoList_EditPage)
end

function TDL:ResetCompletedTasks()
	local completedTasks = taskDataBridge:GetCompletedTasks()
	for i, task in ipairs(completedTasks) do
		local hours = task.Hours
		if (task.AmPm == 2) then
			hours = hours + 12
		end
		local mostRecentResetTime = DateTimeUtil.GetMostRecentResetTime(task.Minutes, hours, task.Days)
		if mostRecentResetTime > task["LastCompleted"] then task["LastCompleted"] = nil end
	end
end

function TDL:SetTaskCompleted (task)
	task["LastCompleted"] = time()
	TDL:ReloadUI(ToDoList_TaskPage)
end

function TDL:ToggleTaskCompleted(task)
	if (task["LastCompleted"]) then
		task["LastCompleted"] = nil
	else
		task["LastCompleted"] = time()
	end
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

function TDL:CreateMinimapButton()
	TDL.LDBIcon:Register("TDL", TDLLauncher, taskDataBridge.GetCharInfo().minimapIcon)
end

function TDL:ResetData()
	taskDataBridge.ResetDB()
	collectgarbage()
	TDL.LDBIcon:Show("TDL")
	TDL:ReloadTrackingFrame()
	TDL:CheckPlayerData()
end

function TDL_UpdateTrackingFrame(self, elapsed)
  ToDoList_TimeSinceLastUpdate = ToDoList_TimeSinceLastUpdate + elapsed;

  if (ToDoList_TimeSinceLastUpdate > ToDoList_UpdateInterval) then
	TDL.CompletedDailiesCounter:SetText("Daily Quests completed today: "..GetDailyQuestsCompleted())
	TDL.DailiesResetTimer:SetText("Dailies reset in "..SecondsToTime(GetQuestResetTime()))
    ToDoList_TimeSinceLastUpdate = 0;
    TDL:ResetCompletedTasks()
  end

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

function TDL:CreateTrackingFrame()
	local char = taskDataBridge.GetCharInfo()
	TDL.TrackingFrame = CreateFrame("Frame","TrackingFrame",UIParent)
	TDL.TrackingFrame:SetMovable(true)
	TDL.TrackingFrame:EnableMouse(true)
	TDL.TrackingFrame:SetClampedToScreen(true)
	TDL.TrackingFrame:RegisterForDrag("LeftButton")
	TDL.TrackingFrame:SetScript("OnUpdate",TDL_UpdateTrackingFrame)
	TDL.TrackingFrame:SetScript("OnDragStart", TDL.TrackingFrame.StartMoving)
	TDL.TrackingFrame:SetScript("OnDragStop", TDL.TrackingFrame.StopMovingOrSizing)
	TDL.TrackingFrame:SetBackdropColor(0,0,0,1);
	TDL.TrackingFrame:SetHeight(200)
	TDL.TrackingFrame:SetWidth(300)
	TDL.TrackingFrame:SetAlpha(1.0)
	local ypos = 0

	local title = TDL.TrackingFrame:CreateFontString("TitleText",nil,"GameFontNormalLarge")
	title:SetText("|cff7FFF00To-Do List|r")
	title:SetPoint("TOPLEFT",TDL.TrackingFrame,"TOPLEFT",0,-ypos)
	title:Show()
	ypos = ypos + ToDoList_TrackingPane_HeaderHeight

	--Display the completed quests and countdown time
	TDL.CompletedDailiesCounter = TDL.TrackingFrame:CreateFontString("CompletedDailiesCounter", nil, "GameFontWhite")
	TDL.CompletedDailiesCounter:SetText("Daily Quests completed today: "..GetDailyQuestsCompleted())
	TDL.CompletedDailiesCounter:SetPoint("TOPLEFT",TDL.TrackingFrame,"TOPLEFT",0,-ypos)
	TDL.CompletedDailiesCounter:Show()
	ypos = ypos + ToDOList_TrackingPane_MessageHeight

	TDL.DailiesResetTimer = TDL.TrackingFrame:CreateFontString("DailiesResetTimer",nil,"GameFontWhite")
	TDL.DailiesResetTimer:SetText("Dailies reset in "..SecondsToTime(GetQuestResetTime()))
	TDL.DailiesResetTimer:SetPoint("TOPLEFT",TDL.TrackingFrame,"TOPLEFT",0,-ypos)
	TDL.DailiesResetTimer:Show()
	ypos = ypos + ToDOList_TrackingPane_MessageHeight

	local iterator = function (v) return v.Character end
	local uniqueCharacters = __.uniq(taskDataBridge.GetAllTasks(), false, iterator)

	for i, character in ipairs(uniqueCharacters) do
		--self:Print(character)

		local expandButton = CreateFrame("Button",nil,TDL.TrackingFrame,"OptionsButtonTemplate")
		if char.trackerCharacterExpanded[character] then
			expandButton:SetText("--")
		else
			expandButton:SetText("+")
		end
		expandButton:SetWidth(20)
		expandButton:SetHeight(20)
		expandButton:SetAlpha(1)
		expandButton:SetPoint("TOPLEFT",TDL.TrackingFrame,"TOPLEFT", 0,-ypos-2)
		expandButton:SetScript("OnClick",function ()
										if char.trackerCharacterExpanded[character] then
											char.trackerCharacterExpanded[character] = false
											TDL:ReloadTrackingFrame()
										else
											char.trackerCharacterExpanded[character] = true
											TDL:ReloadTrackingFrame()
										end
									end)
		expandButton:Show()
		local characterHeader = TDL.TrackingFrame:CreateFontString("header"..i,nil,"GameFontNormal")
		characterHeader:SetText(character)
		characterHeader:SetPoint("TOPLEFT",TDL.TrackingFrame,"TOPLEFT", 18,-ypos - 4)
		characterHeader:Show()
		ypos = ypos+20
		if (char.trackerCharacterExpanded[character]) then
			characterTasks = __.select(taskDataBridge:GetAllTasks(), function (i) return i.Character == character end)
			for i, characterTask in ipairs(characterTasks) do

				local markCompletedButton = CreateFrame("Button",nil,TDL.TrackingFrame)
				markCompletedButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
				markCompletedButton:SetBackdrop(tx)
				markCompletedButton:SetWidth(12)
				markCompletedButton:SetHeight(12)
				markCompletedButton:SetAlpha(1)
				if (characterTask.LastCompleted) then
					local tx = markCompletedButton:CreateTexture()
					tx:SetAllPoints(markCompletedButton)
					tx:SetTexture(TDL_TaskCompleted_Texture,1)
				end
				markCompletedButton:SetPoint("TOPLEFT",TDL.TrackingFrame,"TOPLEFT",15,-ypos)
				markCompletedButton:Show()

				local characterTaskLabel = TDL.TrackingFrame:CreateFontString(character.." task "..i,nil,"GameFontWhiteSmall")
				characterTaskLabel:SetText("|cffFFFFFF"..characterTask.Description.."|r")
				characterTaskLabel:SetPoint("TOPLEFT", TDL.TrackingFrame, "TOPLEFT", 25, -ypos)
				characterTaskLabel:Show()

				local characterTaskLabelButton = CreateFrame("Button",nil,TDL.TrackingFrame)
				characterTaskLabelButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
				local tx = characterTaskLabelButton:CreateTexture()
				tx:SetAllPoints(characterTaskLabelButton)
				tx:SetTexture(1,1,1,0.1)
				characterTaskLabelButton:SetHighlightTexture(tx)
				characterTaskLabelButton:SetWidth(characterTaskLabel:GetStringWidth())
				characterTaskLabelButton:SetHeight(12)
				characterTaskLabelButton:SetAlpha(1)
				characterTaskLabelButton:SetPoint("TOPLEFT",TDL.TrackingFrame,"TOPLEFT",25,-ypos)

				characterTaskLabelButton:SetScript("OnClick", function (_, button)
																TDL:ToggleTaskCompleted(characterTask)
																TDL:ReloadTrackingFrame()
														end)

				characterTaskLabelButton:SetScript("OnEnter", function ()
															if TDL_Tooltips then
																TDL_Tooltips:TDL_CreateTaskTooltip(characterTaskLabel, characterTask)
															end
														end)
				characterTaskLabelButton:SetScript("OnLeave", function ()
															if TDL_Tooltips then
																QTip:Release(self.tooltip)
																self.tooltip = nil
															end
														end)

				characterTaskLabelButton:Show()
				ypos = ypos + 12
			end
		end


	end

	TDL.TrackingFrame:SetHeight(32)
    local xO,yO = char.TrackingFramePos[1], char.TrackingFramePos[2]
    TDL.TrackingFrame:SetPoint( char.TrackingFramePos[3],nil, char.TrackingFramePos[3],xO,yO-(TDL.TrackingFrame:GetHeight()/2))

    collectgarbage()


    if not char.showTrackingFrame then
		TDL.TrackingFrame:Hide()
	else
		TDL.TrackingFrame:Show()
	end

	if char.lockTrackingFrame then
		TDL.TrackingFrame:SetMovable(false)
		TDL.TrackingFrame:EnableMouse(false)
    else
		TDL.TrackingFrame:SetMovable(true)
		TDL.TrackingFrame:EnableMouse(true)
    end

end

function TDL:ReloadTrackingFrame()
	local char = taskDataBridge.GetCharInfo()
	local point, relativeTo, relativePoint, xOfs, yOfs = TDL.TrackingFrame:GetPoint()
	char.TrackingFramePos[1] = xOfs
    char.TrackingFramePos[2] = yOfs+(TDL.TrackingFrame:GetHeight()/2)
	char.TrackingFramePos[3] = point

	TDL.TrackingFrame:Hide()
	TDL.TrackingFrame = nil
	collectgarbage()

	TDL:CreateTrackingFrame()
end

function TDL:ResetTrackingFrame()
	local char = taskDataBridge.GetCharInfo()
	char.TrackingFramePos =
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
