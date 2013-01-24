function requireTaskList()

	local TaskList = {}
	TaskList.__index = TaskList

	--Creates an new list
	function TaskList.create()
		local list = {}
		setmetatable(list, TaskList)
		list.count = 0
		list.nextId = 0
		list.items = {}
		return list
	end

	--loads an existing list into this list
	function TaskList.load(taskList)
		local list = {}
		setmetatable(list, TaskList)
		list.count = taskList.count
		list.nextId = taskList.nextId
		list.items = taskList.items
		return list
	end

	function TaskList:Add(newItem)
		newItem.id = self.nextId
		self.nextId = self.nextId + 1

		self.count = self.count + 1
		self.items[self.count] = newItem
	end

	function TaskList:IndexOfElementAtId(elementId)
		for index, item in pairs(self.items) do
			if (item.id == elementId) then
				return index
			end
		end
		return -1
	end

	function TaskList:Remove(elementId)
		local indexToRemove = self:IndexOfElementAtId(elementId)
		if (indexToRemove == -1) then
			return false
		end
		for i = indexToRemove, self.count do
			self.items[i] = self.items[i + 1]
		end
		self.count = self.count - 1
		return true
	end

	function TaskList:GetElementAtId(id)
		return self.items[self:IndexOfElementAtId(id)]
	end

	function TaskList:ToArray()
		return self.items
	end


	return TaskList.create()
end