TDL_Tooltips = TDL:NewModule("Tooltips", "AceEvent-3.0")

local QTip = LibStub('LibQTip-1.0')
local Crayon = LibStub("LibCrayon-3.0")

local TooltipIconSize = 16
local TEXTURE_LINK_FORMAT = "|T%s:%d:%d:0:%d|t "

local QUEST_COMPLETE = "Interface\\RAIDFRAME\\ReadyCheck-Ready.blp"
local QUEST_NOT_COMPLETE = "Interface\\RAIDFRAME\\ReadyCheck-NotReady.blp"
--local QUEST_ACCEPTED = "Interface\\GossipFrame\\DailyActiveQuestIcon.blp"
local QUEST_ACCEPTED = "Interface\\GossipFrame\\ActiveQuestIcon.blp"
local QUEST_AVAILABLE = "Interface\\GossipFrame\\DailyQuestIcon.blp"
local WOWHEAD_ICON = "Interface\\Addons\\DailyTodos\\Textures\\wowhead.tga"

local function RGBToHex(r, g, b)
	r = r <= 255 and r >= 0 and r or 0
	g = g <= 255 and g >= 0 and g or 0
	b = b <= 255 and b >= 0 and b or 0
	return string.format("%02x%02x%02x", r, g, b)
end

local function RGBPercToHex(r, g, b)
	r = r <= 1 and r >= 0 and r or 0
	g = g <= 1 and g >= 0 and g or 0
	b = b <= 1 and b >= 0 and b or 0
	return string.format("%02x%02x%02x", r*255, g*255, b*255)
end

function TDL_Tooltips:TDL_CreateTaskTooltip(parent, task)
	local tooltip = QTip:Acquire("TDLTooltip",2,"LEFT","LEFT")
	TDL.tooltip = tooltip
	
	-- Title the tooltip with the quest name
	tooltip:AddHeader(task.Description)
	tooltip:AddHeader(task.Character)
	if task.LastCompleted then
		tooltip:AddSeparator()
		tooltip:AddLine("Last completed:")
		tooltip:AddLine(date("%c", task.LastCompleted))
	end
	tooltip:AddSeparator()
	tooltip:AddLine("Resets:")
	tooltip:AddLine(task:GetExpirationDaysString())
	tooltip:AddLine(task:GetExpirationTimeString())


	if parent then
		tooltip:SmartAnchorTo(parent)
		tooltip:Show()
	end
	return tooltip
end
