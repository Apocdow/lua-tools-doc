---@class PoolLink
---@field obj any 节点持有的对象
---@field prev PoolLink? 前一个节点
---@field next PoolLink? 后一个节点
--- 链表节点结构，用于维护对象池的链表结构。
local PoolLink = {}
PoolLink.__index = PoolLink

--- 创建一个新的PoolLink节点
---@param _obj any 节点持有的对象
---@return PoolLink 新的PoolLink节点
function PoolLink.new(_obj)
    local link = setmetatable({}, PoolLink)
    link.obj = _obj
    link.prev = nil
    link.next = nil
    return link
end

--- 从链表中弹出当前节点，并断开与前后节点的连接
---@return any 节点持有的对象, PoolLink 当前节点自身
function PoolLink:Pop()
    if self.prev then
        self.prev.next = self.next
    end
    if self.next then
        self.next.prev = self.prev
    end
    self.prev = nil
    self.next = nil
    return self.obj,self
end

--- 销毁节点持有的对象，并从链表中移除当前节点
---@param _destroy_func fun(obj:any)? 销毁对象的回调函数（可选）
function PoolLink:Destroy(_destroy_func)
    if self.obj then
        if _destroy_func then
            _destroy_func(self.obj)
        else
            error("PoolLink:Destroy - 没有提供销毁函数，无法销毁对象")
        end
    end
    self:Pop()
end

return PoolLink