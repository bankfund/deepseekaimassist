-- Universial Aim Assist
-- Totally Not Made By ChatGPT

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local Camera = WS.CurrentCamera
local TweenService = game:GetService("TweenService")

local Config = {
    -- Core Settings
    ToggleKey = Enum.KeyCode.E,
    RotationKey = Enum.KeyCode.Z,
    FOV = 120,
    Smoothness = 0.3,
    Prediction = 0.1227,
    
    -- Easing Configuration
    EasingStyle = Enum.EasingStyle.Linear,  -- All styles: Linear, Sine, Quad, Cubic, Quart, Quint, 
    EasingDirection = Enum.EasingDirection.InOut,  -- All directions: In, Out, InOut
    
    -- Rotation Settings
    RotationSpeed = 3000, -- 2500-3500 degrees/sec
    RotationSmoothness = 0.2, -- Lower = snappier, Higher = smoother
    
    -- Visuals
    FOVColor = Color3.new(0, 0, 0),
    LockColor = Color3.new(0, 0, 0),
    FOVThickness = 1,
    
    -- Target Parts
    AimParts = {
        "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", -- R6
        "UpperTorso", "LowerTorso", "HumanoidRootPart", -- R15
        "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"
    }
}

-- System Initialization
local LocalPlayer = Players.LocalPlayer
local FOV = Drawing.new("Circle")
local LockedTarget = {Player = nil, Part = nil, Humanoid = nil}
local ActiveTween = nil

-- Rotation System
local rotationActive = false
local rotationProgress = 0
local rotationStartCFrame = CFrame.new()
local rotationStartTime = 0

-- FOV Setup
FOV.Visible = true
FOV.Filled = true
FOV.Transparency = 0.4
FOV.Color = Config.FOVColor
FOV.Thickness = Config.FOVThickness
FOV.NumSides = 128
FOV.Radius = Config.FOV
FOV.Position = Camera.ViewportSize / 2

-- Validation Functions
local function ValidateTarget(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    if char:FindFirstChildOfClass("ForceField") then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function GetValidParts(character)
    local validParts = {}
    for _, partName in pairs(Config.AimParts) do
        local part = character:FindFirstChild(partName)
        if part then table.insert(validParts, part) end
    end
    return validParts
end

local function FindClosestPart(character)
    local closestPart, minDistance = nil, math.huge
    local screenCenter = Camera.ViewportSize / 2
    for _, part in pairs(GetValidParts(character)) do
        local screenPos = Camera:WorldToViewportPoint(part.Position)
        if screenPos.Z > 0 then
            local distance = (screenCenter - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
            if distance < minDistance then
                closestPart = part
                minDistance = distance
            end
        end
    end
    return closestPart
end

-- Lock System
local function AcquireOrReleaseLock()
    if not LockedTarget.Player then
        local closestPlayer, closestPart, minDist = nil, nil, Config.FOV
        
        for _, player in Players:GetPlayers() do
            if ValidateTarget(player) then
                local character = player.Character
                local part = FindClosestPart(character)
                if part then
                    local screenPos = Camera:WorldToViewportPoint(part.Position)
                    local distance = (Camera.ViewportSize/2 - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                    if distance < minDist then
                        closestPlayer, closestPart, minDist = player, part, distance
                    end
                end
            end
        end
        
        if closestPlayer then
            LockedTarget.Player = closestPlayer
            LockedTarget.Part = closestPart
            LockedTarget.Humanoid = closestPlayer.Character:FindFirstChildOfClass("Humanoid")
            FOV.Color = Config.LockColor
        end
    else
        LockedTarget.Player = nil
        LockedTarget.Part = nil
        LockedTarget.Humanoid = nil
        FOV.Color = Config.FOVColor
        if ActiveTween then ActiveTween:Cancel() end
    end
end

-- Aim System
local function SmoothAim(targetPos)
    if ActiveTween then ActiveTween:Cancel() end
    ActiveTween = TweenService:Create(
        Camera,
        TweenInfo.new(
            Config.Smoothness,
            Config.EasingStyle,
            Config.EasingDirection
        ),
        {CFrame = CFrame.new(Camera.CFrame.Position, targetPos)}
    )
    ActiveTween:Play()
end

-- Enhanced Rotation System
local function HandleRotation(deltaTime)
    if not rotationActive then return end
    
    local currentTime = tick()
    local elapsed = currentTime - rotationStartTime
    
    -- Smooth acceleration curve
    local progress = math.min(elapsed / Config.RotationSmoothness, 1)
    local smoothFactor = math.sin(progress * math.pi/2)
    
    local targetRotation = math.rad(Config.RotationSpeed * elapsed)
    Camera.CFrame = rotationStartCFrame * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), targetRotation * smoothFactor)
    
    -- Auto-complete at 360°
    if targetRotation >= math.rad(360) then
        rotationActive = false
        Camera.CFrame = rotationStartCFrame
        if LockedTarget.Part then
            local predictedPos = LockedTarget.Part.Position + (LockedTarget.Part.Velocity * Config.Prediction)
            SmoothAim(predictedPos)
        end
    end
end

-- Input Handling
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Config.ToggleKey then
        AcquireOrReleaseLock()
    elseif input.KeyCode == Config.RotationKey then
        if not rotationActive then
            rotationStartCFrame = Camera.CFrame
            rotationStartTime = tick()
            if ActiveTween then ActiveTween:Cancel() end
        end
        rotationActive = not rotationActive
    end
end)

-- Main Loop
RS.RenderStepped:Connect(function(deltaTime)
    HandleRotation(deltaTime)
    if rotationActive then return end

    FOV.Position = Camera.ViewportSize / 2
    
    if LockedTarget.Player and LockedTarget.Part then
        if not ValidateTarget(LockedTarget.Player) then
            AcquireOrReleaseLock()
            return
        end
        
        LockedTarget.Part = FindClosestPart(LockedTarget.Player.Character) or LockedTarget.Part
        
        if LockedTarget.Part and LockedTarget.Part.Parent then
            local predictedPos = LockedTarget.Part.Position + 
                (LockedTarget.Part.Velocity * Config.Prediction)
            SmoothAim(predictedPos)
        else
            AcquireOrReleaseLock()
        end
    end
end)

warn("NiggaWare Universial has loaded...")