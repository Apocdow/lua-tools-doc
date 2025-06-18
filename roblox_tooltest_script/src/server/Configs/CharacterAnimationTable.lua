local CharacterAnimationTable = {}

for _,v in pairs(CharacterAnimationTable) do
    setmetatable(v,{__index = {
        ID = "",
        Climb = "",
        Fall = "",
        Idle = "",
        Jump = "",
        Swim = "",
        Mood = "",
        Run = "",
        Walk = "",
        Other = "",
    }})
end

return CharacterAnimationTable
--[[
    ID: 角色ID
    Climb: 爬行动画ID
    Fall: 跌落动画ID
    Idle: 站立动画ID
    Jump: 跳跃动画ID
    Swim: 游泳动画ID
    Mood: 情绪动画ID
    Run: 跑步动画ID
    Walk: 行走动画ID
    Other: 其他自定义动画，格式为 "name1:animId1;name2:animId2,..."
]]
-- 这个表用于存储所有角色的动画配置数据
-- 每个角色ID对应一个包含各种动画ID的表