---@class Pool
---@field No_Use_Head PoolLink 未使用对象链表头节点
---@field Used_Head PoolLink 已使用对象链表头节点
---@field Used_Tail PoolLink 已使用对象链表尾节点
---@field Used_Cache table<any, PoolLink> 对象到链表节点的映射表
---@field Size number 当前池中对象数量
---@field _instanc_func fun(_obj_model:any):any 实例化对象的函数
---@field _reset_func fun(obj:any) 重置对象的函数
---@field _give_back_func fun(obj:any) 归还对象的函数
---@field _destroy_func fun(obj:any) 销毁对象的函数
---@field MAX_POOL_SIZE number 最大池容量，-1表示无限制
local Pool = {}
Pool.__index = Pool

local PoolLink = require(script.Parent.PoolLink)

--- 创建一个新的对象池
---@param _obj any 类型检查对象类型
---@param _instanc_func fun(_obj_model:any):any 实例化对象的函数
---@param _reset_func fun(obj:any) 重置对象的函数
---@param _give_back_func fun(obj:any) 归还对象的函数
---@param _destroy_func fun(obj:any) 销毁对象的函数
---@param _max_pool_size number? 池的最大大小，默认为 -1（无限制，可选）
---@return Pool 新的对象池
function Pool.new(_obj, _instanc_func, _reset_func, _give_back_func, _destroy_func, _max_pool_size)
    local self = setmetatable({}, Pool)
    self.No_Use_Head = PoolLink.new()
    self.Used_Head = PoolLink.new()
    self.Used_Tail = self.Used_Head
    self.Used_Cache = {}
    self.Size = 0
    self._obj_type = typeof(_obj)
    self._obj_model = _obj
    self._instanc_func = _instanc_func
    self._reset_func = _reset_func
    self._give_back_func = _give_back_func
    self._destroy_func = _destroy_func
    self.MAX_POOL_SIZE = _max_pool_size or -1
    return self
end

--- 获取当前池中对象数量
---@return number 池中对象数量
function Pool:Count()
    return self.Size
end

--- 重置对象池，销毁所有未使用和已使用的对象，并清空链表
function Pool:Reset()
    while self.No_Use_Head and self.No_Use_Head.next do
        self.No_Use_Head.next:Destroy(self._destroy_func)
    end
    self.No_Use_Head = nil
    while self.Used_Head and self.Used_Head.next do
        self.Used_Head.next:Destroy(self._destroy_func)
    end
    self.Used_Head = nil
    self.Used_Tail = nil
    self.Size = 0
end

--- 获取一个对象
---@param _is_aotu_give_up_old boolean? 是否自动归还最旧对象以获取新对象（池满时，可选）
---@return any 可用对象或nil
function Pool:Get(_is_aotu_give_up_old)
    if self.No_Use_Head.next then
        local obj,nil_link = self.No_Use_Head.next:Pop()
        if not obj then
            error("Pool:Get - 没有可用对象，返回 nil" .. tostring(self._obj_model.Name))
            return nil
        end
        self:LinkToUsed(nil_link)
        self._reset_func(obj)
        return obj
    else
        if self.MAX_POOL_SIZE == -1 or self.Size < self.MAX_POOL_SIZE then
            local obj = self._instanc_func(self._obj_model)
            if not obj then
                error("Pool:Get - _instanc_func 返回了 nil" .. tostring(self._obj_model.Name))
                return nil
            end
            self._reset_func(obj)
            local new_link = PoolLink.new(obj)
            self.Used_Cache[obj] = new_link
            self:LinkToUsed(new_link)
            self.Size = self.Size + 1
            return obj
        elseif _is_aotu_give_up_old then
            if self.Used_Tail ~= self.Used_Head then
                -- print("Pool:Get - 池已达到最大容量限制，自动归还旧对象:", self.Used_Tail.obj.Name)
                -- self:DebugPrintUsed()
                self:GiveBack(self.Used_Tail.obj)
                -- 归还后重新获取对象
                return  self:Get()
            else
                -- print("Pool:Get - 池已达到最大容量限制，且没有旧对象可归还")
                return nil
            end
        else
            -- print("Pool:Get - 池已达到最大容量限制")
            return nil
        end
    end
end

--- 归还一个对象到对象池
---@param _obj any 需要归还的对象
function Pool:GiveBack(_obj)
    local cache_link = self.Used_Cache[_obj]
    if cache_link == nil then
        error("Pool:GiveBack - 该对象不属于此池")
        return
    end
    if not self.Used_Head then
        error("Pool:GiveBack - 当前没有正在使用的对象，无法归还")
        return
    end
    self._give_back_func(_obj)

    if cache_link == self.Used_Tail then
        self.Used_Tail = cache_link.prev
    end
    
    cache_link:Pop()

    self:LinkToNoUse(cache_link)

end

--- 将_link插入到_to_link之后
---@param _link PoolLink 需要插入的节点
---@param _to_link PoolLink 目标节点
function Pool:LinkTo(_link,_to_link)
    if not _link or not _link.obj then
        error("Pool:LinkTo - 链接无效或对象为空")
        return
    end
    local first_used_link = _to_link.next
    _link.next = first_used_link
    _link.prev = _to_link
    _to_link.next = _link
    if first_used_link then
        first_used_link.prev = _link
    end
end

--- 将链接的对象添加到已使用的链表中
---@param _link PoolLink 要添加的链接对象
function Pool:LinkToUsed(_link)
    if not _link or not _link.obj then
        error("Pool:LinkToUsed - 链接无效或对象为空")
        return
    end
    if self.Used_Head == nil then
        self.Used_Head = PoolLink.new()
    end
    self:LinkTo(_link, self.Used_Head)
    if _link.next == nil then
        self.Used_Tail = _link
    end
end

--- 将链接的对象添加到未使用的链表中
---@param _link PoolLink 要添加的链接对象
function Pool:LinkToNoUse(_link)
    if not _link or not _link.obj then
        error("Pool:LinkToNoUse - 链接无效或对象为空")
        return
    end
    if self.No_Use_Head == nil then
        self.No_Use_Head = PoolLink.new()
    end
    self:LinkTo(_link, self.No_Use_Head)
end

--- 销毁对象池，释放所有资源
function Pool:Destroy()
    self:Reset()
    self._instanc_func = nil
    self._reset_func = nil
    self._give_back_func = nil
    self._destroy_func = nil
    self._obj_type = nil
    self._obj_model = nil
end

--- 打印当前已使用链表中的对象名称，便于调试
function Pool:DebugPrintUsed()
    local cur = self.Used_Head.next
    local str = {}
    while cur do
        table.insert(str, tostring(cur.obj and cur.obj.Name or "nil"))
        cur = cur.next
    end
    warn("Used链表:", table.concat(str, " -> "))
end

return Pool