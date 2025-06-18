--- ManagerBase: 所有Manager的基类，统一接口
---@class ManagerBase
---@field MGR_TYPE 'S'|'C'|'B' -- 'server'|'client'|'shared'
---@field DEPENDS string[]
local ManagerBase = {}
ManagerBase.MGR_TYPE_ENUM = {
    Globally = "Globally",
    Normal = "Normal",
    Leaves = "Leaves"
}
ManagerBase.__index = ManagerBase

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedManagersFolder = ReplicatedStorage:FindFirstChild("Managers")
local RunService = game:GetService("RunService")

--- 标识类型，派生类需覆盖
ManagerBase.__MGR_OWNER__ = 'S'  -- 'S'|'C'|'B' -- 'server'|'client'|'shared'
--- 依赖列表，派生类可覆盖
ManagerBase.__DEPENDS__ = {}
ManagerBase.__MGR_TYPE__ = "Normal"  -- 新增类型字段，默认Normal

---
--- 创建一个新的Manager实例
--- @param _module ModuleScript 模块脚本实例
--- @return table 新的Manager实例
function ManagerBase:__CreateNewManager__(_module)
    -- 创建新表并设置元表为ManagerBase
    local newManager = setmetatable({}, self)
    if _module.Parent == SharedManagersFolder then
        newManager.__MGR_OWNER__ = "B" 
    else
        newManager.__MGR_OWNER__ = RunService:IsServer() and "S" or "C" -- 根据运行环境设置类型
    end
    newManager.__DEPENDS__ = {}     -- 初始化依赖为空
    newManager.__Name__ = _module.Name     -- 设置名称
    return newManager
end

---
--- 设置依赖的Manager名称列表
--- @vararg string 依赖的Manager名称
function ManagerBase:__SetDependencies__(...)
    -- 将所有参数收集为依赖列表
    self.__DEPENDS__ = {...}
end

---
--- 获取当前Manager的类型
--- @return string 类型（'S'|'C'|'B'）
function ManagerBase:__GetManagerOwner__()
    return self.__MGR_OWNER__
end

---
--- 获取当前Manager的依赖列表
--- @return table 依赖的Manager名称列表
function ManagerBase:__GetDependencies__()
    return self.__DEPENDS__
end

---
--- 获取当前Manager的名称
--- @return string 名称
function ManagerBase:__GetName__()
    return self.__Name__
end

---
--- 判断当前Manager是否为共享（双端）类型
--- @return boolean 是否为共享类型
function ManagerBase:__IsShared__()
    return self.__MGR_OWNER__ == 'B'
end

---
--- 判断当前Manager是否为服务器类型
--- @return boolean 是否为服务器类型
function ManagerBase:__IsServer__()
    return self.__MGR_OWNER__ == 'S'
end

---
--- 判断当前Manager是否为客户端类型
--- @return boolean 是否为客户端类型
function ManagerBase:__IsClient__()
    return self.__MGR_OWNER__ == 'C'
end

---
--- 判断传入模块是否为Manager（通过元表判断）
--- @param _module table 需要判断的模块
--- @return boolean 是否为Manager
function ManagerBase:__IsManager__(_module)
    if _module == ManagerBase or not _module or type(_module) ~= 'table' then
        return false
    end
    return getmetatable(_module) == self
end

function ManagerBase.__newindex(manager, key, value)
    -- 包装Init方法，确保派生类只能初始化一次
    if key == "Init" and type(value) == "function" then
        local originalInit = value
        rawset(manager, key, function(...)
            if manager.__initialized then
                error("Manager '" .. (manager.__GetName__ and manager:__GetName__() or tostring(manager)) .. "' has already been initialized.")
            end
            manager.__initialized = true
            return originalInit(...)
        end)
    else
        rawset(manager, key, value)
    end
end

setmetatable(ManagerBase, {
    __call = function(cls, _module)
        if not _module or not _module:IsA("ModuleScript") then
            error("Module must be a ModuleScript")
        end
        return cls:__CreateNewManager__(_module)
    end
})

---
--- 初始化方法，派生类需实现
function ManagerBase:Init()
    -- override in subclass
end

---
--- 设置Manager类型
--- @param mgrType string 类型名称
function ManagerBase:__SetManagerType__(mgrType)
    if not mgrType or not ManagerBase.MGR_TYPE_ENUM[mgrType] then
        error("Invalid manager type: " .. tostring(mgrType))
    end
    self.__MGR_TYPE__ = mgrType
end

---
--- 获取Manager类型
--- @return string 类型名称
function ManagerBase:__GetManagerType__()
    return self.__MGR_TYPE__
end

return ManagerBase
