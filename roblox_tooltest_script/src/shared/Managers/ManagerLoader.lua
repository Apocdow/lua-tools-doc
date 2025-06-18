-- ManagerLoader: 支持依赖、类型标识、循环依赖检测的统一Manager加载器
-- 用法： 自动加载当前用户端Mgr ManagerLoader()
--      或手动调用 ManagerLoader:LoadAllManagers(mgrTable, currentType)
-- mgrTable: { [name]=MgrModule, ... }，currentType: 'server'|'client'|'shared'

local ManagerLoader = {}
local ManagerBase = require(game:GetService("ReplicatedStorage"):WaitForChild("Managers"):WaitForChild("Manager_Base"))

local RequiredMgrs = nil  -- 存储所有已加载必需的Mgr，供外部使用

local RunService = game:GetService("RunService")

---
--- 扫描并require所有有效的Mgr模块（支持三端分文件夹，自动过滤非Mgr脚本）
--- @return table<string, table> mgrTable 名称到Mgr实例的映射
local function scanAndRequireAllMgrs()
    local mgrTable = {}
    local isServer = RunService:IsServer()
    local isClient = RunService:IsClient()
    local folders = {}
    -- 服务器端Mgr目录
    if isServer then
        local sss = game:GetService("ServerScriptService")
        local serverFolder = sss:FindFirstChild("Managers")
        if serverFolder then table.insert(folders, serverFolder) end
    end
    -- 客户端Mgr目录
    if isClient then
        local sps = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
        local clientFolder = sps and sps:FindFirstChild("Managers")
        if clientFolder then table.insert(folders, clientFolder) end
    end
    -- 共享Mgr目录
    local rs = game:GetService("ReplicatedStorage")
    local sharedMgrFolder = rs:FindFirstChild("Managers")
    if sharedMgrFolder then table.insert(folders, sharedMgrFolder) end

    for _, folder in ipairs(folders) do
        for _, moduleScript in ipairs(folder:GetChildren()) do
            if moduleScript:IsA("ModuleScript") then
                -- 排除自身和ManagerBase
                if moduleScript.Name == "ManagerLoader" or moduleScript.Name == "Manager_Base" then
                    continue
                end
                local ok, mgr = pcall(require, moduleScript)
                if not ok then
                    warn(string.format("ManagerLoader: 加载模块 %s 失败: %s", moduleScript:GetFullName(), tostring(mgr)))
                elseif not ManagerBase:__IsManager__(mgr) then
                    warn(string.format("ManagerLoader: 模块 %s 不是有效的Manager（未继承ManagerBase）", moduleScript:GetFullName()))
                else
                    mgrTable[moduleScript.Name] = mgr
                end
            end
        end
    end
    return mgrTable
end

---
--- 判断Mgr类型是否与当前端类型匹配
--- @param mgr table Mgr实例
--- @param currentType string 当前端类型（'server'|'client'|'shared'）
--- @return boolean 是否匹配
local function typeMatch(mgr, currentType)
    local t = mgr:__GetManagerOwner__()
    if currentType == 'server' then
        return t == 'S' or t == 'B'
    elseif currentType == 'client' then
        return t == 'C' or t == 'B'
    end
    return false
end

---
--- 拓扑排序，保证依赖先于被依赖项加载，检测循环依赖和依赖项缺失
--- @param mgrTable table<string, table> 所有Mgr
--- @param currentType string 当前端类型
--- @return string[] 按依赖顺序排序的Mgr名称列表
local function topoSort(mgrTable, currentType)
    local sorted, visited, visiting = {}, {}, {}
    -- 分类
    local globallyNames, normalNames, leavesNames = {}, {}, {}
    for name, mgr in pairs(mgrTable) do
        if typeMatch(mgr, currentType) then
            local mgrType = mgr.__GetManagerType__ and mgr:__GetManagerType__() or "Normal"
            if mgrType == "Globally" then
                table.insert(globallyNames, name)
            elseif mgrType == "Leaves" then
                table.insert(leavesNames, name)
            else
                table.insert(normalNames, name)
            end
        end
    end
    -- 递归访问Mgr依赖
    local function visit(name, extraDeps)
        if visited[name] then return end
        if visiting[name] then error('ManagerLoader: 检测到循环依赖: '..name) end
        visiting[name] = true
        local mgr = mgrTable[name]
        if not mgr then error('ManagerLoader: 依赖的Mgr未找到: '..name) end
        if typeMatch(mgr, currentType) then
            local deps = mgr:__GetDependencies__() or {}
            -- 自动依赖
            if extraDeps then
                for _, gname in ipairs(extraDeps) do
                    table.insert(deps, gname)
                end
            end
            for _, dep in ipairs(deps) do
                if not mgrTable[dep] then
                    error(string.format('ManagerLoader: Mgr "%s" 依赖的 "%s" 不存在或未被正确加载', name, dep))
                end
                visit(dep, extraDeps)
            end
            table.insert(sorted, name)
        end
        visiting[name] = false
        visited[name] = true
    end
    -- 先处理Globally
    for _, name in ipairs(globallyNames) do
        visit(name)
    end
    -- 再处理Normal
    for _, name in ipairs(normalNames) do
        visit(name)
    end
    -- Leaves类型最后
    for _, name in ipairs(leavesNames) do
        visit(name)
    end
    return sorted
end

---
--- 加载并初始化所有Mgr，保证依赖顺序，抛出详细错误
--- @param mgrTable table<string, table> 名称到Mgr实例的映射
--- @param currentType string 当前端类型
--- @return string[] 已初始化的Mgr名称列表
function ManagerLoader:LoadAllManagers(mgrTable, currentType)
    local order = topoSort(mgrTable, currentType)
    local inited = {}
    for _, name in ipairs(order) do
        local mgr = mgrTable[name]
        if mgr and mgr.Init then
            local ok, err = pcall(function() mgr:Init(ManagerLoader) end)
            if not ok then
                error(string.format('ManagerLoader: 初始化Mgr "%s" 失败: %s', name, tostring(err)))
            end
            inited[#inited+1] = name
        else
            warn(string.format('ManagerLoader: Mgr "%s" 缺少Init方法，已跳过', name))
        end
    end
    return inited
end

---
--- 自动扫描、加载并初始化所有Mgr（根据当前端类型）
--- @return string[] 已初始化的Mgr名称列表
function ManagerLoader:LoadAllManagersAuto()
    if RequiredMgrs then return self end
    RequiredMgrs = {
        client = {},
        server = {},
        shared = {}
    }  -- 初始化RequiredMgrs表
    -- 扫描并加载Mgr模块
    local currentType = RunService:IsServer() and 'server' or 'client'
    local mgrTable = scanAndRequireAllMgrs()
    local list = ManagerLoader:LoadAllManagers(mgrTable, currentType)
    -- 更新RequiredMgrs表
    for _, name in ipairs(list) do
        -- 将Mgr实例添加到对应的RequiredMgrs表中
        local mgr = mgrTable[name]
        mgr.ML = ManagerLoader
        if mgr then
            if mgr:__IsShared__() then
                RequiredMgrs.shared[name] = mgr
            elseif mgr:__IsServer__() then
                RequiredMgrs.server[name] = mgr
            elseif mgr:__IsClient__() then
                RequiredMgrs.client[name] = mgr
            else
                warn(string.format("ManagerLoader: Mgr '%s' has an unknown type, skipping.", name))
            end
        else
            warn(string.format("ManagerLoader: Mgr '%s' not found in loaded modules.", name))
        end
    end
    return self
end

setmetatable(ManagerLoader, { 
    __call = function()
        return ManagerLoader:LoadAllManagersAuto()
    end,
    __index = function(_, key)
        if RequiredMgrs then
            -- 如果 Mgr是共享类型，则直接放回该Mgr 否则 根据当前端类型返回对应的Mgr 
            if RequiredMgrs.shared[key] then
                return RequiredMgrs.shared[key]
            elseif RequiredMgrs.server[key] and RunService:IsServer() then
                return RequiredMgrs.server[key]
            elseif RequiredMgrs.client[key] and RunService:IsClient() then
                return RequiredMgrs.client[key]
            else
                return nil  -- 如果没有找到对应的Mgr，则返回nil
            end
        else
            error(string.format("ManagerLoader: Mgr '%s' not found. Please ensure it is loaded.", key))
        end
    end
})

return ManagerLoader
