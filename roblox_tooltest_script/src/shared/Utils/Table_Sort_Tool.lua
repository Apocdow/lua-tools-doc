--- Table_Sort_Tool: 表排序工具类
--- 支持多条件排序、自定义排序函数、升降序切换等功能
--- 用于对表（table）进行灵活的多条件排序，适用于复杂的数据排序场景。
---@class Table_Sort_Tool
---@field order_config_tab table 排序配置表
---@field sort_func_tab table 排序类型到排序函数的映射表
---@field is_descending boolean 是否降序
---@field orderBy_tool any 内部OrderBy工具
local Table_Sort_Tool = {}
Table_Sort_Tool.__index = Table_Sort_Tool

Table_Sort_Tool.IsDescending = false -- 是否降序排序，默认升序

local table_orderBy_tool = require(script.Parent:WaitForChild("Table_OrderBy_Tool"))

--- 构造函数
---@param order_config_tab table 排序配置表（包含head/body/tail等阶段的排序函数列表）
---@param sort_func_tab table 排序类型到排序函数的映射表
---@param is_descending boolean 是否降序
---@return Table_Sort_Tool Table_Sort_Tool实例
function Table_Sort_Tool.new(order_config_tab, sort_func_tab, is_descending)
    local obj = setmetatable({}, Table_Sort_Tool)
    -- 链式设置配置表、排序函数表、降序标志，并初始化OrderBy工具
    return obj:SetOrderConfigTab(order_config_tab)
        :SetSortFuncTab(sort_func_tab)
        :SetIsDescending(is_descending):GetOrderByTool()
end

--- 初始化OrderBy工具（每次调用会销毁旧的OrderBy工具）
---@return Table_Sort_Tool self
function Table_Sort_Tool:GetOrderByTool()
    if self.orderBy_tool then
        self.orderBy_tool:Destroy()
    end
    self.orderBy_tool = table_orderBy_tool()
    return self
end

--- 数值比较器
---@param a number|nil 需要比较的数值
---@param b number|nil 需要比较的数值
---@param is_descending boolean 是否降序
---@return number 0表示相等，1表示a排在b前，-1表示a排在b后
function Table_Sort_Tool.Num_Comparator(a,b,is_descending)
    -- 如果两个数值相等，返回0
    if a == b then return 0 end
    -- 如果其中一个数值为nil，另一个不为nil，则根据is_descending返回相应的结果
    if a == nil or b == nil then return (a == nil and is_descending) and -1 or 1 end
    -- 如果a或b不是数字类型，则抛出错误
    if type(a) ~= "number" or type(b) ~= "number" then
        error("Num_Comparator: a and b must be numbers")
    end
    -- 如果a小于b，则根据is_descending返回相应的结果
    if a < b then
        return (is_descending) and -1 or 1
    else
        -- 如果a大于b，则根据is_descending返回相应的结果
        return (is_descending) and 1 or -1
    end
end

--- 布尔值比较器
---@param a boolean|nil 需要比较的布尔值
---@param b boolean|nil 需要比较的布尔值
---@param is_descending boolean 是否降序
---@return number 0表示相等，1表示a排在b前，-1表示a排在b后
function Table_Sort_Tool.Bool_Comparator(a,b,is_descending)
    -- 布尔值相等
    if (not a) == (not b) then return 0 end
    -- a为true排前还是排后取决于is_descending
    if a then
        return (is_descending) and -1 or 1
    else
        return (is_descending) and 1 or -1
    end
end

--- 设置是否降序
---@param _is_descending boolean 是否降序
---@return Table_Sort_Tool self
function Table_Sort_Tool:SetIsDescending(_is_descending)
    -- 若未传入参数则保持原值，否则更新
    self.is_descending = (_is_descending == nil and {self.is_descending} or {_is_descending})[1]
    return self
end

--- 设置排序配置表
---@param _order_config_tab table 排序配置表
---@return Table_Sort_Tool self
function Table_Sort_Tool:SetOrderConfigTab(_order_config_tab)
    if not _order_config_tab or type(_order_config_tab) ~= "table" then
        error("order_config_tab 必须为table类型")
    end
    self.order_config_tab = _order_config_tab
    return self
end

--- 设置排序函数表
---@param _sort_func_tab table 排序函数表
---@return Table_Sort_Tool self
function Table_Sort_Tool:SetSortFuncTab(_sort_func_tab)
    if not _sort_func_tab or type(_sort_func_tab) ~= "table" then
        error("sort_func_tab 必须为table类型")
    end
    self.sort_func_tab = _sort_func_tab
    return self
end

--- 获取是否降序
---@return boolean 是否降序
function Table_Sort_Tool:GetIsDescending()
    return self.is_descending
end

--- 设置某个排序类型的排序函数
---@param _sort_type string 排序类型
---@param _func fun(a:any, b:any, is_descending:boolean):number 排序函数
---@return Table_Sort_Tool self
function Table_Sort_Tool:SetSortFunc(_sort_type, _func)
    if not _func or type(_func) ~= "function" then
        error("_func 必须为function类型")
    end
    self.sort_func_tab[_sort_type] = _func
    return self
end

--- 按照指定的排序配置列表依次添加排序函数
---@param _target_sort_config_list table 排序类型列表
---@return Table_Sort_Tool self
function Table_Sort_Tool:_Loop_OrderBy(_target_sort_config_list)
    if _target_sort_config_list then
        for _,check_type in ipairs(_target_sort_config_list) do
            self:_OrderBy(self.sort_func_tab[check_type])
        end
    end
    return self
end

--- 添加单个排序函数到OrderBy工具
---@param _func fun(a:any, b:any, is_descending:boolean):number 排序函数
---@return Table_Sort_Tool self
function Table_Sort_Tool:_OrderBy(_func)
    if _func then
        self.orderBy_tool:OrderBy(_func)
    end
    return self
end

--- 对表进行排序
---@param _tab table 需要排序的表
---@param _sort_type string 排序类型
---@param _is_descending boolean? 是否降序（可选）
---@return table 返回排序后的列表
function Table_Sort_Tool:Sort(_tab, _sort_type , _is_descending)
    if not _tab or type(_tab) ~= "table" then
        error("输入必须为table类型")
    end
    if not _sort_type or self.sort_func_tab[_sort_type] == nil then
        error("_sort_type 必须是sort_func_tab中的有效key")
    end
    _is_descending = (_is_descending == nil and {self.is_descending} or {_is_descending})[1]
    
    -- 清空OrderBy工具，依次添加head/body/tail阶段的排序函数
    self.orderBy_tool:Clear()
    return self:_Loop_OrderBy(self.order_config_tab.head)
        :OrderBy(self.sort_func_tab[_sort_type])
        :_Loop_OrderBy(self.order_config_tab.body)
        :_Loop_OrderBy(self.order_config_tab.tail).orderBy_tool:Sort(_tab,_is_descending)
end

--- 销毁函数
function Table_Sort_Tool:Destroy()
    self.order_config_tab = nil
    self.sort_func_tab = nil
    if self.orderBy_tool then
        self.orderBy_tool:Destroy()
        self.orderBy_tool = nil
    end
end

--- 函数工厂化
--- 允许通过Table_Sort_Tool(...)直接创建实例
---@param order_config_tab table 排序配置表
---@param sort_func_tab table 排序函数表
---@param is_descending boolean? 是否降序（可选）
---@return Table_Sort_Tool Table_Sort_Tool实例
setmetatable(Table_Sort_Tool, {
    __call = function(cls, order_config_tab, sort_func_tab, is_descending)
        if not order_config_tab or type(order_config_tab) ~= "table" then
            error("order_config_tab 必须为table类型")
        end
        if not sort_func_tab or type(sort_func_tab) ~= "table" then
            error("sort_func_tab 必须为table类型")
        end
        -- is_descending强制转为布尔值
        return cls.new(order_config_tab, sort_func_tab,not not is_descending)
    end
})

return Table_Sort_Tool

--[=[

Table_Sort_Tool 使用示例
------------------------
该工具类用于对表进行多条件排序，支持自定义排序函数和升降序切换。

示例用法：
local Sort_Type_Enum = {
    Level = 'level_sort',
    Atk = 'atk_sort',
    Def = 'def_sort',
    Hp = 'hp_sort',
    IsActive = 'active_sort',
}
local order_config = {
    head = {Sort_Type_Enum.IsActive}, -- 先按激活状态排序
    body = {
        Sort_Type_Enum.Level,
        Sort_Type_Enum.Atk,
        Sort_Type_Enum.Def,
        Sort_Type_Enum.Hp
    },
    tail = {}
}
local sort_funcs = {
    [Sort_Type_Enum.IsActive] = function(_a,_b,_idescending) 
        return Table_Sort_Tool.Bool_Comparator(_a.IsActive, _b.IsActive, false) 
        -- 注意这里因为希望未解锁的对象永远排在后面，不受升降序影响。
        -- 所以 IsActive 的 _idescending 是固定布尔值，
        -- 如果需要控制升降序，可以将 false 改为 _idescending
    end,
    [Sort_Type_Enum.Level] = function(_a,_b,_idescending) 
        return Table_Sort_Tool.Num_Comparator(_a.Level, _b.Level, _idescending)
    end,
    [Sort_Type_Enum.Atk] = function(_a,_b,_idescending) 
        return Table_Sort_Tool.Num_Comparator(_a.Atk, _b.Atk, _idescending)
    end,
    [Sort_Type_Enum.Def] = function(_a,_b,_idescending) 
        return Table_Sort_Tool.Num_Comparator(_a.Def, _b.Def, _idescending)
    end,
    [Sort_Type_Enum.Hp] = function(_a,_b,_idescending) 
        return Table_Sort_Tool.Num_Comparator(_a.Hp, _b.Hp, _idescending)
    end,
}
local sorter = require(game:GetService('ReplicatedStorage'):WaitForChild('Utils'):WaitForChild('Table_Sort_Tool'))(order_config, sort_funcs, true)
local my_table = {
    {Level = 10, Atk = 100, Def = 50, Hp = 200, IsActive = true},
    {Level = 5, Atk = 80, Def = 30, Hp = 150, IsActive = false},
    {Level = 8, Atk = 90, Def = 40, Hp = 180, IsActive = true},
}
-- 使用排序工具对表进行排序
sorter:Sort(my_table, Sort_Type_Enum.Level,true)
-- my_table 现在已经按照 Level 降序排序

print("Sorted Table: ", my_table)

-- 输出结果示例
-- Sorted Table:  {
--     {Level = 10, Atk = 100, Def = 50, Hp = 200, IsActive = true},
--     {Level = 8, Atk = 90, Def = 40, Hp = 180, IsActive = true},
--     {Level = 5, Atk = 80, Def = 30, Hp = 150, IsActive = false}
-- }

]=]