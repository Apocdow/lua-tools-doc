-- 客户端 TableLoadManager
-- 通过 RemoteFunction 向服务端请求配置表
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteFunction = ReplicatedStorage:WaitForChild("GetConfigTable")

local ManagerBase = require(ReplicatedStorage:WaitForChild("Managers"):WaitForChild("Manager_Base"))
local TableLoadManager = ManagerBase:__CreateNewManager__(script)

local configCache = {}

-- 获取配置表（优先本地缓存）
function TableLoadManager:GetConfig(configName)
    if configCache[configName] then
        return configCache[configName]
    end
    local config = RemoteFunction:InvokeServer(configName)
    if config then
        configCache[configName] = config
    end
    return config
end

return TableLoadManager
