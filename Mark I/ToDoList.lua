function ShowToDoFrame() 
	local AceGUI = LibStub("AceGUI-3.0")
	--Create a container frame
	local f = AceGUI:Create("Frame")
	f:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end)
	f:SetTitle("ToDo's")
	f:SetLayout("Flow")
end

function Init()
	local AceConsole = LibStub("AceConsole-3.0")
	AceConsole:RegisterChatCommand("todo", ShowToDoFrame)
end

