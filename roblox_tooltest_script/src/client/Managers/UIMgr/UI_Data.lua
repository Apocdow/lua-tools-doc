--- UIData: 用于存储UI相关数据的类，提供数据的获取和设置功能。
---@class UIData
---@field model Instance UI模型对象
---@field module table UI逻辑模块
---@field ui_type string UI类型（Functional/Tab/Tips）
---@field ui_name string UI名称
---@field params any UI参数（用于状态恢复）
---@field tabs table? 仅Functional类型UI使用，存储其下Tab
local UIData = {}
UIData.__index = UIData

UIData.model = nil -- UI模型对象
UIData.module = nil -- UI逻辑模块
UIData.ui_type = nil -- UI类型
UIData.ui_name = nil -- UI名称
UIData.params = nil -- UI参数（用于状态恢复）
UIData.tabs = nil -- 仅Functional类型UI使用，存储其下Tab

--- 创建一个新的UIData实例
---@param _model Instance UI模型对象
---@param _module table UI逻辑模块
---@return UIData 新的UIData实例
function UIData.new(_model, _module)
    local instance = setmetatable({}, UIData)
    instance.model = _model
    instance.module = _module
    instance.ui_type = _model:GetAttribute("Type")
    instance.ui_name = _model.Name
    instance.params = nil
    if instance.ui_type == "Functional" then
        instance.tabs = {}
    end
    return instance
end

return UIData.new