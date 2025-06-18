local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ManagerFolder = ReplicatedStorage:WaitForChild("Managers")

local ManagerLoader = require(ManagerFolder:WaitForChild("ManagerLoader"))

game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function(character)
    ManagerLoader()
    local UIMgr = ManagerLoader.UIMgr
    -- 当本地玩家角色加载完成时，初始化UI管理器
    -- 当本地玩家加入时，显示主UI
    -- UIMgr:ShowUI("MainUI")
end)
