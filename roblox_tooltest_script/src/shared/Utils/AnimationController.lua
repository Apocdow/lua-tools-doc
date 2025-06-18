--- AnimationController: 支持角色动画配置表的高级动画控制器
--- 自动从CharacterAnimationTable和AnimationTable读取配置，按需加载并缓存动画资源
---@class AnimationController
---@field animator Animator
---@field tracks table<string, AnimationTrack>
---@field anims table<string, Animation|string>
---@field characterId string 当前角色ID
local AnimationController = {}
AnimationController.__index = AnimationController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTable = nil require(ReplicatedStorage:WaitForChild("server"):WaitForChild("configs"):WaitForChild("AnimationTable"))
local CharacterAnimationTable = nil require(ReplicatedStorage:WaitForChild("server"):WaitForChild("configs"):WaitForChild("CharacterAnimationTable"))
local InsertService = game:GetService("InsertService")

--- 静态配置缓存表
AnimationController._characterAnimConfigMap = nil
AnimationController._animationIdMap = nil

--- 全局动画资源缓存表，所有控制器共享
AnimationController._animationAssetCache = AnimationController._animationAssetCache or {}

--- 解析Other字段，返回{name=AnimationId,...}
---@param str string Other字段内容
---@return table<string, string> 解析后的动画名到动画ID的映射
local function parseOther(str)
    local t = {}
    for pair in string.gmatch(str or "", "[^;]+") do
        local name, id = string.match(pair, "([^:]+):([^:]+)")
        if name and id then t[name] = id end
    end
    return t
end

--- 支持链式调用的方法（无明确返回值，返回self） ---

---
--- 初始化配置表映射（只需调用一次）
--- @return AnimationController self
function AnimationController:InitConfig()
    if AnimationController._inited then return self end
    AnimationController._inited = true
    -- 角色动画配置表映射：characterId -> {key=AnimationId,...}
    AnimationController._characterAnimConfigMap = {}
    for characterId, cfg in pairs(CharacterAnimationTable) do
        -- 复制配置表，移除Other项
        local newCfg = {}
        for key, value in pairs(cfg) do
            if key ~= "Other" then
                newCfg[key] = value
            end
        end
        -- 处理Other项，将其解析为多个自定义动画名:动画ID，直接合并到newCfg
        if cfg.Other and cfg.Other ~= "" then
            local otherMap = parseOther(cfg.Other)
            for name, animId in pairs(otherMap) do
                newCfg[name] = animId
            end
        end
        AnimationController._characterAnimConfigMap[characterId] = newCfg
    end
    -- 动画ID映射表：动画配置ID -> AnimationId
    AnimationController._animationIdMap = {}
    for animId, animCfg in pairs(AnimationTable) do
        AnimationController._animationIdMap[animId] = animCfg.AnimationId or animId
    end
    return self
end

---
--- 通过CharacterID加载所有动画配置到anims表（使用映射表）
--- @param characterId string 角色ID
--- @return AnimationController self
function AnimationController:LoadCharacterAnimations(characterId)
    -- 如果当前已存在动画列表，先停止所有动画，防止残留
    if self.anims and next(self.anims) then
        self:StopAllAnims()
    end
    self.characterId = characterId
    self.anims = {}
    local charCfg = AnimationController._characterAnimConfigMap and AnimationController._characterAnimConfigMap[characterId] or CharacterAnimationTable[characterId]
    if not charCfg then error("No config for characterId:"..tostring(characterId)) end
    -- 遍历配置表，加载每个动画（已无Other项，所有自定义名已合并进来）
    for key, animId in pairs(charCfg) do
        if animId ~= "" then
            local realId = AnimationController._animationIdMap and AnimationController._animationIdMap[animId] or (AnimationTable[animId] and AnimationTable[animId].AnimationId or animId)
            self.anims[key] = self:_getOrLoadAnimation(realId)
        end
    end
    return self
end

---
--- 播放动画
--- @param name string 动画名（如Jump/Run/Other自定义名）
--- @param fadeTime number? 淡入时间
--- @param weight number? 权重
--- @param looped boolean? 是否循环
--- @return AnimationController self, AnimationTrack|nil track
function AnimationController:PlayAnim(name, fadeTime, weight, looped)
    -- 获取动画实例
    local anim = self.anims[name]
    if not anim then warn("No animation for:", name) return self, nil end
    -- 加载并播放动画
    local track = self.animator:LoadAnimation(anim)
    if looped ~= nil then track.Looped = looped end
    track:Play(fadeTime or 0.1, weight or 1)
    self.tracks[name] = track
    -- 自动清理：动画停止时移除引用，防止内存泄漏
    track.Stopped:Connect(function()
        if self.tracks[name] == track then
            self.tracks[name] = nil
        end
        -- 可选：销毁track释放内存
        if track.Destroy then pcall(function() track:Destroy() end) end
    end)
    return self, track
end

---
--- 停止动画
--- @param name string 动画名
--- @return AnimationController self
function AnimationController:StopAnim(name)
    -- 停止指定动画
    local track = self.tracks[name]
    if track then
        track:Stop()
    end
    return self
end

---
--- 停止所有动画
--- @return AnimationController self
function AnimationController:StopAllAnims()
    -- 停止所有已缓存的动画Track
    for name, track in pairs(self.tracks) do
        track:Stop()
        -- track.Stopped事件会自动清理self.tracks[name]
    end
    return self
end

---
--- 接管动画控制权（禁用 Animate 脚本，完全由 AnimationController 控制）
--- @return AnimationController self
function AnimationController:TakeOverControl()
    if not self.character then return self end
    local animateScript = self.character:FindFirstChild("Animate")
    if animateScript and not animateScript.Disabled then
        animateScript.Disabled = true
    end
    return self
end

---
--- 归还动画控制权（启用 Animate 脚本，恢复默认动画控制）
--- @return AnimationController self
function AnimationController:ReturnControl()
    if not self.character then return self end
    local animateScript = self.character:FindFirstChild("Animate")
    if animateScript and animateScript.Disabled then
        animateScript.Disabled = false
    end
    self:StopAllAnims()
    return self
end

--- 有明确返回值的方法（如new、PlayAnim、IsPlaying等） ---

---
--- 构造函数
--- @param character Model 角色模型
--- @param characterId string 角色ID
--- @return AnimationController
function AnimationController.new(character, characterId)
    local self = setmetatable({}, AnimationController)
    -- 优先查找Humanoid下的Animator
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        -- 若无则查找模型下的Animator
        animator = character:FindFirstChildOfClass("Animator")
    end
    if not animator then
        -- 若还没有则自动创建一个Animator
        animator = Instance.new("Animator")
        if humanoid then
            animator.Parent = humanoid
        else
            animator.Parent = character
        end
    end
    self.animator = animator
    self.tracks = {}
    self.character = character
    self:LoadCharacterAnimations(characterId)
    return self
end

---
--- 加载动画资源并缓存（全局缓存）
--- @param animId string 动画ID
--- @return Animation|nil 加载到的Animation实例
function AnimationController:_getOrLoadAnimation(animId)
    -- 全局缓存优先
    AnimationController._animationAssetCache = AnimationController._animationAssetCache or {}
    if AnimationController._animationAssetCache[animId] then
        return AnimationController._animationAssetCache[animId]
    end
    -- 动态加载动画资源
    local success, asset = pcall(function()
        return InsertService:LoadAsset(animId)
    end)
    if success and asset then
        -- 优先查找顶层Animation
        local anim = asset:FindFirstChildOfClass("Animation")
        if not anim then
            -- 递归查找所有子节点中的Animation
            for _, v in ipairs(asset:GetDescendants()) do
                if v:IsA("Animation") then anim = v break end
            end
        end
        if anim then
            AnimationController._animationAssetCache[animId] = anim -- 全局缓存
            return anim
        end
    end
    warn("Animation asset not found or failed to load:", animId)
    return nil
end

---
--- 检查动画是否正在播放
--- @param name string 动画名
--- @return boolean
function AnimationController:IsPlaying(name)
    -- 检查指定动画Track是否正在播放
    local track = self.tracks[name]
    return track and track.IsPlaying or false
end

return AnimationController:InitConfig()

--[=[
使用示例：

-- 1. 服务启动时初始化配置（只需一次）
local AnimationController = require(path.to.AnimationController)
AnimationController:InitConfig()

-- 2. 创建角色动画控制器
local character = ... -- 你的角色模型（玩家、NPC、宠物等）
local characterId = "Hero001" -- 角色ID，对应CharacterAnimationTable配置
local animCtrl = AnimationController.new(character, characterId)

-- 3. 链式调用示例
animCtrl:TakeOverControl()
       :StopAllAnims()
       :LoadCharacterAnimations("Pet001")
       :PlayAnim("Idle")

-- 4. 播放动画
animCtrl:PlayAnim("Run")
animCtrl:PlayAnim("Jump", 0.2, 1, false)
animCtrl:PlayAnim("MyCustomAnim") -- 支持Other自定义名

-- 5. 停止动画
animCtrl:StopAnim("Run")

-- 6. 停止所有动画
animCtrl:StopAllAnims()

-- 7. 检查动画是否正在播放
if animCtrl:IsPlaying("Jump") then
    print("Jump动画正在播放")
end

-- 8. 动画资源全局缓存，所有控制器共享，无需重复加载

-- 9. 动态切换角色动画配置（如切换为新角色、皮肤、宠物等）
-- 只需调用 LoadCharacterAnimations(newCharacterId)，即可切换动画表，无需重新创建控制器
local newCharacterId = "Pet001" -- 新角色/宠物ID
animCtrl:LoadCharacterAnimations(newCharacterId)
-- 之后可直接播放新配置下的动画
animCtrl:PlayAnim("Idle")
]=]