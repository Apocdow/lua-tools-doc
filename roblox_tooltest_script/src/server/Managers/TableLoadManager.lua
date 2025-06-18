-- 服务端 TableLoadManager
-- 负责加载 ServerScriptService.Configs 下所有配置表，并通过 RemoteFunction 响应客户端请求
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteFunction = Instance.new("RemoteFunction")
RemoteFunction.Name = "GetConfigTable"
RemoteFunction.Parent = ReplicatedStorage

local ManagerBase = require(ReplicatedStorage:WaitForChild("Managers"):WaitForChild("Manager_Base"))
local TableLoadManager = ManagerBase:__CreateNewManager__(script)

local configsFolder = ServerScriptService:WaitForChild("Configs")
local configCache = {}

-- 加载所有配置表
local function loadAllConfigs()
    for _, moduleScript in ipairs(configsFolder:GetChildren()) do
        if moduleScript:IsA("ModuleScript") then
            local ok, config = pcall(require, moduleScript)
            if ok then
                table.freeze(config) -- 冻结配置表，防止修改
                configCache[moduleScript.Name] = config
            else
                warn("加载配置表失败：" .. moduleScript.Name .. ", 错误：" .. tostring(config))
            end
        end
    end
end

function TableLoadManager:Init()
    loadAllConfigs()
    -- 设置 RemoteFunction 响应
    RemoteFunction.OnServerInvoke = function(player, configName)
        return configCache[configName]
    end
end

return TableLoadManager
