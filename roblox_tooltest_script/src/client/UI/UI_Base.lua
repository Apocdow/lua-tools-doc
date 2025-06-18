local UIBase = {}
UIBase.__index = UIBase
-- UIBase: 基础UI类，提供基本的UI操作和事件处理功能。
-- 包含UI的显示、隐藏、销毁等基本操作。
-- 支持UI控件自动映射（如Name.Text => Name_Text）

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local thisPlayer = game:GetService("Players").LocalPlayer
local playerScripts = thisPlayer:WaitForChild("PlayerScripts")
local UtilsFolder = game:GetService("ReplicatedStorage"):WaitForChild("Utils")
local mgrFolder = playerScripts:WaitForChild("Managers")
local uiMgr = require(mgrFolder:WaitForChild("UIMgr"))
local TweenService = game:GetService("TweenService")

UIBase._CLICK_DELAY_ = 0.5 -- 默认点击间隔为0.5秒
UIBase._IS_IN_OC_EFFECT_STATE_LIST_ = {} -- 是否正在打开或关闭特效
UIBase._OC_EFFECT_TARGET_ = nil -- 特效目标对象
UIBase._ORIGINAL_OC_EFFECT_DATA_ = nil -- 特效目标对象的原始状态数据
UIBase._CURRENT_TWEEN_ = nil -- 当前正在播放的Tween动画
UIBase._CLICK_BINDINGS_ = {} -- 存储点击事件绑定
UIBase._UI_MODEL_ = nil -- UI模型对象
UIBase._NAME_ = "UIBase" -- 默认名称
UIBase._LAST_CLICK_TIME_ = nil -- 上次点击时间
UIBase._UI_STATE_ENUM_ = {
    OPENED = "OPENED", -- UI已打开
    CLOSED = "CLOSED",  -- UI已关闭
    NOT_INITIALIZED = "NOT_INITIALIZED", -- UI未初始化
    OPEN_EFFECT = "OPEN_EFFECT", -- UI打开特效状态
    CLOSE_EFFECT = "CLOSE_EFFECT", -- UI关闭特效状态
    OPEN_EFFECT_COMPLETED = "OPEN_EFFECT_COMPLETED", -- UI打开特效完成状态
    CLOSE_EFFECT_COMPLETED = "CLOSE_EFFECT_COMPLETED" -- UI关闭特效完成状态
}

UIBase.UIMgr = uiMgr -- 引用UI管理器
-- 创建UIBase实例
function UIBase:new()
    -- 自动装饰Awake方法，使子类Awake中self为ui对象
    local ui = setmetatable({uiBase = UIBase}, {__index = self,__newindex = function(t, k, v)
        if k == "Awake" and type(v) == "function" then
            rawset(t, k, function(_self, _obj)
                local ui = UIBase.Awake(_self, _obj)
                -- 用ui作为_self调用子类Awake逻辑
                v(ui, _obj)
                return ui
            end)
        elseif k == "OnOpen" and type(v) == "function" then
            rawset(t, k, function(_self, _is_passive, _parameters)
                UIBase.OnOpen(_self, _is_passive, _parameters)
                -- 用ui作为_self调用子类OnOpen逻辑
                v(_self, _is_passive, _parameters)
            end)
        elseif k == "OnClose" and type(v) == "function" then
            rawset(t, k, function(_self, _is_passive)
                -- 用ui作为self调用子类OnClose逻辑
                v(_self, _is_passive)
                UIBase.OnClose(_self, _is_passive)
            end)
        else
            rawset(t, k, v)
        end
    end})
    return ui
end

-- UI打开时调用
function UIBase:OnOpen(_is_passive, _parameters)

    if not self:IsInState(self._UI_STATE_ENUM_.OPEN_EFFECT_COMPLETED, self._UI_STATE_ENUM_.OPENED) then
        if self._UI_MODEL_ then
            self._UI_MODEL_.Enabled = true
            self:ChangeUIState(self._UI_STATE_ENUM_.OPENED) -- 修改状态为打开特效中
        end
        if not _is_passive then
            self:ChangeUIState(self._UI_STATE_ENUM_.OPEN_EFFECT) -- 修改状态为打开特效中
            self:OpenEffect(function()
                self:ChangeUIState(self._UI_STATE_ENUM_.OPEN_EFFECT_COMPLETED) -- 修改状态为已打开
            end) -- 打开特效
        end
    end
    self:Refresh()
end

-- UI对象Awake时调用，初始化控件映射
function UIBase:Awake(_obj)
    local ui = self:new()
    ui._UI_MODEL_ = _obj
    ui._UI_MODEL_.Enabled = false -- 默认不启用UI
    ui._UI_MODEL_:SetAttribute("UI_STATE", "CLOSED") -- 设置UI状态为关闭
    ui._OC_EFFECT_TARGET_ = nil -- 初始化特效目标对象
    ui._ORIGINAL_OC_EFFECT_DATA_ = nil -- 初始化特效目标对象的原始状态数据
    ui._CURRENT_TWEEN_ = nil -- 初始化当前Tween动画
    ui._CLICK_BINDINGS_ = {} -- 初始化点击事件绑定
    ui._CLICK_DELAY_ = 0.5 -- 默认点击间隔为0.5秒
    ui._LAST_CLICK_TIME_ = nil -- 上次点击时间

    ui._NAME_ = _obj.Name -- 保存UI名称
    -- 自动映射所有带"."的控件为Name_XX
    for _, child in ipairs(ui._UI_MODEL_:GetDescendants()) do
        local name = child.Name -- 获取控件名称
        local parts = name:split(".")
        if #parts > 1 then
            local newName = table.concat(parts, "_")
            ui[newName] = child
        end
    end

    ui:SetOCEffectTarget(ui._UI_MODEL_:GetChildren()[1]) -- 设置特效目标为UI对象

    return ui
end

-- UI关闭时调用
function UIBase:OnClose(_is_passive)
    if self._UI_MODEL_ then
        if not _is_passive then
            self:ChangeUIState(self._UI_STATE_ENUM_.CLOSE_EFFECT) -- 修改状态为关闭特效中
            self:CloseEffect(function()
                self._UI_MODEL_.Enabled = false
                self:ChangeUIState(self._UI_STATE_ENUM_.CLOSED) -- 修改状态为已关闭
            end)
        else
            self._UI_MODEL_.Enabled = false -- 被动关闭（如点击其他UI）
            self:ChangeUIState(self._UI_STATE_ENUM_.CLOSED) -- 修改状态为已关闭
        end
    end
end

-- UI刷新时调用
function UIBase:Refresh()
    -- 刷新UI逻辑
    if self._UI_MODEL_ then
        -- 这里可以添加刷新UI的具体逻辑
        -- print("Refreshing UI: " .. self:GetName())
    end
end

-- UI销毁时调用
function UIBase:Destroy()

end


--------------------------点击事件处理---------------------

--- 设置点击间隔
---@param _delay number 点击间隔（秒），必须为非负数
function UIBase:SetClickDelay(_delay)
    if type(_delay) ~= "number" or _delay < 0 then
        error("SetClickDelay参数错误，_delay必须是非负数")
    end
    self._CLICK_DELAY_ = _delay
end

--- 获取点击间隔
---@return number 点击间隔（秒）
function UIBase:GetClickDelay()
    return self._CLICK_DELAY_ or 0.5 -- 默认点击间隔为0.5秒
end

--- 绑定点击事件
---@param _obj Instance 要绑定点击事件的UI对象（如Button等）
---@param _callback fun(...) 点击事件回调函数，参数为点击事件的参数
---@param _delay number? 点击间隔，单位秒，默认为0.5秒（可选）
--- 注意：如果UI未启用或点击间隔未到，则忽略此次点击
function UIBase:BindingClickEvent(_obj, _callback, _delay)
    -- 绑定点击事件
    if _obj and _callback and type(_callback) == "function" and _obj.MouseButton1Click then
        if self._CLICK_BINDINGS_ == nil then
            self._CLICK_BINDINGS_ = {}
        end
        -- 检查是否已经绑定过
        if self._CLICK_BINDINGS_[_obj] then
            self._CLICK_BINDINGS_[_obj]:Disconnect()
            self._CLICK_BINDINGS_[_obj] = nil
            return
        end
        self._CLICK_BINDINGS_[_obj] = _obj.MouseButton1Click:Connect(function(...)
            -- print(self:GetName() .. " Clicked") -- 打印点击事件
            -- 如果正在特效状态中，则忽略点击
            if #UIBase._IS_IN_OC_EFFECT_STATE_LIST_ > 0 then
                -- print("存在正在打开或关闭特效的UI，忽略此次点击")
                return -- 如果正在打开或关闭特效，则忽略此次点击
            end
            -- 检查UI是否启用
            if not self._UI_MODEL_ or not self._UI_MODEL_.Enabled then
                -- print("UI未启用，忽略此次点击")
                return -- 如果UI未启用，则忽略点击
            end
            -- 检查点击间隔
            if self._LAST_CLICK_TIME_ and (tick() - self._LAST_CLICK_TIME_ < (_delay or self:GetClickDelay())) then
                -- print("点击间隔未到，忽略此次点击")
                return -- 如果点击间隔未到，则忽略此次点击
            end
            self._LAST_CLICK_TIME_ = tick() -- 更新最后点击时间
            -- 调用回调函数
            _callback(...)
        end)
    else
        error("BindingClickEvent参数错误，_obj和_callback必须有效且_callback必须是函数")
    end
end

function UIBase:SetOCEffectTarget(_obj)
    -- 设置特效目标对象
    if _obj and _obj:IsA("GuiObject") then
        self._OC_EFFECT_TARGET_ = _obj
        -- 记录初始状态数据
        self._ORIGINAL_OC_EFFECT_DATA_ = {
            Size = _obj.Size,
            Position = _obj.Position,
            Visible = _obj.Visible,
            Transparency = _obj.BackgroundTransparency
        }
    else
        error("SetOCEffectTarget 参数错误，_obj 必须是有效的 Instance 对象")
    end
end

---------------------Effect处理---------------------
--- 打开UI时的特效处理
---@return number effect_time 特效持续时间（秒）
function UIBase:OpenEffect(_callback)
    local effect_time = .2 -- 特效持续时间
    -- 打开UI时的特效逻辑
    if self._UI_MODEL_ and self._OC_EFFECT_TARGET_ then
        -- 这里可以添加打开UI时的特效逻辑
        -- 例如播放动画、音效等
        -- print("Opening UI with effect: " .. self:GetName())
        local root = self._OC_EFFECT_TARGET_
        local baseSize = self._ORIGINAL_OC_EFFECT_DATA_.Size or root.Size -- 获取原始大小
        local changedSize = UDim2.new(baseSize.X.Scale * 0.25, baseSize.X.Offset * 0.25, baseSize.Y.Scale * 0.25, baseSize.Y.Offset * 0.25) -- 目标大小为原始大小的1/4

        root.Size = changedSize
        --定义一个动画
        local tweenInFo_1 = TweenInfo.new(effect_time,Enum.EasingStyle.Linear,Enum.EasingDirection.In)

        local mubiao = {
            Size = baseSize
        }

        local tween_1 = TweenService:Create(root, tweenInFo_1, mubiao)
        self._CURRENT_TWEEN_ = tween_1 -- 保存当前Tween引用
        self._CURRENT_TWEEN_COMPLETED = tween_1.Completed:Connect(function()
            root.Size = baseSize -- 重置大小
            if _callback and type(_callback) == "function" then
                _callback() -- 调用回调函数
            end
            if self._CURRENT_TWEEN_ == tween_1 then
                self._CURRENT_TWEEN_ = nil -- 清除当前Tween引用
                self._CURRENT_TWEEN_COMPLETED:Disconnect() -- 断开Completed事件连接
                self._CURRENT_TWEEN_COMPLETED = nil -- 清除Completed事件引用
            end
        end)
        tween_1:Play()
    end
    return effect_time
end

--- 关闭UI时的特效处理
---@return number effect_time 特效持续时间（秒）
function UIBase:CloseEffect(_callback)
    local effect_time = .2 -- 特效持续时间
    -- 关闭UI时的特效逻辑
    if self._UI_MODEL_ and self._OC_EFFECT_TARGET_ then
        -- 这里可以添加关闭UI时的特效逻辑
        -- 例如播放动画、音效等
        -- print("Closing UI with effect: " .. self:GetName())
        local root = self._OC_EFFECT_TARGET_
        local baseSize = self._ORIGINAL_OC_EFFECT_DATA_.Size or root.Size -- 获取原始大小
        local changedSize = UDim2.new(baseSize.X.Scale * 0.25, baseSize.X.Offset * 0.25, baseSize.Y.Scale * 0.25, baseSize.Y.Offset * 0.25) -- 目标大小为原始大小的1/4

        root.Size = baseSize
        root.Visible = true
        --定义一个动画
        local tweenInFo_1 = TweenInfo.new(effect_time,Enum.EasingStyle.Linear,Enum.EasingDirection.In)

        local mubiao = {
            Size = changedSize,
        }

        local tween_1 = TweenService:Create(root, tweenInFo_1, mubiao)
        self._CURRENT_TWEEN_ = tween_1 -- 保存当前Tween引用
        self._CURRENT_TWEEN_COMPLETED = tween_1.Completed:Connect(function()
            self:ChangeUIState(self._UI_STATE_ENUM_.CLOSE_EFFECT_COMPLETED) -- 修改状态为关闭特效完成
            if _callback and type(_callback) == "function" then
                _callback() -- 调用回调函数
            end
            root.Size = baseSize -- 重置大小
            if self._CURRENT_TWEEN_ == tween_1 then
                self._CURRENT_TWEEN_ = nil -- 清除当前Tween引用
                self._CURRENT_TWEEN_COMPLETED:Disconnect() -- 断开Completed事件连接
                self._CURRENT_TWEEN_COMPLETED = nil -- 清除Completed事件引用
            end

        end)
        tween_1:Play()
    end
    return effect_time
end

--- 关闭自身UI
---@param _callback fun()? 关闭后回调（可选）
function UIBase:HideUI(_callback)
    self.UIMgr:HideUI(self:GetName())
    if _callback and type(_callback) == "function" then
        _callback() -- 调用回调函数
    end
end

function UIBase:ForceStopEffect(_callback)
    if self._OC_EFFECT_TARGET_ then
        local root = self._OC_EFFECT_TARGET_
        -- 停止当前动画（需要确保动画引用被保存并可以访问）
        if self._CURRENT_TWEEN_ and self._CURRENT_TWEEN_.PlaybackState == Enum.PlaybackState.Playing then
            self._CURRENT_TWEEN_COMPLETED:Disconnect() -- 断开Completed事件连接
            self._CURRENT_TWEEN_COMPLETED = nil -- 清除Completed事件引用
            self._CURRENT_TWEEN_COMPLETED = self._CURRENT_TWEEN_.Completed:Connect(function()
                if _callback and type(_callback) == "function" then
                    self._CURRENT_TWEEN_ = nil -- 清除当前Tween引用
                    self._CURRENT_TWEEN_COMPLETED:Disconnect() -- 断开Completed事件连接
                    self._CURRENT_TWEEN_COMPLETED = nil -- 清除Completed事件引用
                    -- 重置UI表现
                    root.Size = self._ORIGINAL_OC_EFFECT_DATA_.Size or root.Size -- 恢复原始大小
                    root.Visible = true -- 确保UI可见
                    -- print("ForceStopEffect 被调用，特效已强制停止并重置 UI: " .. self:GetName())
                    _callback() -- 调用回调函数
                end
            end)
            self._CURRENT_TWEEN_:Cancel() -- 停止当前动画
        else
            -- 重置UI表现
            if self._ORIGINAL_OC_EFFECT_DATA_ then
                for key, value in pairs(self._ORIGINAL_OC_EFFECT_DATA_) do
                    if root[key] ~= nil then
                        root[key] = value -- 恢复原始属性
                    end
                end
            end
            root.Visible = true -- 确保UI可见
            -- print("ForceStopEffect 被调用，特效已强制停止并重置 UI: " .. self:GetName())
            if _callback and type(_callback) == "function" then
                _callback() -- 调用回调函数
            end
        end
    end
end

-------------- 管理方法

--- 获取UI模型对象
---@return Instance? UI模型对象，如果未设置则返回nil
function UIBase:GetUIModel()
    return self._UI_MODEL_
end

--- 获取UI名称
---@return string UI名称
function UIBase:GetName()
    return self._NAME_
end

--- 获取UI状态
---@return string UI状态，可能的值为 "OPENED" 或 "CLOSED"
function UIBase:GetUIState()
    if self._UI_MODEL_ then
        return self._UI_MODEL_:GetAttribute("UI_STATE") or "CLOSED"
    end
    return "NOT_INITIALIZED"
end

function UIBase:IsInState(...)
    for _, state in ipairs({...}) do
        if self:GetUIState() == state then
            return true
        end
    end
    return false
end

--- 设置UI状态
---@param newState string 新的UI状态，必须是 UIBase._UI_STATE_ENUM_ 中定义的状态
---@return UIBase self 返回当前UIBase实例
function UIBase:ChangeUIState(newState)
    if self._UI_MODEL_ then
        if not self._UI_STATE_ENUM_[newState] then
            error("ChangeUIState 参数错误，newState 必须是 UIBase._UI_STATE_ENUM_ 中定义的状态")
        end
        -- 如果状态未改变，则不做任何操作
        if self:GetUIState() == newState then
            return self -- 如果状态未改变，直接返回当前实例
        end
        -- print("ChangeUIState 被调用，当前状态: " .. self:GetUIState() .. "，新状态: " .. newState, "UI名称: " .. self:GetName())
        if (not self:IsInState(self._UI_STATE_ENUM_.OPEN_EFFECT, self._UI_STATE_ENUM_.CLOSE_EFFECT)) 
            and (newState == self._UI_STATE_ENUM_.OPEN_EFFECT 
                or newState == self._UI_STATE_ENUM_.CLOSE_EFFECT) 
            then
                table.insert(UIBase._IS_IN_OC_EFFECT_STATE_LIST_, self) -- 添加到特效状态列表
        elseif self:IsInState(self._UI_STATE_ENUM_.OPEN_EFFECT, self._UI_STATE_ENUM_.CLOSE_EFFECT) 
            and (newState ~= self._UI_STATE_ENUM_.OPEN_EFFECT 
                and newState ~= self._UI_STATE_ENUM_.CLOSE_EFFECT) then
                local index = table.find(UIBase._IS_IN_OC_EFFECT_STATE_LIST_, self)
                if index then
                    table.remove(UIBase._IS_IN_OC_EFFECT_STATE_LIST_, index) -- 从特效状态列表中移除
                end
        end
        -- 更新UI状态
        self._UI_MODEL_:SetAttribute("UI_STATE", newState)
    end
    return self
end

return UIBase