local TweenService = game:GetService("TweenService")
--- UI管理器
---@class UIMgr
---@field UI_Tips_Pool_Creater_Cache table<string, any> UI池创建器缓存（Tips类型UI专用）
---@field UI_Data_Cache table<string, any> UI数据缓存，key为UI名
---@field Tips_Cache_List table<number,any> Tips缓存列表
---@field UI_Cache_List table<number,any> UI缓存列表（顺序：Functional, Tab, ...）
---@field _cur_controller any 当前激活的Functional UIData
---@field _cur_functional_index number 当前Functional在UI_Cache_List中的索引
---@field _last_functional_index number 上一个Functional在UI_Cache_List中的索引
local UIMgr = require(game:GetService("ReplicatedStorage"):WaitForChild("Managers"):WaitForChild("Manager_Base")):__CreateNewManager__(script)

local UI_TYPE_ENUM = {
    Functional = "Functional", -- 功能性UI
    Tab = "Tab", -- 标签页UI
    Tips = "Tips", -- 提示UI
}

local replicatedStorage = game:GetService("ReplicatedStorage")
local startGui = game:GetService("StarterGui")
local uiModulesFolder = replicatedStorage:WaitForChild("UI")
local UIData = require(script:WaitForChild("UI_Data"))
local poolTool = require(replicatedStorage:WaitForChild("Utils"):WaitForChild("Pool_Tool"))

UIMgr.UI_Tips_Pool_Creater_Cache = {} -- UI池创建器缓存
UIMgr.UI_Data_Cache = {} -- UI数据缓存
UIMgr.Tips_Cache_List = {} -- Tips缓存
UIMgr.UI_Cache_List = {} -- UI缓存列表（顺序：Functional, Tab, ...）
UIMgr._cur_controller = nil -- 当前激活的Functional UIData
UIMgr._cur_functional_index = -1 -- 当前Functional在UI_Cache_List中的索引
UIMgr._last_functional_index = -1 -- 上一个Functional在UI_Cache_List中的索引

--- 初始化UI管理器，禁用所有ScreenGui
function UIMgr:Init()
    self.player = game:GetService("Players").LocalPlayer
    self.UI_Tips_Pool_Creater_Cache = {}
    self.UI_Data_Cache = {}
    self.Tips_Cache_List = {}
    self.UI_Cache_List = {}
    self._cur_controller = nil
    self._cur_functional_index = -1
    self._last_functional_index = -1

end

local function CloseUI(_data,_is_passive)
    if _data.module:IsInState(_data.module._UI_STATE_ENUM_.OPEN_EFFECT, _data.module._UI_STATE_ENUM_.CLOSE_EFFECT) then
        -- 如果Functional正在开启或关闭特效中，强制停止特效
        _data.module:ForceStopEffect(function()
            _data.params = _data.module:OnClose(_is_passive)
            if not _is_passive then _data.params = nil end
        end)
    else
        _data.params = _data.module:OnClose(_is_passive)
        if not _is_passive then _data.params = nil end
    end
end

local function OpenUI(_data,_is_passive,_parameters)
    if _data.module:IsInState(_data.module._UI_STATE_ENUM_.OPEN_EFFECT, _data.module._UI_STATE_ENUM_.CLOSE_EFFECT) then
        -- 如果Functional正在开启或关闭特效中，强制停止特效
        _data.module:ForceStopEffect(function()
            _data.module:OnOpen(_is_passive, _parameters)
        end)
    else
        _data.module:OnOpen(_is_passive, _parameters)
    end
end

--- 显示UI
---@param _ui_name string UI名称
---@param _parameters any? 传递给UI的参数（可选）
---@param _is_refresh_when_is_opened boolean? 如果UI已开启，是否强制刷新（可选）
function UIMgr:ShowUI(_ui_name, _parameters , _is_refresh_when_is_opened)
    if not _ui_name or type(_ui_name) ~= "string" then
        error("UIMgr:ShowUI - Invalid UI name provided.")
    end
    local data = self.UI_Data_Cache[_ui_name]
    if not data then
        data = self:_CreateNewUI(_ui_name)
    end
    -- print("UIDATA",data)
    if data.ui_type == "Tips" then
        -- Tips类型UI，池化管理，独立弹出
        local uiPool = self.UI_Tips_Pool_Creater_Cache[_ui_name]
        data = uiPool:Get()
        data.module:OnOpen(false, _parameters)
        table.insert(self.Tips_Cache_List, data)
        data.model.DisplayOrder = #self.Tips_Cache_List + 100 -- 设置显示层级
    else
        -- 检查是否已在UI_Cache_List中（即已开启）
        local inCache = false
        if table.find(self.UI_Cache_List, data) then inCache = data.model.Enabled end
        if inCache and _is_refresh_when_is_opened then
            -- 已开启且要求刷新
            if data.module and data.module.Refresh then
                data.module:Refresh(_parameters)
            end
            return
        end
        if data.ui_type == "Tab" then
            -- Tab只能在Functional下开启
            if not self._cur_controller then
                error("Tab UI must be opened under a Functional UI.")
            end
            -- 避免重复添加同一个Tab
            self._cur_controller.tabs = self._cur_controller.tabs or {}
            local alreadyInTabs = table.find(self._cur_controller.tabs, data)
            if not alreadyInTabs then
                table.insert(self._cur_controller.tabs, data)
            end
            OpenUI(data, false, _parameters)
            data.model.DisplayOrder = self._cur_controller.model.DisplayOrder + #self._cur_controller.tabs + 1 -- 设置显示层级
            -- 避免重复插入UI_Cache_List
            table.insert(self.UI_Cache_List, data)
        else
            -- Functional UI
            -- 关闭当前Functional及其下所有Tab
            if self._cur_controller and self._cur_controller ~= data then
                -- 记录上一个Functional的索引
                self._last_functional_index = self._cur_functional_index
                -- 计算上一个Functional及其所有Tab的最大DisplayOrder
                local maxDisplayOrder = self._cur_controller.model.DisplayOrder
                if self._cur_controller.tabs then
                    for _, tabData in ipairs(self._cur_controller.tabs) do
                        maxDisplayOrder = math.max(maxDisplayOrder, tabData.model.DisplayOrder)
                    end
                end
                -- 设置新的Functional的DisplayOrder
                data.model.DisplayOrder = maxDisplayOrder + 1
                -- 关闭当前Functional及其所有Tab
                if self._cur_controller.tabs then
                    for _, tabData in ipairs(self._cur_controller.tabs) do
                        CloseUI(tabData, true)
                    end
                end
                CloseUI(self._cur_controller, true)
            end
            data.tabs = data.tabs or {}
            self._cur_controller = data

            -- 记录当前Functional的索引（插入前，等价于#self.UI_Cache_List+1）
            self._cur_functional_index = #self.UI_Cache_List + 1

            OpenUI(data, false, _parameters)
            table.insert(self.UI_Cache_List, data)
        end
    end
end

--- 隐藏UI
---@param _ui_name string UI名称
function UIMgr:HideUI(_ui_name)
    if not _ui_name or type(_ui_name) ~= "string" then
        error("UIMgr:HideUI - Invalid UI name provided.")
    end
    local data = self.UI_Data_Cache[_ui_name]
    if not data then
        error("UIMgr:HideUI - UI not found: " .. _ui_name)
    end
    if data.ui_type == "Tips" then
        -- Tips类型UI，直接回收
        local uiPool = self.UI_Tips_Pool_Creater_Cache[_ui_name]
        uiPool:GiveBack(data)
        for i, v in ipairs(self.Tips_Cache_List) do
            if v == data then
                table.remove(self.Tips_Cache_List, i)
                break
            end
        end
    elseif data.ui_type == "Tab" then
        CloseUI(data, false)
        -- 从当前Functional的tabs移除
        if self._cur_controller and self._cur_controller.tabs then
            for i, v in ipairs(self._cur_controller.tabs) do
                if v == data then
                    table.remove(self._cur_controller.tabs, i)
                    break
                end
            end
        end
        -- 从UI_Cache_List移除
        for i, v in ipairs(self.UI_Cache_List) do
            if v == data then
                table.remove(self.UI_Cache_List, i)
                break
            end
        end
    else
        -- Functional关闭
        if data == self._cur_controller then
            -- 直接用记录的索引获取上一个Functional
            local lastFunctional = nil
            local maxDisplayOrder = 0
            if self._last_functional_index and self._last_functional_index > 0 then
                lastFunctional = self.UI_Cache_List[self._last_functional_index]
                if lastFunctional then
                    maxDisplayOrder = lastFunctional.model.DisplayOrder
                    if lastFunctional.tabs then
                        for _, tabData in ipairs(lastFunctional.tabs) do
                            maxDisplayOrder = math.max(maxDisplayOrder, tabData.model.DisplayOrder)
                        end
                    end
                end
            end
            -- 设置当前Functional的DisplayOrder
            data.model.DisplayOrder = maxDisplayOrder + 1
            -- 关闭所有Tab
            if data.tabs then
                for _, tabData in ipairs(data.tabs) do
                    CloseUI(tabData, false)
                end
                data.tabs = {}
            end
            -- 关闭自身
            CloseUI(data, false)
            -- 从UI_Cache_List移除
            for i = #self.UI_Cache_List, 1, -1 do
                if self.UI_Cache_List[i] == data then
                    table.remove(self.UI_Cache_List, i)
                    break
                end
            end
            -- 恢复上一个Functional及其Tab
            self._cur_controller = lastFunctional
            self._cur_functional_index = self._last_functional_index or -1
            -- 刷新_last_functional_index
            for i = self._cur_functional_index-1 ,1,-1 do
                if self.UI_Cache_List[i].ui_type == "Functional" then
                    self._last_functional_index = i
                    break
                end
            end
        
            if lastFunctional then
                OpenUI(lastFunctional, true, lastFunctional.params)
                if lastFunctional.tabs then
                    for _, tabData in ipairs(lastFunctional.tabs) do
                        OpenUI(tabData, true, tabData.params)
                    end
                end
            end
        else
            -- 关闭非当前Functional（极少见，通常不允许）
            CloseUI(data, false)
            for i, v in ipairs(self.UI_Cache_List) do
                if v == data then
                    table.remove(self.UI_Cache_List, i)
                    break
                end
            end
        end
    end
end

--- 创建新的UIData对象
---@param _ui_name string UI名称
---@return any 新创建的UIData对象
function UIMgr:_CreateNewUI(_ui_name)
    local ui_module = uiModulesFolder:FindFirstChild(_ui_name)
    if not ui_module then
        error("UIMgr:_CreateNewUI - UI module not found: " .. _ui_name)
    end
    ui_module = require(ui_module)
    local ui_model = self.player.PlayerGui:FindFirstChild(_ui_name)
    if not ui_model then
        error("UIMgr:_CreateNewUI - UI model not found in StarterGui: " .. _ui_name)
    end
    local uiData = UIData(ui_model, ui_module)
    local uiPool = nil
    if uiData.ui_type == "Tips" then
        -- Tips类型UI池化
        uiPool = poolTool(uiData,
            function(_uiData)
                local model = ui_model:Clone()
                model.Parent = self.player.PlayerGui
                local module = ui_module:Awake(model)
                local data = UIData(model, module)
                return data
            end,
            function(_uiData)
                _uiData.model.Enabled = false
                _uiData.params = nil
            end,
            function(_ui_obj)
                _ui_obj:Destroy()
            end
        )
        self.UI_Tips_Pool_Creater_Cache[_ui_name] = uiPool
        self.UI_Data_Cache[_ui_name] = uiData
    else
        self.UI_Data_Cache[_ui_name] = uiData
        uiData.module = uiData.module:Awake(ui_model)
    end
    return uiData
end

return UIMgr