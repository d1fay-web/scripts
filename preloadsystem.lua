local Players = game:GetService("Players")

local ContentProvider = game:GetService("ContentProvider")

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local player = Players.LocalPlayer

local MAX_CONCURRENT_LOADS = 25

local ASSET_TYPES = {

    Image = {"ImageLabel", "ImageButton"},

    Sound = {"Sound"},

    Animation = {"Animation"},

    Model = {"Model"},

    MeshPart = {"MeshPart"},

}

local AssetLoader = {}

AssetLoader.__index = AssetLoader

function AssetLoader.new()

    local self = setmetatable({}, AssetLoader)

    self.AssetCache = {}

    self.PriorityQueue = {}

    self.DeferredQueue = {}

    self.LoadedCount = 0

    self.TotalAssets = 0

    self.IsLoading = false

    self.ProgressCallback = nil

    return self

end

function AssetLoader:CategorizeAsset(asset)

    for assetType, classNames in pairs(ASSET_TYPES) do

        for _, className in ipairs(classNames) do

            if asset:IsA(className) then

                return assetType, (assetType == "Image" and asset.Image) or (assetType == "Sound" and asset.SoundId) or (assetType == "Animation" and asset.AnimationId) or asset:GetFullName()

            end

        end

    end

    return "Other", asset:GetFullName()

end

function AssetLoader:CollectAssets(priorityAreas)

    priorityAreas = priorityAreas or {ReplicatedFirst, game.StarterGui}

    local function processDescendants(container, priority)

        if not container then return end

        for _, asset in ipairs(container:GetDescendants()) do

            local assetType, assetId = self:CategorizeAsset(asset)

            if assetId and not self.AssetCache[assetId] then

                self.AssetCache[assetId] = { Asset = asset, Type = assetType, Priority = priority, Loaded = false }

                table.insert(self.PriorityQueue, {AssetId = assetId, Priority = priority})

                self.TotalAssets = self.TotalAssets + 1

            end

        end

    end

    for priority, area in ipairs(priorityAreas) do

        processDescendants(area, priority)

    end

    self.DeferredQueue = {ReplicatedStorage, workspace}

    table.sort(self.PriorityQueue, function(a, b) return a.Priority < b.Priority end)

end

function AssetLoader:LoadBatch(batch)

    local success, error = pcall(function()

        ContentProvider:PreloadAsync(batch)

    end)

    if not success then

        print("Ошибка загрузки пакета:", error)

    end

    return success

end

function AssetLoader:PreloadAssets(callback)

    if self.IsLoading then return end

    self.IsLoading = true

    self.ProgressCallback = callback

    local function updateProgress()

        if self.ProgressCallback then

            self.ProgressCallback(self.LoadedCount / self.TotalAssets)

        end

    end

    local function processQueue(queue, onComplete)

        local toLoad = {}

        for _, entry in ipairs(queue) do

            local assetData = self.AssetCache[entry.AssetId]

            if assetData and not assetData.Loaded then

                table.insert(toLoad, assetData.Asset)

            end

        end

        local activeLoads = 0

        local completedLoads = 0

        local function loadNextBatch()

            while #toLoad > 0 and activeLoads < MAX_CONCURRENT_LOADS do

                local batchSize = math.min(10, #toLoad)

                local batch = table.move(toLoad, 1, batchSize, 1, {})

                for i = 1, batchSize do

                    table.remove(toLoad, 1)

                end

                activeLoads = activeLoads + 1

                task.spawn(function()

                    if self:LoadBatch(batch) then

                        for _, asset in ipairs(batch) do

                            local _, assetId = self:CategorizeAsset(asset)

                            if self.AssetCache[assetId] then

                                self.AssetCache[assetId].Loaded = true

                                self.LoadedCount = self.LoadedCount + 1

                            end

                        end

                    end

                    activeLoads = activeLoads - 1

                    completedLoads = completedLoads + batchSize

                    updateProgress()

                    if activeLoads < MAX_CONCURRENT_LOADS and #toLoad > 0 then

                        loadNextBatch()

                    elseif activeLoads == 0 and #toLoad == 0 then

                        onComplete()

                    end

                end)

            end

        end

        if #toLoad > 0 then

            loadNextBatch()

        else

            onComplete()

        end

    end

    processQueue(self.PriorityQueue, function()

        local function processDeferred()

            for _, area in ipairs(self.DeferredQueue) do

                for _, asset in ipairs(area:GetDescendants()) do

                    local assetType, assetId = self:CategorizeAsset(asset)

                    if assetId and not self.AssetCache[assetId] then

                        self.AssetCache[assetId] = { Asset = asset, Type = assetType, Priority = 3, Loaded = false }

                        table.insert(self.PriorityQueue, {AssetId = assetId, Priority = 3})

                        self.TotalAssets = self.TotalAssets + 1

                    end

                end

            end

            processQueue(self.PriorityQueue, function()

                self:OnLoadingComplete()

            end)

        end

        if game:IsLoaded() then

            processDeferred()

        else

            game.Loaded:Connect(processDeferred)

        end

    end)

end

function AssetLoader:OnLoadingComplete()

    self.IsLoading = false

    print(string.format("【 Загружено %d/%d активов успешно 】", self.LoadedCount, self.TotalAssets))

end

function AssetLoader:OptimizeGame()

    local playerGui = player:WaitForChild("PlayerGui", 5)

    if not playerGui then return function() end end

    local originalStates = {}

    for _, element in ipairs(playerGui:GetDescendants()) do

        if element:IsA("GuiObject") then

            originalStates[element] = element.Enabled

            element.Enabled = false

        end

    end

    return function()

        for element, state in pairs(originalStates) do

            element.Enabled = state

        end

    end

end

local function LoadGame()

    local loader = AssetLoader.new()

    local progressCallback = function(progress) end

    local restoreFunction = loader:OptimizeGame()

    loader:CollectAssets()

    loader:PreloadAssets(progressCallback)

    RunService.Heartbeat:Connect(function()

        if not loader.IsLoading then

            restoreFunction()

        end

    end)

end

LoadGame()