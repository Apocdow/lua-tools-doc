--[[
@module FrameAnimator
@desc 帧动画播放器，支持播放、暂停、停止、自动释放、事件监听等
]]

--- 帧动画播放器类
---@class FrameAnimator
---@field guiObject GuiObject? 目标UI对象
---@field frames table? 图片id列表
---@field fps number 帧率
---@field loop boolean 是否循环
---@field playing boolean 是否正在播放
---@field currentFrame number 当前帧索引
---@field _elapsed number 已累计的时间
---@field _released boolean 是否已释放
---@field _checker Instance? 托管对象
---@field manager table? 管理器引用
---@field OnPlay Signal 播放事件
---@field OnPause Signal 暂停事件
---@field OnStop Signal 停止事件
---@field OnComplete Signal 播放完成事件
---@field OnFrameChange Signal 帧切换事件
local FrameAnimator = {}
FrameAnimator.__index = FrameAnimator

--- 事件信号类型
---@class Signal
---@field Connect fun(self:Signal, fn:function):table 连接事件
---@field Fire fun(self:Signal, ...):nil 触发事件

-- 事件工具
local function createSignal()
    local listeners = {}
    return {
        Connect = function(self, fn)
            table.insert(listeners, fn)
            return {
                Disconnect = function()
                    for i, v in ipairs(listeners) do
                        if v == fn then table.remove(listeners, i) break end
                    end
                end
            }
        end,
        Fire = function(self, ...)
            for _, fn in ipairs(listeners) do
                fn(...)
            end
        end
    }
end

--- 创建一个帧动画播放器
---@param guiObject GuiObject 目标UI对象
---@param frames table? 图片id列表
---@param fps number? 帧率，默认12
---@param loop boolean? 是否循环，默认false
---@return FrameAnimator
function FrameAnimator.new(guiObject, frames, fps, loop)
    local self = setmetatable({}, FrameAnimator)
    self.guiObject = guiObject
    self.frames = frames or {}
    self.fps = fps or 12
    self.loop = loop or false
    self.playing = false
    self.currentFrame = 1
    self._elapsed = 0
    self._released = false
    self._checker = nil
    self.manager = nil
    self.speed = 1
    -- 事件
    self.OnPlay = createSignal()
    self.OnPause = createSignal()
    self.OnStop = createSignal()
    self.OnComplete = createSignal()
    self.OnFrameChange = createSignal()
    return self
end

--- 设置帧列表
---@param frames table 图片id列表
function FrameAnimator:SetFrames(frames)
    self.frames = frames
    self.currentFrame = 1
    self._elapsed = 0
    self:UpdateFrame()
    return self
end

--- 设置帧率
---@param fps number 帧率
function FrameAnimator:SetFps(fps)
    self.fps = fps
    return self
end

--- 设置是否循环
---@param loop boolean 是否循环
function FrameAnimator:SetLoop(loop)
    self.loop = loop
    return self
end

--- 设置托管对象
---@param checker Instance 托管对象
function FrameAnimator:SetChecker(checker)
    self._checker = checker
    return self
end

--- 设置管理器引用
---@param mgr table 帧动画管理器
function FrameAnimator:SetManager(mgr)
    self.manager = mgr
    return self
end

--- 设置播放速度（倍速）
---@param speed number 倍速，1为正常速度
function FrameAnimator:SetSpeed(speed)
    self.speed = speed or 1
    return self
end

--- 获取当前播放速度
---@return number
function FrameAnimator:GetSpeed()
    return self.speed or 1
end

--- 播放动画
function FrameAnimator:Play()
    if self._released then return self end
    if not self.playing then
        self.playing = true
        self.OnPlay:Fire()
    end
    return self
end

--- 暂停动画
function FrameAnimator:Pause()
    if self._released then return self end
    if self.playing then
        self.playing = false
        self.OnPause:Fire()
    end
    return self
end

--- 停止动画并重置到第一帧
function FrameAnimator:Stop()
    if self._released then return self end
    self.playing = false
    self.currentFrame = 1
    self._elapsed = 0
    self:UpdateFrame()
    self.OnStop:Fire()
    return self
end

--- 便捷归还自身到管理器
function FrameAnimator:GaveBack()
    if self.manager and self.manager.GiveBackAnimator then
        self.manager:GiveBackAnimator(self)
    end
    return self
end

--- 解绑当前所有事件Connect的方法
function FrameAnimator:UnBindingAllEvent()
    self.OnPlay = createSignal()
    self.OnPause = createSignal()
    self.OnStop = createSignal()
    self.OnComplete = createSignal()
    self.OnFrameChange = createSignal()
    return self
end

--- 释放播放器，断开所有引用和事件
function FrameAnimator:Release()
    if self._released then return self end
    self._released = true
    self.playing = false
    self.frames = nil
    self.guiObject = nil
    self._checker = nil
    -- 断开所有事件
    self.OnPlay = nil
    self.OnPause = nil
    self.OnStop = nil
    self.OnComplete = nil
    self.OnFrameChange = nil
    return self
end

--- 更新动画帧（由管理器定时调用）
---@param dt number 时间增量
function FrameAnimator:Update(dt)
    if self._released or not self.playing or not self.frames or #self.frames == 0 then return end
    local speed = self.speed or 1
    self._elapsed = self._elapsed + dt * speed
    local frameCount = #self.frames
    local frameDuration = 1 / self.fps
    while self._elapsed >= frameDuration do
        self._elapsed = self._elapsed - frameDuration
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > frameCount then
            if self.loop then
                self.currentFrame = 1
            else
                self.currentFrame = frameCount
                self:Pause()
                self.OnComplete:Fire()
                break
            end
        end
        self:UpdateFrame()
        self.OnFrameChange:Fire(self.currentFrame)
    end
    -- 检查托管对象
    if self._checker and (not self._checker.Parent or (self._checker:IsA("ScreenGui") and not self._checker.Enabled)) then
        self:Release()
    end
end

--- 刷新当前帧图片
function FrameAnimator:UpdateFrame()
    if self.guiObject and self.frames and self.frames[self.currentFrame] then
        self.guiObject.Image = self.frames[self.currentFrame]
    end
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

-- 1. 创建一个帧动画播放器
local animator = FrameAnimator.new(imageLabel, frames, 24, true)

-- 2. 播放动画
animator:Play()

-- 3. 监听帧切换和播放完成事件
animator.OnFrameChange:Connect(function(frameIdx)
    print("当前帧:", frameIdx)
end)
animator.OnComplete:Connect(function()
    print("动画播放完毕")
end)

-- 4. 暂停、继续、停止动画
animator:Pause()
animator:Play()
animator:Stop()

-- 5. 设置新帧列表、帧率、循环状态
animator:SetFrames({"rbxassetid://111","rbxassetid://222"})
animator:SetFps(12)
animator:SetLoop(false)

-- 6. 托管到ScreenGui，关闭时自动释放
local screenGui = script.Parent:FindFirstAncestorOfClass("ScreenGui")
animator:SetChecker(screenGui)

-- 7. 释放播放器（手动）
animator:Release()

==================================================
]]

return FrameAnimator