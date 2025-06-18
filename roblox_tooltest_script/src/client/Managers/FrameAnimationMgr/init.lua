--[[
@module FrameAnimationMgr
@desc 帧动画管理器，统一管理所有活跃的帧动画播放器，并通过对象池高效复用
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ManagerBase = require(ReplicatedStorage:WaitForChild("Managers"):WaitForChild("Manager_Base"))
local FrameAnimator = require(script:WaitForChild("FrameAnimator"))

---@class FrameAnimationMgr : ManagerBase
---@field animatorPool Pool 帧动画播放器对象池
---@field animators table<FrameAnimator, boolean> 当前活跃的动画播放器集合
local FrameAnimationMgr = ManagerBase(script)

local PoolTool = require(game:GetService("ReplicatedStorage"):WaitForChild("Utils"):WaitForChild("Pool_Tool"))

--- 帧动画播放器对象池，最大容量20
---@type Pool
local animatorPool = PoolTool(
    FrameAnimator, -- 模板
    function(_model) return FrameAnimator.new() end, -- 实例化函数
    function(animator) -- 重置函数
        animator:Stop()
            :SetFrames(nil)
            :SetFps(12)
            :SetLoop(false)
            :SetChecker(nil)
    end,
    function(animator) -- 归还函数
        animator:Stop():UnBindingAllEvent()
    end,
    function(animator) -- 销毁函数
        animator:Release()
    end,
    20 -- 最大池容量
)

--- 当前活跃的动画播放器集合
---@type table<FrameAnimator, boolean>
local animators = {}

-- 全局更新所有活跃的动画播放器
RunService.RenderStepped:Connect(function(dt)
    for animator, _ in pairs(animators) do
        if animator._released then
            animators[animator] = nil
        else
            animator:Update(dt)
        end
    end
end)

--- 从池中获取一个Animator并初始化
---@param guiObject GuiObject 目标UI对象
---@param frames table 图片id列表
---@param fps number 帧率
---@param loop boolean 是否循环
---@param checker Instance? 托管对象（可选）
---@return FrameAnimator
function FrameAnimationMgr:GetAnimator(guiObject, frames, fps, loop, checker)
    local animator = animatorPool:Get() or FrameAnimator.new()
    animator.guiObject = guiObject
    animator:SetFrames(frames)
    animator:SetFps(fps or 12)
    animator:SetLoop(loop or false)
    if checker then animator:SetChecker(checker) end
    animator:SetManager(self)
    animators[animator] = true
    return animator
end

--- 归还Animator到池
---@param animator FrameAnimator
function FrameAnimationMgr:GiveBackAnimator(animator)
    if animators[animator] then
        animators[animator] = nil
        animatorPool:GiveBack(animator)
    end
end

--- 创建一个帧动画播放器（对象池复用）
---@param guiObject GuiObject
---@param frames table
---@param fps number
---@param loop boolean
---@return FrameAnimator
function FrameAnimationMgr:Create(guiObject, frames, fps, loop)
    return self:GetAnimator(guiObject, frames, fps, loop)
end

--- 一次性播放并自动释放（对象池复用）
---@param guiObject GuiObject
---@param frames table
---@param fps number
---@param checker Instance
---@return FrameAnimator
function FrameAnimationMgr:PlayOnce(guiObject, frames, fps, checker)
    local animator = self:GetAnimator(guiObject, frames, fps, false, checker)
    animator.OnComplete:Connect(function()
        self:GiveBackAnimator(animator)
    end)
    animator:Play()
    return animator
end

--- 托管对象自动释放（对象池复用）
---@param guiObject GuiObject
---@param frames table
---@param fps number
---@param loop boolean
---@param checker Instance
---@return FrameAnimator
function FrameAnimationMgr:CreateWithChecker(guiObject, frames, fps, loop, checker)
    return self:GetAnimator(guiObject, frames, fps, loop, checker):Play()
end

--- 释放Animator
---@param animator FrameAnimator
function FrameAnimationMgr:DestroyAnimator(animator)
    if not animators[animator] then return end
    animatorPool:Destroy(animator)
    animators[animator] = nil
end

--[[
==================== 使用案例 ====================

-- 假设有一个ImageLabel和一组图片id
local imageLabel = script.Parent:WaitForChild("MyImageLabel")
local frames = {
    "rbxassetid://123456",
    "rbxassetid://123457",
    "rbxassetid://123458",
    -- ...更多图片id
}

-- 1. 创建并播放一个循环动画
local animator = FrameAnimationMgr:Create(imageLabel, frames, 24, true)
animator:Play()

-- 2. 监听动画事件
animator.OnFrameChange:Connect(function(frameIdx)
    print("当前帧:", frameIdx)
end)
animator.OnComplete:Connect(function()
    print("动画播放完毕")
end)

-- 3. 一次性播放动画，播放完自动释放
FrameAnimationMgr:PlayOnce(imageLabel, frames, 12)

-- 4. 托管到ScreenGui，关闭时自动释放
local screenGui = script.Parent:FindFirstAncestorOfClass("ScreenGui")
local animator2 = FrameAnimationMgr:CreateWithChecker(imageLabel, frames, 12, true, screenGui)
animator2:Play()

-- 5. 手动归还动画播放器到池
FrameAnimationMgr:GiveBackAnimator(animator)
或者
animator:GaveBack()
-- 或者直接调用 animator:Release() 释放资源
-- 这样会自动归还到对象池并清理事件绑定

==================================================
]]

return FrameAnimationMgr