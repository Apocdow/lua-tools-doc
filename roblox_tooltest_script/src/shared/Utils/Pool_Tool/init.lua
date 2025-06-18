--- 对象池工具模块
--- 提供对象池的创建、获取、归还、重置和销毁等功能，支持最大池容量限制。
--- 适用于需要频繁复用对象以减少GC压力的场景。
local CreatePoolTool= {}

local Pool = require(script:WaitForChild("Pool"))


--- 创建一个新的对象池
---@param _obj any 类型检查对象类型
---@param _instanc_func fun(_obj_model:any):any 实例化对象的函数
---@param _reset_func fun(obj:any) 重置对象的函数
---@param _give_back_func fun(obj:any) 归还对象的函数
---@param _destroy_func fun(obj:any) 销毁对象的函数
---@param _max_pool_size number? 池的最大大小，默认为 -1（无限制，可选）
---@return Pool 新的 Pool 对象或nil
function CreatePoolTool.CreatePool(_obj, _instanc_func,_reset_func,_give_back_func,_destroy_func,_max_pool_size)
    if _obj == nil then
        error("CreatePoolTool:CreatePool - _obj 不能为空")
        return nil
    end

    if _instanc_func == nil then
        error("CreatePoolTool:CreatePool - _instanc_func 不能为空")
        return nil
    end
    if _reset_func == nil then
        error("CreatePoolTool:CreatePool - _reset_func 不能为空")
        return nil
    end
    if _give_back_func == nil then
        error("CreatePoolTool:CreatePool - _give_back_func 不能为空")
        return nil
    end
    local pool = Pool.new(_obj, _instanc_func, _reset_func, _give_back_func, _destroy_func, _max_pool_size)
    if not pool then
        error("CreatePoolTool:CreatePool - 创建对象池失败")
        return nil
    end
    return pool
end

return CreatePoolTool.CreatePool

--[=[
local pool = CreatePoolTool.CreatePool(
    MyObject, -- 池中对象的模板
    function(_obj_model) return MyObject.new() end, -- 池中对象的实例化函数
    function(obj) obj:Reset() end, -- 池中对象的重置函数
    function(obj) obj:GiveBack() end, -- 池中对象的归还函数
    function(obj) obj:Destroy() end, -- 池中对象的销毁函数
    10 -- 池的最大大小，默认为 -1（无限制）
)
pool:Get() -- 获取一个对象
pool:Get(true) -- 获取一个对象，如果池满则自动归还最旧对象
pool:GiveBack(obj) -- 归还对象
pool:Reset() -- 重置池
pool:Destroy() -- 销毁池
--]=]