--[[
InfiniteScroller
================
这是一个用于Roblox UI的无限滚动列表组件，支持垂直、水平、网格布局，支持对象池、分组、循环滚动、动画等功能。
适用于大数据量的高性能滚动场景。

主要功能：
- 自动回收与复用单元格，提升性能
- 支持垂直、水平、网格三种布局
- 支持分组显示与分组间距
- 支持循环滚动
- 支持自定义刷新回调
- 支持动画效果
- 支持对象池最大容量限制

使用方式：
local scroller = InfiniteScroller(ScrollingFrame)
scroller:Init(dataList)
scroller:SetRefreshCallback(function(cell, index, data) ... end)
scroller:ScrollToIndex(10)
scroller:UpdateData(newData)
scroller:Destroy()
]]

local TweenService = game:GetService("TweenService")
local Pool_Tool = require(game:GetService("ReplicatedStorage"):WaitForChild("Utils"):WaitForChild("pool_tool")) -- 引入对象池工具

local InfiniteScroller = {}
InfiniteScroller.__index = InfiniteScroller

-- 构造函数，创建InfiniteScroller实例
-- @param scroller ScrollingFrame对象
function InfiniteScroller._New(scroller)
	local self = setmetatable({}, InfiniteScroller)

	-- 基础属性
	self.scroller = scroller -- 滚动容器
	self.data = {}           -- 数据源
	self.activeCells = {}    -- 当前激活的cell（索引->cell）

	self.cellPool = nil      -- 对象池

	-- 性能控制
	self.scrolling = false           -- 是否正在处理跳转
	self.lastScrollPosition = 0      -- 上一次滚动位置
	self.scrollThrottle = 0.08       -- 滚动事件节流时间(秒)
	self.lastScrollTime = 0          -- 上一次滚动事件触发时间

	-- 初始化属性
	self:InitProperties()

	-- 初始化UI，若失败则返回nil
	if not self:InitUI() then
		return nil
	end

	-- 初始化对象池
	self:InitCellPool(scroller:GetAttribute("Cache") or 5)

	return self
end

-- 初始化对象池
function InfiniteScroller:InitCellPool(cacheCount)
	-- 对象池实例化、重置、归还、销毁函数
	local function inst_func(template)
		local cell = template:Clone()
		cell.Visible = false
		cell.Parent = self.scroller
		return cell
	end
	local function reset_func(cell)
		cell.Visible = false
	end
	local function give_back_func(cell)
		cell.Visible = false
	end
	local function destroy_func(cell)
		cell:Destroy()
	end

	self.cellPool = Pool_Tool(
		self.cellTemplate,
		inst_func,
		reset_func,
		give_back_func,
		destroy_func,
		cacheCount
	)
end

-- 预分配对象池中的cell（已废弃，Pool_Tool自动管理）
function InfiniteScroller:PreallocateCells(count)
	-- Pool_Tool会自动按需创建，无需手动预分配
end

-- 初始化属性，从scroller的属性中读取配置
function InfiniteScroller:InitProperties()
	-- 方向: "Vertical", "Horizontal", "Grid"
	self.direction = self.scroller:GetAttribute("Direction") or "Vertical"

	-- 是否循环滚动
	self.loop = self.scroller:GetAttribute("Loop") or false

	-- 单元格间距
	self.padding = self.scroller:GetAttribute("Padding") or 5

	-- 网格列数（仅Grid模式有效）
	self.gridColumns = self.scroller:GetAttribute("GridColumns") or 3

	-- 分组支持
	self.groupSize = self.scroller:GetAttribute("GroupSize") or 0
	self.groupPadding = self.scroller:GetAttribute("GroupPadding") or self.padding * 2

	-- 动画效果
	self.animationEnabled = self.scroller:GetAttribute("AnimationEnabled") or false
	self.animationDuration = self.scroller:GetAttribute("AnimationDuration") or 0.3

	-- 单元格模板（必须存在）
	self.cellTemplate = self.scroller:FindFirstChild("CellTemplate")
	if self.cellTemplate then
		self.cellTemplate.Visible = false
	end

	return self
end

-- 初始化UI，移除自动布局，设置滚动属性，连接滚动事件
function InfiniteScroller:InitUI()
	if not self.cellTemplate then
		warn("No CellTemplate found in InfiniteScroller")
		return false
	end

	-- 移除自动添加的UIListLayout或UIGridLayout
	for _, child in ipairs(self.scroller:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end

	-- 根据方向设置滚动属性
	if self.direction == "Vertical" then
		self.scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		self.scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		self.scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	elseif self.direction == "Horizontal" then
		self.scroller.AutomaticCanvasSize = Enum.AutomaticSize.X
		self.scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		self.scroller.ScrollingDirection = Enum.ScrollingDirection.X
	elseif self.direction == "Grid" then
		self.scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		self.scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		self.scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	end

	-- 获取cell尺寸
	self.cellSize = Vector2.new(
		self.cellTemplate.AbsoluteSize.X,
		self.cellTemplate.AbsoluteSize.Y
	)

	-- 连接滚动事件（带节流，防止频繁刷新）
	self.scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local now = os.clock()
		if now - self.lastScrollTime < self.scrollThrottle then return end
		self.lastScrollTime = now
		self:OnScroll()
	end)

	return true
end

-- 初始化数据源
-- @param dataList 数据表
function InfiniteScroller:Init(dataList)
	self.data = dataList or {}
	self:UpdateContentSize()
	return self:RenderVisibleItems()
end

-- 设置刷新回调
-- @param callback function(cell, index, data)
function InfiniteScroller:SetRefreshCallback(callback)
	self.refreshCallback = callback
	return self:RenderVisibleItems()
end

-- 支持变长cell：设置获取cell尺寸的回调
-- @param func function(index, data) -> Vector2
function InfiniteScroller:SetCellSizeByIndex(func)
	self._cellSizeByIndexFunc = func
end

-- 获取指定index的cell尺寸（如未设置则返回默认cellSize）
function InfiniteScroller:GetCellSizeByIndex(index)
	if self._cellSizeByIndexFunc then
		local ok, size = pcall(self._cellSizeByIndexFunc, index, self.data[index])
		if ok and size then
			if typeof(size) == "Vector2" then
				return size
			elseif typeof(size) == "table" and size.X and size.Y then
				return size
			elseif typeof(size) == "table" and size[1] and size[2] then
				return Vector2.new(size[1], size[2])
			end
		end
	end
	return self.cellSize
end

-- 更新内容区域大小（根据数据量和布局方式）
function InfiniteScroller:UpdateContentSize()
	if self.groupSize > 0 then
		-- 分组模式下的内容大小计算
		local groupCount = math.ceil(#self.data / self.groupSize)
		if self.direction == "Vertical" then
			local totalHeight = groupCount * (self.cellSize.Y * self.groupSize + self.groupPadding)
			self.scroller.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
		elseif self.direction == "Horizontal" then
			local totalWidth = groupCount * (self.cellSize.X * self.groupSize + self.groupPadding)
			self.scroller.CanvasSize = UDim2.new(0, totalWidth, 0, 0)
		end
	else
		-- 非分组模式
		if self.direction == "Vertical" then
			-- 支持变长cell：累加每个cell的高度
			local totalHeight = 0
			for i = 1, #self.data do
				local size = self:GetCellSizeByIndex(i)
				totalHeight = totalHeight + (size.Y + self.padding)
			end
			self.scroller.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
		elseif self.direction == "Horizontal" then
			-- 支持变长cell：累加每个cell的宽度
			local totalWidth = 0
			for i = 1, #self.data do
				local size = self:GetCellSizeByIndex(i)
				totalWidth = totalWidth + (size.X + self.padding)
			end
			self.scroller.CanvasSize = UDim2.new(0, totalWidth, 0, 0)
		elseif self.direction == "Grid" then
			local rows = math.ceil(#self.data / self.gridColumns)
			local totalHeight = rows * (self.cellSize.Y + self.padding)
			self.scroller.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
		end 
	end
	return self
end

-- 获取当前可见范围的索引（带缓冲区，避免滚动时闪烁）
function InfiniteScroller:GetVisibleRange()
	local visibleIndices = {}
	local containerSize = self.scroller.AbsoluteSize
	local scrollPosition = self.scroller.CanvasPosition
	local buffer = 2 -- 缓冲单元格数量

	if self.direction == "Vertical" then
		-- 支持变长cell：遍历累加高度，判断可见范围
		local total = 0
		local startIndex, endIndex
		for i = 1, #self.data do
			local size = self:GetCellSizeByIndex(i)
			local cellHeight = size.Y + self.padding
			if not startIndex and total + cellHeight > scrollPosition.Y then
				startIndex = math.max(1, i - buffer)
			end
			if not endIndex and total > scrollPosition.Y + containerSize.Y then
				endIndex = math.min(#self.data, i + buffer)
				break
			end
			total = total + cellHeight
		end
		startIndex = startIndex or 1
		endIndex = endIndex or #self.data
		for i = startIndex, endIndex do
			table.insert(visibleIndices, i)
		end
	elseif self.direction == "Horizontal" then
		-- 支持变长cell：遍历累加宽度，判断可见范围
		local total = 0
		local startIndex, endIndex
		for i = 1, #self.data do
			local size = self:GetCellSizeByIndex(i)
			local cellWidth = size.X + self.padding
			if not startIndex and total + cellWidth > scrollPosition.X then
				startIndex = math.max(1, i - buffer)
			end
			if not endIndex and total > scrollPosition.X + containerSize.X then
				endIndex = math.min(#self.data, i + buffer)
				break
			end
			total = total + cellWidth
		end
		startIndex = startIndex or 1
		endIndex = endIndex or #self.data
		for i = startIndex, endIndex do
			table.insert(visibleIndices, i)
		end
	else
		-- Grid模式暂不支持变长cell
		local itemsPerRow = self.gridColumns
		local rowHeight = self.cellSize.Y + self.padding
		local startPos = scrollPosition.Y
		local endPos = startPos + containerSize.Y

		local startRow = math.max(0, math.floor(startPos / rowHeight) - 1)
		local endRow = math.floor(endPos / rowHeight) + 1

		local startIndex = startRow * itemsPerRow + 1
		local endIndex = endRow * itemsPerRow

		startIndex = math.max(1, startIndex)
		endIndex = math.min(#self.data, endIndex)

		for i = startIndex, endIndex do
			table.insert(visibleIndices, i)
		end
	end

	return visibleIndices
end

-- 滚动事件处理（含循环滚动逻辑）
function InfiniteScroller:OnScroll()
	if self.scrolling then return end

	local newScrollPosition
	if self.direction == "Vertical" then
		newScrollPosition = self.scroller.CanvasPosition.Y
	else
		newScrollPosition = self.scroller.CanvasPosition.X
	end

	-- 循环滚动处理（注意：变长cell时循环滚动不准确，仅适用于等长cell）
	if self.loop and #self.data > 0 then
		local itemSize = self.direction == "Vertical" and 
			(self.cellSize.Y + self.padding) or 
			(self.cellSize.X + self.padding)

		local totalSize = #self.data * itemSize
		local containerSize = self.direction == "Vertical" and 
			self.scroller.AbsoluteSize.Y or 
			self.scroller.AbsoluteSize.X

		-- 滚动到开头，跳转到结尾
		if newScrollPosition < itemSize and self.lastScrollPosition > newScrollPosition then
			self.scrolling = true
			local jumpPosition = totalSize - containerSize * 2
			if self.direction == "Vertical" then
				self.scroller.CanvasPosition = Vector2.new(0, jumpPosition)
			else
				self.scroller.CanvasPosition = Vector2.new(jumpPosition, 0)
			end
			self.scrolling = false
		-- 滚动到结尾，跳转到开头
		elseif newScrollPosition > totalSize - containerSize - itemSize and self.lastScrollPosition < newScrollPosition then
			self.scrolling = true
			local jumpPosition = containerSize
			if self.direction == "Vertical" then
				self.scroller.CanvasPosition = Vector2.new(0, jumpPosition)
			else
				self.scroller.CanvasPosition = Vector2.new(jumpPosition, 0)
			end
			self.scrolling = false
		end
	end

	self.lastScrollPosition = newScrollPosition
	self:RenderVisibleItems()
end

-- 渲染当前可见的单元格（对象池优化）
function InfiniteScroller:RenderVisibleItems()
	local visibleIndices = self:GetVisibleRange()
	local toKeep = {}
	for _, index in ipairs(visibleIndices) do
		toKeep[index] = true
	end

	-- 回收不可见cell到对象池
	for index, cell in pairs(self.activeCells) do
		if not toKeep[index] then
			self.cellPool:GiveBack(cell)
			self.activeCells[index] = nil
		end
	end

	-- 渲染可见cell
	for _, index in ipairs(visibleIndices) do
		if not self.activeCells[index] then
			local cell = self:GetCellFromPool()
			self:PositionCell(cell, index)
			self:RefreshCell(cell, index)
			cell.Visible = true
			cell.LayoutOrder = index
			self.activeCells[index] = cell
		end
	end

	return self
end

-- 从对象池获取cell
function InfiniteScroller:GetCellFromPool()
	return self.cellPool:Get()
end

-- 定位cell（支持分组、网格、方向）
function InfiniteScroller:PositionCell(cell, index)
	if self.groupSize > 0 then
		-- 分组模式定位
		local groupIndex = math.floor((index - 1) / self.groupSize)
		local inGroupIndex = (index - 1) % self.groupSize

		if self.direction == "Vertical" then
			local yPos = groupIndex * (self.cellSize.Y * self.groupSize + self.groupPadding) 
				+ inGroupIndex * (self.cellSize.Y + self.padding)
			cell.Position = UDim2.new(0, 0, 0, yPos)
			cell.Size = UDim2.new(0, self.cellSize.X, 0, self.cellSize.Y)
		elseif self.direction == "Horizontal" then
			local xPos = groupIndex * (self.cellSize.X * self.groupSize + self.groupPadding) 
				+ inGroupIndex * (self.cellSize.X + self.padding)
			cell.Position = UDim2.new(0, xPos, 0, 0)
			cell.Size = UDim2.new(0, self.cellSize.X, 0, self.cellSize.Y)
		elseif self.direction == "Grid" then
			local row = math.floor(inGroupIndex / self.gridColumns)
			local col = inGroupIndex % self.gridColumns
			local xPos = groupIndex * (self.cellSize.X * self.gridColumns + self.groupPadding)
				+ col * (self.cellSize.X + self.padding)
			local yPos = row * (self.cellSize.Y + self.padding)
			cell.Position = UDim2.new(0, xPos, 0, yPos)
			cell.Size = UDim2.new(0, self.cellSize.X, 0, self.cellSize.Y)
		end
	else
		-- 非分组模式
		if self.direction == "Vertical" then
			-- 支持变长cell：累加前面所有cell的高度
			local y = 0
			for i = 1, index - 1 do
				local size = self:GetCellSizeByIndex(i)
				y = y + (size.Y + self.padding)
			end
			cell.Position = UDim2.new(0, 0, 0, y)
			local size = self:GetCellSizeByIndex(index)
			cell.Size = UDim2.new(0, size.X, 0, size.Y)
		elseif self.direction == "Horizontal" then
			-- 支持变长cell：累加前面所有cell的宽度
			local x = 0
			for i = 1, index - 1 do
				local size = self:GetCellSizeByIndex(i)
				x = x + (size.X + self.padding)
			end
			cell.Position = UDim2.new(0, x, 0, 0)
			local size = self:GetCellSizeByIndex(index)
			cell.Size = UDim2.new(0, size.X, 0, size.Y)
		elseif self.direction == "Grid" then
			local row = math.floor((index - 1) / self.gridColumns)
			local col = (index - 1) % self.gridColumns
			cell.Position = UDim2.new(
				0, col * (self.cellSize.X + self.padding),
				0, row * (self.cellSize.Y + self.padding)
			)
			cell.Size = UDim2.new(0, self.cellSize.X, 0, self.cellSize.Y)
		end
	end
	return self
end

-- 刷新指定cell内容（支持动画）
function InfiniteScroller:RefreshCell(cell, index)
	-- 调用用户自定义刷新回调
	if self.refreshCallback then
		self.refreshCallback(cell, index, self.data[index])
	end

	-- 动画效果
	if self.animationEnabled then
		cell.Visible = true
		cell.Size = UDim2.new(0, 0, 0, 0)

		local tweenInfo = TweenInfo.new(
			self.animationDuration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)

		TweenService:Create(
			cell,
			tweenInfo,
			{Size = UDim2.new(1, 0, 1, 0)}
		):Play()
	end

	return self
end

-- 刷新指定索引的cell
function InfiniteScroller:RefreshByIndex(index)
	if self.activeCells[index] then
		self:RefreshCell(self.activeCells[index], index)
	end
	return self
end

-- 滚动到指定索引
-- @param index 目标索引
-- @param instant 是否瞬间跳转
function InfiniteScroller:ScrollToIndex(index, instant)
	index = math.max(1, math.min(index, #self.data))

	if self.groupSize > 0 then
		-- 分组模式下滚动
		local groupIndex = math.floor((index - 1) / self.groupSize)
		if self.direction == "Vertical" then
			local position = groupIndex * (self.cellSize.Y * self.groupSize + self.groupPadding)
			if instant then
				self.scroller.CanvasPosition = Vector2.new(0, position)
			else
				self.scroller:ScrollTo(UDim.new(0, position))
			end
		elseif self.direction == "Horizontal" then
			local position = groupIndex * (self.cellSize.X * self.groupSize + self.groupPadding)
			if instant then
				self.scroller.CanvasPosition = Vector2.new(position, 0)
			else
				self.scroller:ScrollTo(UDim.new(0, position))
			end
		end
	else
		-- 非分组模式
		if self.direction == "Vertical" then
			-- 变长cell下ScrollToIndex只支持跳转到大致位置（精确支持需额外实现）
			local position = 0
			for i = 1, index - 1 do
				local size = self:GetCellSizeByIndex(i)
				position = position + (size.Y + self.padding)
			end
			if instant then
				self.scroller.CanvasPosition = Vector2.new(0, position)
			else
				self.scroller:ScrollTo(UDim.new(0, position))
			end
		elseif self.direction == "Horizontal" then
			local position = 0
			for i = 1, index - 1 do
				local size = self:GetCellSizeByIndex(i)
				position = position + (size.X + self.padding)
			end
			if instant then
				self.scroller.CanvasPosition = Vector2.new(position, 0)
			else
				self.scroller:ScrollTo(UDim.new(0, position))
			end
		elseif self.direction == "Grid" then
			local row = math.ceil(index / self.gridColumns) - 1
			local position = row * (self.cellSize.Y + self.padding)
			if instant then
				self.scroller.CanvasPosition = Vector2.new(0, position)
			else
				self.scroller:ScrollTo(UDim.new(0, position))
			end
		end
	end
	return self
end

-- 更新数据源并刷新显示
function InfiniteScroller:UpdateData(newData)
	self.data = newData or {}
	self:UpdateContentSize()
	self:RenderVisibleItems()
	self:CleanupPool() -- 清理多余对象池
	return self
end

-- 清理对象池，保留最大maxPoolSize个cell
function InfiniteScroller:CleanupPool(maxPoolSize)
	-- Pool_Tool不需要手动清理，Destroy时会自动销毁多余对象
end

-- 销毁所有cell与对象池，释放资源
function InfiniteScroller:Destroy()
	self.activeCells = {}
	if self.cellPool then
		self.cellPool:Destroy()
		self.cellPool = nil
	end
	setmetatable(self, nil)
end

-- 构造器入口
-- @param scroller 必须为ScrollingFrame
return function(scroller)
	if scroller == nil then error("需要传入滑动栏") end
	if scroller.ClassName ~= "ScrollingFrame" then error("传入参数并非滑动栏") end

	return InfiniteScroller._New(scroller)
end