print("Server_Game_Start.lua 已加载")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ManagerFolder = ReplicatedStorage:WaitForChild("Managers")
local ManagerLoader = require(ManagerFolder:WaitForChild("ManagerLoader"))()
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local ModelsFolder = SharedFolder:WaitForChild("Models")
local HumanoidDescriptionMgr = ManagerLoader.HumanoidDescriptionMgr

local function PlayerCharacterAdded(_character)
    local player = Players:GetPlayerFromCharacter(_character)
    -- 当玩家角色加载完成时，保存玩家的HumanoidDescription
    if not HumanoidDescriptionMgr:IsPlayerCached(player) then
        HumanoidDescriptionMgr:SavePlayerHumanoidDescription(player)
    end
    local isChanged = false
    -- task.spawn(function()
    --     while true do
    --         task.wait(5) -- 每秒检查一次
    --         HumanoidDescriptionMgr:ChangePlayerHumanoidDescription(player , not isChanged and HumanoidDescriptionMgr:GetModelHumanoidDescription("TestModel") or HumanoidDescriptionMgr:GetPlayerHumanoidDescription(player))
    --         isChanged = not isChanged -- 切换状态
    --     end
    -- end)


    -- local Highlight = Instance.new("Highlight")
    -- Highlight.Name = "BlackOutLine"
    -- Highlight.FillColor = Color3.new(0, 0, 0)
    -- Highlight.FillTransparency = 1
    -- Highlight.OutlineColor = Color3.new(0, 0, 0)
    -- Highlight.OutlineTransparency = 0
    -- Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    -- Highlight.Parent = _character

end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(PlayerCharacterAdded)
end)

local door1 = workspace:WaitForChild("Door1")
local camera1 = door1:WaitForChild("Camera")

local door2 = workspace:WaitForChild("Door2")
local camera2 = door2:WaitForChild("Camera")


