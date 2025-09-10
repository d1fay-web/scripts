local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")
local userinputservice = game:GetService("UserInputService")
local tweenservice = game:GetService("TweenService")
local runservice = game:GetService("RunService")
local player = players.LocalPlayer
local playergui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local humanoidrootpart = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera
local settings = require(script.CrouchSystemSettings)

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local runsystem = character:WaitForChild("Systems"):WaitForChild("RunSystem")
local animations = {
    idleCrouch = animator:LoadAnimation(script.CrouchSystemSettings.Animations.IdleCrouch),
    movingCrouch = animator:LoadAnimation(script.CrouchSystemSettings.Animations.MovingCrouch)
}

animations.idleCrouch.Priority = Enum.AnimationPriority.Idle
animations.movingCrouch.Priority = Enum.AnimationPriority.Idle

local crouchactive = false
local ismoving = false
local camerainfo = TweenInfo.new(settings.tween_duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local crouchtween = tweenservice:Create(humanoid, camerainfo, {CameraOffset = settings.camera_offset_crouch})
local uncrouchtween = tweenservice:Create(humanoid, camerainfo, {CameraOffset = settings.camera_offset_default})
local cameracrouchfov = tweenservice:Create(camera, camerainfo, {FieldOfView = settings.crouch_fov})
local camerauncrouchfov = tweenservice:Create(camera, camerainfo, {FieldOfView = settings.base_fov})

local function loadanimation(animationobject)
    local animator = animator or Instance.new("Animator", humanoid)
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track.Name == animationobject.Name then
            return track
        end
    end
    return animator:LoadAnimation(animationobject)
end

local function startcrouching()
    crouchactive = true
    humanoid.WalkSpeed = settings.crouch_speed
    humanoidrootpart.CanCollide = false
    character:SetAttribute("CanRun", false)
    
    if player then
        local char = player.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                local animt = hum:FindFirstChild("Animator")
                if animt then
                    local playinganimations = animt:GetPlayingAnimationTracks()
                    local targetanimations = runsystem.RunSystemSettings.Animations
                    local runanim = targetanimations.RunAnimation
                    local toolanim = targetanimations.ToolAnimation
                    local lanternanim = targetanimations.LanternsAnimation
                    
                    coroutine.wrap(function()
                        for i = 1, #playinganimations do
                            local animtrack = playinganimations[i]
                            if animtrack == runanim or animtrack == toolanim or animtrack == lanternanim then
                                animtrack:Stop(0.1)
                            end
                        end
                    end)()
                end
            end
        end
    end
    
    crouchtween:Play()
    cameracrouchfov:Play()
    character:SetAttribute("Crouching", true)
    ismoving = humanoid.MoveDirection.Magnitude > 0
    
    if ismoving then
        animations.movingCrouch:Play(settings.animation_fade_time)
    else
        animations.idleCrouch:Play(settings.animation_fade_time)
    end
end

local function stopcrouching()
    crouchactive = false
    humanoid.WalkSpeed = settings.walk_speed
    humanoidrootpart.CanCollide = true
    character:SetAttribute("CanRun", true)
    uncrouchtween:Play()
    camerauncrouchfov:Play()
    character:SetAttribute("Crouching", false)
    animations.idleCrouch:Stop(settings.animation_fade_time)
    animations.movingCrouch:Stop(settings.animation_fade_time)
    ismoving = false
end

local function togglecrouch()
    if crouchactive then
        stopcrouching()
    else
        startcrouching()
    end
end

runservice.Heartbeat:Connect(function()
    local ismovingnow = humanoid.MoveDirection.Magnitude > 0
    if crouchactive then
        for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
            if track.Name == "RunAnimation" then
                track:Stop(settings.animation_fade_time)
            end
        end
        if ismovingnow and not ismoving then
            animations.idleCrouch:Stop(settings.animation_fade_time)
            animations.movingCrouch:Play(settings.animation_fade_time)
            ismoving = true
        elseif not ismovingnow and ismoving then
            animations.movingCrouch:Stop(settings.animation_fade_time)
            animations.idleCrouch:Play(settings.animation_fade_time)
            ismoving = false
        end
    end
end)

playergui:WaitForChild("Stamina_UI"):WaitForChild("Crouch"):WaitForChild("ImageButton").Activated:Connect(togglecrouch)

userinputservice.InputBegan:Connect(function(input, gameprocessed)
    if gameprocessed then return end
    if userinputservice.KeyboardEnabled and
        (input.KeyCode == settings.crouch_key_pc or input.KeyCode == settings.crouch_key_alt_pc) then
        startcrouching()
    elseif userinputservice.GamepadEnabled and input.KeyCode == settings.crouch_button_console then
        togglecrouch()
    end
end)

userinputservice.InputEnded:Connect(function(input, gameprocessed)
    if gameprocessed then return end
    if userinputservice.KeyboardEnabled and
        (input.KeyCode == settings.crouch_key_pc or input.KeyCode == settings.crouch_key_alt_pc) then
        stopcrouching()
    end
end)

replicatedstorage:WaitForChild("StopCrouch").Event:Connect(stopcrouching)

player.CharacterAdded:Connect(function(newcharacter)
    character = newcharacter
    humanoid = character:WaitForChild("Humanoid")
    animator = humanoid:WaitForChild("Animator")
    humanoidrootpart = character:WaitForChild("HumanoidRootPart")
    runsystem = character:WaitForChild("Systems"):WaitForChild("RunSystem")
    animations.idleCrouch = loadanimation(script:WaitForChild("IdleCrouch"))
    animations.movingCrouch = loadanimation(script:WaitForChild("MovingCrouch"))
    animations.idleCrouch.Priority = Enum.AnimationPriority.Idle
    animations.movingCrouch.Priority = Enum.AnimationPriority.Action4
    crouchactive = false
    ismoving = false
end)