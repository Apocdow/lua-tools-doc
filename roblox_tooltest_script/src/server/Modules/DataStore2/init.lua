--[[
	DataStore2：一个用于数据存储的封装器，用于缓存和保存玩家数据。

	DataStore2(dataStoreName, player) - 返回一个 DataStore2 数据存储对象

	DataStore2 数据存储对象方法:
	- Get([defaultValue])         -- 获取数据（可选默认值）
	- Set(value)                  -- 设置数据
	- Update(updateFunc)          -- 使用函数更新数据
	- Increment(value, defaultValue) -- 增加数据（可选默认值）
	- BeforeInitialGet(modifier)  -- 在首次获取前修改数据
	- BeforeSave(modifier)        -- 在保存前修改数据
	- Save()                      -- 保存数据
	- SaveAsync()                 -- 异步保存数据
	- OnUpdate(callback)          -- 数据更新时回调
	- BindToClose(callback)       -- 关闭时回调

	local coinStore = DataStore2("Coins", player)

	给玩家增加金币：

	coinStore:Increment(50)

	获取当前玩家金币数：

	coinStore:Get()
--]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(script.Constants)
local IsPlayer = require(script.IsPlayer)
local Promise = require(script.Promise)
local SavingMethods = require(script.SavingMethods)
local Settings = require(script.Settings)
local TableUtil = require(script.TableUtil)
local Verifier = require(script.Verifier)

local SaveInStudioObject = ServerStorage:FindFirstChild("SaveInStudio")
local SaveInStudio = SaveInStudioObject and SaveInStudioObject.Value

local function clone(value)
	if typeof(value) == "table" then
		return TableUtil.clone(value)
	else
		return value
	end
end

--DataStore对象
local DataStore = {}

--内部函数
function DataStore:Debug(...)
	if self.debug then
		print("[DataStore2.Debug]", ...)
	end
end

function DataStore:_GetRaw()
	if self.getRawPromise then
		return self.getRawPromise
	end

	self.getRawPromise = self.savingMethod:Get():andThen(function(value)
		self.value = value
		self:Debug("value received")
		self.haveValue = true
		self.getting = false
	end):catch(function(reason)
		self.getting = false
		self.getRawPromise = nil
		return Promise.reject(reason)
	end)

	return self.getRawPromise
end

function DataStore:_Update(dontCallOnUpdate)
	if not dontCallOnUpdate then
		for _, callback in ipairs(self.callbacks) do
			callback(self.value, self)
		end
	end

	self.haveValue = true
	self.valueUpdated = true
end

--公开函数

function DataStore:Get(defaultValue, dontAttemptGet)
	if dontAttemptGet then
		return self.value
	end

	local backupCount = 0

	if not self.haveValue then
		while not self.haveValue do
			local success, error = self:_GetRaw():await()

			if not success then
				if self.backupRetries then
					backupCount = backupCount + 1

					if backupCount >= self.backupRetries then
						self.backup = true
						self.haveValue = true
						self.value = self.backupValue
						break
					end
				end

				self:Debug("Get returned error:", error)
			end
		end

		if self.value ~= nil then
			for _, modifier in ipairs(self.beforeInitialGet) do
				self.value = modifier(self.value, self)
			end
		end
	end

	local value

	if self.value == nil and defaultValue ~= nil then --not using "not" because false is a possible value
		value = defaultValue
	else
		value = self.value
	end

	value = clone(value)

	self.value = value

	return value
end

function DataStore:GetAsync(...)
	return Promise.promisify(function(...)
		return self:Get(...)
	end)(...)
end

function DataStore:GetTable(default, ...)
	local success, result = self:GetTableAsync(default, ...):await()
	if not success then
		error(result)
	end
	return result
end

function DataStore:GetTableAsync(default, ...)
	assert(default ~= nil, "你必须提供一个默认值。")

	return self:GetAsync(default, ...):andThen(function(result)
		local changed = false
		assert(
			typeof(result) == "table",
			":GetTable/:GetTableAsync was used when the value in the data store isn't a table."
		)

		for defaultKey, defaultValue in pairs(default) do
			if result[defaultKey] == nil then
				result[defaultKey] = defaultValue
				changed = true
			end
		end

		if changed then
			self:Set(result)
		end

		return result
	end)
end

function DataStore:Set(value, _dontCallOnUpdate)
	self.value = clone(value)
	self:_Update(_dontCallOnUpdate)
end

function DataStore:Update(updateFunc)
	self.value = updateFunc(self.value)
	self:_Update()
end

function DataStore:Increment(value, defaultValue)
	self:Set(self:Get(defaultValue) + value)
end

function DataStore:IncrementAsync(add, defaultValue)
	return self:GetAsync(defaultValue):andThen(function(value)
		return Promise.promisify(function()
			self:Set(value + add)
		end)()
	end)
end

function DataStore:OnUpdate(callback)
	table.insert(self.callbacks, callback)
end

function DataStore:BeforeInitialGet(modifier)
	table.insert(self.beforeInitialGet, modifier)
end

function DataStore:BeforeSave(modifier)
	self.beforeSave = modifier
end

function DataStore:AfterSave(callback)
	table.insert(self.afterSave, callback)
end

--[[**
	<description>
	如果 :Get() 失败指定次数，则为数据存储添加备份。
	将返回提供的值（如果该值为 nil，则返回 :Get() 的默认值），
	并将数据存储标记为备份存储，尝试 :Save() 时不会真正保存。
	</description>

	<parameter name = "retries">
	在使用备份前的重试次数。
	</parameter>

	<parameter name = "value">
	在失败情况下 :Get() 返回的值。
	可以留空，则使用 :Get() 提供的默认值。
	</parameter>
**--]]
function DataStore:SetBackup(retries, value)
	self.backupRetries = retries
	self.backupValue = value
end

--[[**
	<description>
	取消数据存储的备份标记，并重置 :Get() 和相关值为 nil。
	</description>
**--]]
function DataStore:ClearBackup()
	self.backup = nil
	self.haveValue = false
	self.value = nil
	self.getRawPromise = nil
end

--[[**
	<returns>
	判断数据存储是否为备份存储，如果是则 :Save() 不会保存且不会调用 :AfterSave()。
	</returns>
**--]]
function DataStore:IsBackup()
	return self.backup ~= nil --some people haven't learned if x then yet, and will do if x == false then.
end

--[[**
	<description>
	保存数据到数据存储。玩家离开时调用。
	</description>
**--]]
function DataStore:Save()
	local success, result = self:SaveAsync():await()

	if success then
		print("saved", self.Name)
	else
		error(result)
	end
end

--[[**
	<description>
	异步保存数据到数据存储。
	</description>
**--]]
function DataStore:SaveAsync()
	return Promise.async(function(resolve, reject)
		if not self.valueUpdated then
			warn(("Data store %s was not saved as it was not updated."):format(self.Name))
			resolve(false)
			return
		end

		if RunService:IsStudio() and not SaveInStudio then
			warn(("Data store %s attempted to save in studio while SaveInStudio is false."):format(self.Name))
			if not SaveInStudioObject then
				warn("You can set the value of this by creating a BoolValue named SaveInStudio in ServerStorage.")
			end
			resolve(false)
			return
		end

		if self.backup then
			warn("This data store is a backup store, and thus will not be saved.")
			resolve(false)
			return
		end

		if self.value ~= nil then
			local save = clone(self.value)

			if self.beforeSave then
				local success, result = pcall(self.beforeSave, save, self)

				if success then
					save = result
				else
					reject(result, Constants.SaveFailure.BeforeSaveError)
					return
				end
			end

			local problem = Verifier.testValidity(save)
			if problem then
				reject(problem, Constants.SaveFailure.InvalidData)
				return
			end

			return self.savingMethod:Set(save):andThen(function()
				resolve(true, save)
			end)
		end
	end):andThen(function(saved, save)
		if saved then
			for _, afterSave in ipairs(self.afterSave) do
				local success, err = pcall(afterSave, save, self)

				if not success then
					warn("Error on AfterSave:", err)
				end
			end

			self.valueUpdated = false
		end
	end)
end

function DataStore:BindToClose(callback)
	table.insert(self.bindToClose, callback)
end

function DataStore:GetKeyValue(key)
	return (self.value or {})[key]
end

function DataStore:SetKeyValue(key, newValue)
	if not self.value then
		self.value = self:Get({})
	end

	self.value[key] = newValue
end

local CombinedDataStore = {}

do
	function CombinedDataStore:BeforeInitialGet(modifier)
		self.combinedBeforeInitialGet = modifier
	end

	function CombinedDataStore:BeforeSave(modifier)
		self.combinedBeforeSave = modifier
	end

	function CombinedDataStore:Get(defaultValue, dontAttemptGet)
		local tableResult = self.combinedStore:Get({})
		local tableValue = tableResult[self.combinedName]

		if not dontAttemptGet then
			if tableValue == nil then
				tableValue = defaultValue
			else
				if self.combinedBeforeInitialGet and not self.combinedInitialGot then
					tableValue = self.combinedBeforeInitialGet(tableValue)
				end
			end
		end

		self.combinedInitialGot = true
		tableResult[self.combinedName] = clone(tableValue)
		self.combinedStore:Set(tableResult, true)
		return clone(tableValue)
	end

	function CombinedDataStore:Set(value, dontCallOnUpdate)
		return self.combinedStore:GetAsync({}):andThen(function(tableResult)
			tableResult[self.combinedName] = value
			self.combinedStore:Set(tableResult, dontCallOnUpdate)
			self:_Update(dontCallOnUpdate)
		end)
	end

	function CombinedDataStore:Update(updateFunc)
		self:Set(updateFunc(self:Get()))
	end

	function CombinedDataStore:Save()
		self.combinedStore:Save()
	end

	function CombinedDataStore:OnUpdate(callback)
		if not self.onUpdateCallbacks then
			self.onUpdateCallbacks = {callback}
		else
			table.insert(self.onUpdateCallbacks, callback)
		end
	end

	function CombinedDataStore:_Update(dontCallOnUpdate)
		if not dontCallOnUpdate then
			for _, callback in ipairs(self.onUpdateCallbacks or {}) do
				callback(self:Get(), self)
			end
		end

		self.combinedStore:_Update(true)
	end

	function CombinedDataStore:SetBackup(retries)
		self.combinedStore:SetBackup(retries)
	end
end

local DataStoreMetatable = {}

DataStoreMetatable.__index = DataStore

--库
local DataStoreCache = {}

local DataStore2 = {}
local combinedDataStoreInfo = {}

--[[**
	<description>
	运行一次，将所有提供的 key 合并到一个“主 key”下。
	内部实现为数据以主 key 为表存储。
	用于绕过 2-DataStore2 的可靠性限制。
	</description>

	<parameter name = "mainKey">
	用于存储表的主 key。
	</parameter>

	<parameter name = "...">
	需要合并到一个表下的所有 key。
	</parameter>
**--]]
function DataStore2.Combine(mainKey, ...)
	for _, name in ipairs({...}) do
		combinedDataStoreInfo[name] = mainKey
	end
end

function DataStore2.ClearCache()
	DataStoreCache = {}
end

function DataStore2.SaveAll(player)
	if DataStoreCache[player] then
		for _, dataStore in pairs(DataStoreCache[player]) do
			if dataStore.combinedStore == nil then
				dataStore:Save()
			end
		end
	end
end

DataStore2.SaveAllAsync = Promise.promisify(DataStore2.SaveAll)

function DataStore2.PatchGlobalSettings(patch)
	for key, value in pairs(patch) do
		assert(Settings[key] ~= nil, "不存在该设置项: " .. key)
		-- TODO: 当 osyris 的 t 可用时实现类型检查
		Settings[key] = value
	end
end

function DataStore2.__call(_, dataStoreName, player)
	assert(
		typeof(dataStoreName) == "string" and IsPlayer.Check(player),
		("DataStore2() API 调用期望参数为 {string dataStoreName, Player player}，实际为 {%s, %s}")
		:format(
			typeof(dataStoreName),
			typeof(player)
		)
	)

	if DataStoreCache[player] and DataStoreCache[player][dataStoreName] then
		return DataStoreCache[player][dataStoreName]
	elseif combinedDataStoreInfo[dataStoreName] then
		local dataStore = DataStore2(combinedDataStoreInfo[dataStoreName], player)

		dataStore:BeforeSave(function(combinedData)
			for key in pairs(combinedData) do
				if combinedDataStoreInfo[key] then
					local combinedStore = DataStore2(key, player)
					local value = combinedStore:Get(nil, true)
					if value ~= nil then
						if combinedStore.combinedBeforeSave then
							value = combinedStore.combinedBeforeSave(clone(value))
						end
						combinedData[key] = value
					end
				end
			end

			return combinedData
		end)

		local combinedStore = setmetatable({
			combinedName = dataStoreName,
			combinedStore = dataStore,
		}, {
			__index = function(_, key)
				return CombinedDataStore[key] or dataStore[key]
			end,
		})

		if not DataStoreCache[player] then
			DataStoreCache[player] = {}
		end

		DataStoreCache[player][dataStoreName] = combinedStore
		return combinedStore
	end

	local dataStore = {
		Name = dataStoreName,
		UserId = player.UserId,
		callbacks = {},
		beforeInitialGet = {},
		afterSave = {},
		bindToClose = {},
	}

	dataStore.savingMethod = SavingMethods[Settings.SavingMethod].new(dataStore)

	setmetatable(dataStore, DataStoreMetatable)

	local saveFinishedEvent, isSaveFinished = Instance.new("BindableEvent"), false
	local bindToCloseEvent = Instance.new("BindableEvent")

	local bindToCloseCallback = function()
		if not isSaveFinished then
			-- 延迟以避免连接和触发 "saveFinishedEvent" 之间的竞争
			Promise.defer(function()
				bindToCloseEvent:Fire() -- 触发 Promise.race 保存数据
			end)

			saveFinishedEvent.Event:Wait()
		end

		local value = dataStore:Get(nil, true)

		for _, bindToClose in ipairs(dataStore.bindToClose) do
			bindToClose(player, value)
		end
	end

	local success, errorMessage = pcall(function()
		game:BindToClose(function()
			if bindToCloseCallback == nil then
				return
			end
	
			bindToCloseCallback()
		end)
	end)
	if not success then
		warn("DataStore2 无法 BindToClose", errorMessage)
	end

	Promise.race({
		Promise.fromEvent(bindToCloseEvent.Event),
		Promise.fromEvent(player.AncestryChanged, function()
			return not player:IsDescendantOf(game)
		end),
	}):andThen(function()
		dataStore:SaveAsync():andThen(function()
			print("玩家离开，已保存", dataStoreName)
		end):catch(function(error)
			-- TODO: 更优雅的处理
			warn("玩家离开时出错！", error)
		end):finally(function()
			isSaveFinished = true
			saveFinishedEvent:Fire()
		end)

		-- 给未清理缓存的开发者一个较长的延迟 :^(
		return Promise.delay(40):andThen(function() 
			DataStoreCache[player] = nil
			bindToCloseCallback = nil
		end)
	end)

	if not DataStoreCache[player] then
		DataStoreCache[player] = {}
	end

	DataStoreCache[player][dataStoreName] = dataStore

	return dataStore
end

DataStore2.Constants = Constants

return setmetatable(DataStore2, DataStore2)
