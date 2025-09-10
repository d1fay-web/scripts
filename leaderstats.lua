local Service = {
	Players = game:GetService("Players"),
	DataStoreService = game:GetService("DataStoreService"),
	ReplicatedStorage = game:GetService("ReplicatedStorage")
}

local LeaderstatsDataStore = Service.DataStoreService:GetDataStore("LeaderstatsData")

local LeaderstatsModule = {}
LeaderstatsModule.__index = LeaderstatsModule

local Defualt_Cash = 0
local Defualt_Rebirth = 0
local DATASTORE_RETRY_ATTEMPTS = 3
local DATASTORE_RETRY_DELAY = 1

local playerData = {}

function LeaderstatsModule.new(player)
	local self = setmetatable({}, LeaderstatsModule)
	self.Player = player
	self.Cash = Defualt_Cash
	self.Rebirth = Defualt_Rebirth
	self.LeaderstatsFolder = nil
	self:SetupLeaderstats()
	return self
end

function LeaderstatsModule:SetupLeaderstats()
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = self.Player

	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash💰"
	cashValue.Value = self.Cash
	cashValue.Parent = leaderstats

	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirth💫"
	rebirthValue.Value = self.Rebirth
	rebirthValue.Parent = leaderstats

	self.LeaderstatsFolder = leaderstats

	cashValue.Changed:Connect(function(newValue)
		self.Cash = newValue
		self:SaveDataAsync()
	end)

	rebirthValue.Changed:Connect(function(newValue)
		self.Rebirth = newValue
		self:SaveDataAsync()
	end)
end

function LeaderstatsModule:LoadDataAsync()
	local success, result
	for attempt = 1, DATASTORE_RETRY_ATTEMPTS do
		success, result = pcall(function()
			return LeaderstatsDataStore:GetAsync(self.Player.UserId)
		end)

		if success then
			if result then
				self.Cash = result.Cash or Defualt_Cash
				self.Rebirth = result.Rebirth or Defualt_Rebirth
				self.LeaderstatsFolder:FindFirstChild("Cash💰").Value = self.Cash
				self.LeaderstatsFolder:FindFirstChild("Rebirth💫").Value = self.Rebirth
			end
			return true
		else
			warn("Не удалось загрузить данные для " .. self.Player.Name .. ": " .. tostring(result))
			task.wait(DATASTORE_RETRY_DELAY)
		end
	end

	warn("Не удалось загрузить данные для " .. self.Player.Name .. " после " .. DATASTORE_RETRY_ATTEMPTS .. " попыток")
	return false
end

function LeaderstatsModule:SaveDataAsync()
	local success, result
	local data = {
		Cash = self.Cash,
		Rebirth = self.Rebirth
	}

	for attempt = 1, DATASTORE_RETRY_ATTEMPTS do
		success, result = pcall(function()
			return LeaderstatsDataStore:UpdateAsync(self.Player.UserId, function(oldData)
				return data
			end)
		end)

		if success then
			return true
		else
			warn("Не удалось сохранить данные для " .. self.Player.Name .. ": " .. tostring(result))
			task.wait(DATASTORE_RETRY_DELAY)
		end
	end

	warn("Не удалось сохранить данные для " .. self.Player.Name .. " после " .. DATASTORE_RETRY_ATTEMPTS .. " попыток")
	return false
end

function LeaderstatsModule:ModifyCash(amount, operation)
	if not self.LeaderstatsFolder then
		warn("LeaderstatsFolder отсутствует для " .. self.Player.Name)
		return false
	end

	local currentCash = self.Cash
	local newCash

	if operation == "Add" then
		newCash = currentCash + amount
	elseif operation == "Subtract" then
		newCash = math.max(0, currentCash - amount)
	elseif operation == "Set" then
		newCash = math.max(0, amount)
	else
		warn("Неверная операция для ModifyCash: " .. tostring(operation))
		return false
	end

	self.LeaderstatsFolder:FindFirstChild("Cash💰").Value = newCash
	return true
end

function LeaderstatsModule:ModifyRebirth(amount, operation)
	if not self.LeaderstatsFolder then
		warn("LeaderstatsFolder отсутствует для " .. self.Player.Name)
		return false
	end

	local currentRebirth = self.Rebirth
	local newRebirth

	if operation == "Add" then
		newRebirth = currentRebirth + amount
	elseif operation == "Set" then
		newRebirth = math.max(0, amount)
	else
		warn("Неверная операция для ModifyRebirth: " .. tostring(operation))
		return false
	end

	self.LeaderstatsFolder:FindFirstChild("Rebirth💫").Value = newRebirth
	return true
end

function LeaderstatsModule:Destroy()
	self:SaveDataAsync()
	if self.LeaderstatsFolder then
		self.LeaderstatsFolder:Destroy()
	end
	setmetatable(self, nil)
end

function LeaderstatsModule.Init()
	Service.Players.PlayerAdded:Connect(function(player)
		local leaderstats = LeaderstatsModule.new(player)
		playerData[player] = leaderstats
		leaderstats:LoadDataAsync()
	end)

	Service.Players.PlayerRemoving:Connect(function(player)
		local leaderstats = playerData[player]
		if leaderstats then
			leaderstats:Destroy()
			playerData[player] = nil
		end
	end)

	game:BindToClose(function()
		for player, leaderstats in pairs(playerData) do
			leaderstats:SaveDataAsync()
		end
	end)
end

function LeaderstatsModule:GetPlayerStats(player)
	return playerData[player]
end

return LeaderstatsModule