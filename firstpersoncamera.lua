local FirstPersonCamera = {}
FirstPersonCamera.__index = FirstPersonCamera

function FirstPersonCamera.new(config)
	local self = setmetatable({}, FirstPersonCamera)
	self.config = config or {}
	self.canToggleMouse = self.config.canToggleMouse or {allowed = true, activationKey = Enum.KeyCode.F}
	
	self.canViewBody = self.config.canViewBody or true
	
	self.sensitivity = self.config.sensitivity
	self.smoothness = self.config.smoothness
	self.fieldOfView = self.config.fieldOfView
	
	self.player = game:GetService("Players").LocalPlayer
	self.camera = workspace.CurrentCamera
	
	self.mouse = self.player:GetMouse()
	self.mouse.Icon = "http://www.roblox.com/asset/?id=569021388"
	
	self.runService = game:GetService("RunService")
	self.inputService = game:GetService("UserInputService")
	
	self.freeMouse = false
	self.running = true
	
	self.camPos = self.camera.CoordinateFrame.Position
	self.targetCamPos = self.camera.CoordinateFrame.Position
	
	self.angleX = 0
	self.targetAngleX = 0
	self.angleY = 0
	self.targetAngleY = 0
	
	self.thumbstickPosition = Vector2.new(0, 0)
	
	self.dragTouch = nil
	self.lastTouchPosition = Vector3.new()
	
	self.gamepadHorizontalSpeed = 180
	self.gamepadVerticalSpeed = 120
	
	self.character = self.player.Character

	if not self.character then
		self.character = self.player.CharacterAdded:Wait()
	end

	self:SetupCharacter()
	self.connections = {}

	table.insert(self.connections, self.player.CharacterAdded:Connect(function(char)
		self.character = char
		self:SetupCharacter()
	end))

	table.insert(self.connections, self.inputService.InputBegan:Connect(function(input)
		self:OnInputBegan(input)
	end))

	table.insert(self.connections, self.inputService.InputChanged:Connect(function(input)
		self:OnInputChanged(input)
	end))

	table.insert(self.connections, self.inputService.InputEnded:Connect(function(input)
		self:OnInputEnded(input)
	end))

	table.insert(self.connections, self.runService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end))

	return self
end

function FirstPersonCamera:SetupCharacter()
	repeat task.wait() until self.character:FindFirstChild("Head") and self.character:FindFirstChild("HumanoidRootPart") and self.character:FindFirstChild("Humanoid")
	
	self.head = self.character.Head
	self.rootPart = self.character.HumanoidRootPart
	self.humanoid = self.character.Humanoid
	self.humanoid.AutoRotate = false
	self:UpdateTransparency()

	self.camera.FieldOfView = self.fieldOfView

	if self.characterChildAddedConnection then
		self.characterChildAddedConnection:Disconnect()
	end
	
	self.characterChildAddedConnection = self.character.ChildAdded:Connect(function(child)
		if child:IsA("Accessory") then
			self:UpdateTransparency()
		end
	end)
end

function FirstPersonCamera:UpdateTransparency()
	for _, child in pairs(self.character:GetChildren()) do
		if child.Name == "Head" then
			child.Transparency = 1
			child.CanCollide = false
		elseif child:IsA("Accessory") then
				if child.AccessoryType == Enum.AccessoryType.Hat 
				or child.AccessoryType == Enum.AccessoryType.Face
				or child.AccessoryType == Enum.AccessoryType.Hair then
					local handle = child:WaitForChild("Handle", 3)
					if handle then
						handle.Transparency = 1
						handle.CanCollide = false
					end
				end
		elseif not self.canViewBody then
			if child:IsA("BasePart") or child:IsA("UnionOperation") or child:IsA("MeshPart") then
				child.Transparency = 1
				child.CanCollide = false
			end
		end
	end
end

function FirstPersonCamera:OnInputBegan(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == self.canToggleMouse.activationKey and self.canToggleMouse.allowed then
			self.freeMouse = not self.freeMouse
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		self.dragTouch = input
		self.lastTouchPosition = input.Position
	end
end

function FirstPersonCamera:OnInputChanged(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local rawDelta = Vector2.new(input.Delta.X, input.Delta.Y)
		local delta = (rawDelta / self.sensitivity) * self.smoothness
		local x = self.targetAngleX - delta.Y
		self.targetAngleX = math.clamp(x, -80, 80)
		self.targetAngleY = (self.targetAngleY - delta.X) % 360
	elseif input.UserInputType == Enum.UserInputType.Touch then
		if input == self.dragTouch then
			local rawDelta = input.Position - self.lastTouchPosition
			local delta = (rawDelta / self.sensitivity) * self.smoothness
			local x = self.targetAngleX - delta.Y
			self.targetAngleX = math.clamp(x, -80, 80)
			self.targetAngleY = (self.targetAngleY - delta.X) % 360
			self.lastTouchPosition = input.Position
		end
	elseif input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
		self.thumbstickPosition = Vector2.new(input.Position.X, input.Position.Y)
	end
end

function FirstPersonCamera:OnInputEnded(input)
	if input.UserInputType == Enum.UserInputType.Touch and input == self.dragTouch then
		self.dragTouch = nil
	end
end

function FirstPersonCamera:Update(dt)
	if not self.character or not self.head or not self.rootPart or not self.humanoid then
		return
	end

	if self.inputService.GamepadEnabled then
		self.targetAngleY = (self.targetAngleY - self.thumbstickPosition.X * self.gamepadHorizontalSpeed * dt) % 360
		local x = self.targetAngleX - self.thumbstickPosition.Y * self.gamepadVerticalSpeed * dt
		self.targetAngleX = math.clamp(x, -80, 80)
	end

	self.bobbingTime = self.bobbingTime or 0
	local bobbingOffset = Vector3.new(0, 0, 0)
	local moveDirection = self.humanoid.MoveDirection
	local isMoving = moveDirection.Magnitude > 0
	local isRunning = self.humanoid.WalkSpeed > 16
	local bobbingAmplitude = 0
	local bobbingFrequency = 0

	if isMoving then
		if isRunning then
			bobbingAmplitude = 0.2
			bobbingFrequency = 12
		else
			bobbingAmplitude = 0.1
			bobbingFrequency = 8 
		end
		self.bobbingTime = self.bobbingTime + dt * bobbingFrequency
		local verticalBob = math.sin(self.bobbingTime) * bobbingAmplitude
		local horizontalBob = math.cos(self.bobbingTime * 0.5) * bobbingAmplitude * 0.5
		bobbingOffset = Vector3.new(horizontalBob, verticalBob, 0)
	else
		self.bobbingTime = 0
	end

	if self.running then
		self.camPos = self.camPos + (self.targetCamPos - self.camPos) * 0.28
		self.angleX = self.angleX + (self.targetAngleX - self.angleX) * 0.35
		local dist = self.targetAngleY - self.angleY
		if math.abs(dist) > 180 then
			dist = dist - (math.sign(dist) * 360)
		end
		self.angleY = (self.angleY + dist * 0.35) % 360

		self.camera.CameraType = Enum.CameraType.Scriptable
		local cameraCFrame = CFrame.new(self.head.Position) *
			CFrame.Angles(0, math.rad(self.angleY), 0) *
			CFrame.Angles(math.rad(self.angleX), 0, 0) *
			CFrame.new(0, 0.8, 0) *
			CFrame.new(bobbingOffset)
		self.camera.CFrame = cameraCFrame
		self.rootPart.CFrame = CFrame.new(self.rootPart.Position) * CFrame.Angles(0, math.rad(self.angleY), 0)
		self.humanoid.AutoRotate = false
	else
		self.inputService.MouseBehavior = Enum.MouseBehavior.Default
		self.humanoid.AutoRotate = true
	end

	local distance = (self.camera.Focus.Position - self.camera.CoordinateFrame.Position).Magnitude
	if distance < 1 then
		self.running = false
	else
		self.running = true
		if self.inputService.MouseEnabled then
			if self.freeMouse then
				self.inputService.MouseBehavior = Enum.MouseBehavior.Default
			else
				self.inputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			end
		end
	end

	if not self.canToggleMouse.allowed then
		self.freeMouse = false
	end
end

local config = {
	canToggleMouse = {allowed = true, activationKey = Enum.KeyCode.F},
	canViewBody = true,
	sensitivity = 0.2,
	smoothness = 0.1,
	fieldOfView = 75
}

local firstPersonCamera = FirstPersonCamera.new(config)