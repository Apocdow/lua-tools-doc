local ReplicatedStorage = game:GetService("ReplicatedStorage")
local untils = ReplicatedStorage:WaitForChild("Utils")
local testPart = game:GetService("Workspace"):WaitForChild("PoolTestPart")
local testFolder = game:GetService("Workspace"):WaitForChild("TestFolder")
local index = 0
local pool = require(untils:WaitForChild("Pool_Tool"))(testPart,function(_model)
    local new_obj = Instance.new(_model.ClassName, testFolder)
    index = index + 1
    new_obj.Name = "TestPart" .. index
    return new_obj
end,function(_obj)
    _obj.Size = Vector3.new(1, 1, 1)
    _obj.Position = Vector3.new(0, 0, 0)
    _obj.Anchored = true
    _obj.CanCollide = false
    _obj.BrickColor = BrickColor.Random()
    _obj.Transparency = 0
end,function(_obj)
    _obj.Transparency = 1
    _obj.CanCollide = false
    _obj.Anchored = true
    _obj:ClearAllChildren() -- 清除所有子对象
end,function(_obj)
    _obj:Destroy()
end,5)

local testCount = 50

-- 监听玩家输入空格
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessedEvent)
    if input.KeyCode == Enum.KeyCode.Space and not gameProcessedEvent then
        testCount = 50 -- 重置测试次数
    end
end)

while true do
    -- if testCount <= 0 then
    --     task.wait(0.1) -- 等待池中有对象可用
    --     continue 
    -- end
    testCount = testCount - 1
    local obj = pool:Get(true)
    if not obj then 
        task.wait(0.1) -- 等待池中有对象可用
        continue 
    end
    obj.Anchored = false
    local velocity = Instance.new("BodyVelocity", obj)
    velocity.Velocity = Vector3.new(math.random(-50, 50), math.random(10, 50), math.random(-50, 50))
    velocity.MaxForce = Vector3.new(10000, 10000, 10000)
    task.delay(2, function()
        pool:GiveBack(obj)
        velocity:Destroy()
    end)
    task.wait(0.1) -- 控制生成速度
end