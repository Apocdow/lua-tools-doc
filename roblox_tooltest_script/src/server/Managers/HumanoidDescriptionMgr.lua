--!strict
--[[
    @module HumanoidDescriptionMgr
    @desc 管理玩家和模型的人形描述缓存与应用
    @author Copilot
    @date 2025-06-17
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local ModelsFolder = SharedFolder:WaitForChild("Models")

--- @class HumanoidDescriptionMgr 
local HumanoidDescriptionMgr = require(ReplicatedStorage:WaitForChild("Managers"):WaitForChild("Manager_Base"))
    :__CreateNewManager__(script)

--- 玩家的人形描述缓存表
---@type table<number, HumanoidDescription>
HumanoidDescriptionMgr.playerHumanoidDescriptions = {}
--- 模型的人形描述缓存表
---@type table<string, HumanoidDescription>
HumanoidDescriptionMgr.modelHumanoidDescriptions = {}

--- 判断玩家的人形描述是否已缓存
---@param player Player @要检查的玩家对象
---@return boolean @是否已缓存
function HumanoidDescriptionMgr:IsPlayerCached(player)
    if not player or not player:IsA("Player") then
        error("传入的player无效: 不是Player对象")
    end
    return self.playerHumanoidDescriptions[player.UserId] ~= nil
end

--- 获取玩家的人形描述
---@param player Player @要获取的玩家对象
---@return HumanoidDescription|nil @玩家的人形描述或nil
function HumanoidDescriptionMgr:GetPlayerHumanoidDescription(player)
    if not player or not player:IsA("Player") then
        error("传入的player无效: 不是Player对象")
    end
    return self.playerHumanoidDescriptions[player.UserId]
end

--- 保存玩家当前的人形描述到缓存
---@param player Player @要保存的玩家对象
function HumanoidDescriptionMgr:SavePlayerHumanoidDescription(player)
    if not player or not player:IsA("Player") then
        error("传入的player无效: 不是Player对象")
    end
    local humanoidDescription = nil
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoidDescription = humanoid:GetAppliedDescription():Clone()
    end
    if humanoidDescription then
        self.playerHumanoidDescriptions[player.UserId] = humanoidDescription
        print("已保存玩家的人形描述：", player.Name)
    else
        warn("未找到玩家的人形描述：", player.Name)
    end
end

--- 获取模型的人形描述（带缓存）
---@param name string @模型名称
---@return HumanoidDescription|nil @模型的人形描述或nil
function HumanoidDescriptionMgr:GetModelHumanoidDescription(name)
    if not name or type(name) ~= "string" then
        error("传入的模型名称无效")
    end
    if self.modelHumanoidDescriptions[name] then
        return self.modelHumanoidDescriptions[name]
    end
    local model = ModelsFolder:FindFirstChild(name)
    if not model then
        warn("未找到模型：", name)
        return nil
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("模型中未找到Humanoid：", name)
        return nil
    end
    self.modelHumanoidDescriptions[name] = humanoid:GetAppliedDescription():Clone()
    return self.modelHumanoidDescriptions[name]
end

--- 更换玩家的人形描述
---@param player Player @要更换的玩家对象
---@param newDescription HumanoidDescription @新的描述对象
function HumanoidDescriptionMgr:ChangePlayerHumanoidDescription(player, newDescription)
    if not player or not player:IsA("Player") then
        error("传入的player无效: 不是Player对象")
    end
    if not newDescription or not newDescription:IsA("HumanoidDescription") then
        error("传入的人形描述无效: 不是HumanoidDescription对象")
    end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ApplyDescription(newDescription)
        print("已更换玩家的人形描述：", player.Name)
    else
        warn("玩家角色中未找到Humanoid：", player.Name)
    end
end

--- 初始化管理器
---@return HumanoidDescriptionMgr
function HumanoidDescriptionMgr:Init()
    -- 可在此处添加初始化逻辑
    return self
end

return HumanoidDescriptionMgr