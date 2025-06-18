-- 创建日期: 
-- 功能描述: 实现一个迭代器函数的封装, 并带有后缀操作函数. 具体用法见单元测试.
-----------------------------------------------------------------------------------------
local Iterator = { }
local meta = {
    __index = Iterator,
}

--[[
将普通表包装为带有迭代器功能的对象
@param t table 需要包装的表
@return table 迭代器对象
]]
local function AsIter(t)
    setmetatable(t, meta)
    return t
end

--[[
创建一个新的迭代器对象
@param t table 需要遍历的表
@return Iterator 迭代器对象
]]
function Iterator.New(t)
    assert(type(t) == 'table')
    local iter = { }
    local k
    local next, iterTable = pairs(t)
    iter.iterator = function()
        local v
        k, v = next(iterTable, k)
        return k, v
    end
    return AsIter(iter)
end



-------------------------------------------------------------------------------
-- 迭代器串联
-------------------------------------------------------------------------------

--[[
对每个元素应用函数f，返回新的k,v
@param f function(k, v) -> k, v
@return self 支持链式调用
]]
function Iterator:Map(f)
    local iter = self.iterator
    self.iterator = function()
        local k, v = iter()
        if k == nil and v == nil then return end
        return f(k, v)
    end
    return self
end

--[[
简版map，把所有value映射到value[key1][key2]...
@param ... string 可变参数，依次访问value的key
@return self 支持链式调用
]]
function Iterator:Select(...)
    local iter = self.iterator
    local t = { ... }
    self.iterator = function()
        local k, v = iter()
        if k == nil and v == nil then return end
        for _, key in pairs(t) do v = v[key] end
        return k, v
    end
    return self
end

--[[
过滤迭代器中的元素，只保留满足条件的元素
@param f function(k, v) -> boolean 返回true保留，false跳过
@return self 支持链式调用
]]
function Iterator:Filter(f)
    local iter = self.iterator
    self.iterator = function()
        local k, v
        repeat
            k, v = iter()
            if k == nil and v == nil then return end
        until f(k, v)
        return k, v
    end
    return self
end

--[[
反转迭代器的遍历顺序
注意：Lua的table无序，只有顺序表（数组）反转才有意义
@return self 支持链式调用
]]
function Iterator:Reverse()
    local iter = self.iterator
    
    local keys = { }
    local values = { }
    local k, v
    local i = 0
    repeat
        k, v = iter()
        i = i + 1
        keys[i] = k
        values[i] = v
    until k == nil and v == nil
    
    local cnt = i
    
    i = 0
    self.iterator = function()
        i = i + 1
        return keys[cnt - i], values[cnt - i]
    end
    
    return self
end

--[[
只返回每个元素的value
@return self 支持链式调用
]]
function Iterator:Values()
    local iter = self.iterator
    self.iterator = function()
        local k, v = iter()
        return v
    end
    return self
end


--[[
将另一个迭代器串联到当前迭代器后面
@param otherIter Iterator 另一个迭代器
@return self 支持链式调用
]]
function Iterator:Concat(otherIter)
    if self.concatList then
        table.insert(self.concatList, 1, otherIter.iterator)     -- 插到最前面.
        return self
    end
    self.concatList = { [1] = otherIter.iterator }
    local curIter = self.iterator
    self.iterator = function()
        local k, v = curIter()
        while k == nil and v == nil do       -- 当前 iterator 消耗完毕, 开始下一个迭代器消耗.
            curIter = table.remove(self.concatList)
            if curIter == nil then return nil, nil end
            k, v = curIter()            -- 取有效元素.
        end
        return k, v
    end
    return self
end

--[[ Iterator:Concat 的测试代码.
    
package.loaded["Common/Iterator"] = nil
local a = { 11, 12, 13 }
local b = { 21, 22 }
local t = Iter(a):Concat(Iter(b))
local g = Iter(b):Concat(Iter(a))
local h = Iter({ }):Concat(t):Concat(g)
for i, j in h:Iter() do
    error(":: %s %s", i, j)
end

]]


--[[
将key和value都转为字符串
@return self 支持链式调用
]]
function Iterator:StrKeyValue()
    local iter = self.iterator
    self.iterator = function()
        local k, v = iter()
        return tostring(k), tostring(v)
    end
    return self
end


--[[
将key转为字符串
@return self 支持链式调用
]]
function Iterator:StrKey()
    local iter = self.iterator
    self.iterator = function()
        local k, v = iter()
        return tostring(k), v
    end
    return self
end

--[[
将value转为字符串
@return self 支持链式调用
]]
function Iterator:StrValue()
    local iter = self.iterator
    self.iterator = function()
        local k, v = iter()
        return k, tostring(v)
    end
    return self
end



-------------------------------------------------------------------------------
-- 迭代器消耗
-------------------------------------------------------------------------------

--[[
找到第一个满足条件的k-v对
@param f function(k, v) -> boolean
@return k, v 满足条件的k,v
]]
function Iterator:Find(f)
    local iter = self.iterator
    local k, v
    while true do
        k, v = iter()
        if k == nil and v == nil then return end
        if f(k, v) then return k, v end
    end
end

--[[
找到第一个满足条件的k-v对并返回value
@param f function(k, v) -> boolean
@return v 满足条件的value
]]
function Iterator:FindValue(f)
    local iter = self.iterator
    local k, v
    while true do
        k, v = iter()
        if k == nil and v == nil then return end
        if f(k, v) then return v end
    end
end

--[[
将迭代器内容转为table
@return table
]]
function Iterator:ToTable()
    local res = { }
    for k, v in self:Iter() do
        res[k] = v
    end
    return res
end

--[[
将所有value组成数组
@return table 数组
]]
function Iterator:ToList()
    local res = { }
    local i = 0
    for k, v in self:Iter() do
        i = i + 1
        res[i] = v
    end
    return res
end

--[[
统计迭代器元素个数
@return number 元素数量
]]
function Iterator:Count()
    local c = 0
    for k, v in self:Iter() do
        c = c + 1
    end
    return c
end

--[[
获取迭代函数，可用于for循环
@return function 迭代器函数
]]
function Iterator:Iter()
    local iter = self.iterator
    self.iterator = nil
    return iter
end

--[[
获取第一个k-v对
@return k, v
]]
function Iterator:First()
    return self:Iter()()
end

--[[
获取第一个value
@return v
]]
function Iterator:FirstValue()
    local _, v = self:Iter()()
    return v
end

--[[
取前n个元素，返回value数组
@param n number
@return table
]]
function Iterator:Take(n)
    local res = { }
    for i = 1, n do
        local _, v = self:Iter()
        res[i] = v
    end
    return res
end

--[[
聚合操作，对每个元素调用f(a, k, v)，a为累加器
@param a any 初始值
@param f function(a, k, v) -> a
@return a 聚合结果
]]
function Iterator:Aggregate(a, f)
    for k, v in self:Iter() do
        if a ~= nil then
            a = f(a, k, v)
        else
            f(a, k, v)
        end
        
    end
    return a
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


-- local arr = {
--     a = 1,
--     b = 2,
--     c = 3,
--     d = 4,
--     e = 5,
-- }

-- local p = Iterator.New(arr):ToTable()
-- assert(p.a == 1)
-- assert(p.b == 2)
-- assert(p.c == 3)
-- assert(p.d == 4)
-- assert(p.e == 5)

-- local g = Iterator.New(arr)
--     :Map(function(k, v) return k, v + 1 end)
--     :ToTable()
-- assert(g.a == 2)
-- assert(g.b == 3)
-- assert(g.c == 4)
-- assert(g.d == 5)
-- assert(g.e == 6)

-- local w = Iterator.New(arr)
--     :Filter(function(k, v) return v % 2 == 0 end)
--     :ToTable()
-- assert(w.a == nil)
-- assert(w.b == 2)
-- assert(w.c == nil)
-- assert(w.d == 4)
-- assert(w.e == nil)

-- local r = Iterator.New(arr)
--     :Map(function(k, v) return v, k end)
--     :ToTable()
-- assert(r[1] == 'a')
-- assert(r[2] == 'b')
-- assert(r[3] == 'c')
-- assert(r[4] == 'd')
-- assert(r[5] == 'e')

-- local c = Iterator.New(arr):Count()
-- assert(c == 5)

-- local c = Iterator.New({ 1, 3, 5, 7, 9 }):Aggregate(0, function(a, k, v) return a + k * v end)
-- assert(c == 1 * 1 + 2 * 3 + 3 * 5 + 4 * 7 + 5 * 9)

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

--[[

local gset = { }
for i = 1, 10000000 do
    gset[i] = (i % 3 == 0 and 999) or (i % 3 == 1 and 998) or 997
end

print(
    gset[1], gset[2], gset[3],
    gset[4], gset[5], gset[6],
    gset[7], gset[8], gset[9]
)

-- map
local begin = os.clock()
for i = 1, 10000000 do
    gset[i] = 99 - gset[i]
end
local total = os.clock()
print('map ordinary', total)

local begin = os.clock()
for i, _ in Iterator.New(gset):Iter(), nil, nil do
    gset[i] = 99 - gset[i]
end
local total = os.clock()
print('map iterator', total)

local begin = os.clock()
for i, _ in pairs(Iterator.New(gset):ToTable()) do
    gset[i] = 99 - gset[i]
end
local total = os.clock()
print('map table', total)

-- i7-7700
-- map ordinary    1.291
-- map iterator    2.447
-- map table       4.078

-- i7-9700K
-- map ordinary    0.751
-- map iterator    1.418
-- map table       2.648

]]--


return Iterator.New
