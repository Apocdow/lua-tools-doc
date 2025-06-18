local AnimationTable = {}


for _,v in pairs(AnimationTable) do
    setmetatable(v,{__index = {
        ID = "",
        AnimationName = "",
        AnimationID = 0,
    }})
end
return AnimationTable
--[[
    ID: 动画ID
    AnimationName: 动画名称
    AnimationID: 动画资源ID
]]
-- 这个表用于存储所有动画的配置数据
