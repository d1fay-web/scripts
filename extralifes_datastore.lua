local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local GROUP_ID = 17242483
local MINIMUM_RANK = 3
local ENABLE_LIVES_FOR_RANK = true
local ProfileTemplate = {
    Lives = 0,
    ReceivedGroupBonus = false
}
local ProfileService = require(game.ServerStorage.ProfileService)
local ProfileStore = ProfileService.GetProfileStore("PlayerData", ProfileTemplate)
local Profiles = {}

local function HasRequiredRank(player)
    local success, rank = pcall(function()
        return player:GetRankInGroup(GROUP_ID)
    end)
    if success then
        return rank >= MINIMUM_RANK
    else
        warn("[ОШИБКА] Не удалось проверить ранг для " .. player.Name .. ": " .. rank)
        return false
    end
end

local function IsInGroup(player)
    local success, result = pcall(function()
        return player:IsInGroup(GROUP_ID)
    end)
    if success then
        return result
    else
        warn("[ОШИБКА] Не удалось проверить членство в группе для " .. player.Name .. ": " .. result)
        return false
    end
end

local function PlayerAdded(player)
    local success, err = pcall(function()
        local value = Instance.new("IntValue")
        value.Name = "Lives"
        value.Parent = player
        local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
        if profile ~= nil then
            profile:AddUserId(player.UserId)
            profile:Reconcile()
            profile:ListenToRelease(function()
                Profiles[player] = nil
                player:Kick()
            end)
            if player:IsDescendantOf(Players) then
                Profiles[player] = profile
                if ENABLE_LIVES_FOR_RANK and HasRequiredRank(player) then
                    Profiles[player].Data.Lives += 1
                elseif IsInGroup(player) and not Profiles[player].Data.ReceivedGroupBonus then
                    Profiles[player].Data.Lives += 1
                    Profiles[player].Data.ReceivedGroupBonus = true
                elseif Profiles[player].Data.Lives <= 0 then
                    Profiles[player].Data.Lives = 0
                end
                player.PlayerGui:WaitForChild("Top_things_idkk"):WaitForChild("Frame"):WaitForChild("Framed"):WaitForChild("TextLabel").Text = Profiles[player].Data.Lives
                value.Value = Profiles[player].Data.Lives
            else
                profile:Release()
            end
        else
            player:Kick()
        end
    end)
end

local function UpdateLives(player)
    if not Profiles[player] then return end
    player:WaitForChild("Lives").Value = Profiles[player].Data.Lives
    player.PlayerGui:WaitForChild("Top_things_idkk"):WaitForChild("Frame"):WaitForChild("Framed"):WaitForChild("TextLabel").Text = Profiles[player].Data.Lives
end

local function UpdateDeaths(Player)
    task.spawn(function()
        local success, err = pcall(function()
            local DataStore = DataStoreService:GetGlobalDataStore()
            local Current_Death = DataStore:GetAsync("Client_2"..Player.UserId) or {0}
            DataStore:SetAsync("Client_2"..Player.UserId, {Current_Death[1] + 1})
        end)
        if not success then
            warn("[ОШИБКА] Не удалось обновить счетчик смертей для " .. Player.Name .. ": " .. err)
        end
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(PlayerAdded, player)
end

Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    local profile = Profiles[player]
    if profile ~= nil then
        profile:Release()
    end
end)

local function CheckLives(player)
    if Profiles[player] then
        return Profiles[player].Data.Lives
    else
        warn("[ОШИБКА] Профиль не найден для " .. player.Name .. " в CheckLives")
        return 0
    end
end

ReplicatedStorage.RemoteEvents.UpdateDeaths.OnServerEvent:Connect(UpdateDeaths)
game.ReplicatedStorage.Lives.OnServerInvoke = CheckLives

game.ReplicatedStorage.RespawnPlayer.OnServerEvent:Connect(function(plr)
    if not Profiles[plr] then
        warn("[ОШИБКА] Профиль не найден для " .. plr.Name .. " в Respawn")
        return
    end
    if ENABLE_LIVES_FOR_RANK and HasRequiredRank(plr) then
        Profiles[plr].Data.Lives += 1
    else
        if Profiles[plr].Data.Lives < 0 then
            return
        end
        Profiles[plr].Data.Lives -= 1
    end
    UpdateLives(plr)
end)