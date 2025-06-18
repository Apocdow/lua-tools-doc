--- Table_OrderBy_Tool: 排序函数链式组合工具
--- 支持多条件排序函数的链式组合与执行
---@class Table_OrderBy_Tool
---@field _orderBy_cache table 排序函数缓存，防止重复添加
---@field _orderBy_list table 排序函数链表
---@field _target_tab table? 目标表
local Table_OrderBy_Tool = {}
Table_OrderBy_Tool.__index = Table_OrderBy_Tool

--- 构造函数
---@return Table_OrderBy_Tool Table_OrderBy_Tool实例
function Table_OrderBy_Tool.new()
    local obj = setmetatable({},Table_OrderBy_Tool)
    obj._orderBy_cache = {} -- 排序函数缓存，防止重复添加
    obj._orderBy_list = {}  -- 排序函数链表
    obj._target_tab = nil   -- 目标表
    return obj
end

--- 设置目标表
---@param _tab table 目标表
---@return Table_OrderBy_Tool self
function Table_OrderBy_Tool:SetTargetTable(_tab)
    if _tab ~= nil and type(_tab) ~= 'table' then
        error("Table_OrderBy_Tool:SetTargetTable传入参数需要是表")
        return
    end
    self._target_tab = _tab
    return self
end

--- 数值比较器
---@param a number|nil 需要比较的数值
---@param b number|nil 需要比较的数值
---@return number 0表示相等，1表示a排在b前，-1表示a排在b后
function Table_OrderBy_Tool.Num_Comparator(a,b)
    -- 如果两个数值相等，返回0
    if a == b then return 0 end
    -- 如果其中一个数值为nil，另一个不为nil，则a为nil排后
    if a == nil or b == nil then return (a == nil) and -1 or 1 end
    -- 如果a或b不是数字类型，则抛出错误
    if type(a) ~= "number" or type(b) ~= "number" then
        error("Num_Comparator: a and b must be numbers")
    end
    -- a小于b返回-1，否则返回1
    return a < b and -1 or 1
end

--- 布尔值比较器
---@param a boolean|nil 需要比较的布尔值
---@param b boolean|nil 需要比较的布尔值
---@return number 0表示相等，1表示a排在b前，-1表示a排在b后
function Table_OrderBy_Tool.Bool_Comparator(a,b)
    if (not a) == (not b) then return 0 end
    return a and 1 or -1
end

--- 添加排序函数到链表
---@param _func fun(a:any, b:any, is_descending:boolean):number 排序函数 (function(a, b, is_descending) return 1/-1/0 end)
---@return Table_OrderBy_Tool self
function Table_OrderBy_Tool:OrderBy(_func)
    if type(_func) ~= 'function' then
        error("Table_OrderBy_Tool:OrderBy传入参数需要是function(a,b)return 1/-1/0 end")
        return self
    end
    if self._orderBy_cache[_func] then
        print("排序方法重复，此项拒绝加入列表")
        return self
    end
    self._orderBy_list[#self._orderBy_list+1] = _func
    self._orderBy_cache[_func] = true
    return self
end

--- 清空排序函数链表和目标表
---@return Table_OrderBy_Tool self
function Table_OrderBy_Tool:Clear()
    self._orderBy_list = {}
    self._target_tab = nil
    self._orderBy_cache = {}
    return self
end

--- 对表进行排序
---@param _tab table? 目标表（可选，默认用SetTargetTable设置的表）
---@param _is_descending boolean? 是否降序（传递给排序函数）
---@return table 返回排序后的列表
function Table_OrderBy_Tool:Sort(_tab,_is_descending)
    _tab = _tab or self._target_tab
    if _tab == nil then
        error("排序目标列表为空")
        return
    end
    -- 多条件排序，依次调用排序函数链表
    table.sort(_tab,function(_a,_b)
        for _,check_func in ipairs(self._orderBy_list) do
            local res = check_func(_a,_b,_is_descending)
            if res ~= 0 then return res == 1 end
        end
        return false
    end)
    return _tab
end

--- 销毁对象，释放资源
function Table_OrderBy_Tool:Destroy()
    self._orderBy_cache = nil
    self._orderBy_list = nil
    self._target_tab = nil
end

--- 工厂调用支持，允许Table_OrderBy_Tool()直接创建实例
---@return Table_OrderBy_Tool Table_OrderBy_Tool实例
setmetatable(Table_OrderBy_Tool,{__call = function(_tab)
    return _tab.new()
end})

return Table_OrderBy_Tool